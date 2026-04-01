// macOS_Minecraft.mm — macOS entry point for Minecraft Legacy Console Edition
// Cocoa + Metal application matching the Windows64_Minecraft.cpp game loop.

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CVDisplayLink.h>
#import <GameController/GameController.h>
#import <Carbon/Carbon.h>  // kVK_ key codes

#include <cstdio>
#include <cstring>
#include <string>
#include <pthread.h>

// ── Forward declarations for Minecraft engine types ──────────────────────────
// These match the same types the Windows64 entry point uses.

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

// ── Engine globals (defined in platform-agnostic code / libs) ────────────────

// RenderManager, InputManager, StorageManager, ProfileManager, etc. are
// global singletons declared in the 4J libraries. They are extern here so
// the linker resolves them from the static libs.
//
// On macOS we use Metal, so the Renderer back-end will be the Metal
// variant of C4JRender (4J_Render_Metal.a) rather than the D3D11 one.

// Screen resolution — auto-detected from the main display at startup.
static int g_iScreenWidth  = 1920;
static int g_iScreenHeight = 1080;
static int g_rScreenWidth  = 1920;
static int g_rScreenHeight = 1080;
static float g_iAspectRatio = 16.0f / 9.0f;

// Username — loaded from username.txt next to the bundle
static char    g_AppleUsername[17]  = { 0 };
static wchar_t g_AppleUsernameW[17] = { 0 };

// Fullscreen state
static bool g_isFullscreen = false;

// Metal objects
static id<MTLDevice>       g_mtlDevice       = nil;
static id<MTLCommandQueue> g_mtlCommandQueue = nil;

// ── KeyboardMouseInput (lightweight re-implementation for macOS) ─────────────
// Maps NSEvent key codes to the same virtual-key constants the Windows version
// uses, then feeds them into the same KeyboardMouseInput class.

#pragma mark - Key Code Mapping

// Convert macOS virtual key code (kVK_*) to a Windows-compatible VK code
// so the existing KeyboardMouseInput class works unmodified.
static int MapMacKeyToVK(unsigned short keyCode)
{
    switch (keyCode)
    {
        case kVK_ANSI_A: return 'A';
        case kVK_ANSI_B: return 'B';
        case kVK_ANSI_C: return 'C';
        case kVK_ANSI_D: return 'D';
        case kVK_ANSI_E: return 'E';
        case kVK_ANSI_F: return 'F';
        case kVK_ANSI_G: return 'G';
        case kVK_ANSI_H: return 'H';
        case kVK_ANSI_I: return 'I';
        case kVK_ANSI_J: return 'J';
        case kVK_ANSI_K: return 'K';
        case kVK_ANSI_L: return 'L';
        case kVK_ANSI_M: return 'M';
        case kVK_ANSI_N: return 'N';
        case kVK_ANSI_O: return 'O';
        case kVK_ANSI_P: return 'P';
        case kVK_ANSI_Q: return 'Q';
        case kVK_ANSI_R: return 'R';
        case kVK_ANSI_S: return 'S';
        case kVK_ANSI_T: return 'T';
        case kVK_ANSI_U: return 'U';
        case kVK_ANSI_V: return 'V';
        case kVK_ANSI_W: return 'W';
        case kVK_ANSI_X: return 'X';
        case kVK_ANSI_Y: return 'Y';
        case kVK_ANSI_Z: return 'Z';

        case kVK_ANSI_0: return '0';
        case kVK_ANSI_1: return '1';
        case kVK_ANSI_2: return '2';
        case kVK_ANSI_3: return '3';
        case kVK_ANSI_4: return '4';
        case kVK_ANSI_5: return '5';
        case kVK_ANSI_6: return '6';
        case kVK_ANSI_7: return '7';
        case kVK_ANSI_8: return '8';
        case kVK_ANSI_9: return '9';

        case kVK_Return:     return 0x0D; // VK_RETURN
        case kVK_Escape:     return 0x1B; // VK_ESCAPE
        case kVK_Delete:     return 0x08; // VK_BACK (backspace)
        case kVK_Tab:        return 0x09; // VK_TAB
        case kVK_Space:      return 0x20; // VK_SPACE

        case kVK_LeftArrow:  return 0x25; // VK_LEFT
        case kVK_UpArrow:    return 0x26; // VK_UP
        case kVK_RightArrow: return 0x27; // VK_RIGHT
        case kVK_DownArrow:  return 0x28; // VK_DOWN

        case kVK_Shift:      return 0xA0; // VK_LSHIFT
        case kVK_RightShift: return 0xA1; // VK_RSHIFT
        case kVK_Control:    return 0xA2; // VK_LCONTROL
        case kVK_RightControl: return 0xA3; // VK_RCONTROL
        case kVK_Option:     return 0xA4; // VK_LMENU (left alt)
        case kVK_RightOption:return 0xA5; // VK_RMENU (right alt)

        case kVK_F1:  return 0x70;
        case kVK_F2:  return 0x71;
        case kVK_F3:  return 0x72;
        case kVK_F4:  return 0x73;
        case kVK_F5:  return 0x74;
        case kVK_F6:  return 0x75;
        case kVK_F7:  return 0x76;
        case kVK_F8:  return 0x77;
        case kVK_F9:  return 0x78;
        case kVK_F10: return 0x79;
        case kVK_F11: return 0x7A;
        case kVK_F12: return 0x7B;

        default: return 0;
    }
}

