// MetalShaders.metal - Metal Shading Language shaders for C4JRender
// Handles all vertex types: standard, compressed, lit, and texgen.
// Provides fog (linear/exponential), lighting (2 directional + ambient),
// alpha test, texture sampling, and texture generation modes.

#include <metal_stdlib>
using namespace metal;

// Maximum number of directional lights supported
#define MAX_LIGHTS 2

// Temporary debugging toggles.
#define DEBUG_VISUALIZE_BASE_TEXTURE 0
#define DEBUG_VISUALIZE_SOLID_WHITE 0
#define DEBUG_VISUALIZE_UV_GRADIENT 0
#define DEBUG_BYPASS_TEXTURE_MATRIX 0
#define DEBUG_VISUALIZE_VERTEX_PATH 0
#define DEBUG_DISABLE_LIGHT_TEXTURE 0
#define DEBUG_DISABLE_FOG 0

// Shared uniform data passed from CPU to GPU each draw call
struct Uniforms {
    float4x4 modelview_matrix;
    float4x4 projection_matrix;
    float4x4 texture_matrix;

    // Per-vertex colour tint
    float4 colour_tint;             // StateSetColour RGBA

    // Fog parameters
    float4 fog_colour;              // RGB fog colour, A unused
    float  fog_near;                // Linear fog start distance
    float  fog_far;                 // Linear fog end distance
    float  fog_density;             // Exponential fog density
    int    fog_mode;                // 0 = linear, 1 = exp, 2 = exp2
    int    fog_enable;              // 1 if fog enabled

    // Lighting parameters
    int    lighting_enable;         // 1 if lighting enabled
    int    light_enable[MAX_LIGHTS]; // Per-light enable flag
    float4 light_colour[MAX_LIGHTS]; // Directional light RGB
    float4 light_direction[MAX_LIGHTS]; // World-space light direction (normalized)
    float4 ambient_colour;          // Global ambient light colour

    // Alpha test parameters
    int    alpha_test_enable;       // 1 if alpha test enabled
    int    alpha_test_func;         // Comparison function index
    float  alpha_test_ref;          // Reference value for alpha test

    // Texture generation columns (S, T, R, Q)
    float4 texgen_col[4];          // TexGen plane equations
    int    texgen_enable;           // 1 if texgen mode active
    int    texgen_eye_space;        // 1 if eye-space, 0 if object-space

    // Vertex texture UV offset (for vertex texture fetch)
    float2 vertex_texture_uv;

    // Force LOD for pixel shader
    int    force_lod;

    // Gamma correction value
    float  gamma;
};

// Standard vertex: Position(3f), TexCoord(2f), Colour(4b), Normal(4b), Tex2(2 x int16) = 32 bytes
struct VertexStandard {
    float3 position  [[attribute(0)]];
    float2 texcoord  [[attribute(1)]];
    uchar4 colour    [[attribute(2)]];
    char4  normal    [[attribute(3)]];
    short2 texcoord2 [[attribute(4)]];
};

// Compressed vertex format used by the non-Xbox client path:
// 8 x int16_t per vertex = x, y, z, rgb565, u, v, tex2u, tex2v.
struct VertexCompressed {
    short4 position_and_colour [[attribute(0)]];
    short4 uv_and_aux          [[attribute(1)]];
};

// Vertex shader output / fragment shader input
struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
    float2 light_texcoord;
    float4 colour;
    float3 normal;
    float  fog_factor;             // 0.0 = fully fogged, 1.0 = no fog
};

// Vertex shader output for lines (no texture needed)
struct VertexOutLine {
    float4 position [[position]];
    float4 colour;
    float  fog_factor;
};

static float4 to_metal_clip_space(float4 clip_pos)
{
    clip_pos.z = (clip_pos.z + clip_pos.w) * 0.5;
    return clip_pos;
}

