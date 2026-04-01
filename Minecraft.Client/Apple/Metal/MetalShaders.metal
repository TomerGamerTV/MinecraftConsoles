// MetalShaders.metal - Metal Shading Language shaders for C4JRender
// Handles all vertex types: standard, compressed, lit, and texgen.
// Provides fog (linear/exponential), lighting (2 directional + ambient),
// alpha test, texture sampling, and texture generation modes.

#include <metal_stdlib>
using namespace metal;

// Maximum number of directional lights supported
#define MAX_LIGHTS 2

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

// Standard vertex: Position(3f), TexCoord(2f), Colour(4b), Normal(4b), Padding(4b) = 36 bytes
struct VertexStandard {
    float3 position  [[attribute(0)]];
    float2 texcoord  [[attribute(1)]];
    uchar4 colour    [[attribute(2)]];
    char4  normal    [[attribute(3)]];
    // Padding attribute(4) consumed but unused
};

// Compressed vertex format
struct VertexCompressed {
    short4  position_packed [[attribute(0)]];  // xyz in .xyz, texU in .w
    short4  data_packed     [[attribute(1)]];   // texV in .x, colour+normal packed
};

// Vertex shader output / fragment shader input
struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
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
    out.position = uniforms.projection_matrix * world_pos;

    // Pass through texture coordinates, transformed by texture matrix
    float4 tex_transformed = uniforms.texture_matrix * float4(in.texcoord, 0.0, 1.0);
    out.texcoord = tex_transformed.xy;

    // Convert colour from RGBA8 (0-255) to float4 (0.0-1.0), apply tint
    out.colour = float4(in.colour) / 255.0 * uniforms.colour_tint;

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
    out.position = uniforms.projection_matrix * world_pos;

    float4 tex_transformed = uniforms.texture_matrix * float4(in.texcoord, 0.0, 1.0);
    out.texcoord = tex_transformed.xy;

    // Decode colour and normal
    float4 base_colour = float4(in.colour) / 255.0 * uniforms.colour_tint;
    float3 normal_vec = float3(in.normal.xyz) / 127.0;

    // Transform normal into eye space for lighting
    float3 eye_normal = normalize((uniforms.modelview_matrix * float4(normal_vec, 0.0)).xyz);

    // Apply lighting in vertex shader
    out.colour = apply_lighting(eye_normal, base_colour, uniforms);
    out.normal = eye_normal;

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
    out.position = uniforms.projection_matrix * world_pos;

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
    out.texcoord = tex_transformed.xy;

    out.colour = float4(in.colour) / 255.0 * uniforms.colour_tint;
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

    // Unpack position from short4 (xyz in .xyz, texU encoded in .w)
    // Scale factor for compressed positions (1/16 for sub-block precision)
    float3 pos = float3(in.position_packed.xyz) / 16.0;
    float4 world_pos = uniforms.modelview_matrix * float4(pos, 1.0);
    out.position = uniforms.projection_matrix * world_pos;

    // Unpack texture coordinates from packed shorts
    float tex_u = float(in.position_packed.w) / 32768.0;
    float tex_v = float(in.data_packed.x) / 32768.0;

    float4 tex_transformed = uniforms.texture_matrix * float4(tex_u, tex_v, 0.0, 1.0);
    out.texcoord = tex_transformed.xy;

    // Unpack colour from data_packed.y (RGBA4444 or similar encoding)
    // For compressed format, colour is typically white with alpha
    uint packed_colour = uint(in.data_packed.y) & 0xFFFF;
    float red   = float((packed_colour >> 12) & 0xF) / 15.0;
    float green = float((packed_colour >> 8)  & 0xF) / 15.0;
    float blue  = float((packed_colour >> 4)  & 0xF) / 15.0;
    float alpha = float((packed_colour >> 0)  & 0xF) / 15.0;
    out.colour = float4(red, green, blue, alpha) * uniforms.colour_tint;

    // Unpack normal from data_packed.zw
    float nx = float(int8_t(in.data_packed.z & 0xFF)) / 127.0;
    float ny = float(int8_t((in.data_packed.z >> 8) & 0xFF)) / 127.0;
    float nz = float(int8_t(in.data_packed.w & 0xFF)) / 127.0;
    out.normal = float3(nx, ny, nz);

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
    sampler tex_sampler [[sampler(0)]])
{
    // Sample texture
    float4 tex_colour = tex.sample(tex_sampler, in.texcoord);

    // Multiply texture colour by vertex colour
    float4 final_colour = tex_colour * in.colour;

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
    if (uniforms.fog_enable) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
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
    if (uniforms.fog_enable) {
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
    sampler tex_sampler [[sampler(0)]])
{
    // Project texture coordinates (perspective divide already handled by vertex shader)
    float4 tex_colour = tex.sample(tex_sampler, in.texcoord);
    float4 final_colour = tex_colour * in.colour;

    if (uniforms.alpha_test_enable) {
        if (final_colour.a <= uniforms.alpha_test_ref) {
            discard_fragment();
        }
    }

    if (uniforms.fog_enable) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
}

// ------------------------------------------------------------------
// FRAGMENT SHADER: Force LOD (samples specific mip level)
// ------------------------------------------------------------------
fragment float4 fragment_force_lod(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> tex [[texture(0)]],
    sampler tex_sampler [[sampler(0)]])
{
    // Sample at a forced mip level
    float4 tex_colour = tex.sample(tex_sampler, in.texcoord, level(float(uniforms.force_lod)));
    float4 final_colour = tex_colour * in.colour;

    if (uniforms.alpha_test_enable) {
        if (final_colour.a <= uniforms.alpha_test_ref) {
            discard_fragment();
        }
    }

    if (uniforms.fog_enable) {
        final_colour.rgb = mix(uniforms.fog_colour.rgb, final_colour.rgb, in.fog_factor);
    }

    return final_colour;
}
