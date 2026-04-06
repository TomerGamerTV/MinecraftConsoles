// MetalRenderer.mm - Metal implementation of C4JRender for Apple platforms
// Provides the full C4JRender API using Metal instead of D3D11.
// Uses simd types for matrix math, MTLDevice/MTLCommandQueue for GPU work.

#include "stdafx.h"
#define Component CarbonComponent_Renamed
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <ImageIO/ImageIO.h>
#import <simd/simd.h>
#undef Component
#import <vector>
#import <stack>
#import <cstring>
#import <cmath>
#import <cstdlib>
#import <cstdio>

#include "../AppleTypes.h"
#include "../4JLibs/inc/4J_Render.h"

// ------------------------------------------------------------------
// Constants
// ------------------------------------------------------------------

// Maximum number of textures the renderer can manage
static const int MAX_TEXTURES = 4096;

// Maximum number of command buffer recordings
static const int MAX_COMMAND_BUFFERS = 256;

// Matrix stack depth limit
static const int MAX_MATRIX_STACK_DEPTH = 32;

// Number of directional lights
static const int MAX_LIGHTS = 2;

// Vertex stride for standard vertex type: pos(12) + tex(8) + col(4) + norm(4) + pad(4) = 32
// Actually the spec says 36 bytes: pos(12) + tex(8) + col(4) + norm(4) + pad(4) + extra(4)
static const int VERTEX_STRIDE_STANDARD = 36;

// ------------------------------------------------------------------
// Uniform buffer structure (must match MetalShaders.metal)
// ------------------------------------------------------------------
struct MetalUniforms {
    simd_float4x4 modelview_matrix;
    simd_float4x4 projection_matrix;
    simd_float4x4 texture_matrix;

    simd_float4 colour_tint;

    simd_float4 fog_colour;
    float fog_near;
    float fog_far;
    float fog_density;
    int32_t fog_mode;
    int32_t fog_enable;

    int32_t lighting_enable;
    int32_t light_enable[MAX_LIGHTS];
    simd_float4 light_colour[MAX_LIGHTS];
    simd_float4 light_direction[MAX_LIGHTS];
    simd_float4 ambient_colour;

    int32_t alpha_test_enable;
    int32_t alpha_test_func;
    float alpha_test_ref;

    simd_float4 texgen_col[4];
    int32_t texgen_enable;
    int32_t texgen_eye_space;

    simd_float2 vertex_texture_uv;

    int32_t force_lod;
    float gamma;
};

// ------------------------------------------------------------------
// Internal texture entry
// ------------------------------------------------------------------
struct MetalTextureEntry {
    id<MTLTexture> texture;
    int width;
    int height;
    int mip_levels;
    int min_filter;         // GL_NEAREST or GL_LINEAR
    int mag_filter;
    int wrap_s;             // GL_CLAMP or GL_REPEAT
    int wrap_t;
    bool in_use;
};

// ------------------------------------------------------------------
// Recorded draw command for command buffers
// ------------------------------------------------------------------
struct RecordedDrawCommand {
    enum Type {
        CMD_DRAW_VERTICES,
        CMD_SET_STATE,
        CMD_CLEAR,
        CMD_BIND_TEXTURE,
        CMD_MATRIX_OP,
    };
    Type type;

    // Draw data
    C4JRender::ePrimitiveType primitive_type;
    C4JRender::eVertexType vertex_type;
    C4JRender::ePixelShaderType pixel_shader_type;
    int vertex_count;
    std::vector<uint8_t> vertex_data;

    // State data (stored as a snapshot of relevant state)
    MetalUniforms uniforms_snapshot;
    int bound_texture_index;
};

// Command buffer recording
struct CommandBufferRecord {
    std::vector<RecordedDrawCommand> commands;
    bool in_use;
    bool is_static;
};

// ------------------------------------------------------------------
// Private implementation data (hidden from the header)
// ------------------------------------------------------------------
struct MetalRendererImpl {
    // Metal device and command infrastructure
    id<MTLDevice> device;
    CAMetalLayer *metal_layer;
    id<MTLCommandQueue> command_queue;
    id<MTLLibrary> shader_library;

    // Current frame state
    id<CAMetalDrawable> current_drawable;
    id<MTLCommandBuffer> current_command_buffer;
    id<MTLRenderCommandEncoder> current_encoder;
    id<MTLTexture> depth_stencil_texture;

    // Pipeline state objects (indexed by vertex_type * PIXEL_SHADER_COUNT + pixel_shader_type)
    id<MTLRenderPipelineState> pipeline_states[C4JRender::VERTEX_TYPE_COUNT * C4JRender::PIXEL_SHADER_COUNT];

    // Pipeline states for blending enabled variants
    id<MTLRenderPipelineState> pipeline_states_blend[C4JRender::VERTEX_TYPE_COUNT * C4JRender::PIXEL_SHADER_COUNT];

    // Depth stencil states
    id<MTLDepthStencilState> depth_stencil_enabled;
    id<MTLDepthStencilState> depth_stencil_disabled;
    id<MTLDepthStencilState> depth_stencil_read_only;  // Test enabled, write disabled
    id<MTLDepthStencilState> depth_stencil_custom;     // Dynamic based on current state

    // Sampler states (nearest, linear, nearest-clamp, linear-clamp, etc.)
    id<MTLSamplerState> sampler_nearest_repeat;
    id<MTLSamplerState> sampler_linear_repeat;
    id<MTLSamplerState> sampler_nearest_clamp;
    id<MTLSamplerState> sampler_linear_clamp;

    // Matrix stacks (modelview=0, projection=1, texture=2)
    simd_float4x4 matrix_current[3];
    std::stack<simd_float4x4> matrix_stack[3];
    int matrix_mode;                // Current matrix mode index
    bool matrix_dirty;

    // Render state
    MetalUniforms uniforms;
    float clear_colour[4];
    bool blend_enabled;
    int blend_src;
    int blend_dst;
    unsigned int blend_factor_colour;
    bool depth_test_enabled;
    bool depth_write_enabled;
    int depth_func;
    bool face_cull_enabled;
    bool face_cull_cw;
    bool colour_write_r, colour_write_g, colour_write_b, colour_write_a;
    float depth_slope;
    float depth_bias;
    int stencil_func;
    uint8_t stencil_ref;
    uint8_t stencil_func_mask;
    uint8_t stencil_write_mask;

    // Texture management
    MetalTextureEntry textures[MAX_TEXTURES];
    int bound_texture_index;        // Currently bound texture
    int bound_vertex_texture_index; // Currently bound vertex texture
    int texture_levels_hint;        // Mip levels for next texture creation

    // Command buffer recording
    CommandBufferRecord command_buffers[MAX_COMMAND_BUFFERS];
    int recording_command_buffer;   // -1 if not recording
    bool command_buffers_locked;
    bool deferred_mode;

    // Screen capture
    bool screen_grab_pending;

    // Viewport state
    C4JRender::eViewportType current_viewport;
    int screen_width;
    int screen_height;

    // Suspend/resume
    bool suspended;

    // Gamma
    float gamma_value;
};

// ------------------------------------------------------------------
// Singleton storage
// ------------------------------------------------------------------
C4JRender RenderManager;

// The private implementation pointer (allocated on Initialise)
static MetalRendererImpl *g_impl = nullptr;

// ------------------------------------------------------------------
// Helper: create a 4x4 identity matrix using simd
// ------------------------------------------------------------------
static simd_float4x4 make_identity_matrix()
{
    return matrix_identity_float4x4;
}

// ------------------------------------------------------------------
// Helper: multiply two 4x4 matrices
// ------------------------------------------------------------------
static simd_float4x4 lce_matrix_multiply(simd_float4x4 a, simd_float4x4 b)
{
    return simd_mul(a, b);
}

// ------------------------------------------------------------------
// Helper: create translation matrix
// ------------------------------------------------------------------
static simd_float4x4 make_translation_matrix(float x, float y, float z)
{
    simd_float4x4 result = matrix_identity_float4x4;
    result.columns[3] = simd_make_float4(x, y, z, 1.0f);
    return result;
}

// ------------------------------------------------------------------
// Helper: create scale matrix
// ------------------------------------------------------------------
static simd_float4x4 make_scale_matrix(float x, float y, float z)
{
    simd_float4x4 result = matrix_identity_float4x4;
    result.columns[0][0] = x;
    result.columns[1][1] = y;
    result.columns[2][2] = z;
    return result;
}

// ------------------------------------------------------------------
// Helper: create rotation matrix (angle in degrees, axis x,y,z)
// ------------------------------------------------------------------
static simd_float4x4 make_rotation_matrix(float angle_degrees, float x, float y, float z)
{
    float angle_rad = angle_degrees * (M_PI / 180.0f);
    float cosine = cosf(angle_rad);
    float sine = sinf(angle_rad);
    float one_minus_cos = 1.0f - cosine;

    // Normalize axis
    float length = sqrtf(x * x + y * y + z * z);
    if (length < 1.0e-6f) {
        return matrix_identity_float4x4;
    }
    x /= length;
    y /= length;
    z /= length;

    simd_float4x4 result;
    result.columns[0] = simd_make_float4(
        cosine + x * x * one_minus_cos,
        y * x * one_minus_cos + z * sine,
        z * x * one_minus_cos - y * sine,
        0.0f
    );
    result.columns[1] = simd_make_float4(
        x * y * one_minus_cos - z * sine,
        cosine + y * y * one_minus_cos,
        z * y * one_minus_cos + x * sine,
        0.0f
    );
    result.columns[2] = simd_make_float4(
        x * z * one_minus_cos + y * sine,
        y * z * one_minus_cos - x * sine,
        cosine + z * z * one_minus_cos,
        0.0f
    );
    result.columns[3] = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f);
    return result;
}

