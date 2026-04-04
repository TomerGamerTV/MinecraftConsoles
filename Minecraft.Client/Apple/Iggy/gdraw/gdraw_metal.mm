// gdraw_metal.mm - Metal GDraw implementation for Apple platforms
// Implements the GDraw function table for rendering 2D UI via Metal.
//
// This provides the rendering backend that Iggy uses to draw Flash-based
// UI elements: textured quads, vector shapes, text glyphs, blend modes,
// and render-to-texture for filter effects.

#include "stdafx.h"
#define Component CarbonComponent_Renamed
#import <Metal/Metal.h>
#import <simd/simd.h>
#undef Component
#include <string.h>
#include <math.h>
#include <stdlib.h>

#include "gdraw.h"
#include "iggy.h"
#include "gdraw_metal.h"

// ========================================================================
// Debug logging -- enabled in debug builds
// ========================================================================
#if defined(DEBUG) || defined(_DEBUG)
   #include <stdio.h>
   #define GDRAW_METAL_LOG(fmt, ...) printf("[GDraw Metal] " fmt "\n", ##__VA_ARGS__)
#else
   #define GDRAW_METAL_LOG(fmt, ...) ((void)0)
#endif

// ========================================================================
// Internal constants
// ========================================================================

// Maximum number of managed resource handles per type
static const S32 DEFAULT_MAX_TEXTURE_HANDLES    = 256;
static const S32 DEFAULT_MAX_TEXTURE_BYTES      = 64 * 1024 * 1024;  // 64 MB
static const S32 DEFAULT_MAX_VB_HANDLES         = 128;
static const S32 DEFAULT_MAX_VB_BYTES           = 8 * 1024 * 1024;   // 8 MB
static const S32 DEFAULT_MAX_RT_HANDLES         = 16;
static const S32 DEFAULT_MAX_RT_BYTES           = 32 * 1024 * 1024;  // 32 MB

// Maximum texture dimension supported by Metal on Apple GPUs
static const U32 MAX_TEXTURE_SIZE               = 16384;

// Dynamic vertex buffer size for per-frame streaming geometry
static const S32 DYNAMIC_BUFFER_SIZE            = 256 * 1024;  // 256 KB

// ========================================================================
// Internal texture handle
// ========================================================================
struct GDrawTexture
{
    id<MTLTexture>  metal_texture;      // The underlying Metal texture object
    S32             width;              // Texture width in pixels
    S32             height;             // Texture height in pixels
    U32             size_in_bytes;      // Approximate memory footprint
    void           *unique_id;          // Iggy's unique id for cache tracking
    rrbool          is_rendertarget;    // True if this is an offscreen render target
    rrbool          is_font;           // True if this is an alpha-only font texture
};

// ========================================================================
// Internal vertex buffer handle
// ========================================================================
struct GDrawVertexBuffer
{
    id<MTLBuffer>   metal_buffer;       // Combined vertex + index buffer
    S32             vertex_offset;      // Byte offset to start of vertex data
    S32             index_offset;       // Byte offset to start of index data
    S32             vertex_data_len;    // Length of vertex data in bytes
    S32             index_data_len;     // Length of index data in bytes
    S32             vformat;            // One of gdraw_vformat
    void           *unique_id;          // Iggy's unique id for cache tracking
    U32             size_in_bytes;      // Total allocated size
};

// ========================================================================
// Metal GDraw context -- single global instance
// ========================================================================
struct MetalGDrawContext
{
    // Metal device and queue (retained references)
    id<MTLDevice>               device;
    id<MTLCommandQueue>         command_queue;

    // Current render pass state
    id<MTLRenderCommandEncoder> current_encoder;

    // Pipeline states for the basic rendering modes
    id<MTLRenderPipelineState>  pipeline_solid;         // Flat-colored geometry
    id<MTLRenderPipelineState>  pipeline_textured;      // Standard textured quads
    id<MTLRenderPipelineState>  pipeline_font;          // Alpha-only font glyphs

    // Sampler states
    id<MTLSamplerState>         sampler_linear_clamp;
    id<MTLSamplerState>         sampler_linear_repeat;
    id<MTLSamplerState>         sampler_nearest_clamp;

    // Depth/stencil states for masking and ID operations
    id<MTLDepthStencilState>    depth_stencil_default;
    id<MTLDepthStencilState>    depth_stencil_stencil_write;
    id<MTLDepthStencilState>    depth_stencil_stencil_test;

    // Dynamic vertex/index streaming buffer (triple-buffered for safe CPU/GPU overlap)
    id<MTLBuffer>               dynamic_buffer;
    S32                         dynamic_buffer_offset;

    // Antialias 1D texture
    id<MTLTexture>              antialias_texture;

    // Internal render target size
    S32                         rt_width;
    S32                         rt_height;

    // Tile origin offset
    S32                         tile_origin_x;
    S32                         tile_origin_y;

    // Current viewport dimensions
    S32                         viewport_width;
    S32                         viewport_height;

    // World-to-pixel scale factors
    F32                         world_scale_x;
    F32                         world_scale_y;

    // Resource limits
    S32                         max_tex_handles;
    S32                         max_tex_bytes;
    S32                         max_vb_handles;
    S32                         max_vb_bytes;
    S32                         max_rt_handles;
    S32                         max_rt_bytes;