static float4 decode_standard_vertex_colour(uchar4 packed_colour, constant Uniforms &uniforms)
{
    float4 colour = float4(packed_colour.w, packed_colour.z, packed_colour.y, packed_colour.x) / 255.0;
    return colour * uniforms.colour_tint;
}

static float2 decode_light_texcoord(short2 packed_texcoord, constant Uniforms &uniforms)
{
    if (packed_texcoord.x == -512 && packed_texcoord.y == -512) {
        return uniforms.vertex_texture_uv;
    }
    return float2(packed_texcoord) / 256.0;
}

static float4 sample_game_texture(
    texture2d<float> tex,
    sampler tex_sampler,
    float2 encoded_uv)
{
    float2 sample_uv = encoded_uv;
    bool disable_mipmap = sample_uv.x > 1.0;
    if (disable_mipmap) {
        sample_uv.x -= 1.0;
        return tex.sample(tex_sampler, sample_uv, level(0.0));
    }
    return tex.sample(tex_sampler, sample_uv);
}

// ------------------------------------------------------------------
// Helper: compute fog factor from eye-space Z distance
// ------------------------------------------------------------------
static float compute_fog_factor(float eye_distance, constant Uniforms &u)
{
    if (!u.fog_enable) {
        return 1.0; // No fog
    }

    float fog = 1.0;
    float dist = abs(eye_distance);

    if (u.fog_mode == 0) {
        // Linear fog
        float range = u.fog_far - u.fog_near;
        if (range > 0.0) {
            fog = (u.fog_far - dist) / range;
        }
    } else if (u.fog_mode == 1) {
        // Exponential fog
        fog = exp(-u.fog_density * dist);
    } else {
        // Exponential squared fog
        float exponent = u.fog_density * dist;
        fog = exp(-(exponent * exponent));
    }

    return clamp(fog, 0.0, 1.0);
}

// ------------------------------------------------------------------
// Helper: apply directional lighting to a vertex
// ------------------------------------------------------------------
static float4 apply_lighting(float3 world_normal, float4 vertex_colour, constant Uniforms &u)
{
    if (!u.lighting_enable) {
        return vertex_colour;
    }

    // Start with ambient light
    float3 lit_colour = u.ambient_colour.rgb;

    // Add contribution from each directional light
    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (u.light_enable[i]) {
            float n_dot_l = max(dot(normalize(world_normal), normalize(u.light_direction[i].xyz)), 0.0);
            lit_colour += u.light_colour[i].rgb * n_dot_l;
        }
    }

    // Multiply vertex colour by lighting result
    return float4(vertex_colour.rgb * clamp(lit_colour, 0.0, 1.0), vertex_colour.a);
}

// ------------------------------------------------------------------
// VERTEX SHADER: Standard vertex type (VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1)
// ------------------------------------------------------------------
vertex VertexOut vertex_standard(
    VertexStandard in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;

    // Transform position: projection * modelview * position
    float4 world_pos = uniforms.modelview_matrix * float4(in.position, 1.0);
    out.position = to_metal_clip_space(uniforms.projection_matrix * world_pos);

    // Pass through texture coordinates, transformed by texture matrix
    float4 tex_transformed = uniforms.texture_matrix * float4(in.texcoord, 0.0, 1.0);
#if DEBUG_BYPASS_TEXTURE_MATRIX
    out.texcoord = in.texcoord;
#else
    out.texcoord = tex_transformed.xy;
#endif
    out.light_texcoord = decode_light_texcoord(in.texcoord2, uniforms);

    out.colour = decode_standard_vertex_colour(in.colour, uniforms);
#if DEBUG_VISUALIZE_VERTEX_PATH
    out.colour = float4(0.0, 1.0, 0.0, 1.0);
#endif

    // Unpack signed normal from bytes (-128..127 -> -1.0..1.0)
    out.normal = float3(in.normal.xyz) / 127.0;

    // Compute fog from eye-space Z
    out.fog_factor = compute_fog_factor(world_pos.z, uniforms);

    return out;
}