// ── Application delegate ─────────────────────────────────────────────────────

@interface MinecraftAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (strong) NSWindow*  window;
@property (strong) MTKView*   metalView;
@end

// ── MTKView delegate — drives the game loop each frame ───────────────────────

@interface MinecraftRenderer : NSObject <MTKViewDelegate>
@property (assign) bool gameInitialised;
@end

// ── Globals for the delegates ────────────────────────────────────────────────

static MinecraftAppDelegate* g_appDelegate  = nil;
static MinecraftRenderer*    g_renderer     = nil;

// ── Helper: load username from username.txt beside the app bundle ────────────

static void LoadUsername()
{
    // Look for username.txt next to the .app bundle
    NSString* bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString* parentDir  = [bundlePath stringByDeletingLastPathComponent];
    NSString* userFile   = [parentDir stringByAppendingPathComponent:@"username.txt"];

    FILE* f = fopen([userFile UTF8String], "r");
    if (f)
    {
        char buf[128] = {};
        if (fgets(buf, sizeof(buf), f))
        {
            // Trim trailing whitespace and newlines
            int len = (int)strlen(buf);
            while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r' || buf[len - 1] == ' '))
                buf[--len] = '\0';

            if (len > 0)
                strncpy(g_AppleUsername, buf, sizeof(g_AppleUsername) - 1);
        }
        fclose(f);
    }

    // Fallback
    if (g_AppleUsername[0] == 0)
        strncpy(g_AppleUsername, "Player", sizeof(g_AppleUsername) - 1);

    // Convert to wide (simple ASCII-safe conversion)
    for (int i = 0; i < 17; i++)
        g_AppleUsernameW[i] = static_cast<wchar_t>(g_AppleUsername[i]);
}

// ── Helper: set working directory to Resources inside the .app bundle ────────

static void SetWorkingDirectoryToResources()
{
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    if (resourcePath)
        chdir([resourcePath UTF8String]);
}

// ── Helper: toggle borderless fullscreen ─────────────────────────────────────

