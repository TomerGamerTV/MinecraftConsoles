// macOS_Minecraft.mm — macOS entry point for Minecraft Legacy Console Edition
// Cocoa + Metal application matching the Windows64_Minecraft.cpp game loop.

// Include game precompiled header FIRST (defines types, STL, etc.)
#include "stdafx.h"

// Workaround: CarbonCore's 'Component' type conflicts with game code
#define Component CarbonComponent_Renamed
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CVDisplayLink.h>
#import <GameController/GameController.h>
#import <Carbon/Carbon.h>  // kVK_ key codes
#undef Component

#include <cstdio>
#include <cstring>
#include <string>
#include <sys/stat.h>
#include <pthread.h>
#include <sstream>
#include <vector>

// Game headers - access Minecraft class and game systems
#include "../Minecraft.h"
#include "../Common/Consoles_App.h"
#include "../Common/Network/GameNetworkManager.h"
#include "../Apple/Apple_App.h"
#include "../Apple/Input/AppleKeyboardMouseInput.h"
#include "../Apple/Network/BSDNetLayer.h"

// Game renderer for post-processing
#include "../GameRenderer.h"

// Forward-declare thread storage init functions
// (full headers have complex dependency chains, we just need the static methods)
extern "C" void AppleInitThreadStorage();

// ── Logging system ───────────────────────────────────────────────────────────
// All game logs go to a file so they can be inspected later

static FILE* g_logFile = nullptr;
static const char* g_logPath = nullptr;
static const char* g_controlPath = nullptr;

static void InitLogging()
{
    // Place log file next to the .app bundle
    NSString* bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString* parentDir  = [bundlePath stringByDeletingLastPathComponent];
    NSString* logFile    = [parentDir stringByAppendingPathComponent:@"minecraft_runtime.log"];
    g_logPath = strdup([logFile UTF8String]);

    g_logFile = fopen(g_logPath, "w");
    if (!g_logFile) {
        // Fallback to /tmp
        g_logPath = "/tmp/minecraft_runtime.log";
        g_logFile = fopen(g_logPath, "w");
    }

    if (g_logFile) {
        // Get current time
        time_t now = time(nullptr);
        char timeStr[64];
        strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(g_logFile, "=== Minecraft LCE macOS Runtime Log ===\n");
        fprintf(g_logFile, "=== Started: %s ===\n\n", timeStr);
        fflush(g_logFile);

        // Redirect stderr to our log file so fprintf(stderr,...) in game code is captured
        dup2(fileno(g_logFile), STDERR_FILENO);
    }

    if (bundlePath) {
        NSString* parentDir = [bundlePath stringByDeletingLastPathComponent];
        NSString* controlFile = [parentDir stringByAppendingPathComponent:@"minecraft_control.txt"];
        g_controlPath = strdup([controlFile UTF8String]);

        FILE* control = fopen(g_controlPath, "a");
        if (control) {
            fclose(control);
        }
    }
}

// Log a message to both the file and NSLog (console)
static void GameLog(const char* fmt, ...)
{
    va_list args;
    char buf[2048];

    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    // Write to log file
    if (g_logFile) {
        // Timestamp each line
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        double elapsed = ts.tv_sec + ts.tv_nsec / 1e9;
        fprintf(g_logFile, "[%10.3f] %s\n", elapsed, buf);
        fflush(g_logFile);
    }

    // Also print to console (visible in Xcode/Console.app)
    NSLog(@"[MC] %s", buf);
}

// ── External declarations ────────────────────────────────────────────────────

// These are defined in game code / Apple stubs
extern C4JRender RenderManager;
extern C_4JInput InputManager;
extern C4JStorage StorageManager;
extern C_4JProfile ProfileManager;
extern CConsoleMinecraftApp app;
extern Apple_UIController ui;
extern KeyboardMouseInput g_KBMInput;
// g_NetworkManager declared in GameNetworkManager.h

// From Xbox_Minecraft.cpp / DefineActions
extern void DefineActions(void);

// Screen resolution
static int g_iScreenWidth  = 1920;
static int g_iScreenHeight = 1080;
static int g_rScreenWidth  = 1920;
static int g_rScreenHeight = 1080;
static float g_iAspectRatio = 16.0f / 9.0f;

// Username
static char    g_AppleUsername[17]  = { 0 };
static wchar_t g_AppleUsernameW[17] = { 0 };

// Fullscreen state
static bool g_isFullscreen = false;
static NSRect g_windowedFrame = NSZeroRect;
static NSWindowStyleMask g_windowedStyleMask = 0;

// Metal objects
static id<MTLDevice>       g_mtlDevice       = nil;
static id<MTLCommandQueue> g_mtlCommandQueue = nil;

// Game state
static Minecraft* g_pMinecraft = nullptr;
static bool g_gameInitialized = false;
static int g_frameCount = 0;
static bool g_autoStartIssued = false;
static int g_framesWithoutGameStart = 0;
static int g_framesWithoutLevel = 0;
static time_t g_lastControlMTime = 0;
static bool g_frameInProgress = false;