// ------------------------------------------------------------------
// VERTEX SHADER: Lit vertex type (same layout, lighting applied here)
// ------------------------------------------------------------------
vertex VertexOut vertex_lit(
    VertexStandard in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;

    float4 world_pos = uniforms.modelview_matrix * float4(in.position, 1.0);
    out.position = to_metal_clip_space(uniforms.projection_matrix * world_pos);

    float4 tex_transformed = uniforms.texture_matrix * float4(in.texcoord, 0.0, 1.0);
#if DEBUG_BYPASS_TEXTURE_MATRIX
    out.texcoord = in.texcoord;
#else
    out.texcoord = tex_transformed.xy;
#endif
    out.light_texcoord = decode_light_texcoord(in.texcoord2, uniforms);

    // Decode colour and normal
    float4 base_colour = decode_standard_vertex_colour(in.colour, uniforms);
    float3 normal_vec = float3(in.normal.xyz) / 127.0;

    // Transform normal into eye space for lighting
    float3 eye_normal = normalize((uniforms.modelview_matrix * float4(normal_vec, 0.0)).xyz);

    // Apply lighting in vertex shader
    out.colour = apply_lighting(eye_normal, base_colour, uniforms);
    out.normal = eye_normal;
#if DEBUG_VISUALIZE_VERTEX_PATH
    out.colour = float4(0.0, 0.0, 1.0, 1.0);
#endif

    out.fog_factor = compute_fog_factor(world_pos.z, uniforms);

    return out;
}

// ------------------------------------------------------------------
// VERTEX SHADER: TexGen vertex type (texture coords generated)
// ------------------------------------------------------------------
vertex VertexOut vertex_texgen(
    VertexStandard in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;

    float4 world_pos = uniforms.modelview_matrix * float4(in.position, 1.0);
    out.position = to_metal_clip_space(uniforms.projection_matrix * world_pos);

    // Generate texture coordinates from texgen planes
    float4 source_pos;
    if (uniforms.texgen_eye_space) {
        // Eye-space: use transformed position
        source_pos = world_pos;
    } else {
        // Object-space: use original position
        source_pos = float4(in.position, 1.0);
    }

    float gen_s = dot(uniforms.texgen_col[0], source_pos);
    float gen_t = dot(uniforms.texgen_col[1], source_pos);

    float4 tex_transformed = uniforms.texture_matrix * float4(gen_s, gen_t, 0.0, 1.0);
#if DEBUG_BYPASS_TEXTURE_MATRIX
    out.texcoord = float2(gen_s, gen_t);
#else
    out.texcoord = tex_transformed.xy;
#endif
    out.light_texcoord = decode_light_texcoord(in.texcoord2, uniforms);

    out.colour = decode_standard_vertex_colour(in.colour, uniforms);
#if DEBUG_VISUALIZE_VERTEX_PATH
    out.colour = float4(1.0, 1.0, 0.0, 1.0);
#endif
    out.normal = float3(in.normal.xyz) / 127.0;

    out.fog_factor = compute_fog_factor(world_pos.z, uniforms);

    return out;
}

