// iOS_Minecraft.mm — iOS entry point for Minecraft Legacy Console Edition
// UIKit + Metal application matching the Windows64_Minecraft.cpp game loop.

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <GameController/GameController.h>

#include <cstdio>
#include <cstring>
#include <string>
#include <pthread.h>

// ── Forward declarations for Minecraft engine types ──────────────────────────

class Minecraft;
class MinecraftServer;
class ChatScreen;
class Tesselator;
class Level;
class Tile;
class Compression;
class OldChunkStorage;
class IntCache;
class AABB;
class Vec3;

// ── Screen resolution ────────────────────────────────────────────────────────

static int g_iScreenWidth  = 1920;
static int g_iScreenHeight = 1080;
static int g_rScreenWidth  = 1920;
static int g_rScreenHeight = 1080;
static float g_iAspectRatio = 16.0f / 9.0f;

// Username
static char    g_AppleUsername[17]  = { 0 };
static wchar_t g_AppleUsernameW[17] = { 0 };

// Metal objects
static id<MTLDevice>       g_mtlDevice       = nil;
static id<MTLCommandQueue> g_mtlCommandQueue = nil;

// Safe area insets (updated every layout pass for Dynamic Island / notch)
static float g_safeAreaTop    = 0.0f;
static float g_safeAreaBottom = 0.0f;
static float g_safeAreaLeft   = 0.0f;
static float g_safeAreaRight  = 0.0f;

// Controller tracking
static bool g_controllerConnected = false;

// ── Forward-declare the touch overlay (TouchInput.h) ─────────────────────────
#import "TouchInput.h"

// ── Helper: load username ────────────────────────────────────────────────────

static void LoadUsername()
{
    // On iOS the Documents directory is writable; look for username.txt there
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir  = [paths firstObject];
    NSString* userFile = [docsDir stringByAppendingPathComponent:@"username.txt"];

    FILE* f = fopen([userFile UTF8String], "r");
    if (f)
    {
        char buf[128] = {};
        if (fgets(buf, sizeof(buf), f))
        {
            int len = (int)strlen(buf);
            while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r' || buf[len - 1] == ' '))
                buf[--len] = '\0';
            if (len > 0)
                strncpy(g_AppleUsername, buf, sizeof(g_AppleUsername) - 1);
        }
        fclose(f);
    }

    if (g_AppleUsername[0] == 0)
        strncpy(g_AppleUsername, "Player", sizeof(g_AppleUsername) - 1);

    for (int i = 0; i < 17; i++)
        g_AppleUsernameW[i] = static_cast<wchar_t>(g_AppleUsername[i]);
}

// ── Helper: set working directory to app bundle Resources ────────────────────