extern "C" void AppleMarkWorldStartRequested()
{
    g_autoStartIssued = true;
    g_framesWithoutGameStart = 0;
    g_framesWithoutLevel = 0;
    GameLog("World start requested from Apple frontend");
}

// ── Key Code Mapping ─────────────────────────────────────────────────────────

static int MapMacKeyToVK(unsigned short keyCode)
{
    switch (keyCode)
    {
        case kVK_ANSI_A: return 'A';  case kVK_ANSI_B: return 'B';
        case kVK_ANSI_C: return 'C';  case kVK_ANSI_D: return 'D';
        case kVK_ANSI_E: return 'E';  case kVK_ANSI_F: return 'F';
        case kVK_ANSI_G: return 'G';  case kVK_ANSI_H: return 'H';
        case kVK_ANSI_I: return 'I';  case kVK_ANSI_J: return 'J';
        case kVK_ANSI_K: return 'K';  case kVK_ANSI_L: return 'L';
        case kVK_ANSI_M: return 'M';  case kVK_ANSI_N: return 'N';
        case kVK_ANSI_O: return 'O';  case kVK_ANSI_P: return 'P';
        case kVK_ANSI_Q: return 'Q';  case kVK_ANSI_R: return 'R';
        case kVK_ANSI_S: return 'S';  case kVK_ANSI_T: return 'T';
        case kVK_ANSI_U: return 'U';  case kVK_ANSI_V: return 'V';
        case kVK_ANSI_W: return 'W';  case kVK_ANSI_X: return 'X';
        case kVK_ANSI_Y: return 'Y';  case kVK_ANSI_Z: return 'Z';
        case kVK_ANSI_0: return '0';  case kVK_ANSI_1: return '1';
        case kVK_ANSI_2: return '2';  case kVK_ANSI_3: return '3';
        case kVK_ANSI_4: return '4';  case kVK_ANSI_5: return '5';
        case kVK_ANSI_6: return '6';  case kVK_ANSI_7: return '7';
        case kVK_ANSI_8: return '8';  case kVK_ANSI_9: return '9';
        case kVK_Return:     return 0x0D;
        case kVK_Escape:     return 0x1B;
        case kVK_Delete:     return 0x08;
        case kVK_Tab:        return 0x09;
        case kVK_Space:      return 0x20;
        case kVK_LeftArrow:  return 0x25;
        case kVK_UpArrow:    return 0x26;
        case kVK_RightArrow: return 0x27;
        case kVK_DownArrow:  return 0x28;
        case kVK_Shift:      return 0xA0;
        case kVK_RightShift: return 0xA1;
        case kVK_Control:    return 0xA2;
        case kVK_RightControl: return 0xA3;
        case kVK_Option:     return 0xA4;
        case kVK_RightOption:return 0xA5;
        case kVK_F1:  return 0x70;  case kVK_F2:  return 0x71;
        case kVK_F3:  return 0x72;  case kVK_F4:  return 0x73;
        case kVK_F5:  return 0x74;  case kVK_F6:  return 0x75;
        case kVK_F7:  return 0x76;  case kVK_F8:  return 0x77;
        case kVK_F9:  return 0x78;  case kVK_F10: return 0x79;
        case kVK_F11: return 0x7A;  case kVK_F12: return 0x7B;
        default: return 0;
    }
}

// ── Profile settings (matching Windows64) ────────────────────────────────────

#define NUM_PROFILE_VALUES   5
#define NUM_PROFILE_SETTINGS 4
static DWORD dwProfileSettingsA[NUM_PROFILE_VALUES] = { 0, 0, 0, 0, 0 };

// ══════════════════════════════════════════════════════════════════════════════
// Game Initialization — mirrors InitialiseMinecraftRuntime() from Windows64
// ══════════════════════════════════════════════════════════════════════════════