// ------------------------------------------------------------------
// VERTEX SHADER: Compressed vertex type
// Compressed layout: position is 3x short (scaled), texcoords packed in shorts
// ------------------------------------------------------------------
vertex VertexOut vertex_compressed(
    VertexCompressed in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;

    // Tesselator writes x/y/z as signed 16-bit values scaled by 1024.
    float3 pos = float3(in.position_and_colour.xyz) / 1024.0;
    float4 world_pos = uniforms.modelview_matrix * float4(pos, 1.0);
    out.position = to_metal_clip_space(uniforms.projection_matrix * world_pos);

    // Primary UVs are signed 16-bit values scaled by 8192.
    float tex_u = float(in.uv_and_aux.x) / 8192.0;
    float tex_v = float(in.uv_and_aux.y) / 8192.0;

    float4 tex_transformed = uniforms.texture_matrix * float4(tex_u, tex_v, 0.0, 1.0);
#if DEBUG_BYPASS_TEXTURE_MATRIX
    out.texcoord = float2(tex_u, tex_v);
#else
    out.texcoord = tex_transformed.xy;
#endif
    out.light_texcoord = decode_light_texcoord(in.uv_and_aux.zw, uniforms);

    // Colour is packed as RGB565. Alpha is implicit for this path.
    uint packed_colour_biased = uint(as_type<ushort>(in.position_and_colour.w));
    ushort packed_colour = ushort((packed_colour_biased + 32768u) & 0xFFFFu);
    float red = float((packed_colour >> 11) & 0x1F) / 31.0;
    float green = float((packed_colour >> 5) & 0x3F) / 63.0;
    float blue = float(packed_colour & 0x1F) / 31.0;
    out.colour = float4(red, green, blue, 1.0) * uniforms.colour_tint;
#if DEBUG_VISUALIZE_VERTEX_PATH
    out.colour = float4(1.0, 0.0, 0.0, 1.0);
#endif

    // This compact path does not carry normals; leave lighting neutral.
    out.normal = float3(0.0, 0.0, 1.0);

    out.fog_factor = compute_fog_factor(world_pos.z, uniforms);

    return out;
}

// ------------------------------------------------------------------
// FRAGMENT SHADER: Standard textured rendering
// Applies texture sampling, fog blending, and alpha test.
// ------------------------------------------------------------------
fragment float4 fragment_standard(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> light_tex [[texture(1)]],
    sampler tex_sampler [[sampler(0)]])
{
#if DEBUG_VISUALIZE_SOLID_WHITE
    return float4(1.0, 1.0, 1.0, 1.0);
#else
#if DEBUG_VISUALIZE_VERTEX_PATH
    return in.colour;
#endif
    // Sample texture
    float4 tex_colour = sample_game_texture(tex, tex_sampler, in.texcoord);

#if DEBUG_VISUALIZE_UV_GRADIENT
    float2 uv = fract(in.texcoord);
    float4 final_colour = float4(uv.x, uv.y, 0.0, 1.0);
#elif DEBUG_VISUALIZE_BASE_TEXTURE
    float4 final_colour = float4(tex_colour.rgb, 1.0);
#else
    // Multiply texture colour by vertex colour
    float4 final_colour = tex_colour * in.colour;

    if (!DEBUG_DISABLE_LIGHT_TEXTURE && light_tex.get_width() > 0) {
        final_colour.rgb *= light_tex.sample(tex_sampler, in.light_texcoord).rgb;
    }
#endif

    // Alpha test: discard fragments that fail the comparison
    if (uniforms.alpha_test_enable) {
        bool pass = false;
        float ref = uniforms.alpha_test_ref;

        // Match MTLCompareFunction values
        switch (uniforms.alpha_test_func) {
            case 1: pass = false; break;                             // Never
            case 2: pass = (final_colour.a == ref); break;          // Equal
            case 3: pass = (final_colour.a <= ref); break;          // LessEqual
            case 4: pass = (final_colour.a > ref); break;           // Greater
            case 5: pass = (final_colour.a >= ref); break;          // GreaterEqual
            case 6: pass = (final_colour.a != ref); break;          // NotEqual
            case 7: pass = true; break;                              // Always
            default: pass = (final_colour.a > ref); break;          // Default: Greater
        }

        if (!pass) {
            discard_fragment();
        }
    }

    // Apply fog: blend between final colour and fog colour
    if (!DEBUG_DISABLE_FOG && uniforms.fog_enable && !DEBUG_VISUALIZE_BASE_TEXTURE) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
#endif
}

