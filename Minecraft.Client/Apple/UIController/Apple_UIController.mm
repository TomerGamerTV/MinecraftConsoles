// Apple_UIController.mm — Metal-based UIController implementation
// Stub implementation. Once GDraw Metal is available, this mirrors
// Windows64_UIController.cpp but uses gdraw_Metal_* calls.

#include "stdafx.h"
#define Component CarbonComponent_Renamed
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#undef Component

#include "Apple_UIController.h"

// Enable Iggy UI rendering when the GDraw Metal back-end is linked
// #define _ENABLEIGGY

Apple_UIController ui;

extern "C" void AppleMarkWorldStartRequested();

@interface AppleMainMenuController : NSObject
@property(nonatomic, assign) Apple_UIController* owner;
@property(nonatomic, strong) NSView* overlay;
@property(nonatomic, strong) NSView* panel;
@property(nonatomic, strong) NSTextField* titleLabel;
@property(nonatomic, strong) NSTextField* subtitleLabel;
@property(nonatomic, strong) NSTextField* statusLabel;
@property(nonatomic, strong) NSProgressIndicator* spinner;
@property(nonatomic, strong) NSButton* playButton;
@property(nonatomic, strong) NSButton* fullscreenButton;
@property(nonatomic, strong) NSButton* quitButton;
- (instancetype)initWithOwner:(Apple_UIController*)owner;
- (void)attachIfNeeded;
- (void)setMenuVisible:(BOOL)visible;
- (BOOL)isMenuVisible;
- (void)syncFromOwner;
@end

static AppleMainMenuController* s_nativeMainMenu = nil;
static const unsigned int kNativeWorldReadyStableFramesRequired = 3;

@protocol AppleGameFullscreenHandling <NSObject>
- (void)toggleGameFullscreen:(id)sender;
@end

static NSTextField* CreateMenuLabel(NSString* text, CGFloat fontSize, NSColor* color, NSFontWeight weight)
{
    NSTextField* label = [NSTextField labelWithString:text];
    label.alignment = NSTextAlignmentCenter;
    label.textColor = color;
    label.font = [NSFont systemFontOfSize:fontSize weight:weight];
    label.backgroundColor = [NSColor clearColor];
    return label;
}

static NSString* NSStringFromWideString(const std::wstring& text)
{
    if (text.empty()) {
        return @"";
    }
    return [[NSString alloc] initWithBytes:text.data()
                                    length:text.length() * sizeof(wchar_t)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}

static void AppleOverlayLog(const char* fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    fflush(stderr);
    va_end(args);
}

@implementation AppleMainMenuController

- (instancetype)initWithOwner:(Apple_UIController*)owner
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.owner = owner;

    self.overlay = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 720)];
    self.overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.overlay.wantsLayer = YES;
    self.overlay.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.06 alpha:0.72] CGColor];
    self.overlay.hidden = YES;

    NSVisualEffectView* backdrop = [[NSVisualEffectView alloc] initWithFrame:self.overlay.bounds];
    backdrop.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backdrop.material = NSVisualEffectMaterialHUDWindow;
    backdrop.state = NSVisualEffectStateActive;
    [self.overlay addSubview:backdrop];

    self.panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 380)];
    self.panel.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
    self.panel.wantsLayer = YES;
    self.panel.layer.cornerRadius = 28.0;
    self.panel.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0.13 green:0.16 blue:0.19 alpha:0.94] CGColor];
    self.panel.layer.borderWidth = 1.0;
    self.panel.layer.borderColor = [[NSColor colorWithCalibratedRed:0.33 green:0.40 blue:0.23 alpha:0.85] CGColor];
    [self.overlay addSubview:self.panel];

    self.titleLabel = CreateMenuLabel(@"Minecraft", 34.0, [NSColor whiteColor], NSFontWeightHeavy);
    self.titleLabel.frame = NSMakeRect(40, 280, 460, 40);
    [self.panel addSubview:self.titleLabel];

    self.subtitleLabel = CreateMenuLabel(@"Apple fallback main menu", 15.0,
                                         [NSColor colorWithCalibratedRed:0.82 green:0.88 blue:0.76 alpha:1.0],
                                         NSFontWeightMedium);
    self.subtitleLabel.frame = NSMakeRect(40, 248, 460, 24);
    [self.panel addSubview:self.subtitleLabel];

    self.statusLabel = CreateMenuLabel(@"Temporary native frontend while Apple Iggy UI is stubbed.",
                                       13.0,
                                       [NSColor colorWithCalibratedWhite:0.88 alpha:1.0],
                                       NSFontWeightRegular);
    self.statusLabel.frame = NSMakeRect(48, 206, 444, 40);
    self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.statusLabel.usesSingleLineMode = NO;
    [self.panel addSubview:self.statusLabel];

    self.spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(254, 156, 32, 32)];
    self.spinner.style = NSProgressIndicatorStyleSpinning;
    self.spinner.controlSize = NSControlSizeLarge;
    self.spinner.displayedWhenStopped = NO;
    self.spinner.hidden = YES;
    [self.panel addSubview:self.spinner];

    self.playButton = [NSButton buttonWithTitle:@"Play Test World"
                                         target:self
                                         action:@selector(playPressed:)];
    self.playButton.frame = NSMakeRect(120, 144, 300, 36);
    self.playButton.bezelStyle = NSBezelStyleRegularSquare;
    self.playButton.font = [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold];
    [self.panel addSubview:self.playButton];

    self.fullscreenButton = [NSButton buttonWithTitle:@"Toggle Fullscreen"
                                               target:self
                                               action:@selector(fullscreenPressed:)];
    self.fullscreenButton.frame = NSMakeRect(120, 96, 300, 32);
    self.fullscreenButton.bezelStyle = NSBezelStyleRegularSquare;
    [self.panel addSubview:self.fullscreenButton];

    self.quitButton = [NSButton buttonWithTitle:@"Quit"
                                         target:self
                                         action:@selector(quitPressed:)];
    self.quitButton.frame = NSMakeRect(120, 52, 300, 32);
    self.quitButton.bezelStyle = NSBezelStyleRegularSquare;
    [self.panel addSubview:self.quitButton];

    return self;
}

