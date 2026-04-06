// Apple_UIController.mm — Metal-based UIController implementation
// Stub implementation. Once GDraw Metal is available, this mirrors
// Windows64_UIController.cpp but uses gdraw_Metal_* calls.

#include "stdafx.h"
#define Component CarbonComponent_Renamed
#import <Metal/Metal.h>
#undef Component

#include "Apple_UIController.h"

// Enable Iggy UI rendering when the GDraw Metal back-end is linked
// #define _ENABLEIGGY

Apple_UIController ui;

// ── Initialisation ───────────────────────────────────────────────────────────

void Apple_UIController::init(void* metalDevice, void* metalCommandQueue,
                               void* colorTexture, void* depthStencilTexture,
                               S32 width, S32 height)
{
    m_metalDevice         = metalDevice;
    m_metalCommandQueue   = metalCommandQueue;
    m_colorTexture        = colorTexture;
    m_depthStencilTexture = depthStencilTexture;

    // Base-class pre-init (sets screen dimensions, allocates UIGroups)
    // This MUST be called even without Iggy - the tick/render code needs m_groups
    preInit(width, height);

#ifdef _ENABLEIGGY
    // Create GDraw Metal context
    // gdraw_funcs = gdraw_Metal_CreateContext(...)
    // IggySetGDraw(gdraw_funcs);
    // IggyAudioUseSystemAudio();

    // Base-class post-init (loads Iggy libraries, sets up fonts)
    // Only call when Iggy is available - it tries to load .swf files
    postInit();
#endif
}

// ── Per-frame rendering ──────────────────────────────────────────────────────

void Apple_UIController::render()
{
#ifdef _ENABLEIGGY
    renderScenes();
#endif
}

// Override tick to be safe without Iggy (base class tick accesses Iggy resources)
void Apple_UIController::tick()
{
#ifdef _ENABLEIGGY
    UIController::tick();
#endif
}

void Apple_UIController::CheckMenuDisplayed()
{
#ifdef _ENABLEIGGY
    UIController::CheckMenuDisplayed();
#endif
}

// ── Iggy custom draw stubs ───────────────────────────────────────────────────

void Apple_UIController::beginIggyCustomDraw4J(IggyCustomDrawCallbackRegion* region, CustomDrawData* customDrawRegion)
{
#ifdef _ENABLEIGGY
    // gdraw_Metal_BeginCustomDraw_4J(region, customDrawRegion->mat);
#endif
}

CustomDrawData* Apple_UIController::setupCustomDraw(UIScene* scene, IggyCustomDrawCallbackRegion* region)
{
    CustomDrawData* customDrawRegion = new CustomDrawData();
    customDrawRegion->x0 = region->x0;
    customDrawRegion->x1 = region->x1;
    customDrawRegion->y0 = region->y0;
    customDrawRegion->y1 = region->y1;

#ifdef _ENABLEIGGY
    // gdraw_Metal_BeginCustomDraw_4J(region, customDrawRegion->mat);
    setupCustomDrawGameStateAndMatrices(scene, customDrawRegion);
#endif

    return customDrawRegion;
}

CustomDrawData* Apple_UIController::calculateCustomDraw(IggyCustomDrawCallbackRegion* region)
{
    CustomDrawData* customDrawRegion = new CustomDrawData();
    customDrawRegion->x0 = region->x0;
    customDrawRegion->x1 = region->x1;
    customDrawRegion->y0 = region->y0;
    customDrawRegion->y1 = region->y1;

#ifdef _ENABLEIGGY
    // gdraw_Metal_CalculateCustomDraw_4J(region, customDrawRegion->mat);
#endif

    return customDrawRegion;
}

void Apple_UIController::endCustomDraw(IggyCustomDrawCallbackRegion* region)
{
#ifdef _ENABLEIGGY
    endCustomDrawGameStateAndMatrices();
    // gdraw_Metal_EndCustomDraw(region);
#endif
}

// ── Render target update (after resize) ──────────────────────────────────────

void Apple_UIController::updateRenderTargets(void* colorTexture, void* depthStencilTexture)
{
    m_colorTexture        = colorTexture;
    m_depthStencilTexture = depthStencilTexture;
}

// ── Tile origin (used by multi-viewport rendering) ───────────────────────────

void Apple_UIController::setTileOrigin(S32 xPos, S32 yPos)
{
#ifdef _ENABLEIGGY
    // gdraw_Metal_SetTileOrigin((__bridge id<MTLTexture>)m_colorTexture,
    //                           (__bridge id<MTLTexture>)m_depthStencilTexture,
    //                           nullptr, xPos, yPos);
#endif
}

// ── Texture substitution ─────────────────────────────────────────────────────

GDrawTexture* Apple_UIController::getSubstitutionTexture(int textureId)
{
#ifdef _ENABLEIGGY
    // id<MTLTexture> tex = (__bridge id<MTLTexture>)RenderManager.TextureGetTexture(textureId);
    // return gdraw_Metal_WrappedTextureCreate(tex);
#endif
    return nullptr;
}

void Apple_UIController::destroySubstitutionTexture(void* destroyCallBackData, GDrawTexture* handle)
{
#ifdef _ENABLEIGGY
    // gdraw_Metal_WrappedTextureDestroy(handle);
#endif
}

// ── Shutdown ─────────────────────────────────────────────────────────────────

void Apple_UIController::shutdown()
{
#ifdef _ENABLEIGGY
    // gdraw_Metal_DestroyContext();
#endif
}