// ------------------------------------------------------------------
// Helper: create perspective projection matrix
// fovy in degrees, similar to gluPerspective
// ------------------------------------------------------------------
static simd_float4x4 make_perspective_matrix(float fovy_degrees, float aspect, float z_near, float z_far)
{
    float fovy_rad = fovy_degrees * (M_PI / 180.0f);
    float tan_half_fovy = tanf(fovy_rad / 2.0f);

    simd_float4x4 result = {};
    result.columns[0][0] = 1.0f / (aspect * tan_half_fovy);
    result.columns[1][1] = 1.0f / tan_half_fovy;
    result.columns[2][2] = -(z_far + z_near) / (z_far - z_near);
    result.columns[2][3] = -1.0f;
    result.columns[3][2] = -(2.0f * z_far * z_near) / (z_far - z_near);
    return result;
}

// ------------------------------------------------------------------
// Helper: create orthographic projection matrix
// ------------------------------------------------------------------
static simd_float4x4 make_ortho_matrix(float left, float right, float bottom, float top, float z_near, float z_far)
{
    simd_float4x4 result = {};
    result.columns[0][0] = 2.0f / (right - left);
    result.columns[1][1] = 2.0f / (top - bottom);
    result.columns[2][2] = -2.0f / (z_far - z_near);
    result.columns[3][0] = -(right + left) / (right - left);
    result.columns[3][1] = -(top + bottom) / (top - bottom);
    result.columns[3][2] = -(z_far + z_near) / (z_far - z_near);
    result.columns[3][3] = 1.0f;
    return result;
}

// ------------------------------------------------------------------
// Helper: convert quad list to triangle list
// Takes quad_count quads (quad_count * 4 vertices) and returns
// triangle vertices (quad_count * 6 vertices). Caller frees result.
// ------------------------------------------------------------------
static void *convert_quads_to_triangles(void *quad_data, int quad_count, int vertex_stride, int *out_triangle_vertex_count)
{
    int triangle_count = quad_count * 2;
    *out_triangle_vertex_count = triangle_count * 3;

    uint8_t *src = (uint8_t *)quad_data;
    uint8_t *dst = (uint8_t *)malloc(triangle_count * 3 * vertex_stride);

    for (int i = 0; i < quad_count; i++) {
        uint8_t *v0 = src + (i * 4 + 0) * vertex_stride;
        uint8_t *v1 = src + (i * 4 + 1) * vertex_stride;
        uint8_t *v2 = src + (i * 4 + 2) * vertex_stride;
        uint8_t *v3 = src + (i * 4 + 3) * vertex_stride;

        uint8_t *out_ptr = dst + (i * 6) * vertex_stride;

        // Triangle 1: v0, v1, v2
        memcpy(out_ptr + 0 * vertex_stride, v0, vertex_stride);
        memcpy(out_ptr + 1 * vertex_stride, v1, vertex_stride);
        memcpy(out_ptr + 2 * vertex_stride, v2, vertex_stride);

        // Triangle 2: v0, v2, v3
        memcpy(out_ptr + 3 * vertex_stride, v0, vertex_stride);
        memcpy(out_ptr + 4 * vertex_stride, v2, vertex_stride);
        memcpy(out_ptr + 5 * vertex_stride, v3, vertex_stride);
    }

    return dst;
}

// ------------------------------------------------------------------
// Helper: convert triangle fan to triangle list
// ------------------------------------------------------------------
static void *convert_fan_to_triangles(void *fan_data, int vertex_count, int vertex_stride, int *out_triangle_vertex_count)
{
    int triangle_count = vertex_count - 2;
    if (triangle_count <= 0) {
        *out_triangle_vertex_count = 0;
        return nullptr;
    }

    *out_triangle_vertex_count = triangle_count * 3;
    uint8_t *src = (uint8_t *)fan_data;
    uint8_t *dst = (uint8_t *)malloc(triangle_count * 3 * vertex_stride);

    for (int i = 0; i < triangle_count; i++) {
        uint8_t *v0 = src;                                  // Fan center
        uint8_t *v1 = src + (i + 1) * vertex_stride;
        uint8_t *v2 = src + (i + 2) * vertex_stride;

        uint8_t *out_ptr = dst + (i * 3) * vertex_stride;
        memcpy(out_ptr + 0 * vertex_stride, v0, vertex_stride);
        memcpy(out_ptr + 1 * vertex_stride, v1, vertex_stride);
        memcpy(out_ptr + 2 * vertex_stride, v2, vertex_stride);
    }

    return dst;
}

// ------------------------------------------------------------------
// Helper: get vertex stride for a vertex type
// ------------------------------------------------------------------
static int get_vertex_stride(C4JRender::eVertexType vertex_type)
{
    switch (vertex_type) {
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1:
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_LIT:
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_TEXGEN:
            return 36;
        case C4JRender::VERTEX_TYPE_COMPRESSED:
            return 16; // Compressed: 2 x short4 = 16 bytes
        default:
            return 36;
    }
}

// ------------------------------------------------------------------
// Helper: get MTLBlendFactor from GL_ constant
// ------------------------------------------------------------------
static MTLBlendFactor convert_blend_factor(int gl_factor)
{
    // The GL_ constants in 4J_Render.h map directly to MTLBlendFactor values
    return (MTLBlendFactor)gl_factor;
}

// ------------------------------------------------------------------
// Helper: get MTLCompareFunction from GL_ constant
// ------------------------------------------------------------------
static MTLCompareFunction convert_compare_func(int gl_func)
{
    return (MTLCompareFunction)gl_func;
}

// ------------------------------------------------------------------
// Helper: create sampler states
// ------------------------------------------------------------------
static void create_sampler_states(MetalRendererImpl *impl)
{
    MTLSamplerDescriptor *desc = [[MTLSamplerDescriptor alloc] init];

    // Nearest + Repeat
    desc.minFilter = MTLSamplerMinMagFilterNearest;
    desc.magFilter = MTLSamplerMinMagFilterNearest;
    desc.mipFilter = MTLSamplerMipFilterNearest;
    desc.sAddressMode = MTLSamplerAddressModeRepeat;
    desc.tAddressMode = MTLSamplerAddressModeRepeat;
    impl->sampler_nearest_repeat = [impl->device newSamplerStateWithDescriptor:desc];

    // Linear + Repeat
    desc.minFilter = MTLSamplerMinMagFilterLinear;
    desc.magFilter = MTLSamplerMinMagFilterLinear;
    desc.mipFilter = MTLSamplerMipFilterLinear;
    desc.sAddressMode = MTLSamplerAddressModeRepeat;
    desc.tAddressMode = MTLSamplerAddressModeRepeat;
    impl->sampler_linear_repeat = [impl->device newSamplerStateWithDescriptor:desc];

    // Nearest + Clamp
    desc.minFilter = MTLSamplerMinMagFilterNearest;
    desc.magFilter = MTLSamplerMinMagFilterNearest;
    desc.mipFilter = MTLSamplerMipFilterNearest;
    desc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    desc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    impl->sampler_nearest_clamp = [impl->device newSamplerStateWithDescriptor:desc];

    // Linear + Clamp
    desc.minFilter = MTLSamplerMinMagFilterLinear;
    desc.magFilter = MTLSamplerMinMagFilterLinear;
    desc.mipFilter = MTLSamplerMipFilterLinear;
    desc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    desc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    impl->sampler_linear_clamp = [impl->device newSamplerStateWithDescriptor:desc];
}

// ------------------------------------------------------------------
// Helper: get the correct sampler for a texture entry
// ------------------------------------------------------------------
static id<MTLSamplerState> get_sampler_for_texture(MetalRendererImpl *impl, int texture_index)
{
    if (texture_index < 0 || texture_index >= MAX_TEXTURES || !impl->textures[texture_index].in_use) {
        return impl->sampler_nearest_repeat;
    }

    MetalTextureEntry &entry = impl->textures[texture_index];
    bool is_linear = (entry.min_filter == GL_LINEAR || entry.mag_filter == GL_LINEAR);
    bool is_clamp = (entry.wrap_s == GL_CLAMP || entry.wrap_t == GL_CLAMP);

    if (is_linear && is_clamp) return impl->sampler_linear_clamp;
    if (is_linear)             return impl->sampler_linear_repeat;
    if (is_clamp)              return impl->sampler_nearest_clamp;
    return impl->sampler_nearest_repeat;
}

// ------------------------------------------------------------------
// Helper: create vertex descriptor for a vertex type
// ------------------------------------------------------------------
static MTLVertexDescriptor *create_vertex_descriptor(C4JRender::eVertexType vertex_type)
{
    MTLVertexDescriptor *desc = [[MTLVertexDescriptor alloc] init];

    switch (vertex_type) {
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1:
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_LIT:
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_TEXGEN:
            // Position: 3 floats at offset 0
            desc.attributes[0].format = MTLVertexFormatFloat3;
            desc.attributes[0].offset = 0;
            desc.attributes[0].bufferIndex = 0;

            // TexCoord: 2 floats at offset 12
            desc.attributes[1].format = MTLVertexFormatFloat2;
            desc.attributes[1].offset = 12;
            desc.attributes[1].bufferIndex = 0;

            // Colour: 4 unsigned bytes at offset 20
            desc.attributes[2].format = MTLVertexFormatUChar4;
            desc.attributes[2].offset = 20;
            desc.attributes[2].bufferIndex = 0;

            // Normal: 4 signed bytes at offset 24
            desc.attributes[3].format = MTLVertexFormatChar4;
            desc.attributes[3].offset = 24;
            desc.attributes[3].bufferIndex = 0;

            // Layout: stride 36 bytes
            desc.layouts[0].stride = 36;
            desc.layouts[0].stepRate = 1;
            desc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
            break;

        case C4JRender::VERTEX_TYPE_COMPRESSED:
            // Position packed: short4 at offset 0
            desc.attributes[0].format = MTLVertexFormatShort4;
            desc.attributes[0].offset = 0;
            desc.attributes[0].bufferIndex = 0;

            // Data packed: short4 at offset 8
            desc.attributes[1].format = MTLVertexFormatShort4;
            desc.attributes[1].offset = 8;
            desc.attributes[1].bufferIndex = 0;

            // Layout: stride 16 bytes
            desc.layouts[0].stride = 16;
            desc.layouts[0].stepRate = 1;
            desc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
            break;

        default:
            break;
    }

    return desc;
}