- (void)layoutPanel
{
    NSRect bounds = self.overlay.bounds;
    self.panel.frame = NSMakeRect((NSWidth(bounds) - 540.0) * 0.5,
                                  (NSHeight(bounds) - 380.0) * 0.5,
                                  540.0,
                                  380.0);
}

- (void)attachIfNeeded
{
    NSWindow* window = [NSApp mainWindow] ?: [NSApp keyWindow];
    NSView* hostView = window.contentView;
    if (!hostView) {
        return;
    }

    if (self.overlay.superview != hostView) {
        [self.overlay removeFromSuperview];
        self.overlay.frame = hostView.bounds;
        [self layoutPanel];
        [hostView addSubview:self.overlay];
    } else {
        self.overlay.frame = hostView.bounds;
        [self layoutPanel];
    }
}

- (void)setMenuVisible:(BOOL)visible
{
    [self attachIfNeeded];
    if (visible && self.overlay.superview) {
        NSView* hostView = self.overlay.superview;
        [self.overlay removeFromSuperview];
        [hostView addSubview:self.overlay];
    }
    self.overlay.hidden = !visible;
}

- (BOOL)isMenuVisible
{
    return self.overlay && !self.overlay.hidden;
}

- (void)syncFromOwner
{
    if (!self.owner) {
        return;
    }

    const bool loading = self.owner->IsNativeLoadingOverlayVisible();
    const bool gameplayRunning = app.GetGameStarted() && !loading;
    self.statusLabel.stringValue = NSStringFromWideString(self.owner->GetNativeOverlayStatusText());
    self.playButton.hidden = loading;
    self.fullscreenButton.hidden = loading;
    self.quitButton.hidden = loading;
    self.spinner.hidden = !loading;

    if (loading) {
        self.subtitleLabel.stringValue = @"Apple fallback loading overlay";
        [self.spinner startAnimation:nil];
        return;
    }

    [self.spinner stopAnimation:nil];
    self.playButton.enabled = YES;
    self.fullscreenButton.enabled = YES;
    self.quitButton.enabled = YES;

    if (gameplayRunning) {
        self.subtitleLabel.stringValue = @"Apple fallback pause menu";
        self.playButton.title = @"Resume World";
    } else {
        self.subtitleLabel.stringValue = @"Apple fallback main menu";
        self.playButton.title = @"Play Test World";
    }
}

- (void)playPressed:(id)sender
{
    (void)sender;
    if (!self.owner) {
        return;
    }

    if (app.GetGameStarted()) {
        self.owner->HideNativeMainMenu();
    } else {
        self.owner->StartNativeMainMenuWorld();
    }
}

- (void)fullscreenPressed:(id)sender
{
    (void)sender;
    id<AppleGameFullscreenHandling> delegate = (id<AppleGameFullscreenHandling>)[NSApp delegate];
    if (delegate && [delegate respondsToSelector:@selector(toggleGameFullscreen:)]) {
        [delegate toggleGameFullscreen:nil];
    }
}

