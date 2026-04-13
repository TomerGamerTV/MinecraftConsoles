#pragma once

// Apple_UIController.h — Metal-based UIController for macOS and iOS
// Matches the ConsoleUIController / Windows64_UIController interface,
// but uses GDraw Metal context instead of GDraw D3D11.

#include "../../Common/UI/UIController.h"

// Forward-declare Metal types so this header compiles in pure C++ TUs.
// The .mm implementation file imports <Metal/Metal.h> for the real types.
// Do not declare a fallback `id` here: Apple SDK headers provide the real
// Objective-C runtime types and C++ TUs only store them as opaque `void*`.
#ifdef __OBJC__
@protocol MTLDevice;
@protocol MTLCommandQueue;
@protocol MTLTexture;
#endif

class Apple_UIController : public UIController
{
private:
    enum class NativeOverlayMode : unsigned char
    {
        Hidden,
        MainMenu,
        LoadingWorld,
        PauseMenu
    };

    // Metal render targets (opaque pointers in C++ TUs, real ids in ObjC++)
    void* m_metalDevice;           // id<MTLDevice>
    void* m_metalCommandQueue;     // id<MTLCommandQueue>
    void* m_colorTexture;          // id<MTLTexture> (current render target)
    void* m_depthStencilTexture;   // id<MTLTexture>
    NativeOverlayMode m_nativeOverlayMode;
    bool m_nativeWorldLaunchPending;
    bool m_nativeTrialTimerVisible;
    bool m_nativeAutosaveCountdownVisible;
    bool m_nativeSavingMessageVisible;
    bool m_nativePlayerDisplayNameVisible;
    unsigned int m_nativeAutosaveCountdownSeconds;
    unsigned int m_worldReadyStableFrames;
    double m_nativeWorldLaunchStartedAt;
    std::wstring m_nativeStatusText;

    void SetNativeOverlayMode(NativeOverlayMode mode);
    void RefreshNativeOverlayStatus();
    void SyncNativeOverlay();
    bool IsNativeWorldReadyForGameplay() const;

public:
    void ShowNativeMainMenu();
    void HideNativeMainMenu();
    void StartNativeMainMenuWorld();
    bool IsNativeWorldLaunchPending() const { return m_nativeWorldLaunchPending; }
    bool IsNativeOverlayVisible() const { return m_nativeOverlayMode != NativeOverlayMode::Hidden; }
    bool IsNativeLoadingOverlayVisible() const { return m_nativeOverlayMode == NativeOverlayMode::LoadingWorld; }
    std::wstring GetNativeOverlayStatusText() const;
    void HandleNativeTrialTimer(bool show);
    void HandleNativeTrialTimerUpdate(unsigned int iPad);
    void HandleNativeAutosaveCountdownTimer(bool show);
    void HandleNativeAutosaveCountdownUpdate(unsigned int uiSeconds);
    void HandleNativeSavingMessage(unsigned int iPad, C4JStorage::ESavingMessage eVal);
    void HandleNativePlayerDisplayname(bool show);

    // Initialise with Metal device and render targets
    // width/height = backbuffer dimensions in pixels
    void init(void* metalDevice, void* metalCommandQueue,
              void* colorTexture, void* depthStencilTexture,
              S32 width, S32 height);

    // Per-frame rendering of all Iggy/Flash UI scenes
    virtual void render() override;
    virtual void StartReloadSkinThread() override;
    virtual bool IsReloadingSkin() override;
    virtual void CleanUpSkinReload() override;
    virtual bool NavigateToScene(int iPad, EUIScene scene, void *initData = nullptr, EUILayer layer = eUILayer_Scene, EUIGroup group = eUIGroup_PAD) override;
    virtual bool NavigateBack(int iPad, bool forceUsePad = false, EUIScene eScene = eUIScene_COUNT, EUILayer eLayer = eUILayer_COUNT) override;
    virtual void CloseUIScenes(int iPad, bool forceIPad = false) override;
    virtual void CloseAllPlayersScenes() override;
    virtual bool IsPauseMenuDisplayed(int iPad) override;
    virtual bool IsContainerMenuDisplayed(int iPad) override;
    virtual bool IsIgnorePlayerJoinMenuDisplayed(int iPad) override;
    virtual bool IsIgnoreAutosaveMenuDisplayed(int iPad) override;
    virtual void SetIgnoreAutosaveMenuDisplayed(int iPad, bool displayed) override;
    virtual bool IsSceneInStack(int iPad, EUIScene eScene) override;
    virtual bool GetMenuDisplayed(int iPad) override;
    virtual void CheckMenuDisplayed() override;
    virtual void HandleGameTick() override;
    virtual void SetTooltipText(unsigned int iPad, unsigned int tooltip, int iTextID) override;
    virtual void SetEnableTooltips(unsigned int iPad, BOOL bVal) override;
    virtual void ShowTooltip(unsigned int iPad, unsigned int tooltip, bool show) override;
    virtual void SetTooltips(unsigned int iPad, int iA, int iB = -1, int iX = -1, int iY = -1, int iLT = -1, int iRT = -1, int iLB = -1, int iRB = -1, int iLS = -1, int iRS = -1, int iBack = -1, bool forceUpdate = false) override;
    virtual void EnableTooltip(unsigned int iPad, unsigned int tooltip, bool enable) override;
    virtual void RefreshTooltips(unsigned int iPad) override;
    virtual void DisplayGamertag(unsigned int iPad, bool show) override;
    virtual void SetSelectedItem(unsigned int iPad, const wstring &name) override;
    virtual void UpdateSelectedItemPos(unsigned int iPad) override;
    virtual void SetTutorial(int iPad, Tutorial *tutorial) override;
    virtual void SetTutorialDescription(int iPad, TutorialPopupInfo *info) override;
    virtual void RemoveInteractSceneReference(int iPad, UIScene *scene) override;
    virtual void SetTutorialVisible(int iPad, bool visible) override;
    virtual bool IsTutorialVisible(int iPad) override;
    virtual void ShowTrialTimer(bool show) override;
    virtual void UpdateTrialTimer(unsigned int iPad) override;
    virtual void ShowAutosaveCountdownTimer(bool show) override;
    virtual void UpdateAutosaveCountdownTimer(unsigned int uiSeconds) override;
    virtual void ShowSavingMessage(unsigned int iPad, C4JStorage::ESavingMessage eVal) override;
    virtual void ShowPlayerDisplayname(bool show) override;

    // Iggy custom draw callbacks (stubs until GDraw Metal is integrated)
    void beginIggyCustomDraw4J(IggyCustomDrawCallbackRegion* region, CustomDrawData* customDrawRegion) override;
    virtual CustomDrawData* setupCustomDraw(UIScene* scene, IggyCustomDrawCallbackRegion* region) override;
    virtual CustomDrawData* calculateCustomDraw(IggyCustomDrawCallbackRegion* region) override;
    virtual void endCustomDraw(IggyCustomDrawCallbackRegion* region) override;

    // Update render targets after a resize
    void updateRenderTargets(void* colorTexture, void* depthStencilTexture);

protected:
    virtual void setTileOrigin(S32 xPos, S32 yPos) override;

public:
    GDrawTexture* getSubstitutionTexture(int textureId);
    void destroySubstitutionTexture(void* destroyCallBackData, GDrawTexture* handle);

    // Override tick/render to be safe without Iggy
    virtual void tick() override;

public:
    void shutdown();
};

extern Apple_UIController ui;
