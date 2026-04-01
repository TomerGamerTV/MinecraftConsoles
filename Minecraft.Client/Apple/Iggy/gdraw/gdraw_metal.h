#pragma once
// gdraw_metal.h - Metal GDraw interface for Apple platforms
//
// Interface for creating a Metal-based GDraw driver, used by Iggy
// to render 2D Flash UI elements on Apple devices (iOS, tvOS, macOS).

#include "gdraw.h"
#include "iggy.h"

#define IDOC

// Resource type identifiers for Metal GDraw resource management
typedef enum gdraw_metal_resourcetype
{
   GDRAW_METAL_RESOURCE_rendertarget,   // Render target textures for offscreen passes
   GDRAW_METAL_RESOURCE_texture,        // Regular textures (sprites, fonts, gradients)
   GDRAW_METAL_RESOURCE_vertexbuffer,   // Vertex/index buffers for 2D geometry

   GDRAW_METAL_RESOURCE__count,
} gdraw_metal_resourcetype;

// Create the Metal GDraw context.
// device:       The MTLDevice (cast to void* for C compatibility)
// commandQueue: The MTLCommandQueue (cast to void* for C compatibility)
// w, h:         Width/height for internal render target sizing
// Returns:      A GDrawFunctions pointer to pass to IggySetGDraw, or nullptr on failure
IDOC extern GDrawFunctions * gdraw_Metal_CreateContext(void *device, void *commandQueue, S32 w, S32 h);

// Destroy the current Metal GDraw context and free all resources
IDOC extern void gdraw_Metal_DestroyContext(void);

// Set the tile origin for rendering.
// renderEncoder: The current MTLRenderCommandEncoder (cast to void*)
// x, y:          Pixel offset for the top-left corner of the rendered tile
IDOC extern void gdraw_Metal_SetTileOrigin(void *renderEncoder, S32 x, S32 y);

// Signal that no more GDraw rendering will occur this frame.
// Triggers end-of-frame resource management (thrashing detection, cache eviction)
IDOC extern void gdraw_Metal_NoMoreGDrawThisFrame(void);

// Set resource pool limits for a given resource type.
// type:  One of gdraw_metal_resourcetype
// count: Maximum number of resource handles
// bytes: Maximum total bytes for that resource type
// Returns: 1 on success, 0 on error
IDOC extern int gdraw_Metal_SetResourceLimits(gdraw_metal_resourcetype type, S32 count, S32 bytes);

// Begin a custom draw callback region.
// region: The Iggy custom draw callback region struct
// mat:    Output: receives the current 4x4 object-to-world matrix (column-major)
IDOC extern void RADLINK gdraw_Metal_BeginCustomDraw_4J(IggyCustomDrawCallbackRegion *region, F32 mat[16]);

// End a custom draw callback region, restoring GDraw's internal render state
IDOC extern void RADLINK gdraw_Metal_EndCustomDraw(IggyCustomDrawCallbackRegion *region);

// 4J added -- restore the viewport to the one GDraw last set up
extern void RADLINK gdraw_Metal_setViewport_4J(void);