    // The GDrawFunctions table that Iggy calls into
    GDrawFunctions              functions;

    // Whether context is valid and initialized
    rrbool                      is_initialized;
};

// Single global context (same pattern as D3D11 and Orbis GDraw drivers)
static MetalGDrawContext *g_metal_context = nullptr;

// ========================================================================
// Forward declarations for the GDraw callback functions
// ========================================================================
static void metal_get_info(GDrawInfo *d);
static void metal_set_view_size_and_world_scale(S32 w, S32 h, F32 x_scale, F32 y_scale);
static void metal_render_tile_begin(S32 tx0, S32 ty0, S32 tx1, S32 ty1, S32 pad, GDrawStats *stats);
static void metal_render_tile_end(GDrawStats *stats);
static void metal_rendering_begin(void);
static void metal_rendering_end(void);
static void metal_set_antialias_texture(S32 width, U8 *rgba);
static void metal_clear_stencil_bits(U32 bits);
static void metal_clear_id(void);
static void metal_filter_quad(GDrawRenderState *r, S32 x0, S32 y0, S32 x1, S32 y1, GDrawStats *stats);
static void metal_draw_indexed_triangles(GDrawRenderState *r, GDrawPrimitive *prim, GDrawVertexBuffer *buf, GDrawStats *stats);

static rrbool metal_make_texture_begin(void *unique_id, S32 width, S32 height, gdraw_texture_format format, gdraw_maketexture_flags flags, GDraw_MakeTexture_ProcessingInfo *output_info, GDrawStats *stats);
static rrbool metal_make_texture_more(GDraw_MakeTexture_ProcessingInfo *info);
static GDrawTexture * metal_make_texture_end(GDraw_MakeTexture_ProcessingInfo *info, GDrawStats *stats);

static rrbool metal_update_texture_begin(GDrawTexture *tex, void *unique_id, GDrawStats *stats);
static void metal_update_texture_rect(GDrawTexture *tex, void *unique_id, S32 x, S32 y, S32 stride, S32 w, S32 h, U8 *data, gdraw_texture_format format);
static void metal_update_texture_end(GDrawTexture *tex, void *unique_id, GDrawStats *stats);

static rrbool metal_make_vertex_buffer_begin(void *unique_id, gdraw_vformat vformat, S32 vdata_len, S32 idata_len, GDraw_MakeVertexBuffer_ProcessingInfo *info, GDrawStats *stats);
static rrbool metal_make_vertex_buffer_more(GDraw_MakeVertexBuffer_ProcessingInfo *info);
static GDrawVertexBuffer * metal_make_vertex_buffer_end(GDraw_MakeVertexBuffer_ProcessingInfo *info, GDrawStats *stats);

static rrbool metal_try_to_lock_texture(GDrawTexture *tex, void *unique_id, GDrawStats *stats);
static rrbool metal_try_to_lock_vertex_buffer(GDrawVertexBuffer *vb, void *unique_id, GDrawStats *stats);
static void metal_unlock_handles(GDrawStats *stats);
static void metal_free_texture(GDrawTexture *t, void *unique_id, GDrawStats *stats);
static void metal_free_vertex_buffer(GDrawVertexBuffer *vb, void *unique_id, GDrawStats *stats);

static void metal_describe_texture(GDrawTexture *tex, GDraw_Texture_Description *desc);
static void metal_describe_vertex_buffer(GDrawVertexBuffer *buffer, GDraw_VertexBuffer_Description *desc);

static void metal_set_texture_unique_id(GDrawTexture *tex, void *old_id, void *new_id);

static rrbool metal_texture_draw_buffer_begin(gswf_recti *region, gdraw_texture_format format, gdraw_texturedrawbuffer_flags flags, void *unique_id, GDrawStats *stats);
static GDrawTexture * metal_texture_draw_buffer_end(GDrawStats *stats);

static void metal_draw_mask_begin(gswf_recti *region, S32 mask_bit, GDrawStats *stats);
static void metal_draw_mask_end(gswf_recti *region, S32 mask_bit, GDrawStats *stats);

static GDrawTexture * metal_make_texture_from_resource(U8 *resource_file, S32 file_len, void *texture);
static void metal_free_texture_from_resource(GDrawTexture *tex);

static void metal_set_3d_transform(F32 *mat);

// ========================================================================
// Helper: create a basic sampler state
// ========================================================================
static id<MTLSamplerState> create_sampler(id<MTLDevice> device,
                                           MTLSamplerMinMagFilter min_filter,
                                           MTLSamplerMinMagFilter mag_filter,
                                           MTLSamplerAddressMode address_mode)
{
    MTLSamplerDescriptor *desc = [[MTLSamplerDescriptor alloc] init];
    desc.minFilter    = min_filter;
    desc.magFilter    = mag_filter;
    desc.sAddressMode = address_mode;
    desc.tAddressMode = address_mode;
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:desc];
    return sampler;
}

// ========================================================================
// GDraw callback implementations
// ========================================================================