- (void)quitPressed:(id)sender
{
    (void)sender;
    [NSApp terminate:nil];
}

@end

static void EnsureNativeMainMenu(Apple_UIController* owner)
{
    if (!s_nativeMainMenu) {
        s_nativeMainMenu = [[AppleMainMenuController alloc] initWithOwner:owner];
    }
    s_nativeMainMenu.owner = owner;
    [s_nativeMainMenu attachIfNeeded];
}

std::wstring Apple_UIController::GetNativeOverlayStatusText() const
{
    if (!m_nativeStatusText.empty()) {
        return m_nativeStatusText;
    }

    switch (m_nativeOverlayMode) {
    case NativeOverlayMode::LoadingWorld:
        return L"Loading world...";
    case NativeOverlayMode::PauseMenu:
        return L"World is running. Close the menu to return to gameplay.";
    case NativeOverlayMode::MainMenu:
        return L"Temporary native frontend while Apple Iggy UI is stubbed.";
    case NativeOverlayMode::Hidden:
    default:
        return L"";
    }
}

bool Apple_UIController::IsNativeWorldReadyForGameplay() const
{
    if (!app.GetGameStarted()) {
        return false;
    }

    Minecraft* minecraft = Minecraft::GetInstance();
    if (!minecraft || !minecraft->level) {
        return false;
    }

    const int primaryPad = ProfileManager.GetPrimaryPad();
    if (primaryPad < 0 || primaryPad >= XUSER_MAX_COUNT) {
        return false;
    }

    return minecraft->localplayers[primaryPad] != nullptr;
}

void Apple_UIController::RefreshNativeOverlayStatus()
{
    if (m_nativeOverlayMode == NativeOverlayMode::LoadingWorld) {
        m_nativeStatusText = app.GetGameStarted()
            ? L"Loading world. Waiting for stable gameplay frames..."
            : L"Creating world from the Apple fallback frontend...";
        return;
    }

    if (m_nativeSavingMessageVisible) {
        m_nativeStatusText = L"Saving world...";
        return;
    }

    if (m_nativeAutosaveCountdownVisible) {
        wchar_t autosaveCountdown[128];
        swprintf(autosaveCountdown,
                 sizeof(autosaveCountdown) / sizeof(autosaveCountdown[0]),
                 L"Autosaving in %u second%s.",
                 m_nativeAutosaveCountdownSeconds,
                 m_nativeAutosaveCountdownSeconds == 1 ? L"" : L"s");
        m_nativeStatusText = autosaveCountdown;
        return;
    }

    if (m_nativeTrialTimerVisible) {
        m_nativeStatusText = L"Trial timer is active.";
        return;
    }

    switch (m_nativeOverlayMode) {
    case NativeOverlayMode::PauseMenu:
        m_nativeStatusText = L"World is running. Close the menu to return to gameplay.";
        break;
    case NativeOverlayMode::MainMenu:
        m_nativeStatusText = L"Temporary native frontend while Apple Iggy UI is stubbed.";
        break;
    case NativeOverlayMode::Hidden:
        m_nativeStatusText.clear();
        break;
    case NativeOverlayMode::LoadingWorld:
        break;
    }
}

void Apple_UIController::SyncNativeOverlay()
{
    EnsureNativeMainMenu(this);
    RefreshNativeOverlayStatus();
    if (s_nativeMainMenu) {
        [s_nativeMainMenu syncFromOwner];
        [s_nativeMainMenu setMenuVisible:IsNativeOverlayVisible() ? YES : NO];
    }
}

void Apple_UIController::SetNativeOverlayMode(NativeOverlayMode mode)
{
    if (m_nativeOverlayMode == mode) {
        SyncNativeOverlay();
        return;
    }

    const NativeOverlayMode previousMode = m_nativeOverlayMode;
    m_nativeOverlayMode = mode;
    RefreshNativeOverlayStatus();

    switch (mode) {
    case NativeOverlayMode::MainMenu:
        AppleOverlayLog("Apple overlay shown: main menu");
        break;
    case NativeOverlayMode::LoadingWorld:
        AppleOverlayLog("Apple overlay shown: loading world");
        break;
    case NativeOverlayMode::PauseMenu:
        AppleOverlayLog("Apple overlay shown: pause menu");
        break;
    case NativeOverlayMode::Hidden:
        if (previousMode == NativeOverlayMode::LoadingWorld && m_nativeWorldLaunchStartedAt > 0.0) {
            const double elapsed = CFAbsoluteTimeGetCurrent() - m_nativeWorldLaunchStartedAt;
            AppleOverlayLog("Apple overlay hidden: gameplay ready after %.2fs", elapsed);
        } else {
            AppleOverlayLog("Apple overlay hidden");
        }
        m_nativeWorldLaunchStartedAt = 0.0;
        break;
    }

    if (mode != NativeOverlayMode::LoadingWorld && previousMode != NativeOverlayMode::LoadingWorld) {
        m_worldReadyStableFrames = 0;
    }

    SyncNativeOverlay();
}