// ------------------------------------------------------------------
// Helper: get vertex function name for a vertex type
// ------------------------------------------------------------------
static NSString *get_vertex_function_name(C4JRender::eVertexType vertex_type)
{
    switch (vertex_type) {
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1:
            return @"vertex_standard";
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_LIT:
            return @"vertex_lit";
        case C4JRender::VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_TEXGEN:
            return @"vertex_texgen";
        case C4JRender::VERTEX_TYPE_COMPRESSED:
            return @"vertex_compressed";
        default:
            return @"vertex_standard";
    }
}

// ------------------------------------------------------------------
// Helper: get fragment function name for a pixel shader type
// ------------------------------------------------------------------
static NSString *get_fragment_function_name(C4JRender::ePixelShaderType ps_type)
{
    switch (ps_type) {
        case C4JRender::PIXEL_SHADER_TYPE_STANDARD:
            return @"fragment_standard";
        case C4JRender::PIXEL_SHADER_TYPE_PROJECTION:
            return @"fragment_projection";
        case C4JRender::PIXEL_SHADER_TYPE_FORCELOD:
            return @"fragment_force_lod";
        default:
            return @"fragment_standard";
    }
}

// ------------------------------------------------------------------
// Helper: create pipeline state for a vertex/pixel shader combination
// ------------------------------------------------------------------
static id<MTLRenderPipelineState> create_pipeline_state(
    MetalRendererImpl *impl,
    C4JRender::eVertexType vertex_type,
    C4JRender::ePixelShaderType ps_type,
    bool blend_enabled)
{
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];

    NSString *vertex_func_name = get_vertex_function_name(vertex_type);
    NSString *fragment_func_name = get_fragment_function_name(ps_type);

    desc.vertexFunction = [impl->shader_library newFunctionWithName:vertex_func_name];
    desc.fragmentFunction = [impl->shader_library newFunctionWithName:fragment_func_name];
    desc.vertexDescriptor = create_vertex_descriptor(vertex_type);

    // Colour attachment: BGRA8Unorm (standard Metal drawable format)
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    if (blend_enabled) {
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        // Default blend: src_alpha, one_minus_src_alpha
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    } else {
        desc.colorAttachments[0].blendingEnabled = NO;
    }

    // Depth attachment
    desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    desc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;

    NSError *error = nil;
    id<MTLRenderPipelineState> state = [impl->device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error) {
        NSLog(@"[MetalRenderer] Failed to create pipeline state for vertex=%@ fragment=%@: %@",
              vertex_func_name, fragment_func_name, error.localizedDescription);
    }

    return state;
}

// ------------------------------------------------------------------
// Helper: create all pipeline state objects
// ------------------------------------------------------------------
static void create_all_pipeline_states(MetalRendererImpl *impl)
{
    for (int vt = 0; vt < C4JRender::VERTEX_TYPE_COUNT; vt++) {
        for (int ps = 0; ps < C4JRender::PIXEL_SHADER_COUNT; ps++) {
            int index = vt * C4JRender::PIXEL_SHADER_COUNT + ps;

            // Non-blending variant
            impl->pipeline_states[index] = create_pipeline_state(
                impl,
                (C4JRender::eVertexType)vt,
                (C4JRender::ePixelShaderType)ps,
                false);

            // Blending variant
            impl->pipeline_states_blend[index] = create_pipeline_state(
                impl,
                (C4JRender::eVertexType)vt,
                (C4JRender::ePixelShaderType)ps,
                true);
        }
    }
}

// ------------------------------------------------------------------
// Helper: create depth stencil states
// ------------------------------------------------------------------
static void create_depth_stencil_states(MetalRendererImpl *impl)
{
    MTLDepthStencilDescriptor *desc = [[MTLDepthStencilDescriptor alloc] init];

    // Depth test + write enabled
    desc.depthCompareFunction = MTLCompareFunctionLessEqual;
    desc.depthWriteEnabled = YES;
    impl->depth_stencil_enabled = [impl->device newDepthStencilStateWithDescriptor:desc];

    // Depth test + write disabled
    desc.depthCompareFunction = MTLCompareFunctionAlways;
    desc.depthWriteEnabled = NO;
    impl->depth_stencil_disabled = [impl->device newDepthStencilStateWithDescriptor:desc];

    // Depth test enabled, write disabled (read-only depth)
    desc.depthCompareFunction = MTLCompareFunctionLessEqual;
    desc.depthWriteEnabled = NO;
    impl->depth_stencil_read_only = [impl->device newDepthStencilStateWithDescriptor:desc];
}

// ------------------------------------------------------------------
// Helper: create or resize depth/stencil texture
// ------------------------------------------------------------------
static void create_depth_texture(MetalRendererImpl *impl, int width, int height)
{
    MTLTextureDescriptor *desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8
                                     width:width
                                    height:height
                                 mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;

    impl->depth_stencil_texture = [impl->device newTextureWithDescriptor:desc];
}

// ------------------------------------------------------------------
// Helper: sync uniforms from current render state to the uniform struct
// ------------------------------------------------------------------
static void sync_uniforms(MetalRendererImpl *impl)
{
    impl->uniforms.modelview_matrix = impl->matrix_current[0];
    impl->uniforms.projection_matrix = impl->matrix_current[1];
    impl->uniforms.texture_matrix = impl->matrix_current[2];
    impl->uniforms.gamma = impl->gamma_value;
}

// ------------------------------------------------------------------
// Helper: begin a render encoder for the current frame
// ------------------------------------------------------------------
static void ensure_render_encoder(MetalRendererImpl *impl)
{
    if (impl->current_encoder != nil) {
        return; // Already have an active encoder
    }

    if (impl->current_drawable == nil || impl->current_command_buffer == nil) {
        return; // No frame in progress
    }

    MTLRenderPassDescriptor *pass_desc = [[MTLRenderPassDescriptor alloc] init];

    // Colour attachment from drawable
    pass_desc.colorAttachments[0].texture = impl->current_drawable.texture;
    pass_desc.colorAttachments[0].loadAction = MTLLoadActionLoad;
    pass_desc.colorAttachments[0].storeAction = MTLStoreActionStore;

    // Depth/stencil attachment
    pass_desc.depthAttachment.texture = impl->depth_stencil_texture;
    pass_desc.depthAttachment.loadAction = MTLLoadActionLoad;
    pass_desc.depthAttachment.storeAction = MTLStoreActionStore;
    pass_desc.stencilAttachment.texture = impl->depth_stencil_texture;
    pass_desc.stencilAttachment.loadAction = MTLLoadActionLoad;
    pass_desc.stencilAttachment.storeAction = MTLStoreActionStore;

    impl->current_encoder = [impl->current_command_buffer renderCommandEncoderWithDescriptor:pass_desc];
}

// ------------------------------------------------------------------
// Helper: end the current render encoder
// ------------------------------------------------------------------
static void end_render_encoder(MetalRendererImpl *impl)
{
    if (impl->current_encoder != nil) {
        [impl->current_encoder endEncoding];
        impl->current_encoder = nil;
    }
}

// ------------------------------------------------------------------
// Helper: get the appropriate depth stencil state for current settings
// ------------------------------------------------------------------
static id<MTLDepthStencilState> get_current_depth_stencil_state(MetalRendererImpl *impl)
{
    if (!impl->depth_test_enabled) {
        return impl->depth_stencil_disabled;
    }
    if (!impl->depth_write_enabled) {
        return impl->depth_stencil_read_only;
    }

    // For custom depth functions, create on the fly
    // (In production, these should be cached)
    MTLDepthStencilDescriptor *desc = [[MTLDepthStencilDescriptor alloc] init];
    desc.depthCompareFunction = convert_compare_func(impl->depth_func);
    desc.depthWriteEnabled = impl->depth_write_enabled ? YES : NO;

    // Configure stencil if needed
    if (impl->stencil_func != 0) {
        MTLStencilDescriptor *stencil_desc = [[MTLStencilDescriptor alloc] init];
        stencil_desc.stencilCompareFunction = convert_compare_func(impl->stencil_func);
        stencil_desc.readMask = impl->stencil_func_mask;
        stencil_desc.writeMask = impl->stencil_write_mask;
        stencil_desc.stencilFailureOperation = MTLStencilOperationKeep;
        stencil_desc.depthFailureOperation = MTLStencilOperationKeep;
        stencil_desc.depthStencilPassOperation = MTLStencilOperationReplace;
        desc.frontFaceStencil = stencil_desc;
        desc.backFaceStencil = stencil_desc;
    }

    return [impl->device newDepthStencilStateWithDescriptor:desc];
}