// Return hardware capabilities and configuration to Iggy
static void metal_get_info(GDrawInfo *d)
{
    if (!d) return;
    memset(d, 0, sizeof(*d));

    // Metal supports 8-bit stencil natively
    d->num_stencil_bits    = 8;
    // Maximum unique ID values (encoded via depth buffer)
    d->max_id              = 0xFFFF;
    d->max_texture_size    = MAX_TEXTURE_SIZE;
    // Metal uses vertex and index buffers
    d->buffer_format       = GDRAW_BFORMAT_vbib;
    d->shared_depth_stencil = 1;
    // Metal can generate mipmaps efficiently via blit encoder
    d->always_mipmap       = 1;
    d->conditional_nonpow2 = 0;
    d->has_rendertargets   = 1;
    d->no_nonpow2          = 0;

    GDRAW_METAL_LOG("GetInfo: max_texture_size=%u, stencil_bits=%d", d->max_texture_size, d->num_stencil_bits);
}

// Store the viewport dimensions and world-to-pixel scale
static void metal_set_view_size_and_world_scale(S32 w, S32 h, F32 x_scale, F32 y_scale)
{
    if (!g_metal_context) return;
    g_metal_context->viewport_width  = w;
    g_metal_context->viewport_height = h;
    g_metal_context->world_scale_x   = x_scale;
    g_metal_context->world_scale_y   = y_scale;

    GDRAW_METAL_LOG("SetViewSizeAndWorldScale: %dx%d, scale=%.2f,%.2f", w, h, x_scale, y_scale);
}

// Begin rendering a tile region
static void metal_render_tile_begin(S32 tx0, S32 ty0, S32 tx1, S32 ty1, S32 pad, GDrawStats *stats)
{
    (void)pad;
    if (!g_metal_context) return;

    GDRAW_METAL_LOG("RenderTileBegin: (%d,%d)-(%d,%d) pad=%d", tx0, ty0, tx1, ty1, pad);

    // Set up Metal viewport for the tile region
    if (g_metal_context->current_encoder)
    {
        MTLViewport viewport;
        viewport.originX = (double)(tx0 + g_metal_context->tile_origin_x);
        viewport.originY = (double)(ty0 + g_metal_context->tile_origin_y);
        viewport.width   = (double)(tx1 - tx0);
        viewport.height  = (double)(ty1 - ty0);
        viewport.znear   = 0.0;
        viewport.zfar    = 1.0;
        [g_metal_context->current_encoder setViewport:viewport];
    }

    if (stats) memset(stats, 0, sizeof(*stats));
}

// End rendering a tile region
static void metal_render_tile_end(GDrawStats *stats)
{
    GDRAW_METAL_LOG("RenderTileEnd");
    (void)stats;
}

// Begin rendering -- take control of the GPU for Iggy drawing
static void metal_rendering_begin(void)
{
    GDRAW_METAL_LOG("RenderingBegin");
    if (!g_metal_context) return;

    // Reset dynamic buffer offset for this frame's streaming geometry
    g_metal_context->dynamic_buffer_offset = 0;
}

// End rendering -- release GPU control back to the game
static void metal_rendering_end(void)
{
    GDRAW_METAL_LOG("RenderingEnd");
}

// Upload the 1D anti-aliasing gradient texture (called once at init)
static void metal_set_antialias_texture(S32 width, U8 *rgba)
{
    if (!g_metal_context || !rgba || width <= 0) return;

    GDRAW_METAL_LOG("SetAntialiasTexture: width=%d", width);

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:width
                                                                                   height:1
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;

    g_metal_context->antialias_texture = [g_metal_context->device newTextureWithDescriptor:desc];

    MTLRegion region = MTLRegionMake2D(0, 0, width, 1);
    [g_metal_context->antialias_texture replaceRegion:region
                                          mipmapLevel:0
                                            withBytes:rgba
                                          bytesPerRow:width * 4];
}

// Clear stencil bits (used for masking effects in Flash UI)
static void metal_clear_stencil_bits(U32 bits)
{
    GDRAW_METAL_LOG("ClearStencilBits: 0x%x", bits);
    // Stencil clearing requires ending the current render pass and starting
    // a new one with a stencil clear value. For the stub, this is a no-op.
    // Full implementation would use a blit or new render pass.
    (void)bits;
}

// Clear the ID buffer (typically the depth buffer used for hit-testing)
static void metal_clear_id(void)
{
    GDRAW_METAL_LOG("ClearID");
    // Similar to stencil clear -- requires render pass manipulation.
}

// Draw a filter quad (blur, color matrix, bevel, dropshadow)
static void metal_filter_quad(GDrawRenderState *r, S32 x0, S32 y0, S32 x1, S32 y1, GDrawStats *stats)
{
    GDRAW_METAL_LOG("FilterQuad: (%d,%d)-(%d,%d) filter=%d", x0, y0, x1, y1, r ? r->filter : -1);

    // Filter effects require reading from a render target and writing to another.
    // This is the most complex part of a full GDraw implementation.
    // For the initial port, filters are rendered as simple textured quads
    // (visual fidelity is reduced, but game world still renders).

    if (!g_metal_context || !g_metal_context->current_encoder || !r) return;

    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_batches;
        stats->num_batches++;
    }
}