// ------------------------------------------------------------------
// FRAGMENT SHADER: Untextured rendering (for lines and untextured geometry)
// ------------------------------------------------------------------
fragment float4 fragment_untextured(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]])
{
    float4 final_colour = in.colour;

    // Alpha test
    if (uniforms.alpha_test_enable) {
        bool pass = false;
        float ref = uniforms.alpha_test_ref;
        switch (uniforms.alpha_test_func) {
            case 4: pass = (final_colour.a > ref); break;
            case 5: pass = (final_colour.a >= ref); break;
            case 7: pass = true; break;
            default: pass = (final_colour.a > ref); break;
        }
        if (!pass) {
            discard_fragment();
        }
    }

    // Fog
    if (!DEBUG_DISABLE_FOG && uniforms.fog_enable && !DEBUG_VISUALIZE_BASE_TEXTURE) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
}

// ------------------------------------------------------------------
// FRAGMENT SHADER: Projection texture (uses texcoord as projection)
// ------------------------------------------------------------------
fragment float4 fragment_projection(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> light_tex [[texture(1)]],
    sampler tex_sampler [[sampler(0)]])
{
#if DEBUG_VISUALIZE_SOLID_WHITE
    return float4(1.0, 1.0, 1.0, 1.0);
#else
#if DEBUG_VISUALIZE_VERTEX_PATH
    return in.colour;
#endif
    // Project texture coordinates (perspective divide already handled by vertex shader)
    float4 tex_colour = sample_game_texture(tex, tex_sampler, in.texcoord);
#if DEBUG_VISUALIZE_UV_GRADIENT
    float2 uv = fract(in.texcoord);
    float4 final_colour = float4(uv.x, uv.y, 0.0, 1.0);
#elif DEBUG_VISUALIZE_BASE_TEXTURE
    float4 final_colour = float4(tex_colour.rgb, 1.0);
#else
    float4 final_colour = tex_colour * in.colour;

    if (!DEBUG_DISABLE_LIGHT_TEXTURE && light_tex.get_width() > 0) {
        final_colour.rgb *= light_tex.sample(tex_sampler, in.light_texcoord).rgb;
    }
#endif

    if (uniforms.alpha_test_enable) {
        if (final_colour.a <= uniforms.alpha_test_ref) {
            discard_fragment();
        }
    }

    if (!DEBUG_DISABLE_FOG && uniforms.fog_enable && !DEBUG_VISUALIZE_BASE_TEXTURE) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
#endif
}

// ------------------------------------------------------------------
// FRAGMENT SHADER: Force LOD (samples specific mip level)
// ------------------------------------------------------------------
fragment float4 fragment_force_lod(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> tex [[texture(0)]],
    texture2d<float> light_tex [[texture(1)]],
    sampler tex_sampler [[sampler(0)]])
{
#if DEBUG_VISUALIZE_SOLID_WHITE
    return float4(1.0, 1.0, 1.0, 1.0);
#else
#if DEBUG_VISUALIZE_VERTEX_PATH
    return in.colour;
#endif
    // Sample at a forced mip level
    float2 sample_uv = in.texcoord;
    if (sample_uv.x > 1.0) {
        sample_uv.x -= 1.0;
    }
    float4 tex_colour = tex.sample(tex_sampler, sample_uv, level(float(uniforms.force_lod)));
#if DEBUG_VISUALIZE_UV_GRADIENT
    float2 uv = fract(in.texcoord);
    float4 final_colour = float4(uv.x, uv.y, 0.0, 1.0);
#elif DEBUG_VISUALIZE_BASE_TEXTURE
    float4 final_colour = float4(tex_colour.rgb, 1.0);
#else
    float4 final_colour = tex_colour * in.colour;

    if (!DEBUG_DISABLE_LIGHT_TEXTURE && light_tex.get_width() > 0) {
        final_colour.rgb *= light_tex.sample(tex_sampler, in.light_texcoord).rgb;
    }
#endif

    if (uniforms.alpha_test_enable) {
        if (final_colour.a <= uniforms.alpha_test_ref) {
            discard_fragment();
        }
    }

    if (!DEBUG_DISABLE_FOG && uniforms.fog_enable) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
#endif
}