static Minecraft* InitialiseMinecraftRuntime(CAMetalLayer *metalLayer)
{
    GameLog("=== InitialiseMinecraftRuntime BEGIN ===");

    // Step 1: Load media archive (game assets)
    GameLog("INIT [1/14] loadMediaArchive...");
    app.loadMediaArchive();
    GameLog("INIT [1/14] loadMediaArchive DONE");

    // Step 2: Initialize renderer
    GameLog("INIT [2/14] RenderManager.Initialise (Metal)...");
    RenderManager.Initialise((__bridge void*)g_mtlDevice, (__bridge void*)metalLayer);
    GameLog("INIT [2/14] RenderManager.Initialise DONE");

    // Step 3: Load string table
    GameLog("INIT [3/14] loadStringTable...");
    app.loadStringTable();
    GameLog("INIT [3/14] loadStringTable DONE");

    // Step 4: Initialize UI
    GameLog("INIT [4/14] ui.init...");
    ui.init((__bridge void*)g_mtlDevice, (__bridge void*)g_mtlCommandQueue,
            nullptr, nullptr, g_rScreenWidth, g_rScreenHeight);
    GameLog("INIT [4/14] ui.init DONE (%dx%d)", g_rScreenWidth, g_rScreenHeight);

    // Step 5: Initialize input
    GameLog("INIT [5/14] InputManager.Initialise...");
    InputManager.Initialise(1, 3, MINECRAFT_ACTION_MAX, ACTION_MAX_MENU);
    GameLog("INIT [5/14] InputManager.Initialise DONE");

    // Step 6: Keyboard/mouse input
    GameLog("INIT [6/14] g_KBMInput.Init...");
    g_KBMInput.Init();
    GameLog("INIT [6/14] g_KBMInput.Init DONE");

    // Step 7: Define input actions
    GameLog("INIT [7/14] DefineActions...");
    DefineActions();
    InputManager.SetJoypadMapVal(0, 0);
    InputManager.SetKeyRepeatRate(0.3f, 0.2f);
    GameLog("INIT [7/14] DefineActions DONE");

    // Step 8: Profile manager
    GameLog("INIT [8/14] ProfileManager.Initialise...");
    ProfileManager.Initialise(
        TITLEID_MINECRAFT,
        app.m_dwOfferID,
        PROFILE_VERSION_10,
        NUM_PROFILE_VALUES,
        NUM_PROFILE_SETTINGS,
        dwProfileSettingsA,
        app.GAME_DEFINED_PROFILE_DATA_BYTES * XUSER_MAX_COUNT,
        &app.uiGameDefinedDataChangedBitmask
    );
    ProfileManager.SetDefaultOptionsCallback(&CConsoleMinecraftApp::DefaultOptionsCallback, (LPVOID)&app);
    ProfileManager.SetDebugFullOverride(true);
    GameLog("INIT [8/14] ProfileManager.Initialise DONE");

    // Step 9: Network manager
    GameLog("INIT [9/14] Network init...");
    g_NetworkManager.Initialise();

    // TODO: Set up IQNet player slots (needs IQNet header)
    // For now, skip network player initialization - single player only

    BSDNetLayer::Initialize();
    GameLog("INIT [9/14] Network init DONE");

    // Step 10: Thread storage for game systems
    GameLog("INIT [10/14] CreateNewThreadStorage...");
    AppleInitThreadStorage();
    GameLog("INIT [10/14] CreateNewThreadStorage DONE");

    // Step 11: Minecraft::main() — creates Minecraft instance, calls init() and run()
    // This calls MinecraftWorld_RunStaticCtors, EntityRenderDispatcher::staticCtor, etc.
    // Add a crash signal handler so we can log the crash location
    GameLog("INIT [11/14] Minecraft::main()...");

    // Install signal handler to catch crashes during init
    signal(SIGSEGV, [](int sig) {
        GameLog("CRASH: SIGSEGV during game initialization!");
        GameLog("Check Console.app or ~/Library/Logs/DiagnosticReports/ for full stack trace");
        _exit(1);
    });
    signal(SIGABRT, [](int sig) {
        GameLog("CRASH: SIGABRT during game initialization!");
        _exit(1);
    });

    Minecraft::main();

    // Restore default signal handlers
    signal(SIGSEGV, SIG_DFL);
    signal(SIGABRT, SIG_DFL);

    GameLog("INIT [11/14] Minecraft::main() DONE");

    // Step 12: Get instance
    Minecraft* pMinecraft = Minecraft::GetInstance();
    if (pMinecraft == nullptr) {
        GameLog("INIT ERROR: Minecraft::GetInstance() returned nullptr!");
        return nullptr;
    }
    GameLog("INIT [12/14] Minecraft instance: %p", pMinecraft);

    // Step 13: Game settings
    GameLog("INIT [13/14] InitGameSettings...");
    app.InitGameSettings();
    GameLog("INIT [13/14] InitGameSettings DONE");

    // Step 14: Tips
    GameLog("INIT [14/14] InitialiseTips...");
    app.InitialiseTips();
    GameLog("INIT [14/14] InitialiseTips DONE");

    GameLog("=== InitialiseMinecraftRuntime COMPLETE ===");
    return pMinecraft;
}

// ── Application delegate ─────────────────────────────────────────────────────

@interface MinecraftAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (strong) NSWindow*  window;
@property (strong) MTKView*   metalView;
@property (assign) bool gameStartupScheduled;
@property (strong) NSTimer* windowWatchdogTimer;
@property (strong) NSTimer* frameTimer;
@end

@interface MinecraftWindow : NSWindow
@end

// ── MTKView delegate — drives the game loop each frame ───────────────────────

@interface MinecraftRenderer : NSObject <MTKViewDelegate>
@end

// Globals for the delegates
static MinecraftAppDelegate* g_appDelegate  = nil;
static MinecraftRenderer*    g_renderer     = nil;