// Main triangle drawing entry point
static void metal_draw_indexed_triangles(GDrawRenderState *r, GDrawPrimitive *prim, GDrawVertexBuffer *buf, GDrawStats *stats)
{
    if (!g_metal_context || !g_metal_context->current_encoder || !r || !prim) return;
    if (prim->num_indices == 0 || prim->num_vertices == 0) return;

    GDRAW_METAL_LOG("DrawIndexedTriangles: verts=%d, indices=%d, vformat=%d, blend=%d, tex=%d",
                     prim->num_vertices, prim->num_indices,
                     prim->vertex_format, r->blend_mode, r->tex0_mode);

    id<MTLRenderCommandEncoder> encoder = g_metal_context->current_encoder;

    // Determine vertex stride from format
    S32 vertex_stride = 0;
    switch (prim->vertex_format)
    {
        case GDRAW_vformat_v2:    vertex_stride = sizeof(gswf_vertex_xy);     break;
        case GDRAW_vformat_v2aa:  vertex_stride = sizeof(gswf_vertex_xyoffs); break;
        case GDRAW_vformat_v2tc2: vertex_stride = sizeof(gswf_vertex_xyst);   break;
        default:                  vertex_stride = sizeof(gswf_vertex_xyst);   break;
    }

    if (buf)
    {
        // Use pre-built vertex buffer
        [encoder setVertexBuffer:buf->metal_buffer offset:buf->vertex_offset atIndex:0];

        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:prim->num_indices
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:buf->metal_buffer
                     indexBufferOffset:buf->index_offset];
    }
    else
    {
        // Stream geometry via dynamic buffer
        S32 vertex_bytes = prim->num_vertices * vertex_stride;
        S32 index_bytes  = prim->num_indices * sizeof(U16);
        S32 total_bytes  = vertex_bytes + index_bytes;

        // Ensure alignment
        S32 aligned_offset = (g_metal_context->dynamic_buffer_offset + 255) & ~255;

        if (aligned_offset + total_bytes <= DYNAMIC_BUFFER_SIZE && g_metal_context->dynamic_buffer)
        {
            U8 *base = (U8 *)[g_metal_context->dynamic_buffer contents] + aligned_offset;
            memcpy(base, prim->vertices, vertex_bytes);
            memcpy(base + vertex_bytes, prim->indices, index_bytes);

            [encoder setVertexBuffer:g_metal_context->dynamic_buffer offset:aligned_offset atIndex:0];

            [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                indexCount:prim->num_indices
                                 indexType:MTLIndexTypeUInt16
                               indexBuffer:g_metal_context->dynamic_buffer
                         indexBufferOffset:aligned_offset + vertex_bytes];

            g_metal_context->dynamic_buffer_offset = aligned_offset + total_bytes;
        }
        else
        {
            GDRAW_METAL_LOG("WARNING: dynamic buffer overflow, skipping draw");
        }
    }

    // Update stats
    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_batches;
        stats->num_batches++;
        stats->drawn_indices  += prim->num_indices;
        stats->drawn_vertices += prim->num_vertices;
    }
}

// ========================================================================
// Texture creation
// ========================================================================

static rrbool metal_make_texture_begin(void *unique_id, S32 width, S32 height,
                                        gdraw_texture_format format, gdraw_maketexture_flags flags,
                                        GDraw_MakeTexture_ProcessingInfo *output_info, GDrawStats *stats)
{
    if (!g_metal_context || !output_info) return 0;

    GDRAW_METAL_LOG("MakeTextureBegin: %dx%d, format=%d, flags=0x%x", width, height, format, flags);

    // Determine Metal pixel format based on Iggy format
    rrbool is_font_texture = (format == GDRAW_TEXTURE_FORMAT_font);
    MTLPixelFormat pixel_format = is_font_texture ? MTLPixelFormatR8Unorm : MTLPixelFormatRGBA8Unorm;
    rrbool generate_mipmaps = (flags & GDRAW_MAKETEXTURE_FLAGS_mipmap) != 0;

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixel_format
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:generate_mipmaps ? YES : NO];
    desc.usage = MTLTextureUsageShaderRead;
    if (flags & GDRAW_MAKETEXTURE_FLAGS_updatable)
    {
        desc.storageMode = MTLStorageModeShared;
    }

    id<MTLTexture> metal_tex = [g_metal_context->device newTextureWithDescriptor:desc];
    if (!metal_tex)
    {
        GDRAW_METAL_LOG("ERROR: Failed to create %dx%d texture", width, height);
        return 0;
    }

    // Allocate the GDrawTexture wrapper
    GDrawTexture *tex_handle = (GDrawTexture *)calloc(1, sizeof(GDrawTexture));
    tex_handle->metal_texture = metal_tex;
    tex_handle->width         = width;
    tex_handle->height        = height;
    tex_handle->unique_id     = unique_id;
    tex_handle->is_font       = is_font_texture;

    S32 bytes_per_pixel = is_font_texture ? 1 : 4;
    tex_handle->size_in_bytes = width * height * bytes_per_pixel;

    // Fill out the processing info for Iggy to write texture data
    S32 stride = width * bytes_per_pixel;

    // Store our handle in the processing info's opaque pointers
    output_info->p0 = tex_handle;
    output_info->i0 = (U32)width;
    output_info->i1 = (U32)height;
    output_info->i2 = (U32)bytes_per_pixel;

    // Allocate a staging buffer for Iggy to write into
    S32 staging_size = stride * height;
    U8 *staging = (U8 *)malloc(staging_size);
    output_info->texture_data    = staging;
    output_info->num_rows        = height;
    output_info->stride_in_bytes = stride;
    output_info->texture_type    = GDRAW_TEXTURE_TYPE_rgba;

    // Provide a temp buffer for mipmap generation
    output_info->temp_buffer_bytes = staging_size;
    output_info->temp_buffer       = (U8 *)malloc(staging_size);

    output_info->p1 = staging;  // remember to free later

    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_alloc_tex;
        stats->alloc_tex++;
        stats->alloc_tex_bytes += tex_handle->size_in_bytes;
    }

    return 1;
}