// ------------------------------------------------------------------
// Helper: apply current state to the render encoder before a draw call
// ------------------------------------------------------------------
static void apply_render_state(MetalRendererImpl *impl, C4JRender::eVertexType vt, C4JRender::ePixelShaderType ps)
{
    ensure_render_encoder(impl);
    if (impl->current_encoder == nil) return;

    // Select pipeline state based on blend mode
    int pipeline_index = vt * C4JRender::PIXEL_SHADER_COUNT + ps;
    if (impl->blend_enabled) {
        [impl->current_encoder setRenderPipelineState:impl->pipeline_states_blend[pipeline_index]];
    } else {
        [impl->current_encoder setRenderPipelineState:impl->pipeline_states[pipeline_index]];
    }

    // Depth/stencil state
    id<MTLDepthStencilState> depth_state = get_current_depth_stencil_state(impl);
    [impl->current_encoder setDepthStencilState:depth_state];
    [impl->current_encoder setStencilReferenceValue:impl->stencil_ref];

    // Face culling
    if (impl->face_cull_enabled) {
        if (impl->face_cull_cw) {
            [impl->current_encoder setCullMode:MTLCullModeFront];
        } else {
            [impl->current_encoder setCullMode:MTLCullModeBack];
        }
    } else {
        [impl->current_encoder setCullMode:MTLCullModeNone];
    }
    [impl->current_encoder setFrontFacingWinding:MTLWindingCounterClockwise];

    // Depth bias
    if (impl->depth_slope != 0.0f || impl->depth_bias != 0.0f) {
        [impl->current_encoder setDepthBias:impl->depth_bias slopeScale:impl->depth_slope clamp:0.0f];
    }

    // Sync and set uniforms
    sync_uniforms(impl);
    [impl->current_encoder setVertexBytes:&impl->uniforms length:sizeof(MetalUniforms) atIndex:1];
    [impl->current_encoder setFragmentBytes:&impl->uniforms length:sizeof(MetalUniforms) atIndex:1];

    // Bind texture and sampler
    int tex_idx = impl->bound_texture_index;
    if (tex_idx >= 0 && tex_idx < MAX_TEXTURES && impl->textures[tex_idx].in_use) {
        [impl->current_encoder setFragmentTexture:impl->textures[tex_idx].texture atIndex:0];
        [impl->current_encoder setFragmentSamplerState:get_sampler_for_texture(impl, tex_idx) atIndex:0];
    }

    // Bind vertex texture if set
    int vtex_idx = impl->bound_vertex_texture_index;
    if (vtex_idx >= 0 && vtex_idx < MAX_TEXTURES && impl->textures[vtex_idx].in_use) {
        [impl->current_encoder setVertexTexture:impl->textures[vtex_idx].texture atIndex:0];
    }

    // Viewport
    MTLViewport viewport;
    float vp_x = 0, vp_y = 0;
    float vp_w = impl->screen_width, vp_h = impl->screen_height;

    switch (impl->current_viewport) {
        case C4JRender::VIEWPORT_TYPE_FULLSCREEN:
            break;
        case C4JRender::VIEWPORT_TYPE_SPLIT_TOP:
            vp_h = impl->screen_height / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_SPLIT_BOTTOM:
            vp_y = impl->screen_height / 2.0f;
            vp_h = impl->screen_height / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_SPLIT_LEFT:
            vp_w = impl->screen_width / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_SPLIT_RIGHT:
            vp_x = impl->screen_width / 2.0f;
            vp_w = impl->screen_width / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_QUADRANT_TOP_LEFT:
            vp_w = impl->screen_width / 2.0f;
            vp_h = impl->screen_height / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_QUADRANT_TOP_RIGHT:
            vp_x = impl->screen_width / 2.0f;
            vp_w = impl->screen_width / 2.0f;
            vp_h = impl->screen_height / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_QUADRANT_BOTTOM_LEFT:
            vp_y = impl->screen_height / 2.0f;
            vp_w = impl->screen_width / 2.0f;
            vp_h = impl->screen_height / 2.0f;
            break;
        case C4JRender::VIEWPORT_TYPE_QUADRANT_BOTTOM_RIGHT:
            vp_x = impl->screen_width / 2.0f;
            vp_y = impl->screen_height / 2.0f;
            vp_w = impl->screen_width / 2.0f;
            vp_h = impl->screen_height / 2.0f;
            break;
    }

    viewport.originX = vp_x;
    viewport.originY = vp_y;
    viewport.width = vp_w;
    viewport.height = vp_h;
    viewport.znear = 0.0;
    viewport.zfar = 1.0;
    [impl->current_encoder setViewport:viewport];
}

// ==================================================================
// C4JRender implementation
// ==================================================================

// ------------------------------------------------------------------
// Tick - called once per frame for housekeeping
// ------------------------------------------------------------------
void C4JRender::Tick()
{
    if (!g_impl) return;
    // Housekeeping: nothing needed per tick for Metal
}

// ------------------------------------------------------------------
// UpdateGamma - adjust gamma correction value
// ------------------------------------------------------------------
void C4JRender::UpdateGamma(unsigned short usGamma)
{
    if (!g_impl) return;
    // Convert unsigned short gamma to float (typically 0-65535 -> 0.0-4.0 range)
    g_impl->gamma_value = (float)usGamma / 16384.0f;
}

// ==================================================================
// Matrix stack operations
// ==================================================================

void C4JRender::MatrixMode(int type)
{
    if (!g_impl) return;
    g_impl->matrix_mode = type; // 0=modelview, 1=projection, 2=texture
}

void C4JRender::MatrixSetIdentity()
{
    if (!g_impl) return;
    g_impl->matrix_current[g_impl->matrix_mode] = make_identity_matrix();
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixTranslate(float x, float y, float z)
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_current[mode] = matrix_multiply(
        g_impl->matrix_current[mode],
        make_translation_matrix(x, y, z));
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixRotate(float angle, float x, float y, float z)
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_current[mode] = matrix_multiply(
        g_impl->matrix_current[mode],
        make_rotation_matrix(angle, x, y, z));
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixScale(float x, float y, float z)
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_current[mode] = matrix_multiply(
        g_impl->matrix_current[mode],
        make_scale_matrix(x, y, z));
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixPerspective(float fovy, float aspect, float zNear, float zFar)
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_current[mode] = matrix_multiply(
        g_impl->matrix_current[mode],
        make_perspective_matrix(fovy, aspect, zNear, zFar));
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixOrthogonal(float left, float right, float bottom, float top, float zNear, float zFar)
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_current[mode] = matrix_multiply(
        g_impl->matrix_current[mode],
        make_ortho_matrix(left, right, bottom, top, zNear, zFar));
    g_impl->matrix_dirty = true;
}

void C4JRender::MatrixPop()
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    if (!g_impl->matrix_stack[mode].empty()) {
        g_impl->matrix_current[mode] = g_impl->matrix_stack[mode].top();
        g_impl->matrix_stack[mode].pop();
        g_impl->matrix_dirty = true;
    }
}

void C4JRender::MatrixPush()
{
    if (!g_impl) return;
    int mode = g_impl->matrix_mode;
    g_impl->matrix_stack[mode].push(g_impl->matrix_current[mode]);
}

void C4JRender::MatrixMult(float *mat)
{
    if (!g_impl || !mat) return;
    int mode = g_impl->matrix_mode;

    // Interpret mat as a column-major 4x4 matrix (OpenGL convention)
    simd_float4x4 m;
    memcpy(&m, mat, sizeof(simd_float4x4));

    g_impl->matrix_current[mode] = matrix_multiply(g_impl->matrix_current[mode], m);
    g_impl->matrix_dirty = true;
}

const float *C4JRender::MatrixGet(int type)
{
    if (!g_impl) return nullptr;
    // Return pointer to the raw float data of the requested matrix
    return (const float *)&g_impl->matrix_current[type];
}

void C4JRender::Set_matrixDirty()
{
    if (!g_impl) return;
    g_impl->matrix_dirty = true;
}

// ==================================================================
// Core rendering
// ==================================================================