// ── Helper: load username ────────────────────────────────────────────────────

static void LoadUsername()
{
    NSString* bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString* parentDir  = [bundlePath stringByDeletingLastPathComponent];
    NSString* userFile   = [parentDir stringByAppendingPathComponent:@"username.txt"];

    FILE* f = fopen([userFile UTF8String], "r");
    if (f) {
        char buf[128] = {};
        if (fgets(buf, sizeof(buf), f)) {
            int len = (int)strlen(buf);
            while (len > 0 && (buf[len-1] == '\n' || buf[len-1] == '\r' || buf[len-1] == ' '))
                buf[--len] = '\0';
            if (len > 0) strncpy(g_AppleUsername, buf, sizeof(g_AppleUsername) - 1);
        }
        fclose(f);
    }
    if (g_AppleUsername[0] == 0)
        strncpy(g_AppleUsername, "Player", sizeof(g_AppleUsername) - 1);

    for (int i = 0; i < 17; i++)
        g_AppleUsernameW[i] = static_cast<wchar_t>(g_AppleUsername[i]);
}

// ── Helper: set working directory to app bundle resources ────────────────────

static void SetWorkingDirectoryToResources()
{
    // Assets are in the MacOS/ directory alongside the executable, not Resources/
    NSString* execPath = [[NSBundle mainBundle] executablePath];
    NSString* macOSDir = [execPath stringByDeletingLastPathComponent];
    if (macOSDir) {
        chdir([macOSDir UTF8String]);
        GameLog("Working directory: %s", [macOSDir UTF8String]);
    }
}

// ── Helper: toggle fullscreen ────────────────────────────────────────────────

static void ToggleFullscreen()
{
    NSWindow* window = g_appDelegate.window;
    if (!window) return;

    NSScreen* screen = [window screen] ?: [NSScreen mainScreen];
    if (!screen) return;

    if (!g_isFullscreen) {
        g_windowedFrame = [window frame];
        g_windowedStyleMask = [window styleMask];

        [window setStyleMask:NSWindowStyleMaskBorderless];
        [window setFrame:[screen frame] display:YES animate:NO];
        [window setMovable:NO];
        [window setTitleVisibility:NSWindowTitleHidden];
        [window setTitlebarAppearsTransparent:YES];
        [window setCollectionBehavior:NSWindowCollectionBehaviorManaged];
    } else {
        [window setStyleMask:g_windowedStyleMask ? g_windowedStyleMask : (NSWindowStyleMaskTitled |
                                                                          NSWindowStyleMaskClosable |
                                                                          NSWindowStyleMaskMiniaturizable |
                                                                          NSWindowStyleMaskResizable)];
        [window setFrame:g_windowedFrame display:YES animate:NO];
        [window setMovable:YES];
        [window setTitleVisibility:NSWindowTitleVisible];
        [window setTitlebarAppearsTransparent:NO];
        [window setCollectionBehavior:NSWindowCollectionBehaviorManaged];
    }

    [window makeKeyAndOrderFront:nil];
    g_isFullscreen = !g_isFullscreen;
    GameLog("Fullscreen toggled: %s", g_isFullscreen ? "ON" : "OFF");
}

static int ParseControlVK(const std::string& token)
{
    if (token.size() == 1) {
        unsigned char ch = static_cast<unsigned char>(token[0]);
        if (ch >= 'a' && ch <= 'z') ch = static_cast<unsigned char>(ch - ('a' - 'A'));
        return ch;
    }

    if (token == "ESC" || token == "ESCAPE") return 0x1B;
    if (token == "ENTER" || token == "RETURN") return 0x0D;
    if (token == "TAB") return 0x09;
    if (token == "SPACE") return 0x20;
    if (token == "LEFT") return 0x25;
    if (token == "UP") return 0x26;
    if (token == "RIGHT") return 0x27;
    if (token == "DOWN") return 0x28;
    if (token == "F11") return 0x7A;
    if (token == "SHIFT") return 0xA0;
    if (token == "CTRL" || token == "CONTROL") return 0xA2;
    if (token == "ALT" || token == "OPTION") return 0xA4;

    return 0;
}