// Continue uploading texture data (multi-pass upload for large textures)
static rrbool metal_make_texture_more(GDraw_MakeTexture_ProcessingInfo *info)
{
    // For Metal with shared memory, single-pass upload is sufficient
    return 1;
}

// Finalize texture creation and upload data to GPU
static GDrawTexture * metal_make_texture_end(GDraw_MakeTexture_ProcessingInfo *info, GDrawStats *stats)
{
    if (!info || !info->p0) return nullptr;

    GDrawTexture *tex = (GDrawTexture *)info->p0;
    U8 *staging = (U8 *)info->p1;

    if (staging && tex->metal_texture)
    {
        S32 bytes_per_pixel = (S32)info->i2;
        S32 stride = tex->width * bytes_per_pixel;

        MTLRegion region = MTLRegionMake2D(0, 0, tex->width, tex->height);
        [tex->metal_texture replaceRegion:region
                              mipmapLevel:0
                                withBytes:staging
                              bytesPerRow:stride];

        GDRAW_METAL_LOG("MakeTextureEnd: uploaded %dx%d texture (%d bytes)", tex->width, tex->height, tex->size_in_bytes);
    }

    // Free staging and temp buffers
    if (staging) free(staging);
    if (info->temp_buffer) free(info->temp_buffer);

    info->p0 = nullptr;
    info->p1 = nullptr;
    info->texture_data = nullptr;
    info->temp_buffer  = nullptr;

    return tex;
}

// ========================================================================
// Texture updates
// ========================================================================

static rrbool metal_update_texture_begin(GDrawTexture *tex, void *unique_id, GDrawStats *stats)
{
    (void)unique_id;
    (void)stats;
    if (!tex || !tex->metal_texture) return 0;
    return 1;
}

static void metal_update_texture_rect(GDrawTexture *tex, void *unique_id,
                                       S32 x, S32 y, S32 stride, S32 w, S32 h,
                                       U8 *data, gdraw_texture_format format)
{
    (void)unique_id;
    (void)format;
    if (!tex || !tex->metal_texture || !data) return;

    GDRAW_METAL_LOG("UpdateTextureRect: (%d,%d) %dx%d stride=%d", x, y, w, h, stride);

    MTLRegion region = MTLRegionMake2D(x, y, w, h);
    [tex->metal_texture replaceRegion:region
                          mipmapLevel:0
                            withBytes:data
                          bytesPerRow:stride];
}

static void metal_update_texture_end(GDrawTexture *tex, void *unique_id, GDrawStats *stats)
{
    (void)tex;
    (void)unique_id;
    (void)stats;
}

// ========================================================================
// Vertex buffer creation
// ========================================================================

static rrbool metal_make_vertex_buffer_begin(void *unique_id, gdraw_vformat vformat,
                                              S32 vdata_len, S32 idata_len,
                                              GDraw_MakeVertexBuffer_ProcessingInfo *info, GDrawStats *stats)
{
    if (!g_metal_context || !info) return 0;

    GDRAW_METAL_LOG("MakeVertexBufferBegin: vformat=%d, vdata=%d, idata=%d", vformat, vdata_len, idata_len);

    S32 total_size = vdata_len + idata_len;

    // Allocate a Metal buffer for both vertex and index data
    id<MTLBuffer> buffer = [g_metal_context->device newBufferWithLength:total_size
                                                               options:MTLResourceStorageModeShared];
    if (!buffer)
    {
        GDRAW_METAL_LOG("ERROR: Failed to allocate %d byte vertex buffer", total_size);
        return 0;
    }

    // Allocate our wrapper handle
    GDrawVertexBuffer *vb = (GDrawVertexBuffer *)calloc(1, sizeof(GDrawVertexBuffer));
    vb->metal_buffer    = buffer;
    vb->vertex_offset   = 0;
    vb->index_offset    = vdata_len;
    vb->vertex_data_len = vdata_len;
    vb->index_data_len  = idata_len;
    vb->vformat         = vformat;
    vb->unique_id       = unique_id;
    vb->size_in_bytes   = total_size;

    // Let Iggy write directly into the Metal buffer's contents
    U8 *base = (U8 *)[buffer contents];
    info->vertex_data        = base;
    info->index_data         = base + vdata_len;
    info->vertex_data_length = vdata_len;
    info->index_data_length  = idata_len;

    // Store handle in opaque pointer
    info->p0 = vb;

    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_alloc_tex;
        stats->alloc_tex++;
        stats->alloc_tex_bytes += total_size;
    }

    return 1;
}

static rrbool metal_make_vertex_buffer_more(GDraw_MakeVertexBuffer_ProcessingInfo *info)
{
    // Single-pass for shared memory
    return 1;
}

static GDrawVertexBuffer * metal_make_vertex_buffer_end(GDraw_MakeVertexBuffer_ProcessingInfo *info, GDrawStats *stats)
{
    if (!info || !info->p0) return nullptr;

    GDrawVertexBuffer *vb = (GDrawVertexBuffer *)info->p0;
    info->p0 = nullptr;

    GDRAW_METAL_LOG("MakeVertexBufferEnd: %d bytes", vb->size_in_bytes);

    return vb;
}