void C4JRender::Initialise(void *pDevice, void *pSwapChain)
{
    // Allocate implementation
    g_impl = new MetalRendererImpl();
    memset(g_impl, 0, sizeof(MetalRendererImpl));

    // Store Metal device and layer
    g_impl->device = (__bridge id<MTLDevice>)pDevice;
    g_impl->metal_layer = (__bridge CAMetalLayer *)pSwapChain;

    // Create command queue
    g_impl->command_queue = [g_impl->device newCommandQueue];

    // Load shader library from default library (compiled .metal files)
    NSError *error = nil;

    // Try loading from a metallib file first, then fall back to default library
    NSString *shader_path = [[NSBundle mainBundle] pathForResource:@"MetalShaders" ofType:@"metallib"];
    if (shader_path) {
        g_impl->shader_library = [g_impl->device newLibraryWithFile:shader_path error:&error];
    }

    if (!g_impl->shader_library) {
        g_impl->shader_library = [g_impl->device newDefaultLibrary];
    }

    // Try loading from the executable directory (where Xcode puts it)
    if (!g_impl->shader_library) {
        NSString *execPath = [[NSBundle mainBundle] executablePath];
        NSString *execDir = [execPath stringByDeletingLastPathComponent];
        NSString *metalLibPath = [execDir stringByAppendingPathComponent:@"default.metallib"];
        g_impl->shader_library = [g_impl->device newLibraryWithFile:metalLibPath error:&error];
        if (g_impl->shader_library) {
            NSLog(@"[MetalRenderer] Loaded shader library from: %@", metalLibPath);
        }
    }

    if (!g_impl->shader_library) {
        NSLog(@"[MetalRenderer] FATAL: Could not load Metal shader library (error: %@)", error);
        return;
    }

    // Initialize matrices to identity
    for (int i = 0; i < 3; i++) {
        g_impl->matrix_current[i] = make_identity_matrix();
    }
    g_impl->matrix_mode = 0;
    g_impl->matrix_dirty = true;

    // Default render state
    g_impl->clear_colour[0] = 0.0f;
    g_impl->clear_colour[1] = 0.0f;
    g_impl->clear_colour[2] = 0.0f;
    g_impl->clear_colour[3] = 1.0f;

    g_impl->blend_enabled = false;
    g_impl->blend_src = GL_SRC_ALPHA;
    g_impl->blend_dst = GL_ONE_MINUS_SRC_ALPHA;
    g_impl->depth_test_enabled = true;
    g_impl->depth_write_enabled = true;
    g_impl->depth_func = GL_LEQUAL;
    g_impl->face_cull_enabled = false;
    g_impl->face_cull_cw = false;
    g_impl->colour_write_r = true;
    g_impl->colour_write_g = true;
    g_impl->colour_write_b = true;
    g_impl->colour_write_a = true;
    g_impl->depth_slope = 0.0f;
    g_impl->depth_bias = 0.0f;

    // Default uniform state
    g_impl->uniforms.colour_tint = simd_make_float4(1, 1, 1, 1);
    g_impl->uniforms.fog_enable = 0;
    g_impl->uniforms.fog_mode = 0;
    g_impl->uniforms.fog_near = 0.0f;
    g_impl->uniforms.fog_far = 1.0f;
    g_impl->uniforms.fog_density = 1.0f;
    g_impl->uniforms.fog_colour = simd_make_float4(1, 1, 1, 1);
    g_impl->uniforms.lighting_enable = 0;
    g_impl->uniforms.light_enable[0] = 0;
    g_impl->uniforms.light_enable[1] = 0;
    g_impl->uniforms.ambient_colour = simd_make_float4(0.2f, 0.2f, 0.2f, 1.0f);
    g_impl->uniforms.alpha_test_enable = 0;
    g_impl->uniforms.alpha_test_func = 4; // Greater
    g_impl->uniforms.alpha_test_ref = 0.0f;
    g_impl->uniforms.texgen_enable = 0;
    g_impl->uniforms.force_lod = 0;
    g_impl->gamma_value = 1.0f;

    // Texture management init
    g_impl->bound_texture_index = -1;
    g_impl->bound_vertex_texture_index = -1;
    g_impl->texture_levels_hint = 1;
    for (int i = 0; i < MAX_TEXTURES; i++) {
        g_impl->textures[i].in_use = false;
    }

    // Command buffer recording init
    g_impl->recording_command_buffer = -1;
    g_impl->command_buffers_locked = false;
    g_impl->deferred_mode = false;
    for (int i = 0; i < MAX_COMMAND_BUFFERS; i++) {
        g_impl->command_buffers[i].in_use = false;
        g_impl->command_buffers[i].is_static = false;
    }

    g_impl->current_viewport = VIEWPORT_TYPE_FULLSCREEN;
    g_impl->suspended = false;
    g_impl->screen_grab_pending = false;

    // Get screen dimensions from the metal layer
    CGSize drawable_size = g_impl->metal_layer.drawableSize;
    g_impl->screen_width = (int)drawable_size.width;
    g_impl->screen_height = (int)drawable_size.height;

    // If drawable size is zero (layer not yet laid out), use a default
    if (g_impl->screen_width <= 0 || g_impl->screen_height <= 0) {
        g_impl->screen_width = 1280;
        g_impl->screen_height = 720;
        NSLog(@"[MetalRenderer] drawableSize was zero, using default %dx%d", g_impl->screen_width, g_impl->screen_height);
    }

    // Create depth texture
    create_depth_texture(g_impl, g_impl->screen_width, g_impl->screen_height);

    // Create sampler states
    create_sampler_states(g_impl);

    // Create depth stencil states
    create_depth_stencil_states(g_impl);

    // Create all pipeline state objects
    create_all_pipeline_states(g_impl);

    NSLog(@"[MetalRenderer] Initialised with device: %@, screen: %dx%d",
          g_impl->device.name, g_impl->screen_width, g_impl->screen_height);
}

void C4JRender::InitialiseContext()
{
    // Metal does not have a separate device context like D3D11.
    // Pipeline states and command buffers serve that role.
    if (!g_impl) return;
}

void C4JRender::StartFrame()
{
    if (!g_impl || g_impl->suspended) return;

    // Check if drawable size changed (window resize)
    CGSize drawable_size = g_impl->metal_layer.drawableSize;
    int new_width = (int)drawable_size.width;
    int new_height = (int)drawable_size.height;

    if (new_width != g_impl->screen_width || new_height != g_impl->screen_height) {
        g_impl->screen_width = new_width;
        g_impl->screen_height = new_height;
        create_depth_texture(g_impl, new_width, new_height);
    }

    // Get next drawable from the Metal layer
    g_impl->current_drawable = [g_impl->metal_layer nextDrawable];
    if (!g_impl->current_drawable) {
        NSLog(@"[MetalRenderer] WARNING: Could not get next drawable");
        return;
    }

    // Create a command buffer for this frame
    g_impl->current_command_buffer = [g_impl->command_queue commandBuffer];
    g_impl->current_encoder = nil;
}

void C4JRender::DoScreenGrabOnNextPresent()
{
    if (!g_impl) return;
    g_impl->screen_grab_pending = true;
}

void C4JRender::Present()
{
    if (!g_impl || g_impl->suspended) return;

    // End any active render encoder
    end_render_encoder(g_impl);

    if (g_impl->current_drawable && g_impl->current_command_buffer) {
        // Schedule presentation
        [g_impl->current_command_buffer presentDrawable:g_impl->current_drawable];

        // Commit the command buffer
        [g_impl->current_command_buffer commit];
    }

    // Clear frame state
    g_impl->current_drawable = nil;
    g_impl->current_command_buffer = nil;
    g_impl->current_encoder = nil;
    g_impl->screen_grab_pending = false;
}

void C4JRender::Clear(int flags, void *pRect)
{
    if (!g_impl || g_impl->suspended) return;

    // End any active encoder so we can start a new one with clear actions
    end_render_encoder(g_impl);

    if (!g_impl->current_drawable || !g_impl->current_command_buffer) return;

    MTLRenderPassDescriptor *pass_desc = [[MTLRenderPassDescriptor alloc] init];

    // Colour attachment
    pass_desc.colorAttachments[0].texture = g_impl->current_drawable.texture;
    if (flags & CLEAR_COLOUR_FLAG) {
        pass_desc.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass_desc.colorAttachments[0].clearColor = MTLClearColorMake(
            g_impl->clear_colour[0],
            g_impl->clear_colour[1],
            g_impl->clear_colour[2],
            g_impl->clear_colour[3]);
    } else {
        pass_desc.colorAttachments[0].loadAction = MTLLoadActionLoad;
    }
    pass_desc.colorAttachments[0].storeAction = MTLStoreActionStore;

    // Depth attachment
    pass_desc.depthAttachment.texture = g_impl->depth_stencil_texture;
    if (flags & CLEAR_DEPTH_FLAG) {
        pass_desc.depthAttachment.loadAction = MTLLoadActionClear;
        pass_desc.depthAttachment.clearDepth = 1.0;
    } else {
        pass_desc.depthAttachment.loadAction = MTLLoadActionLoad;
    }
    pass_desc.depthAttachment.storeAction = MTLStoreActionStore;

    // Stencil attachment
    pass_desc.stencilAttachment.texture = g_impl->depth_stencil_texture;
    pass_desc.stencilAttachment.loadAction = MTLLoadActionClear;
    pass_desc.stencilAttachment.clearStencil = 0;
    pass_desc.stencilAttachment.storeAction = MTLStoreActionStore;

    // Create and immediately end an encoder to execute the clear
    g_impl->current_encoder = [g_impl->current_command_buffer renderCommandEncoderWithDescriptor:pass_desc];
    // Leave encoder open for subsequent draw calls
}

void C4JRender::SetClearColour(const float colourRGBA[4])
{
    if (!g_impl) return;
    g_impl->clear_colour[0] = colourRGBA[0];
    g_impl->clear_colour[1] = colourRGBA[1];
    g_impl->clear_colour[2] = colourRGBA[2];
    g_impl->clear_colour[3] = colourRGBA[3];
}

bool C4JRender::IsWidescreen()
{
    if (!g_impl) return true;
    // Widescreen if aspect ratio > 1.5 (wider than 3:2)
    float aspect = (float)g_impl->screen_width / (float)g_impl->screen_height;
    return aspect > 1.5f;
}

bool C4JRender::IsHiDef()
{
    if (!g_impl) return true;
    // HiDef if height >= 720p
    return g_impl->screen_height >= 720;
}

void C4JRender::CaptureThumbnail(ImageFileBuffer *pngOut)
{
    if (!g_impl || !pngOut) return;
    // TODO: Implement Metal texture readback and PNG encoding
    pngOut->m_pBuffer = nullptr;
    pngOut->m_bufferSize = 0;
    pngOut->m_type = ImageFileBuffer::e_typePNG;
}

void C4JRender::CaptureScreen(ImageFileBuffer *jpgOut, XSOCIAL_PREVIEWIMAGE *previewOut)
{
    if (!g_impl) return;
    // TODO: Implement Metal texture readback and JPEG encoding
    if (jpgOut) {
        jpgOut->m_pBuffer = nullptr;
        jpgOut->m_bufferSize = 0;
        jpgOut->m_type = ImageFileBuffer::e_typeJPG;
    }
}

void C4JRender::BeginConditionalSurvey(int identifier)
{
    // Metal does not have GPU occlusion queries in the same D3D11 style.
    // This is a no-op for now; can be implemented with MTLVisibilityResultBuffer.
}

void C4JRender::EndConditionalSurvey()
{
    // No-op, see BeginConditionalSurvey
}

void C4JRender::BeginConditionalRendering(int identifier)
{
    // No-op, see BeginConditionalSurvey
}