static void ProcessControlCommand(const std::string& rawLine)
{
    std::string line = rawLine;
    while (!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ' || line.back() == '\t'))
        line.pop_back();
    size_t start = 0;
    while (start < line.size() && (line[start] == ' ' || line[start] == '\t'))
        ++start;
    line.erase(0, start);

    if (line.empty() || line[0] == '#')
        return;

    if (line == "quit" || line == "close") {
        GameLog("CONTROL: terminating app");
        [NSApp terminate:nil];
        return;
    }

    if (line == "fullscreen") {
        if (!g_isFullscreen)
            ToggleFullscreen();
        return;
    }

    if (line == "windowed") {
        if (g_isFullscreen)
            ToggleFullscreen();
        return;
    }

    if (line == "status") {
        GameLog("CONTROL STATUS: frame=%d gameStarted=%d level=%p screen=%p fullscreen=%d",
                g_frameCount,
                app.GetGameStarted() ? 1 : 0,
                g_pMinecraft ? g_pMinecraft->level : nullptr,
                g_pMinecraft ? g_pMinecraft->screen : nullptr,
                g_isFullscreen ? 1 : 0);
        return;
    }

    if (line == "dump") {
        GameLog("CONTROL: dump requested");
        RenderManager.DoScreenGrabOnNextPresent();
        return;
    }

    if (line == "menu") {
        GameLog("CONTROL: show menu");
        ui.ShowNativeMainMenu();
        return;
    }

    if (line == "start" || line == "play") {
        if (!app.GetGameStarted()) {
            GameLog("CONTROL: start world from menu");
            ui.StartNativeMainMenuWorld();
        } else {
            GameLog("CONTROL: start ignored, world already running");
        }
        return;
    }

    std::istringstream stream(line);
    std::string command;
    stream >> command;

    if (command == "key") {
        std::string keyName;
        stream >> keyName;
        int vk = ParseControlVK(keyName);
        if (vk != 0) {
            GameLog("CONTROL: key %s", keyName.c_str());
            g_KBMInput.OnKeyDown(vk);
            g_KBMInput.OnKeyUp(vk);
        } else {
            GameLog("CONTROL: unknown key '%s'", keyName.c_str());
        }
        return;
    }

    if (command == "text") {
        std::string text;
        std::getline(stream, text);
        if (!text.empty() && text[0] == ' ')
            text.erase(0, 1);
        GameLog("CONTROL: text \"%s\"", text.c_str());
        for (char ch : text)
            g_KBMInput.OnChar(static_cast<wchar_t>(static_cast<unsigned char>(ch)));
        return;
    }

    if (command == "mouse") {
        std::string subcommand;
        stream >> subcommand;

        if (subcommand == "move") {
            int x = 0;
            int y = 0;
            if (stream >> x >> y) {
                GameLog("CONTROL: mouse move %d %d", x, y);
                g_KBMInput.OnMouseMove(x, y);
            }
            return;
        }

        if (subcommand == "click") {
            std::string buttonName;
            stream >> buttonName;
            int button = 0;
            if (buttonName == "left") button = 0;
            else if (buttonName == "right") button = 1;
            else if (buttonName == "middle") button = 2;
            GameLog("CONTROL: mouse click %s", buttonName.c_str());
            g_KBMInput.OnMouseButtonDown(button);
            g_KBMInput.OnMouseButtonUp(button);
            return;
        }
    }

    GameLog("CONTROL: unknown command '%s'", line.c_str());
}

static void PollControlFile()
{
    if (!g_controlPath)
        return;

    struct stat st = {};
    if (stat(g_controlPath, &st) != 0)
        return;

    if (st.st_size <= 0 || st.st_mtime <= g_lastControlMTime)
        return;

    FILE* control = fopen(g_controlPath, "r");
    if (!control)
        return;

    char line[512];
    while (fgets(line, sizeof(line), control))
        ProcessControlCommand(line);
    fclose(control);

    control = fopen(g_controlPath, "w");
    if (control)
        fclose(control);

    g_lastControlMTime = st.st_mtime;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - MTKViewDelegate (game loop)
// ══════════════════════════════════════════════════════════════════════════════

@implementation MinecraftRenderer

// Called once per display refresh — this is the main game loop tick.
- (void)drawInMTKView:(nonnull MTKView*)view
{
    if (g_frameInProgress)
        return;

    g_frameInProgress = true;

    if (!g_gameInitialized || !g_pMinecraft) {
        // Not yet initialized — clear to dark blue placeholder
        @autoreleasepool {
            id<MTLCommandBuffer> commandBuffer = [g_mtlCommandQueue commandBuffer];
            MTLRenderPassDescriptor* passDesc  = view.currentRenderPassDescriptor;
            if (passDesc) {
                passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.125, 0.3, 1.0);
                passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
                id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
                [encoder endEncoding];
            }
            [commandBuffer presentDrawable:view.currentDrawable];
            [commandBuffer commit];
        }
        g_frameInProgress = false;
        return;
    }

    @autoreleasepool {
        @try {
            g_frameCount++;

            // Log first few frames and then every 600th frame (~10 seconds)
            bool shouldLog = (g_frameCount <= 5) || (g_frameCount % 600 == 0);

            if (shouldLog)
                GameLog("FRAME %d BEGIN", g_frameCount);

            // 1. Start frame (acquires Metal drawable, creates command encoder)
            RenderManager.StartFrame();

            // 2. Update time
            app.UpdateTime();

            // 3. Input
            InputManager.Tick();

            // 4. Storage
            StorageManager.Tick();

            // 5. Render manager housekeeping
            RenderManager.Tick();

            // 6. Network
            g_NetworkManager.DoWork();
            if ((g_frameCount % 10) == 0)
                PollControlFile();

            // 7. Game logic
            if (app.GetGameStarted()) {
                g_framesWithoutGameStart = 0;
                static bool firstGameFrame = true;
                if (firstGameFrame || shouldLog) {
                    GameLog("FRAME %d: Game running - run_middle()", g_frameCount);
                    firstGameFrame = false;
                }
                // Only run game logic if we have a valid level
                if (g_pMinecraft->level != nullptr) {
                    g_framesWithoutLevel = 0;
                    g_pMinecraft->applyFrameMouseLook();
                    g_pMinecraft->run_middle();
                    if (shouldLog) GameLog("FRAME %d: run_middle() done", g_frameCount);
                } else {
                    // No level yet - keep network traffic moving so the local client/server handshake can finish.
                    g_pMinecraft->soundEngine->tick(nullptr, 0.0f);
                    g_pMinecraft->textures->tick(true, false);
                    g_pMinecraft->tickAllConnections();
                    g_framesWithoutLevel++;
                    static bool loggedNoLevel = false;
                    if (!loggedNoLevel || (g_frameCount % 300) == 0) {
                        GameLog("FRAME %d: GameStarted but no level - waiting for world load", g_frameCount);
                        loggedNoLevel = true;
                    }
                    if (g_autoStartIssued && g_framesWithoutLevel > (60 * 30)) {
                        GameLog("STALL GUARD: auto-started world never produced a level; terminating app");
                        g_frameInProgress = false;
                        [NSApp terminate:nil];
                        return;
                    }
                }
            } else {
                if (g_autoStartIssued) {
                    g_framesWithoutGameStart++;
                    if (g_framesWithoutGameStart > (60 * 30)) {
                        GameLog("STALL GUARD: auto-started world never reached gameStarted; terminating app");
                        g_frameInProgress = false;
                        [NSApp terminate:nil];
                        return;
                    }
                }
                if (shouldLog) GameLog("FRAME %d: Menu mode", g_frameCount);
                if (shouldLog) GameLog("FRAME %d: soundEngine->tick", g_frameCount);
                g_pMinecraft->soundEngine->tick(nullptr, 0.0f);
                if (shouldLog) GameLog("FRAME %d: textures->tick", g_frameCount);
                g_pMinecraft->textures->tick(true, false);
                // Tick network connections so client can process server packets
                // (needed for the client-server handshake during world loading)
                g_pMinecraft->tickAllConnections();
            }

            // 8. Audio
            if (shouldLog) GameLog("FRAME %d: playMusicTick", g_frameCount);
            g_pMinecraft->soundEngine->playMusicTick();

            // 9. UI
            if (shouldLog) GameLog("FRAME %d: ui.tick", g_frameCount);
            ui.tick();
            if (shouldLog) GameLog("FRAME %d: ui.render", g_frameCount);
            ui.render();

            // 10. Present
            if (shouldLog) GameLog("FRAME %d: Present", g_frameCount);
            RenderManager.Present();

            // 11. Post-present
            if (shouldLog) GameLog("FRAME %d: CheckMenuDisplayed", g_frameCount);
            ui.CheckMenuDisplayed();

            if (shouldLog)
                GameLog("FRAME %d END", g_frameCount);

        } @catch (NSException *exception) {
            GameLog("FRAME %d EXCEPTION: %s - %s",
                    g_frameCount,
                    [[exception name] UTF8String],
                    [[exception reason] UTF8String]);
        }
    }

    g_frameInProgress = false;
}

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size
{
    g_rScreenWidth  = (int)size.width;
    g_rScreenHeight = (int)size.height;
    g_iAspectRatio  = (float)g_rScreenWidth / (float)g_rScreenHeight;

    GameLog("Drawable size changed: %d x %d (aspect %.2f)",
            g_rScreenWidth, g_rScreenHeight, g_iAspectRatio);
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - NSApplicationDelegate
// ══════════════════════════════════════════════════════════════════════════════

@implementation MinecraftAppDelegate

- (void)ensureWindowAndView
{
    bool needsWindow = (self.window == nil);
    bool needsView = (self.metalView == nil);

    if (!needsWindow && !needsView) {
        if (![self.window isVisible] || self.window.contentView != self.metalView) {
            [self.window setContentView:self.metalView];
            [self.window makeKeyAndOrderFront:nil];
            [self.window orderFrontRegardless];
            [NSApp activateIgnoringOtherApps:YES];
            GameLog("Window watchdog re-show: visible=%d windowNumber=%ld",
                    (int)[self.window isVisible],
                    (long)[self.window windowNumber]);
        }
        return;
    }

    if (needsWindow) {
        NSRect contentRect = NSMakeRect(0, 0, 1280, 720);
        NSWindowStyleMask styleMask = NSWindowStyleMaskTitled
                                    | NSWindowStyleMaskClosable
                                    | NSWindowStyleMaskMiniaturizable
                                    | NSWindowStyleMaskResizable;

        self.window = (NSWindow*)[[MinecraftWindow alloc] initWithContentRect:contentRect
                                                                    styleMask:styleMask
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:NO];
        [self.window setTitle:@"Minecraft LCE"];
        [self.window center];
        [self.window setDelegate:self];
        [self.window setAcceptsMouseMovedEvents:YES];
        [self.window setCollectionBehavior:NSWindowCollectionBehaviorManaged];
        [self.window setReleasedWhenClosed:NO];
        [self.window setRestorable:NO];
    }

    if (needsView) {
        NSRect contentRect = [self.window contentRectForFrameRect:self.window.frame];
        self.metalView = [[MTKView alloc] initWithFrame:contentRect device:g_mtlDevice];
        self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        self.metalView.preferredFramesPerSecond = 60;
        self.metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        // Drive MTKView manually from our timer so we only have one frame source.
        self.metalView.paused = YES;
        self.metalView.enableSetNeedsDisplay = YES;

        if (!g_renderer)
            g_renderer = [[MinecraftRenderer alloc] init];
        self.metalView.delegate = g_renderer;
    }

    [self.window setContentView:self.metalView];
    [self.window makeKeyAndOrderFront:nil];
    [self.window orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];

    GameLog("Window ready: visible=%d windowNumber=%ld contentView=%p metalView=%p",
            (int)[self.window isVisible],
            (long)[self.window windowNumber],
            self.window.contentView,
            self.metalView);
}

- (void)startGameInitialization
{
    if (g_gameInitialized || self.gameStartupScheduled)
        return;

    self.gameStartupScheduled = true;
    GameLog("=== Starting game initialization ===");

    @try {
        CAMetalLayer *metalLayer = (CAMetalLayer *)self.metalView.layer;
        g_pMinecraft = InitialiseMinecraftRuntime(metalLayer);
        if (g_pMinecraft) {
            g_gameInitialized = true;
            GameLog("=== Game initialization SUCCEEDED ===");
            GameLog("Minecraft instance: %p", g_pMinecraft);
            GameLog("=== Waiting at main menu for user-driven world start ===");
        } else {
            GameLog("=== Game initialization FAILED (nullptr) ===");
        }
    } @catch (NSException *exception) {
        GameLog("=== Game initialization EXCEPTION: %s - %s ===",
                [[exception name] UTF8String],
                [[exception reason] UTF8String]);
    }

    GameLog("Log file location: %s", g_logPath ? g_logPath : "(unknown)");
}

- (void)windowWatchdogTick:(NSTimer*)timer
{
    (void)timer;
    [self ensureWindowAndView];
}

- (void)frameTimerTick:(NSTimer*)timer
{
    (void)timer;
    if (self.metalView) {
        [self.metalView draw];
    }
}

- (void)toggleGameFullscreen:(id)sender
{
    ToggleFullscreen();
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    // ── Logging ─────────────────────────────────────────────────────────
    InitLogging();
    GameLog("applicationDidFinishLaunching");

    // ── Metal device ─────────────────────────────────────────────────────
    g_mtlDevice = MTLCreateSystemDefaultDevice();
    if (!g_mtlDevice) {
        GameLog("FATAL: Metal is not supported on this Mac.");
        [NSApp terminate:nil];
        return;
    }
    g_mtlCommandQueue = [g_mtlDevice newCommandQueue];
    GameLog("Metal device: %s", [[g_mtlDevice name] UTF8String]);

    // ── Detect display resolution ────────────────────────────────────────
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect screenFrame   = [mainScreen frame];
    CGFloat backingScale = [mainScreen backingScaleFactor];
    g_rScreenWidth  = (int)(screenFrame.size.width  * backingScale);
    g_rScreenHeight = (int)(screenFrame.size.height * backingScale);
    g_iAspectRatio  = (float)g_rScreenWidth / (float)g_rScreenHeight;
    GameLog("Display: %dx%d @ %.1fx scale", g_rScreenWidth, g_rScreenHeight, backingScale);

    [NSWindow setAllowsAutomaticWindowTabbing:NO];
    [self ensureWindowAndView];
    self.windowWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                target:self
                                                              selector:@selector(windowWatchdogTick:)
                                                              userInfo:nil
                                                               repeats:YES];
    self.frameTimer = [NSTimer timerWithTimeInterval:(1.0 / 60.0)
                                              target:self
                                            selector:@selector(frameTimerTick:)
                                            userInfo:nil
                                             repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.frameTimer forMode:NSRunLoopCommonModes];

    // ── Load username and set working directory ──────────────────────────
    LoadUsername();
    SetWorkingDirectoryToResources();
    GameLog("Username: %s", g_AppleUsername);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self ensureWindowAndView];
        [self startGameInitialization];
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    (void)notification;
    [self ensureWindowAndView];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
    GameLog("=== applicationWillTerminate ===");

    g_gameInitialized = false;
    [self.windowWatchdogTimer invalidate];
    self.windowWatchdogTimer = nil;
    [self.frameTimer invalidate];
    self.frameTimer = nil;

    GameLog("Shutting down network...");
    BSDNetLayer::Shutdown();

    GameLog("Shutting down UI...");
    // ui.shutdown();

    GameLog("Shutdown complete.");

    if (g_logFile) {
        fclose(g_logFile);
        g_logFile = nullptr;
    }
}