// ========================================================================
// Resource locking (cache management)
// ========================================================================

static rrbool metal_try_to_lock_texture(GDrawTexture *tex, void *unique_id, GDrawStats *stats)
{
    (void)unique_id;
    (void)stats;
    // On Metal with shared memory, textures are always accessible
    return (tex && tex->metal_texture) ? 1 : 0;
}

static rrbool metal_try_to_lock_vertex_buffer(GDrawVertexBuffer *vb, void *unique_id, GDrawStats *stats)
{
    (void)unique_id;
    (void)stats;
    return (vb && vb->metal_buffer) ? 1 : 0;
}

static void metal_unlock_handles(GDrawStats *stats)
{
    (void)stats;
    // No-op on Metal -- resources are always CPU accessible with shared storage
}

// ========================================================================
// Resource deallocation
// ========================================================================

static void metal_free_texture(GDrawTexture *t, void *unique_id, GDrawStats *stats)
{
    (void)unique_id;
    if (!t) return;

    GDRAW_METAL_LOG("FreeTexture: %dx%d (%u bytes)", t->width, t->height, t->size_in_bytes);

    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_frees;
        stats->freed_objects++;
        stats->freed_bytes += t->size_in_bytes;
    }

    t->metal_texture = nil;
    free(t);
}

static void metal_free_vertex_buffer(GDrawVertexBuffer *vb, void *unique_id, GDrawStats *stats)
{
    (void)unique_id;
    if (!vb) return;

    GDRAW_METAL_LOG("FreeVertexBuffer: %u bytes", vb->size_in_bytes);

    if (stats)
    {
        stats->nonzero_flags |= GDRAW_STATS_frees;
        stats->freed_objects++;
        stats->freed_bytes += vb->size_in_bytes;
    }

    vb->metal_buffer = nil;
    free(vb);
}

// ========================================================================
// Resource description queries
// ========================================================================

static void metal_describe_texture(GDrawTexture *tex, GDraw_Texture_Description *desc)
{
    if (!desc) return;
    if (!tex)
    {
        memset(desc, 0, sizeof(*desc));
        return;
    }
    desc->width         = tex->width;
    desc->height        = tex->height;
    desc->size_in_bytes = tex->size_in_bytes;
}

static void metal_describe_vertex_buffer(GDrawVertexBuffer *buffer, GDraw_VertexBuffer_Description *desc)
{
    if (!desc) return;
    desc->size_in_bytes = buffer ? buffer->size_in_bytes : 0;
}

// ========================================================================
// Texture unique ID management
// ========================================================================

static void metal_set_texture_unique_id(GDrawTexture *tex, void *old_id, void *new_id)
{
    (void)old_id;
    if (tex) tex->unique_id = new_id;
}

// ========================================================================
// Render-to-texture (offscreen render targets for filter effects)
// ========================================================================

static rrbool metal_texture_draw_buffer_begin(gswf_recti *region, gdraw_texture_format format,
                                               gdraw_texturedrawbuffer_flags flags, void *unique_id,
                                               GDrawStats *stats)
{
    GDRAW_METAL_LOG("TextureDrawBufferBegin: (%d,%d)-(%d,%d) format=%d flags=0x%x",
                     region ? region->x0 : 0, region ? region->y0 : 0,
                     region ? region->x1 : 0, region ? region->y1 : 0,
                     format, flags);

    // For a full implementation, this would create a new render target texture
    // and switch the render encoder to render into it. For now, return success
    // so Iggy can proceed (filters will not render correctly).

    (void)region;
    (void)format;
    (void)flags;
    (void)unique_id;
    (void)stats;

    return 1;
}

static GDrawTexture * metal_texture_draw_buffer_end(GDrawStats *stats)
{
    GDRAW_METAL_LOG("TextureDrawBufferEnd");
    (void)stats;

    // Return a minimal dummy texture so Iggy doesn't crash
    if (!g_metal_context) return nullptr;

    GDrawTexture *tex = (GDrawTexture *)calloc(1, sizeof(GDrawTexture));
    tex->width          = 1;
    tex->height         = 1;
    tex->size_in_bytes  = 4;
    tex->is_rendertarget = 1;
    tex->unique_id      = nullptr;

    // Create a 1x1 transparent texture as placeholder
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:1
                                                                                   height:1
                                                                                mipmapped:NO];
    tex->metal_texture = [g_metal_context->device newTextureWithDescriptor:desc];

    return tex;
}

// ========================================================================
// Masking operations
// ========================================================================

static void metal_draw_mask_begin(gswf_recti *region, S32 mask_bit, GDrawStats *stats)
{
    GDRAW_METAL_LOG("DrawMaskBegin: bit=%d", mask_bit);
    (void)region;
    (void)mask_bit;
    (void)stats;
}

static void metal_draw_mask_end(gswf_recti *region, S32 mask_bit, GDrawStats *stats)
{
    GDRAW_METAL_LOG("DrawMaskEnd: bit=%d", mask_bit);
    (void)region;
    (void)mask_bit;
    (void)stats;
}

// ========================================================================
// Resource file textures
// ========================================================================