void C4JRender::EndConditionalRendering()
{
    // No-op
}

// ==================================================================
// Drawing
// ==================================================================

void C4JRender::DrawVertices(ePrimitiveType PrimitiveType, int count, void *dataIn, eVertexType vType, C4JRender::ePixelShaderType psType)
{
    if (!g_impl || !dataIn || count <= 0) return;

    // If recording a command buffer, store the draw command
    if (g_impl->recording_command_buffer >= 0) {
        RecordedDrawCommand cmd;
        cmd.type = RecordedDrawCommand::CMD_DRAW_VERTICES;
        cmd.primitive_type = PrimitiveType;
        cmd.vertex_type = vType;
        cmd.pixel_shader_type = psType;
        cmd.vertex_count = count;
        cmd.bound_texture_index = g_impl->bound_texture_index;

        int stride = get_vertex_stride(vType);
        int data_size = count * stride;
        cmd.vertex_data.resize(data_size);
        memcpy(cmd.vertex_data.data(), dataIn, data_size);

        // Snapshot uniforms
        sync_uniforms(g_impl);
        cmd.uniforms_snapshot = g_impl->uniforms;

        g_impl->command_buffers[g_impl->recording_command_buffer].commands.push_back(cmd);
        return;
    }

    int stride = get_vertex_stride(vType);
    void *draw_data = dataIn;
    int draw_count = count;
    bool free_draw_data = false;

    MTLPrimitiveType metal_primitive;

    switch (PrimitiveType) {
        case PRIMITIVE_TYPE_TRIANGLE_LIST:
            metal_primitive = MTLPrimitiveTypeTriangle;
            break;

        case PRIMITIVE_TYPE_TRIANGLE_STRIP:
            metal_primitive = MTLPrimitiveTypeTriangleStrip;
            break;

        case PRIMITIVE_TYPE_TRIANGLE_FAN:
            // Metal has no triangle fan; convert to triangle list
            draw_data = convert_fan_to_triangles(dataIn, count, stride, &draw_count);
            free_draw_data = true;
            metal_primitive = MTLPrimitiveTypeTriangle;
            break;

        case PRIMITIVE_TYPE_QUAD_LIST:
            // Metal has no quads; convert to triangle list
            {
                int quad_count = count / 4;
                draw_data = convert_quads_to_triangles(dataIn, quad_count, stride, &draw_count);
                free_draw_data = true;
                metal_primitive = MTLPrimitiveTypeTriangle;
            }
            break;

        case PRIMITIVE_TYPE_LINE_LIST:
            metal_primitive = MTLPrimitiveTypeLine;
            break;

        case PRIMITIVE_TYPE_LINE_STRIP:
            metal_primitive = MTLPrimitiveTypeLineStrip;
            break;

        default:
            return;
    }

    if (draw_count <= 0 || !draw_data) {
        if (free_draw_data && draw_data) free(draw_data);
        return;
    }

    // Apply render state (sets pipeline, depth, viewport, uniforms, textures)
    apply_render_state(g_impl, vType, psType);

    if (g_impl->current_encoder == nil) {
        if (free_draw_data) free(draw_data);
        return;
    }

    // Upload vertex data and draw
    int data_size = draw_count * stride;
    [g_impl->current_encoder setVertexBytes:draw_data length:data_size atIndex:0];
    [g_impl->current_encoder drawPrimitives:metal_primitive vertexStart:0 vertexCount:draw_count];

    if (free_draw_data) {
        free(draw_data);
    }
}

void C4JRender::DrawVertexBuffer(ePrimitiveType PrimitiveType, int count, void *buffer, C4JRender::eVertexType vType, C4JRender::ePixelShaderType psType)
{
    if (!g_impl || !buffer || count <= 0) return;

    // buffer is an id<MTLBuffer> cast to void*
    id<MTLBuffer> metal_buffer = (__bridge id<MTLBuffer>)buffer;

    int stride = get_vertex_stride(vType);

    // For quads and fans we need to read back and convert
    // (In a production renderer, this would use an index buffer instead)
    if (PrimitiveType == PRIMITIVE_TYPE_QUAD_LIST || PrimitiveType == PRIMITIVE_TYPE_TRIANGLE_FAN) {
        // Fall back to DrawVertices with the buffer contents
        DrawVertices(PrimitiveType, count, [metal_buffer contents], vType, psType);
        return;
    }

    MTLPrimitiveType metal_primitive;
    switch (PrimitiveType) {
        case PRIMITIVE_TYPE_TRIANGLE_LIST:  metal_primitive = MTLPrimitiveTypeTriangle; break;
        case PRIMITIVE_TYPE_TRIANGLE_STRIP: metal_primitive = MTLPrimitiveTypeTriangleStrip; break;
        case PRIMITIVE_TYPE_LINE_LIST:      metal_primitive = MTLPrimitiveTypeLine; break;
        case PRIMITIVE_TYPE_LINE_STRIP:     metal_primitive = MTLPrimitiveTypeLineStrip; break;
        default: return;
    }

    apply_render_state(g_impl, vType, psType);

    if (g_impl->current_encoder == nil) return;

    [g_impl->current_encoder setVertexBuffer:metal_buffer offset:0 atIndex:0];
    [g_impl->current_encoder drawPrimitives:metal_primitive vertexStart:0 vertexCount:count];
}

// ==================================================================
// Command buffer recording
// ==================================================================

void C4JRender::CBuffLockStaticCreations()
{
    if (!g_impl) return;
    g_impl->command_buffers_locked = true;
}

int C4JRender::CBuffCreate(int count)
{
    if (!g_impl) return -1;

    // Find first available slot
    for (int i = 0; i < MAX_COMMAND_BUFFERS; i++) {
        if (!g_impl->command_buffers[i].in_use) {
            g_impl->command_buffers[i].in_use = true;
            g_impl->command_buffers[i].commands.clear();
            g_impl->command_buffers[i].is_static = g_impl->command_buffers_locked;
            return i;
        }
    }
    return -1;
}

void C4JRender::CBuffDelete(int first, int count)
{
    if (!g_impl) return;
    for (int i = first; i < first + count && i < MAX_COMMAND_BUFFERS; i++) {
        if (i >= 0) {
            g_impl->command_buffers[i].in_use = false;
            g_impl->command_buffers[i].commands.clear();
        }
    }
}

void C4JRender::CBuffStart(int index, bool full)
{
    if (!g_impl || index < 0 || index >= MAX_COMMAND_BUFFERS) return;
    g_impl->recording_command_buffer = index;
    if (full) {
        g_impl->command_buffers[index].commands.clear();
    }
}

void C4JRender::CBuffClear(int index)
{
    if (!g_impl || index < 0 || index >= MAX_COMMAND_BUFFERS) return;
    g_impl->command_buffers[index].commands.clear();
}

int C4JRender::CBuffSize(int index)
{
    if (!g_impl || index < 0 || index >= MAX_COMMAND_BUFFERS) return 0;
    return (int)g_impl->command_buffers[index].commands.size();
}

void C4JRender::CBuffEnd()
{
    if (!g_impl) return;
    g_impl->recording_command_buffer = -1;
}

bool C4JRender::CBuffCall(int index, bool full)
{
    if (!g_impl || index < 0 || index >= MAX_COMMAND_BUFFERS) return false;
    if (!g_impl->command_buffers[index].in_use) return false;

    // Replay all recorded commands
    for (auto &cmd : g_impl->command_buffers[index].commands) {
        if (cmd.type == RecordedDrawCommand::CMD_DRAW_VERTICES) {
            // Restore uniforms snapshot
            g_impl->uniforms = cmd.uniforms_snapshot;
            g_impl->bound_texture_index = cmd.bound_texture_index;

            // Restore matrices from uniforms
            g_impl->matrix_current[0] = cmd.uniforms_snapshot.modelview_matrix;
            g_impl->matrix_current[1] = cmd.uniforms_snapshot.projection_matrix;
            g_impl->matrix_current[2] = cmd.uniforms_snapshot.texture_matrix;

            DrawVertices(cmd.primitive_type, cmd.vertex_count,
                        cmd.vertex_data.data(), cmd.vertex_type, cmd.pixel_shader_type);
        }
    }

    return true;
}

void C4JRender::CBuffTick()
{
    if (!g_impl) return;
    // Housekeeping for command buffers (no-op for Metal)
}

void C4JRender::CBuffDeferredModeStart()
{
    if (!g_impl) return;
    g_impl->deferred_mode = true;
}

void C4JRender::CBuffDeferredModeEnd()
{
    if (!g_impl) return;
    g_impl->deferred_mode = false;
}

// ==================================================================
// Texture management
// ==================================================================

int C4JRender::TextureCreate()
{
    if (!g_impl) return -1;

    // Find first free texture slot
    for (int i = 0; i < MAX_TEXTURES; i++) {
        if (!g_impl->textures[i].in_use) {
            g_impl->textures[i].in_use = true;
            g_impl->textures[i].texture = nil;
            g_impl->textures[i].width = 0;
            g_impl->textures[i].height = 0;
            g_impl->textures[i].mip_levels = g_impl->texture_levels_hint;
            g_impl->textures[i].min_filter = GL_NEAREST;
            g_impl->textures[i].mag_filter = GL_NEAREST;
            g_impl->textures[i].wrap_s = GL_REPEAT;
            g_impl->textures[i].wrap_t = GL_REPEAT;
            return i;
        }
    }
    return -1;
}

void C4JRender::TextureFree(int idx)
{
    if (!g_impl || idx < 0 || idx >= MAX_TEXTURES) return;
    g_impl->textures[idx].texture = nil;
    g_impl->textures[idx].in_use = false;
}

void C4JRender::TextureBind(int idx)
{
    if (!g_impl) return;
    g_impl->bound_texture_index = idx;
}