- (void)windowDidResize:(NSNotification*)notification
{
    // MTKView handles drawable resize via mtkView:drawableSizeDidChange:
}

- (void)windowDidBecomeKey:(NSNotification*)notification
{
    g_KBMInput.SetWindowFocused(true);
}

- (void)windowDidResignKey:(NSNotification*)notification
{
    g_KBMInput.SetWindowFocused(false);
}

- (void)windowWillClose:(NSNotification*)notification
{
    (void)notification;
    GameLog("Window will close");
    self.metalView.delegate = nil;
    self.metalView = nil;
    self.window = nil;
}

- (void)keyDown:(NSEvent*)event
{
    // Prevent beep on unhandled keys
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Custom NSWindow subclass for key/mouse event capture
// ══════════════════════════════════════════════════════════════════════════════

@implementation MinecraftWindow

- (BOOL)canBecomeKeyWindow  { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)keyDown:(NSEvent*)event
{
    int vk = MapMacKeyToVK(event.keyCode);
    if (vk == 0) return;

    // F11 toggles fullscreen
    if (vk == 0x7A) {
        ToggleFullscreen();
        return;
    }

    if (vk == 0x1B && g_gameInitialized && g_pMinecraft && app.GetGameStarted()) {
        if (ui.IsNativeWorldLaunchPending()) {
            GameLog("ESC ignored while Apple loading overlay is active");
            return;
        }
        if (ui.GetMenuDisplayed(ProfileManager.GetPrimaryPad()))
            ui.HideNativeMainMenu();
        else
            ui.ShowNativeMainMenu();
        return;
    }

    g_KBMInput.OnKeyDown(vk);

    // Forward typed characters for chat / text input
    NSString* chars = event.characters;
    if (chars.length > 0) {
        unichar ch = [chars characterAtIndex:0];
        if (ch >= 0x20 || ch == 0x08 || ch == 0x0D)
            g_KBMInput.OnChar((wchar_t)ch);
    }
}

- (void)keyUp:(NSEvent*)event
{
    int vk = MapMacKeyToVK(event.keyCode);
    if (vk == 0) return;
    g_KBMInput.OnKeyUp(vk);
}

- (void)flagsChanged:(NSEvent*)event
{
    // Handle modifier key state changes
}

- (void)mouseDown:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonDown(0); // MOUSE_LEFT
}