static void ToggleFullscreen()
{
    NSWindow* window = g_appDelegate.window;
    if (!window) return;

    [window toggleFullScreen:nil];
    g_isFullscreen = !g_isFullscreen;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - MTKViewDelegate (game loop)
// ══════════════════════════════════════════════════════════════════════════════

@implementation MinecraftRenderer

- (nonnull instancetype)init
{
    self = [super init];
    if (self)
    {
        _gameInitialised = false;
    }
    return self;
}

// Called once per display refresh — this is the main game loop tick.
// Mirrors the MSG loop body from Windows64_Minecraft.cpp.
- (void)drawInMTKView:(nonnull MTKView*)view
{
    // TODO: Once the Metal Renderer back-end is integrated, the full
    // game loop goes here:
    //
    //   g_KBMInput.Tick();
    //   RenderManager.StartFrame();
    //   app.UpdateTime();
    //   InputManager.Tick();
    //   StorageManager.Tick();
    //   RenderManager.Tick();
    //   g_NetworkManager.DoWork();
    //
    //   if (app.GetGameStarted()) {
    //       pMinecraft->applyFrameMouseLook();
    //       pMinecraft->run_middle();
    //   } else {
    //       pMinecraft->soundEngine->tick(nullptr, 0.0f);
    //       pMinecraft->textures->tick(true, false);
    //       IntCache::Reset();
    //   }
    //
    //   pMinecraft->soundEngine->playMusicTick();
    //   ui.tick();
    //   ui.render();
    //   pMinecraft->gameRenderer->ApplyGammaPostProcess();
    //   RenderManager.Present();
    //   ui.CheckMenuDisplayed();

    // Placeholder: clear to dark blue (same as Win64 default)
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

// Called when the view resizes — update internal resolution tracking.
- (void)mtkView:(nonnull MTKView*)view drawableSizeDidChange:(CGSize)size
{
    g_rScreenWidth  = (int)size.width;
    g_rScreenHeight = (int)size.height;
    g_iAspectRatio  = (float)g_rScreenWidth / (float)g_rScreenHeight;

    NSLog(@"[macOS] Drawable size changed: %d x %d", g_rScreenWidth, g_rScreenHeight);

    // TODO: Resize Metal depth/stencil, update RenderManager, ui.updateScreenSize()
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - NSApplicationDelegate
// ══════════════════════════════════════════════════════════════════════════════

@implementation MinecraftAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    // ── Metal device ─────────────────────────────────────────────────────
    g_mtlDevice = MTLCreateSystemDefaultDevice();
    if (!g_mtlDevice)
    {
        NSLog(@"[macOS] FATAL: Metal is not supported on this Mac.");
        [NSApp terminate:nil];
        return;
    }
    g_mtlCommandQueue = [g_mtlDevice newCommandQueue];

    // ── Detect display resolution ────────────────────────────────────────
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect screenFrame   = [mainScreen frame];
    CGFloat backingScale = [mainScreen backingScaleFactor];
    g_rScreenWidth  = (int)(screenFrame.size.width  * backingScale);
    g_rScreenHeight = (int)(screenFrame.size.height * backingScale);
    g_iAspectRatio  = (float)g_rScreenWidth / (float)g_rScreenHeight;

    // ── Create window ────────────────────────────────────────────────────
    NSRect contentRect = NSMakeRect(0, 0, 1280, 720);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled
                                | NSWindowStyleMaskClosable
                                | NSWindowStyleMaskMiniaturizable
                                | NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:contentRect
                                              styleMask:styleMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Minecraft LCE"];
    [self.window center];
    [self.window setDelegate:self];
    [self.window setAcceptsMouseMovedEvents:YES];
    [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

    // ── MTKView ──────────────────────────────────────────────────────────
    self.metalView = [[MTKView alloc] initWithFrame:contentRect device:g_mtlDevice];
    self.metalView.colorPixelFormat      = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    g_renderer = [[MinecraftRenderer alloc] init];
    self.metalView.delegate = g_renderer;

    [self.window setContentView:self.metalView];
    [self.window makeKeyAndOrderFront:nil];

    // ── Load username and set working directory ──────────────────────────
    LoadUsername();
    SetWorkingDirectoryToResources();

    NSLog(@"[macOS] Minecraft LCE starting — user: %s, display: %dx%d",
          g_AppleUsername, g_rScreenWidth, g_rScreenHeight);

    // ── Game initialisation ──────────────────────────────────────────────
    // TODO: Call the same initialisation sequence as Windows:
    //
    //   app.loadMediaArchive();
    //   RenderManager.Initialise(g_mtlDevice, ...);
    //   app.loadStringTable();
    //   ui.init(...);
    //   InputManager.Initialise(1, 3, MINECRAFT_ACTION_MAX, ACTION_MAX_MENU);
    //   g_KBMInput.Init();
    //   DefineActions();
    //   ProfileManager.Initialise(...);
    //   g_NetworkManager.Initialise();
    //   BSDNetLayer::Initialize();
    //   Tesselator::CreateNewThreadStorage(1024 * 1024);
    //   ... (same as InitialiseMinecraftRuntime)
    //   Minecraft::main();
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
    NSLog(@"[macOS] Shutting down...");
    // TODO: BSDNetLayer::Shutdown();
    // TODO: ui.shutdown();
    // TODO: CleanupDevice();
}

// ── Window delegate — resize handling ────────────────────────────────────────

- (void)windowDidResize:(NSNotification*)notification
{
    // MTKView handles drawable resize automatically via mtkView:drawableSizeDidChange:
}

// ── Keyboard events ──────────────────────────────────────────────────────────

- (void)keyDown:(NSEvent*)event
{
    // Prevent beep on unhandled keys
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Custom NSWindow subclass for key/mouse event capture
// ══════════════════════════════════════════════════════════════════════════════

@interface MinecraftWindow : NSWindow
@end

@implementation MinecraftWindow

- (BOOL)canBecomeKeyWindow  { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)keyDown:(NSEvent*)event
{
    int vk = MapMacKeyToVK(event.keyCode);
    if (vk == 0) return;

    // F11 toggles fullscreen
    if (vk == 0x7A) // VK_F11
    {
        ToggleFullscreen();
        return;
    }

    // TODO: g_KBMInput.OnKeyDown(vk);

    // Forward typed characters for chat / text input
    NSString* chars = event.characters;
    if (chars.length > 0)
    {
        unichar ch = [chars characterAtIndex:0];
        if (ch >= 0x20 || ch == 0x08 || ch == 0x0D)
        {
            // TODO: g_KBMInput.OnChar((wchar_t)ch);
        }
    }
}

- (void)keyUp:(NSEvent*)event
{
    int vk = MapMacKeyToVK(event.keyCode);
    if (vk == 0) return;
    // TODO: g_KBMInput.OnKeyUp(vk);
}

- (void)flagsChanged:(NSEvent*)event
{
    // Handle modifier key presses (shift, control, option/alt)
    // TODO: Map modifier flags to OnKeyDown/OnKeyUp calls
}

- (void)mouseDown:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_LEFT);
}

- (void)mouseUp:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_LEFT);
}