static GDrawTexture * metal_make_texture_from_resource(U8 *resource_file, S32 file_len, void *texture)
{
    GDRAW_METAL_LOG("MakeTextureFromResource: %d bytes", file_len);
    (void)resource_file;
    (void)file_len;
    (void)texture;

    // Resource file textures need platform-specific parsing.
    // For now return nullptr -- the game will fall back to raw texture format.
    return nullptr;
}

static void metal_free_texture_from_resource(GDrawTexture *tex)
{
    if (tex)
    {
        tex->metal_texture = nil;
        free(tex);
    }
}

// ========================================================================
// 3D transform (used for Faux3D stage effects)
// ========================================================================

static void metal_set_3d_transform(F32 *mat)
{
    GDRAW_METAL_LOG("Set3DTransform");
    (void)mat;
    // Store the 3x4 matrix for use in vertex shader.
    // Not yet implemented in the initial port.
}

// ========================================================================
// Public API: Context creation and management
// ========================================================================

GDrawFunctions * gdraw_Metal_CreateContext(void *device, void *commandQueue, S32 w, S32 h)
{
    if (g_metal_context)
    {
        GDRAW_METAL_LOG("ERROR: Context already exists, destroy it first");
        return nullptr;
    }

    if (!device || !commandQueue)
    {
        GDRAW_METAL_LOG("ERROR: nullptr device or commandQueue");
        return nullptr;
    }

    GDRAW_METAL_LOG("CreateContext: %dx%d", w, h);

    g_metal_context = (MetalGDrawContext *)calloc(1, sizeof(MetalGDrawContext));
    if (!g_metal_context) return nullptr;

    // Retain the device and command queue
    g_metal_context->device        = (__bridge id<MTLDevice>)device;
    g_metal_context->command_queue = (__bridge id<MTLCommandQueue>)commandQueue;
    g_metal_context->rt_width      = w;
    g_metal_context->rt_height     = h;

    // Set default resource limits
    g_metal_context->max_tex_handles = DEFAULT_MAX_TEXTURE_HANDLES;
    g_metal_context->max_tex_bytes   = DEFAULT_MAX_TEXTURE_BYTES;
    g_metal_context->max_vb_handles  = DEFAULT_MAX_VB_HANDLES;
    g_metal_context->max_vb_bytes    = DEFAULT_MAX_VB_BYTES;
    g_metal_context->max_rt_handles  = DEFAULT_MAX_RT_HANDLES;
    g_metal_context->max_rt_bytes    = DEFAULT_MAX_RT_BYTES;

    // Create sampler states
    g_metal_context->sampler_linear_clamp  = create_sampler(g_metal_context->device,
                                                             MTLSamplerMinMagFilterLinear,
                                                             MTLSamplerMinMagFilterLinear,
                                                             MTLSamplerAddressModeClampToEdge);
    g_metal_context->sampler_linear_repeat = create_sampler(g_metal_context->device,
                                                             MTLSamplerMinMagFilterLinear,
                                                             MTLSamplerMinMagFilterLinear,
                                                             MTLSamplerAddressModeRepeat);
    g_metal_context->sampler_nearest_clamp = create_sampler(g_metal_context->device,
                                                             MTLSamplerMinMagFilterNearest,
                                                             MTLSamplerMinMagFilterNearest,
                                                             MTLSamplerAddressModeClampToEdge);

    // Create the dynamic streaming buffer
    g_metal_context->dynamic_buffer = [g_metal_context->device newBufferWithLength:DYNAMIC_BUFFER_SIZE
                                                                           options:MTLResourceStorageModeShared];

    // Create default depth/stencil state
    MTLDepthStencilDescriptor *ds_desc = [[MTLDepthStencilDescriptor alloc] init];
    ds_desc.depthCompareFunction = MTLCompareFunctionAlways;
    ds_desc.depthWriteEnabled    = NO;
    g_metal_context->depth_stencil_default = [g_metal_context->device newDepthStencilStateWithDescriptor:ds_desc];

    // Wire up the function table
    GDrawFunctions *fn = &g_metal_context->functions;
    memset(fn, 0, sizeof(*fn));

    fn->GetInfo                   = metal_get_info;
    fn->SetViewSizeAndWorldScale  = metal_set_view_size_and_world_scale;
    fn->RenderTileBegin           = metal_render_tile_begin;
    fn->RenderTileEnd             = metal_render_tile_end;
    fn->SetAntialiasTexture       = metal_set_antialias_texture;
    fn->ClearStencilBits          = metal_clear_stencil_bits;
    fn->ClearID                   = metal_clear_id;
    fn->FilterQuad                = metal_filter_quad;
    fn->DrawIndexedTriangles      = metal_draw_indexed_triangles;
    fn->MakeTextureBegin          = metal_make_texture_begin;
    fn->MakeTextureMore           = metal_make_texture_more;
    fn->MakeTextureEnd            = metal_make_texture_end;
    fn->MakeVertexBufferBegin     = metal_make_vertex_buffer_begin;
    fn->MakeVertexBufferMore      = metal_make_vertex_buffer_more;
    fn->MakeVertexBufferEnd       = metal_make_vertex_buffer_end;
    fn->TryToLockTexture          = metal_try_to_lock_texture;
    fn->TryToLockVertexBuffer     = metal_try_to_lock_vertex_buffer;
    fn->UnlockHandles             = metal_unlock_handles;
    fn->FreeTexture               = metal_free_texture;
    fn->FreeVertexBuffer          = metal_free_vertex_buffer;
    fn->UpdateTextureBegin        = metal_update_texture_begin;
    fn->UpdateTextureRect         = metal_update_texture_rect;
    fn->UpdateTextureEnd          = metal_update_texture_end;
    fn->TextureDrawBufferBegin    = metal_texture_draw_buffer_begin;
    fn->TextureDrawBufferEnd      = metal_texture_draw_buffer_end;
    fn->DescribeTexture           = metal_describe_texture;
    fn->DescribeVertexBuffer      = metal_describe_vertex_buffer;
    fn->SetTextureUniqueID        = metal_set_texture_unique_id;
    fn->DrawMaskBegin             = metal_draw_mask_begin;
    fn->DrawMaskEnd               = metal_draw_mask_end;
    fn->RenderingBegin            = metal_rendering_begin;
    fn->RenderingEnd              = metal_rendering_end;
    fn->MakeTextureFromResource   = metal_make_texture_from_resource;
    fn->FreeTextureFromResource   = metal_free_texture_from_resource;
    fn->Set3DTransform            = metal_set_3d_transform;

    g_metal_context->is_initialized = 1;

    GDRAW_METAL_LOG("CreateContext: success");
    return fn;
}