- (void)mouseUp:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonUp(0);
}

- (void)rightMouseDown:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonDown(1); // MOUSE_RIGHT
}

- (void)rightMouseUp:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonUp(1);
}

- (void)otherMouseDown:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonDown(2); // MOUSE_MIDDLE
}

- (void)otherMouseUp:(NSEvent*)event
{
    g_KBMInput.OnMouseButtonUp(2);
}

- (void)mouseMoved:(NSEvent*)event
{
    NSPoint loc = [event locationInWindow];
    g_KBMInput.OnMouseMove((int)loc.x, (int)(g_rScreenHeight - loc.y));
}

- (void)mouseDragged:(NSEvent*)event
{
    g_KBMInput.OnRawMouseDelta((int)event.deltaX, (int)event.deltaY);
}

- (void)rightMouseDragged:(NSEvent*)event
{
    g_KBMInput.OnRawMouseDelta((int)event.deltaX, (int)event.deltaY);
}

- (void)scrollWheel:(NSEvent*)event
{
    int delta = (int)(event.scrollingDeltaY * 120.0);
    g_KBMInput.OnMouseWheel(delta);
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - main()
// ══════════════════════════════════════════════════════════════════════════════

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSImage* appIcon = [NSImage imageNamed:@"AppIcon"];
        if (appIcon)
            [NSApp setApplicationIconImage:appIcon];

        g_appDelegate = [[MinecraftAppDelegate alloc] init];
        [NSApp setDelegate:g_appDelegate];

        // Minimal menu bar
        NSMenu* menuBar = [[NSMenu alloc] init];
        NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:appMenuItem];
        NSMenu* appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"Toggle Fullscreen"
                           action:@selector(toggleGameFullscreen:)
                    keyEquivalent:@"f"];
        [[appMenu itemAtIndex:0] setTarget:g_appDelegate];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Quit Minecraft LCE"
                           action:@selector(terminate:)
                    keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];
        [NSApp setMainMenu:menuBar];

        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