static void SetWorkingDirectoryToResources()
{
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    if (resourcePath)
        chdir([resourcePath UTF8String]);
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - MTKViewDelegate (game loop)
// ══════════════════════════════════════════════════════════════════════════════

@interface MinecraftRenderer : NSObject <MTKViewDelegate>
@property (assign) bool gameInitialised;
@end

@implementation MinecraftRenderer

- (nonnull instancetype)init
{
    self = [super init];
    if (self) _gameInitialised = false;
    return self;
}

// Called once per display refresh — main game loop tick.
- (void)drawInMTKView:(nonnull MTKView*)view
{
    // TODO: Full game loop (same as macOS / Windows):
    //
    //   InputManager.Tick();
    //   RenderManager.StartFrame();
    //   app.UpdateTime();
    //   StorageManager.Tick();
    //   RenderManager.Tick();
    //   g_NetworkManager.DoWork();
    //   if (app.GetGameStarted()) { pMinecraft->run_middle(); ... }
    //   ui.tick(); ui.render();
    //   RenderManager.Present();

    // Placeholder: clear to dark blue
    @autoreleasepool
    {
        id<MTLCommandBuffer> commandBuffer = [g_mtlCommandQueue commandBuffer];
        MTLRenderPassDescriptor* passDesc  = view.currentRenderPassDescriptor;
        if (passDesc)
        {
            passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.125, 0.3, 1.0);
            passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
            id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
            [encoder endEncoding];
        }
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

- (void)mtkView:(nonnull MTKView*)view drawableSizeDidChange:(CGSize)size
{
    g_rScreenWidth  = (int)size.width;
    g_rScreenHeight = (int)size.height;
    g_iAspectRatio  = (float)g_rScreenWidth / (float)g_rScreenHeight;

    NSLog(@"[iOS] Drawable size changed: %d x %d", g_rScreenWidth, g_rScreenHeight);
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - ViewController
// ══════════════════════════════════════════════════════════════════════════════

@interface MinecraftViewController : UIViewController
@property (strong, nonatomic) MTKView*            metalView;
@property (strong, nonatomic) MinecraftRenderer*  renderer;
@property (strong, nonatomic) TouchInputOverlay*  touchOverlay;
@end

@implementation MinecraftViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // ── Metal device ─────────────────────────────────────────────────────
    g_mtlDevice = MTLCreateSystemDefaultDevice();
    if (!g_mtlDevice)
    {
        NSLog(@"[iOS] FATAL: Metal is not supported on this device.");
        return;
    }
    g_mtlCommandQueue = [g_mtlDevice newCommandQueue];

    // ── MTKView ──────────────────────────────────────────────────────────
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:g_mtlDevice];
    self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.metalView.colorPixelFormat      = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    self.renderer = [[MinecraftRenderer alloc] init];
    self.metalView.delegate = self.renderer;

    [self.view addSubview:self.metalView];

    // ── Touch overlay (virtual joystick + buttons) ───────────────────────
    self.touchOverlay = [[TouchInputOverlay alloc] initWithFrame:self.view.bounds];
    self.touchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.touchOverlay];

    // ── Controller connection monitoring ─────────────────────────────────
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil];

    // Check if a controller is already connected
    if ([GCController controllers].count > 0)
        [self setupController:[GCController controllers].firstObject];

    // ── GCKeyboard / GCMouse support (iPadOS 14.0+) ─────────────────────
    if (@available(iOS 14.0, *))
    {
        if (GCKeyboard.coalescedKeyboard)
            [self setupKeyboard:GCKeyboard.coalescedKeyboard];

        if (GCMouse.current)
            [self setupMouse:GCMouse.current];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardConnected:)
                                                     name:GCKeyboardDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mouseConnected:)
                                                     name:GCMouseDidConnectNotification
                                                   object:nil];
    }

    // ── Load username and set working directory ──────────────────────────
    LoadUsername();
    SetWorkingDirectoryToResources();

    NSLog(@"[iOS] Minecraft LCE starting — user: %s", g_AppleUsername);

    // ── Game initialisation ──────────────────────────────────────────────
    // TODO: Same initialisation as macOS/Windows:
    //   app.loadMediaArchive();
    //   RenderManager.Initialise(g_mtlDevice);
    //   ... (see macOS_Minecraft.mm)
}

// ── Safe area handling (Dynamic Island, notch) ───────────────────────────────

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];

    UIEdgeInsets insets = self.view.safeAreaInsets;
    g_safeAreaTop    = (float)insets.top;
    g_safeAreaBottom = (float)insets.bottom;
    g_safeAreaLeft   = (float)insets.left;
    g_safeAreaRight  = (float)insets.right;

    NSLog(@"[iOS] Safe area insets: top=%.0f bottom=%.0f left=%.0f right=%.0f",
          g_safeAreaTop, g_safeAreaBottom, g_safeAreaLeft, g_safeAreaRight);

    // Update touch overlay safe margins
    [self.touchOverlay updateSafeAreaInsets:insets];
}

// ── Orientation lock (landscape only) ────────────────────────────────────────

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate { return YES; }

// Hide the home indicator for immersive gameplay
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (BOOL)prefersStatusBarHidden { return YES; }

// ── GameController callbacks ─────────────────────────────────────────────────

- (void)controllerConnected:(NSNotification*)notification
{
    GCController* controller = notification.object;
    [self setupController:controller];
    g_controllerConnected = true;

    // Hide touch controls when a controller is connected
    self.touchOverlay.hidden = YES;
    NSLog(@"[iOS] Controller connected: %@", controller.vendorName);
}

- (void)controllerDisconnected:(NSNotification*)notification
{
    g_controllerConnected = false;

    // Show touch controls again when controller is disconnected
    self.touchOverlay.hidden = NO;
    NSLog(@"[iOS] Controller disconnected");
}