- (void)rightMouseDown:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_RIGHT);
}

- (void)rightMouseUp:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_RIGHT);
}

- (void)otherMouseDown:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_MIDDLE);
}

- (void)otherMouseUp:(NSEvent*)event
{
    // TODO: g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_MIDDLE);
}

- (void)mouseMoved:(NSEvent*)event
{
    NSPoint loc = [event locationInWindow];
    // TODO: g_KBMInput.OnMouseMove((int)loc.x, (int)(g_rScreenHeight - loc.y));
}

- (void)mouseDragged:(NSEvent*)event
{
    // Raw delta for mouse look when grabbed
    // TODO: g_KBMInput.OnRawMouseDelta((int)event.deltaX, (int)event.deltaY);
}

- (void)rightMouseDragged:(NSEvent*)event
{
    // TODO: g_KBMInput.OnRawMouseDelta((int)event.deltaX, (int)event.deltaY);
}

- (void)scrollWheel:(NSEvent*)event
{
    int delta = (int)(event.scrollingDeltaY * 120.0);
    // TODO: g_KBMInput.OnMouseWheel(delta);
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - main()
// ══════════════════════════════════════════════════════════════════════════════

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        // Create the NSApplication
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        // Set up app icon (loaded from bundle resources)
        NSImage* appIcon = [NSImage imageNamed:@"AppIcon"];
        if (appIcon)
            [NSApp setApplicationIconImage:appIcon];

        // Create and assign the delegate
        g_appDelegate = [[MinecraftAppDelegate alloc] init];
        [NSApp setDelegate:g_appDelegate];

        // Build a minimal menu bar (so Cmd-Q works, etc.)
        NSMenu* menuBar = [[NSMenu alloc] init];
        NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:appMenuItem];
        NSMenu* appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"Toggle Fullscreen"
                           action:@selector(toggleFullScreen:)
                    keyEquivalent:@"f"];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Quit Minecraft LCE"
                           action:@selector(terminate:)
                    keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];
        [NSApp setMainMenu:menuBar];

        // Activate and run
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