void C4JRender::TextureBindVertex(int idx)
{
    if (!g_impl) return;
    g_impl->bound_vertex_texture_index = idx;
}

void C4JRender::TextureSetTextureLevels(int levels)
{
    if (!g_impl) return;
    g_impl->texture_levels_hint = levels;

    // Also update the currently bound texture entry
    int idx = g_impl->bound_texture_index;
    if (idx >= 0 && idx < MAX_TEXTURES && g_impl->textures[idx].in_use) {
        g_impl->textures[idx].mip_levels = levels;
    }
}

int C4JRender::TextureGetTextureLevels()
{
    if (!g_impl) return 1;
    int idx = g_impl->bound_texture_index;
    if (idx >= 0 && idx < MAX_TEXTURES && g_impl->textures[idx].in_use) {
        return g_impl->textures[idx].mip_levels;
    }
    return 1;
}

void C4JRender::TextureData(int width, int height, void *data, int level, eTextureFormat format)
{
    if (!g_impl) return;
    int idx = g_impl->bound_texture_index;
    if (idx < 0 || idx >= MAX_TEXTURES || !g_impl->textures[idx].in_use) return;

    MetalTextureEntry &entry = g_impl->textures[idx];

    // Create or replace the Metal texture if this is level 0 or dimensions changed
    if (level == 0 || entry.texture == nil) {
        // Validate dimensions - Metal requires non-zero width/height
        if (width <= 0 || height <= 0) {
            NSLog(@"[MetalRenderer] WARNING: TextureData called with zero dimensions (%dx%d) for slot %d, skipping", width, height, g_impl->bound_texture_index);
            return;
        }
        int mip_count = entry.mip_levels > 0 ? entry.mip_levels : 1;

        MTLTextureDescriptor *desc = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                         width:width
                                        height:height
                                     mipmapped:(mip_count > 1)];
        desc.usage = MTLTextureUsageShaderRead;
        desc.mipmapLevelCount = mip_count;

        entry.texture = [g_impl->device newTextureWithDescriptor:desc];
        entry.width = width;
        entry.height = height;
    }

    // Upload pixel data to the specified mip level
    if (data && entry.texture) {
        // Calculate mip dimensions
        int mip_width = width;
        int mip_height = height;
        if (level > 0) {
            mip_width = max(1, entry.width >> level);
            mip_height = max(1, entry.height >> level);
        }

        MTLRegion region = MTLRegionMake2D(0, 0, mip_width, mip_height);
        int bytes_per_row = mip_width * 4; // 4 bytes per pixel (RGBA8)

        [entry.texture replaceRegion:region
                         mipmapLevel:level
                           withBytes:data
                         bytesPerRow:bytes_per_row];
    }
}

void C4JRender::TextureDataUpdate(int xoffset, int yoffset, int width, int height, void *data, int level)
{
    if (!g_impl || !data) return;
    int idx = g_impl->bound_texture_index;
    if (idx < 0 || idx >= MAX_TEXTURES || !g_impl->textures[idx].in_use) return;

    MetalTextureEntry &entry = g_impl->textures[idx];
    if (!entry.texture) return;

    MTLRegion region = MTLRegionMake2D(xoffset, yoffset, width, height);
    int bytes_per_row = width * 4;

    [entry.texture replaceRegion:region
                     mipmapLevel:level
                       withBytes:data
                     bytesPerRow:bytes_per_row];
}

void C4JRender::TextureSetParam(int param, int value)
{
    if (!g_impl) return;
    int idx = g_impl->bound_texture_index;
    if (idx < 0 || idx >= MAX_TEXTURES || !g_impl->textures[idx].in_use) return;

    MetalTextureEntry &entry = g_impl->textures[idx];

    switch (param) {
        case GL_TEXTURE_MIN_FILTER:
            entry.min_filter = value;
            break;
        case GL_TEXTURE_MAG_FILTER:
            entry.mag_filter = value;
            break;
        case GL_TEXTURE_WRAP_S:
            entry.wrap_s = value;
            break;
        case GL_TEXTURE_WRAP_T:
            entry.wrap_t = value;
            break;
    }
    // Sampler selection happens dynamically in get_sampler_for_texture
}

void C4JRender::TextureDynamicUpdateStart()
{
    // Metal textures can be updated at any time; no special start needed
}

void C4JRender::TextureDynamicUpdateEnd()
{
    // No-op for Metal
}

HRESULT C4JRender::LoadTextureData(const char *szFilename, D3DXIMAGE_INFO *pSrcInfo, int **ppDataOut)
{
    if (!g_impl || !szFilename || !ppDataOut) return E_INVALIDARG;

    // Load image file using Apple's ImageIO framework
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:szFilename];
        // Convert Windows backslashes to forward slashes
        path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];

        NSData *file_data = [NSData dataWithContentsOfFile:path];
        if (!file_data) {
            NSLog(@"[MetalRenderer] LoadTextureData: file not found: %@", path);
            return E_FAIL;
        }

        // Use CGImage to decode
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)file_data);
        if (!provider) return E_FAIL;

        CGImageRef image = nullptr;

        // Try PNG first, then JPEG
        image = CGImageCreateWithPNGDataProvider(provider, nullptr, true, kCGRenderingIntentDefault);
        if (!image) {
            image = CGImageCreateWithJPEGDataProvider(provider, nullptr, true, kCGRenderingIntentDefault);
        }
        CGDataProviderRelease(provider);

        if (!image) return E_FAIL;

        int img_width = (int)CGImageGetWidth(image);
        int img_height = (int)CGImageGetHeight(image);

        if (pSrcInfo) {
            pSrcInfo->Width = img_width;
            pSrcInfo->Height = img_height;
        }

        // Render into RGBA8 buffer
        int *rgba_data = (int *)malloc(img_width * img_height * 4);
        CGColorSpaceRef colour_space = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(
            rgba_data, img_width, img_height, 8, img_width * 4,
            colour_space, kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(ctx, CGRectMake(0, 0, img_width, img_height), image);
        CGContextRelease(ctx);
        CGColorSpaceRelease(colour_space);
        CGImageRelease(image);

        *ppDataOut = rgba_data;
        return S_OK;
    }
}

HRESULT C4JRender::LoadTextureData(BYTE *pbData, DWORD dwBytes, D3DXIMAGE_INFO *pSrcInfo, int **ppDataOut)
{
    if (!g_impl || !pbData || !ppDataOut) return E_INVALIDARG;

    @autoreleasepool {
        NSData *data = [NSData dataWithBytesNoCopy:pbData length:dwBytes freeWhenDone:NO];
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        if (!provider) return E_FAIL;

        CGImageRef image = CGImageCreateWithPNGDataProvider(provider, nullptr, true, kCGRenderingIntentDefault);
        if (!image) {
            image = CGImageCreateWithJPEGDataProvider(provider, nullptr, true, kCGRenderingIntentDefault);
        }
        CGDataProviderRelease(provider);

        if (!image) return E_FAIL;

        int img_width = (int)CGImageGetWidth(image);
        int img_height = (int)CGImageGetHeight(image);

        if (pSrcInfo) {
            pSrcInfo->Width = img_width;
            pSrcInfo->Height = img_height;
        }

        int *rgba_data = (int *)malloc(img_width * img_height * 4);
        CGColorSpaceRef colour_space = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(
            rgba_data, img_width, img_height, 8, img_width * 4,
            colour_space, kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(ctx, CGRectMake(0, 0, img_width, img_height), image);
        CGContextRelease(ctx);
        CGColorSpaceRelease(colour_space);
        CGImageRelease(image);

        *ppDataOut = rgba_data;
        return S_OK;
    }
}

HRESULT C4JRender::SaveTextureData(const char *szFilename, D3DXIMAGE_INFO *pSrcInfo, int *ppDataOut)
{
    if (!g_impl || !szFilename || !pSrcInfo || !ppDataOut) return E_INVALIDARG;

    @autoreleasepool {
        int img_width = pSrcInfo->Width;
        int img_height = pSrcInfo->Height;

        CGColorSpaceRef colour_space = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(
            ppDataOut, img_width, img_height, 8, img_width * 4,
            colour_space, kCGImageAlphaPremultipliedLast);

        CGImageRef image = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);
        CGColorSpaceRelease(colour_space);

        if (!image) return E_FAIL;

        NSString *path = [NSString stringWithUTF8String:szFilename];
        NSURL *url = [NSURL fileURLWithPath:path];
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)url, kUTTypePNG, 1, nullptr);

        if (!dest) {
            CGImageRelease(image);
            return E_FAIL;
        }

        CGImageDestinationAddImage(dest, image, nullptr);
        bool success = CGImageDestinationFinalize(dest);
        CFRelease(dest);
        CGImageRelease(image);

        return success ? S_OK : E_FAIL;
    }
}

HRESULT C4JRender::SaveTextureDataToMemory(void *pOutput, int outputCapacity, int *outputLength, int width, int height, int *ppDataIn)
{
    if (!g_impl || !pOutput || !outputLength || !ppDataIn) return E_INVALIDARG;

    @autoreleasepool {
        CGColorSpaceRef colour_space = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(
            ppDataIn, width, height, 8, width * 4,
            colour_space, kCGImageAlphaPremultipliedLast);

        CGImageRef image = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);
        CGColorSpaceRelease(colour_space);

        if (!image) return E_FAIL;

        NSMutableData *png_data = [NSMutableData data];
        CGImageDestinationRef dest = CGImageDestinationCreateWithData(
            (__bridge CFMutableDataRef)png_data, kUTTypePNG, 1, nullptr);

        if (!dest) {
            CGImageRelease(image);
            return E_FAIL;
        }

        CGImageDestinationAddImage(dest, image, nullptr);
        CGImageDestinationFinalize(dest);
        CFRelease(dest);
        CGImageRelease(image);

        int copy_size = min((int)png_data.length, outputCapacity);
        memcpy(pOutput, png_data.bytes, copy_size);
        *outputLength = copy_size;

        return S_OK;
    }
}

