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

void Apple_UIController::StartReloadSkinThread()
{
#ifdef _ENABLEIGGY
    UIController::StartReloadSkinThread();
#endif
}

bool Apple_UIController::IsReloadingSkin()
{
#ifdef _ENABLEIGGY
    return UIController::IsReloadingSkin();
#else
    return false;
#endif
}

void Apple_UIController::CleanUpSkinReload()
{
#ifdef _ENABLEIGGY
    UIController::CleanUpSkinReload();
#endif
}

bool Apple_UIController::NavigateToScene(int iPad, EUIScene scene, void *initData, EUILayer layer, EUIGroup group)
{
#ifdef _ENABLEIGGY
    return UIController::NavigateToScene(iPad, scene, initData, layer, group);
#else
    (void)iPad; (void)scene; (void)initData; (void)layer; (void)group;
    return false;
#endif
}

bool Apple_UIController::NavigateBack(int iPad, bool forceUsePad, EUIScene eScene, EUILayer eLayer)
{
#ifdef _ENABLEIGGY
    return UIController::NavigateBack(iPad, forceUsePad, eScene, eLayer);
#else
    (void)iPad; (void)forceUsePad; (void)eScene; (void)eLayer;
    return false;
#endif
}

void Apple_UIController::CloseUIScenes(int iPad, bool forceIPad)
{
#ifdef _ENABLEIGGY
    UIController::CloseUIScenes(iPad, forceIPad);
#else
    (void)iPad; (void)forceIPad;
#endif
}

void Apple_UIController::CloseAllPlayersScenes()
{
#ifdef _ENABLEIGGY
    UIController::CloseAllPlayersScenes();
#endif
}

bool Apple_UIController::IsPauseMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsPauseMenuDisplayed(iPad);
#else
    (void)iPad;
    return false;
#endif
}

bool Apple_UIController::IsContainerMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsContainerMenuDisplayed(iPad);
#else
    (void)iPad;
    return false;
#endif
}

bool Apple_UIController::IsIgnorePlayerJoinMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsIgnorePlayerJoinMenuDisplayed(iPad);
#else
    (void)iPad;
    return false;
#endif
}

bool Apple_UIController::IsIgnoreAutosaveMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsIgnoreAutosaveMenuDisplayed(iPad);
#else
    (void)iPad;
    return false;
#endif
}

void Apple_UIController::SetIgnoreAutosaveMenuDisplayed(int iPad, bool displayed)
{
#ifdef _ENABLEIGGY
    UIController::SetIgnoreAutosaveMenuDisplayed(iPad, displayed);
#else
    (void)iPad; (void)displayed;
#endif
}

bool Apple_UIController::IsSceneInStack(int iPad, EUIScene eScene)
{
#ifdef _ENABLEIGGY
    return UIController::IsSceneInStack(iPad, eScene);
#else
    (void)iPad; (void)eScene;
    return false;
#endif
}

bool Apple_UIController::GetMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::GetMenuDisplayed(iPad);
#else
    (void)iPad;
    return false;
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

void Apple_UIController::HandleGameTick()
{
#ifdef _ENABLEIGGY
    UIController::HandleGameTick();
#endif
}

void Apple_UIController::SetTooltipText(unsigned int iPad, unsigned int tooltip, int iTextID)
{
#ifdef _ENABLEIGGY
    UIController::SetTooltipText(iPad, tooltip, iTextID);
#else
    (void)iPad; (void)tooltip; (void)iTextID;
#endif
}

void Apple_UIController::SetEnableTooltips(unsigned int iPad, BOOL bVal)
{
#ifdef _ENABLEIGGY
    UIController::SetEnableTooltips(iPad, bVal);
#else
    (void)iPad; (void)bVal;
#endif
}

void Apple_UIController::ShowTooltip(unsigned int iPad, unsigned int tooltip, bool show)
{
#ifdef _ENABLEIGGY
    UIController::ShowTooltip(iPad, tooltip, show);
#else
    (void)iPad; (void)tooltip; (void)show;
#endif
}

void Apple_UIController::SetTooltips(unsigned int iPad, int iA, int iB, int iX, int iY, int iLT, int iRT, int iLB, int iRB, int iLS, int iRS, int iBack, bool forceUpdate)
{
#ifdef _ENABLEIGGY
    UIController::SetTooltips(iPad, iA, iB, iX, iY, iLT, iRT, iLB, iRB, iLS, iRS, iBack, forceUpdate);
#else
    (void)iPad; (void)iA; (void)iB; (void)iX; (void)iY;
    (void)iLT; (void)iRT; (void)iLB; (void)iRB; (void)iLS; (void)iRS; (void)iBack; (void)forceUpdate;
#endif
}

void Apple_UIController::EnableTooltip(unsigned int iPad, unsigned int tooltip, bool enable)
{
#ifdef _ENABLEIGGY
    UIController::EnableTooltip(iPad, tooltip, enable);
#else
    (void)iPad; (void)tooltip; (void)enable;
#endif
}

void Apple_UIController::RefreshTooltips(unsigned int iPad)
{
#ifdef _ENABLEIGGY
    UIController::RefreshTooltips(iPad);
#else
    (void)iPad;
#endif
}

void Apple_UIController::DisplayGamertag(unsigned int iPad, bool show)
{
#ifdef _ENABLEIGGY
    UIController::DisplayGamertag(iPad, show);
#else
    (void)iPad; (void)show;
#endif
}

void Apple_UIController::SetSelectedItem(unsigned int iPad, const wstring &name)
{
#ifdef _ENABLEIGGY
    UIController::SetSelectedItem(iPad, name);
#else
    (void)iPad; (void)name;
#endif
}

void Apple_UIController::UpdateSelectedItemPos(unsigned int iPad)
{
#ifdef _ENABLEIGGY
    UIController::UpdateSelectedItemPos(iPad);
#else
    (void)iPad;
#endif
}

void Apple_UIController::SetTutorial(int iPad, Tutorial *tutorial)
{
#ifdef _ENABLEIGGY
    UIController::SetTutorial(iPad, tutorial);
#else
    (void)iPad; (void)tutorial;
#endif
}

void Apple_UIController::SetTutorialDescription(int iPad, TutorialPopupInfo *info)
{
#ifdef _ENABLEIGGY
    UIController::SetTutorialDescription(iPad, info);
#else
    (void)iPad; (void)info;
#endif
}

void Apple_UIController::RemoveInteractSceneReference(int iPad, UIScene *scene)
{
#ifdef _ENABLEIGGY
    UIController::RemoveInteractSceneReference(iPad, scene);
#else
    (void)iPad; (void)scene;
#endif
}

void Apple_UIController::SetTutorialVisible(int iPad, bool visible)
{
#ifdef _ENABLEIGGY
    UIController::SetTutorialVisible(iPad, visible);
#else
    (void)iPad; (void)visible;
#endif
}

bool Apple_UIController::IsTutorialVisible(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsTutorialVisible(iPad);
#else
    (void)iPad;
    return false;
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