- (void)setupController:(GCController*)controller
{
    GCExtendedGamepad* gamepad = controller.extendedGamepad;
    if (!gamepad) return;

    // The 4J InputManager reads controller state via polling each frame
    // through C4JInput. On iOS we set up value-changed handlers that
    // feed into the same system.

    // Left thumbstick -> movement
    gamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* _Nonnull dpad, float xValue, float yValue) {
        // TODO: Feed into InputManager via C4JInput joypad API
    };

    // Right thumbstick -> camera look
    gamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* _Nonnull dpad, float xValue, float yValue) {
        // TODO: Feed into InputManager
    };

    // Buttons
    gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Jump
    };
    gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Drop / Cancel
    };
    gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Crafting
    };
    gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Inventory
    };
    gamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Use / Place
    };
    gamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Attack / Mine
    };
    gamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Left scroll
    };
    gamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Right scroll
    };
    gamepad.buttonMenu.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: Pause menu
    };
}

// ── GCKeyboard support ───────────────────────────────────────────────────────

- (void)keyboardConnected:(NSNotification*)notification API_AVAILABLE(ios(14.0))
{
    GCKeyboard* keyboard = notification.object;
    [self setupKeyboard:keyboard];
}

- (void)setupKeyboard:(GCKeyboard*)keyboard API_AVAILABLE(ios(14.0))
{
    keyboard.keyboardInput.keyChangedHandler = ^(GCKeyboardInput* _Nonnull kbInput,
                                                  GCControllerButtonInput* _Nonnull key,
                                                  GCKeyCode keyCode,
                                                  BOOL pressed) {
        // TODO: Map GCKeyCode to VK code and call g_KBMInput.OnKeyDown/OnKeyUp
    };
}

// ── GCMouse support ──────────────────────────────────────────────────────────

- (void)mouseConnected:(NSNotification*)notification API_AVAILABLE(ios(14.0))
{
    GCMouse* mouse = notification.object;
    [self setupMouse:mouse];
}

- (void)setupMouse:(GCMouse*)mouse API_AVAILABLE(ios(14.0))
{
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput* _Nonnull mouseInput, float deltaX, float deltaY) {
        // TODO: g_KBMInput.OnRawMouseDelta((int)deltaX, (int)deltaY);
    };

    mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: g_KBMInput.OnMouseButtonDown/Up(MOUSE_LEFT)
    };

    mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
        // TODO: g_KBMInput.OnMouseButtonDown/Up(MOUSE_RIGHT)
    };

    if (mouse.mouseInput.middleButton)
    {
        mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput* _Nonnull button, float value, BOOL pressed) {
            // TODO: g_KBMInput.OnMouseButtonDown/Up(MOUSE_MIDDLE)
        };
    }

    mouse.mouseInput.scroll.valueChangedHandler = ^(GCControllerDirectionPad* _Nonnull dpad, float xValue, float yValue) {
        // TODO: g_KBMInput.OnMouseWheel((int)(yValue * 120.0f));
    };
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - UIApplicationDelegate
// ══════════════════════════════════════════════════════════════════════════════

@interface MinecraftAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow* window;
@end

@implementation MinecraftAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[MinecraftViewController alloc] init];
    self.window.backgroundColor    = [UIColor blackColor];
    [self.window makeKeyAndVisible];

    return YES;
}

// ── UIKit lifecycle — background / foreground transitions ────────────────────

- (void)applicationWillResignActive:(UIApplication*)application
{
    // Going to background — pause the game loop
    NSLog(@"[iOS] App will resign active — pausing game");
    // TODO: app.SetAppPaused(true);
    // TODO: Pause Metal rendering (metalView.isPaused = YES)
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
    // Returning to foreground — resume
    NSLog(@"[iOS] App did become active — resuming game");
    // TODO: app.SetAppPaused(false);
    // TODO: Resume Metal rendering (metalView.isPaused = NO)
}

- (void)applicationDidEnterBackground:(UIApplication*)application
{
    NSLog(@"[iOS] App entered background");
    // TODO: Save game state, flush network
}

- (void)applicationWillTerminate:(UIApplication*)application
{
    NSLog(@"[iOS] App will terminate — shutting down");
    // TODO: BSDNetLayer::Shutdown();
    // TODO: ui.shutdown();
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - main()
// ══════════════════════════════════════════════════════════════════════════════

int main(int argc, char* argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([MinecraftAppDelegate class]));
    }
}