void C4JRender::TextureGetStats()
{
    if (!g_impl) return;

    int active_count = 0;
    size_t total_memory = 0;

    for (int i = 0; i < MAX_TEXTURES; i++) {
        if (g_impl->textures[i].in_use && g_impl->textures[i].texture) {
            active_count++;
            total_memory += g_impl->textures[i].width * g_impl->textures[i].height * 4;
        }
    }

    NSLog(@"[MetalRenderer] Texture stats: %d active, ~%zuKB estimated", active_count, total_memory / 1024);
}

void *C4JRender::TextureGetTexture(int idx)
{
    if (!g_impl || idx < 0 || idx >= MAX_TEXTURES || !g_impl->textures[idx].in_use) return nullptr;
    // Return the id<MTLTexture> as a void*
    return (__bridge void *)g_impl->textures[idx].texture;
}

// ==================================================================
// State control
// ==================================================================

void C4JRender::StateSetColour(float r, float g, float b, float a)
{
    if (!g_impl) return;
    g_impl->uniforms.colour_tint = simd_make_float4(r, g, b, a);
}

void C4JRender::StateSetDepthMask(bool enable)
{
    if (!g_impl) return;
    g_impl->depth_write_enabled = enable;
}

void C4JRender::StateSetBlendEnable(bool enable)
{
    if (!g_impl) return;
    g_impl->blend_enabled = enable;
}

void C4JRender::StateSetBlendFunc(int src, int dst)
{
    if (!g_impl) return;
    g_impl->blend_src = src;
    g_impl->blend_dst = dst;
}

void C4JRender::StateSetBlendFactor(unsigned int colour)
{
    if (!g_impl) return;
    g_impl->blend_factor_colour = colour;
}

void C4JRender::StateSetAlphaFunc(int func, float param)
{
    if (!g_impl) return;
    g_impl->uniforms.alpha_test_func = func;
    g_impl->uniforms.alpha_test_ref = param;
}

void C4JRender::StateSetDepthFunc(int func)
{
    if (!g_impl) return;
    g_impl->depth_func = func;
}

void C4JRender::StateSetFaceCull(bool enable)
{
    if (!g_impl) return;
    g_impl->face_cull_enabled = enable;
}

void C4JRender::StateSetFaceCullCW(bool enable)
{
    if (!g_impl) return;
    g_impl->face_cull_cw = enable;
}

void C4JRender::StateSetLineWidth(float width)
{
    // Metal does not support variable line width on most hardware.
    // Lines are always 1 pixel wide. This is a no-op.
}

void C4JRender::StateSetWriteEnable(bool red, bool green, bool blue, bool alpha)
{
    if (!g_impl) return;
    g_impl->colour_write_r = red;
    g_impl->colour_write_g = green;
    g_impl->colour_write_b = blue;
    g_impl->colour_write_a = alpha;
    // Note: colour write mask is set per-pipeline in Metal.
    // For full correctness, pipeline states would need to be recreated or cached.
}

void C4JRender::StateSetDepthTestEnable(bool enable)
{
    if (!g_impl) return;
    g_impl->depth_test_enabled = enable;
}

void C4JRender::StateSetAlphaTestEnable(bool enable)
{
    if (!g_impl) return;
    g_impl->uniforms.alpha_test_enable = enable ? 1 : 0;
}

void C4JRender::StateSetDepthSlopeAndBias(float slope, float bias)
{
    if (!g_impl) return;
    g_impl->depth_slope = slope;
    g_impl->depth_bias = bias;
}

void C4JRender::StateSetFogEnable(bool enable)
{
    if (!g_impl) return;
    g_impl->uniforms.fog_enable = enable ? 1 : 0;
}

void C4JRender::StateSetFogMode(int mode)
{
    if (!g_impl) return;
    // mode: GL_LINEAR=1, GL_EXP=2
    // Map to shader: 0=linear, 1=exp, 2=exp2
    if (mode == GL_LINEAR) {
        g_impl->uniforms.fog_mode = 0;
    } else if (mode == GL_EXP) {
        g_impl->uniforms.fog_mode = 1;
    } else {
        g_impl->uniforms.fog_mode = 2;
    }
}

void C4JRender::StateSetFogNearDistance(float dist)
{
    if (!g_impl) return;
    g_impl->uniforms.fog_near = dist;
}

void C4JRender::StateSetFogFarDistance(float dist)
{
    if (!g_impl) return;
    g_impl->uniforms.fog_far = dist;
}

void C4JRender::StateSetFogDensity(float density)
{
    if (!g_impl) return;
    g_impl->uniforms.fog_density = density;
}

void C4JRender::StateSetFogColour(float red, float green, float blue)
{
    if (!g_impl) return;
    g_impl->uniforms.fog_colour = simd_make_float4(red, green, blue, 1.0f);
}

void C4JRender::StateSetLightingEnable(bool enable)
{
    if (!g_impl) return;
    g_impl->uniforms.lighting_enable = enable ? 1 : 0;
}

void C4JRender::StateSetVertexTextureUV(float u, float v)
{
    if (!g_impl) return;
    g_impl->uniforms.vertex_texture_uv = simd_make_float2(u, v);
}

void C4JRender::StateSetLightColour(int light, float red, float green, float blue)
{
    if (!g_impl || light < 0 || light >= MAX_LIGHTS) return;
    // light index: GL_LIGHT0=8, GL_LIGHT1=9, so subtract GL_LIGHT0
    int light_index = light - GL_LIGHT0;
    if (light_index < 0 || light_index >= MAX_LIGHTS) {
        light_index = light; // If already 0-based
    }
    if (light_index >= 0 && light_index < MAX_LIGHTS) {
        g_impl->uniforms.light_colour[light_index] = simd_make_float4(red, green, blue, 1.0f);
    }
}

void C4JRender::StateSetLightAmbientColour(float red, float green, float blue)
{
    if (!g_impl) return;
    g_impl->uniforms.ambient_colour = simd_make_float4(red, green, blue, 1.0f);
}

void C4JRender::StateSetLightDirection(int light, float x, float y, float z)
{
    if (!g_impl || light < 0) return;
    int light_index = light - GL_LIGHT0;
    if (light_index < 0 || light_index >= MAX_LIGHTS) {
        light_index = light;
    }
    if (light_index >= 0 && light_index < MAX_LIGHTS) {
        g_impl->uniforms.light_direction[light_index] = simd_make_float4(x, y, z, 0.0f);
    }
}

void C4JRender::StateSetLightEnable(int light, bool enable)
{
    if (!g_impl || light < 0) return;
    int light_index = light - GL_LIGHT0;
    if (light_index < 0 || light_index >= MAX_LIGHTS) {
        light_index = light;
    }
    if (light_index >= 0 && light_index < MAX_LIGHTS) {
        g_impl->uniforms.light_enable[light_index] = enable ? 1 : 0;
    }
}

void C4JRender::StateSetViewport(eViewportType viewportType)
{
    if (!g_impl) return;
    g_impl->current_viewport = viewportType;
}

void C4JRender::StateSetEnableViewportClipPlanes(bool enable)
{
    // Metal uses scissor rects for clip regions.
    // For simplicity, this is a no-op; viewport already clips to screen.
}

void C4JRender::StateSetTexGenCol(int col, float x, float y, float z, float w, bool eyeSpace)
{
    if (!g_impl || col < 0 || col >= 4) return;
    g_impl->uniforms.texgen_col[col] = simd_make_float4(x, y, z, w);
    g_impl->uniforms.texgen_enable = 1;
    g_impl->uniforms.texgen_eye_space = eyeSpace ? 1 : 0;
}

void C4JRender::StateSetStencil(int Function, uint8_t stencil_ref, uint8_t stencil_func_mask, uint8_t stencil_write_mask)
{
    if (!g_impl) return;
    g_impl->stencil_func = Function;
    g_impl->stencil_ref = stencil_ref;
    g_impl->stencil_func_mask = stencil_func_mask;
    g_impl->stencil_write_mask = stencil_write_mask;
}

void C4JRender::StateSetForceLOD(int LOD)
{
    if (!g_impl) return;
    g_impl->uniforms.force_lod = LOD;
}

// ==================================================================
// Event tracking (debug markers)
// ==================================================================

void C4JRender::BeginEvent(LPCWSTR eventName)
{
    if (!g_impl || !g_impl->current_encoder) return;
    // Convert wide string to NSString for Metal debug marker
    if (eventName) {
        NSString *label = [NSString stringWithFormat:@"%ls", eventName];
        [g_impl->current_encoder pushDebugGroup:label];
    }
}

void C4JRender::EndEvent()
{
    if (!g_impl || !g_impl->current_encoder) return;
    [g_impl->current_encoder popDebugGroup];
}

// ==================================================================
// Suspend / Resume
// ==================================================================

void C4JRender::Suspend()
{
    if (!g_impl) return;
    // End any active encoder and commit current work
    end_render_encoder(g_impl);
    if (g_impl->current_command_buffer) {
        [g_impl->current_command_buffer commit];
        [g_impl->current_command_buffer waitUntilCompleted];
        g_impl->current_command_buffer = nil;
    }
    g_impl->current_drawable = nil;
    g_impl->suspended = true;
}

bool C4JRender::Suspended()
{
    if (!g_impl) return false;
    return g_impl->suspended;
}

void C4JRender::Resume()
{
    if (!g_impl) return;
    g_impl->suspended = false;
}