// ── Initialisation ───────────────────────────────────────────────────────────

void Apple_UIController::init(void* metalDevice, void* metalCommandQueue,
                               void* colorTexture, void* depthStencilTexture,
                               S32 width, S32 height)
{
    m_metalDevice         = metalDevice;
    m_metalCommandQueue   = metalCommandQueue;
    m_colorTexture        = colorTexture;
    m_depthStencilTexture = depthStencilTexture;
    m_nativeOverlayMode = NativeOverlayMode::Hidden;
    m_nativeWorldLaunchPending = false;
    m_nativeTrialTimerVisible = false;
    m_nativeAutosaveCountdownVisible = false;
    m_nativeSavingMessageVisible = false;
    m_nativePlayerDisplayNameVisible = false;
    m_nativeAutosaveCountdownSeconds = 0;
    m_worldReadyStableFrames = 0;
    m_nativeWorldLaunchStartedAt = 0.0;
    m_nativeStatusText.clear();

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

    EnsureNativeMainMenu(this);
    ShowNativeMainMenu();
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
    (void)iPad; (void)initData; (void)layer; (void)group;
    if (scene == eUIScene_MainMenu || scene == eUIScene_PauseMenu || scene == eUIScene_FullscreenProgress) {
        ShowNativeMainMenu();
        return true;
    }
    return false;
#endif
}

bool Apple_UIController::NavigateBack(int iPad, bool forceUsePad, EUIScene eScene, EUILayer eLayer)
{
#ifdef _ENABLEIGGY
    return UIController::NavigateBack(iPad, forceUsePad, eScene, eLayer);
#else
    (void)iPad; (void)forceUsePad; (void)eScene; (void)eLayer;
    if (IsNativeOverlayVisible() && app.GetGameStarted() && !m_nativeWorldLaunchPending) {
        HideNativeMainMenu();
        return true;
    }
    return false;
#endif
}

void Apple_UIController::CloseUIScenes(int iPad, bool forceIPad)
{
#ifdef _ENABLEIGGY
    UIController::CloseUIScenes(iPad, forceIPad);
#else
    (void)iPad; (void)forceIPad;
    if (app.GetGameStarted() && !m_nativeWorldLaunchPending) {
        HideNativeMainMenu();
    }
#endif
}

void Apple_UIController::CloseAllPlayersScenes()
{
#ifdef _ENABLEIGGY
    UIController::CloseAllPlayersScenes();
#else
    if (app.GetGameStarted() && !m_nativeWorldLaunchPending) {
        HideNativeMainMenu();
    }
#endif
}