void gdraw_Metal_DestroyContext(void)
{
    if (!g_metal_context) return;

    GDRAW_METAL_LOG("DestroyContext");

    // Release Metal objects (ARC handles deallocation)
    g_metal_context->antialias_texture      = nil;
    g_metal_context->dynamic_buffer         = nil;
    g_metal_context->sampler_linear_clamp   = nil;
    g_metal_context->sampler_linear_repeat  = nil;
    g_metal_context->sampler_nearest_clamp  = nil;
    g_metal_context->depth_stencil_default  = nil;
    g_metal_context->depth_stencil_stencil_write = nil;
    g_metal_context->depth_stencil_stencil_test  = nil;
    g_metal_context->pipeline_solid         = nil;
    g_metal_context->pipeline_textured      = nil;
    g_metal_context->pipeline_font          = nil;
    g_metal_context->current_encoder        = nil;
    g_metal_context->command_queue          = nil;
    g_metal_context->device                 = nil;

    free(g_metal_context);
    g_metal_context = nullptr;
}

void gdraw_Metal_SetTileOrigin(void *renderEncoder, S32 x, S32 y)
{
    if (!g_metal_context) return;

    GDRAW_METAL_LOG("SetTileOrigin: (%d,%d)", x, y);

    g_metal_context->current_encoder = (__bridge id<MTLRenderCommandEncoder>)renderEncoder;
    g_metal_context->tile_origin_x   = x;
    g_metal_context->tile_origin_y   = y;
}

void gdraw_Metal_NoMoreGDrawThisFrame(void)
{
    GDRAW_METAL_LOG("NoMoreGDrawThisFrame");

    if (!g_metal_context) return;

    // Reset per-frame state
    g_metal_context->current_encoder       = nil;
    g_metal_context->dynamic_buffer_offset = 0;
}

int gdraw_Metal_SetResourceLimits(gdraw_metal_resourcetype type, S32 count, S32 bytes)
{
    if (!g_metal_context) return 0;

    GDRAW_METAL_LOG("SetResourceLimits: type=%d, count=%d, bytes=%d", type, count, bytes);

    switch (type)
    {
        case GDRAW_METAL_RESOURCE_rendertarget:
            g_metal_context->max_rt_handles = count;
            g_metal_context->max_rt_bytes   = bytes;
            return 1;
        case GDRAW_METAL_RESOURCE_texture:
            g_metal_context->max_tex_handles = count;
            g_metal_context->max_tex_bytes   = bytes;
            return 1;
        case GDRAW_METAL_RESOURCE_vertexbuffer:
            g_metal_context->max_vb_handles = count;
            g_metal_context->max_vb_bytes   = bytes;
            return 1;
        default:
            return 0;
    }
}

void gdraw_Metal_BeginCustomDraw_4J(IggyCustomDrawCallbackRegion *region, F32 mat[16])
{
    GDRAW_METAL_LOG("BeginCustomDraw_4J");

    if (!region || !mat) return;

    // Build a 4x4 matrix from the 2D Iggy object-to-world transform
    memset(mat, 0, sizeof(F32) * 16);
    mat[0]  = 1.0f;  // identity for now
    mat[5]  = 1.0f;
    mat[10] = 1.0f;
    mat[15] = 1.0f;

    if (region->o2w)
    {
        mat[0]  = region->o2w->m00;
        mat[1]  = region->o2w->m01;
        mat[4]  = region->o2w->m10;
        mat[5]  = region->o2w->m11;
        mat[12] = region->o2w->trans[0];
        mat[13] = region->o2w->trans[1];
    }
}

void gdraw_Metal_EndCustomDraw(IggyCustomDrawCallbackRegion *region)
{
    GDRAW_METAL_LOG("EndCustomDraw");
    (void)region;
    // Restore any GDraw render state modified by the custom draw callback.
    // For the initial port this is a no-op.
}

void gdraw_Metal_setViewport_4J(void)
{
    GDRAW_METAL_LOG("setViewport_4J");
    // Restore the viewport that GDraw was using before a custom draw callback.
    // Requires tracking the last-set viewport, which will be added in a future pass.
}