bool Apple_UIController::IsPauseMenuDisplayed(int iPad)
{
#ifdef _ENABLEIGGY
    return UIController::IsPauseMenuDisplayed(iPad);
#else
    (void)iPad;
    return IsNativeOverlayVisible() && app.GetGameStarted();
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
    return IsNativeOverlayVisible();
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
#else
    if (m_nativeWorldLaunchPending) {
        if (IsNativeWorldReadyForGameplay()) {
            if (m_worldReadyStableFrames == 0) {
                AppleOverlayLog("Apple loading overlay: first frame with valid level");
            }

            ++m_worldReadyStableFrames;
            if (m_worldReadyStableFrames == 1) {
                AppleOverlayLog("Apple loading overlay: first stable gameplay frame");
            }

            if (m_worldReadyStableFrames >= kNativeWorldReadyStableFramesRequired) {
                m_nativeWorldLaunchPending = false;
                HideNativeMainMenu();
                return;
            }
        } else {
            if (m_worldReadyStableFrames != 0) {
                AppleOverlayLog("Apple loading overlay: readiness lost, resetting stable frame counter");
            }
            m_worldReadyStableFrames = 0;
        }

        SetNativeOverlayMode(NativeOverlayMode::LoadingWorld);
    } else if (!app.GetGameStarted()) {
        if (!IsNativeOverlayVisible()) {
            ShowNativeMainMenu();
        } else {
            SetNativeOverlayMode(NativeOverlayMode::MainMenu);
        }
    } else if (IsNativeOverlayVisible()) {
        SetNativeOverlayMode(NativeOverlayMode::PauseMenu);
    }
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

void Apple_UIController::ShowTrialTimer(bool show)
{
#ifdef _ENABLEIGGY
    UIController::ShowTrialTimer(show);
#else
    HandleNativeTrialTimer(show);
#endif
}

void Apple_UIController::UpdateTrialTimer(unsigned int iPad)
{
#ifdef _ENABLEIGGY
    UIController::UpdateTrialTimer(iPad);
#else
    HandleNativeTrialTimerUpdate(iPad);
#endif
}

void Apple_UIController::ShowAutosaveCountdownTimer(bool show)
{
#ifdef _ENABLEIGGY
    UIController::ShowAutosaveCountdownTimer(show);
#else
    HandleNativeAutosaveCountdownTimer(show);
#endif
}

void Apple_UIController::UpdateAutosaveCountdownTimer(unsigned int uiSeconds)
{
#ifdef _ENABLEIGGY
    UIController::UpdateAutosaveCountdownTimer(uiSeconds);
#else
    HandleNativeAutosaveCountdownUpdate(uiSeconds);
#endif
}

void Apple_UIController::ShowSavingMessage(unsigned int iPad, C4JStorage::ESavingMessage eVal)
{
#ifdef _ENABLEIGGY
    UIController::ShowSavingMessage(iPad, eVal);
#else
    HandleNativeSavingMessage(iPad, eVal);
#endif
}

void Apple_UIController::ShowPlayerDisplayname(bool show)
{
#ifdef _ENABLEIGGY
    UIController::ShowPlayerDisplayname(show);
#else
    HandleNativePlayerDisplayname(show);
#endif
}

void Apple_UIController::HandleNativeTrialTimer(bool show)
{
    m_nativeTrialTimerVisible = show;
    if (!show) {
        RefreshNativeOverlayStatus();
    }
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
}

void Apple_UIController::HandleNativeTrialTimerUpdate(unsigned int iPad)
{
    (void)iPad;
    if (!m_nativeTrialTimerVisible) {
        return;
    }

    RefreshNativeOverlayStatus();
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
}

void Apple_UIController::HandleNativeAutosaveCountdownTimer(bool show)
{
    m_nativeAutosaveCountdownVisible = show;
    if (!show) {
        m_nativeAutosaveCountdownSeconds = 0;
    }
    RefreshNativeOverlayStatus();
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
}

void Apple_UIController::HandleNativeAutosaveCountdownUpdate(unsigned int uiSeconds)
{
    m_nativeAutosaveCountdownVisible = true;
    m_nativeAutosaveCountdownSeconds = uiSeconds;
    RefreshNativeOverlayStatus();
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
}

void Apple_UIController::HandleNativeSavingMessage(unsigned int iPad, C4JStorage::ESavingMessage eVal)
{
    (void)iPad;
    m_nativeSavingMessageVisible = (eVal != C4JStorage::ESavingMessage_None);
    RefreshNativeOverlayStatus();
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
}

void Apple_UIController::HandleNativePlayerDisplayname(bool show)
{
    m_nativePlayerDisplayNameVisible = show;
    if (IsNativeOverlayVisible()) {
        SyncNativeOverlay();
    }
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
    if (s_nativeMainMenu) {
        [s_nativeMainMenu.overlay removeFromSuperview];
        s_nativeMainMenu = nil;
    }
}

void Apple_UIController::ShowNativeMainMenu()
{
    if (m_nativeWorldLaunchPending) {
        SetNativeOverlayMode(NativeOverlayMode::LoadingWorld);
        return;
    }

    SetNativeOverlayMode(app.GetGameStarted() ? NativeOverlayMode::PauseMenu
                                              : NativeOverlayMode::MainMenu);
}

void Apple_UIController::HideNativeMainMenu()
{
    SetNativeOverlayMode(NativeOverlayMode::Hidden);
}

void Apple_UIController::StartNativeMainMenuWorld()
{
    if (app.GetGameStarted()) {
        HideNativeMainMenu();
        return;
    }

    if (m_nativeWorldLaunchPending) {
        return;
    }

    AppleMarkWorldStartRequested();
    m_nativeWorldLaunchPending = true;
    m_worldReadyStableFrames = 0;
    m_nativeWorldLaunchStartedAt = CFAbsoluteTimeGetCurrent();
    SetNativeOverlayMode(NativeOverlayMode::LoadingWorld);
    app.TemporaryCreateGameStart();
}
