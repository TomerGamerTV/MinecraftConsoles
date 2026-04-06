# Minecraft Legacy Console Edition - Apple/macOS Port Task List

## Mission
Port Minecraft Legacy Console Edition (TU19, originally Xbox 360/PS3/PS4/Vita/Windows) to macOS and iOS using Metal for rendering. The game should compile, link, run, and render the full Minecraft experience on Apple Silicon Macs.

---

## Phase 1: Compilation (COMPLETE)
All source files compile for macOS ARM64.

### What was done:
- [x] Created `Apple/AppleTypes.h` (~1100 lines) - Windows API compatibility layer (types, File I/O, threading, events, VirtualAlloc, atomics, string functions)
- [x] Added `#elif defined _APPLE_PLATFORM` branches throughout C4JThread.cpp (pthread-based threading)
- [x] Created Apple stubs for: 4J_Profile, 4J_Input, 4J_Storage, 4J_Render, SentientManager, SocialManager, ATGXmlParser, LeaderboardManager
- [x] Fixed `byte` ambiguity (std::byte vs game's byte) with `#define byte unsigned char`
- [x] Fixed BOOL type: `typedef bool BOOL` on Apple to match ObjC runtime
- [x] Fixed `Component` name collision with CarbonCore using `#define Component CarbonComponent_Renamed`
- [x] Fixed `min`/`max` macros disabled in ObjC++ to avoid breaking Metal headers
- [x] Fixed `using namespace std` causing `bind()` to shadow POSIX `bind()` in BSDNetLayer
- [x] Added all telemetry enums (MinecraftTelemetry.h, SentientTelemetryCommon.h - copied from Orbis)
- [x] Added full game config (Minecraft.spa.h - copied from Orbis)
- [x] Fixed merge conflict markers in DebugSetCamera.cpp and LevelData.cpp
- [x] Fixed backslash include paths in Xbox headers
- [x] Fixed `xhash` → `<functional>` for Hasher.cpp
- [x] Fixed zlib missing `<unistd.h>` on non-Windows
- [x] Fixed SoundEngine.cpp: `byte` macro push/pop around miniaudio/stb_vorbis, Apple sound paths
- [x] Added UIScene methods for Apple (GetParentLayer, SetFocusToElement, handleMouseClick, direct edit)
- [x] Added UIControl_TextInput direct edit members for Apple
- [x] Created PostProcesser.h with `#ifndef _APPLE_PLATFORM` guards around D3D11 members
- [x] Fixed DLC system: Apple RegisterDLCData stub, dlcFilenames for Apple, null archive safety
- [x] Fixed `static_cast<LPVOID>(false)` → `(LPVOID)(intptr_t)(false)`
- [x] Guarded SoundEngine.cpp `Windows64_App.h` include with `#ifdef _WINDOWS64`
- [x] Fixed platform index in UIScene_Intro.cpp
- [x] Fixed `ConsoleUIController` → `Apple_UIController` in UI.h, Minecraft.cpp, LocalPlayer.cpp
- [x] Created `Apple/Leaderboards/AppleLeaderboardManager.h`
- [x] Created `Apple/Extras/ShutdownManager.h` (inline stubs)
- [x] Added `#include "stdafx.h"` to all Apple .mm files
- [x] Added `#define Component CarbonComponent_Renamed` before ObjC framework imports in all .mm files
- [x] Added `__forceinline` → `__attribute__((always_inline)) inline`
- [x] Added secure string functions: `swscanf_s`, `_vsnprintf_s`, `_TRUNCATE`, `sprintf_s` array overload
- [x] Added `ULARGE_INTEGER`, `GUID`, `DWORD_PTR`, `INT_PTR`, `UINT_PTR`, `PCWSTR`
- [x] Added `_wfopen_s`, `CreateFileW`, `SetFilePointerEx`, `FlushFileBuffers`
- [x] Added `ERROR_CANCELLED`, `ERROR_IO_PENDING`, `ERROR_FILE_NOT_FOUND`, etc.
- [x] Added `XMARKETPLACE_OFFERING_TYPE_*` constants
- [x] Added VK_F1-F15 key constants

## Phase 2: Linking (COMPLETE)
All symbols resolve. Binary links successfully.

### What was done:
- [x] Created `Apple/Apple_App.cpp` with CConsoleMinecraftApp stubs + global `app` instance
- [x] Created `Apple/Extras/AppleODRDefs.cpp` - Out-of-line definitions for 150+ `static const` members (Item::*_Id, Tile::*_Id, AnimatePacket::*, ContainerOpenPacket::*, etc.)
- [x] Created `Apple/Extras/AppleMouseStub.cpp` - Mouse::getX/getY stubs
- [x] Created `Minecraft.World/AppleLevelHelper.cpp` - wrappers for Level/Tile/OldChunkStorage static methods
- [x] Added global variables: `g_Win64UsernameW`, `g_iScreenWidth/Height`, `g_rScreenWidth/Height`
- [x] Added stubs: `DefineActions()`, `MemSect()`, `Minecraft::applyFrameMouseLook()`
- [x] Added `CMinecraftApp::GetTPConfigVal()` stub
- [x] Added `PostProcesser` full method stubs (D3D11 post-processing no-op on Metal)
- [x] Added `NetworkPlayerXbox` full virtual method stubs
- [x] Added `UIScene::handleMouseClick/isDirectEditBlocking/SetFocusToElement` implementations
- [x] Added `LeaderboardManager::m_instance` static definition
- [x] Disabled LTO (`-flto`) to avoid static const ODR issues
- [x] Disabled code signing (`CODE_SIGNING_ALLOWED=NO`)

## Phase 3: Runtime Initialization (IN PROGRESS)
Game launches and initializes subsystems.

### What was done:
- [x] Rewrote `macOS/macOS_Minecraft.mm` with full game init sequence (14 steps matching Windows64)
- [x] Added runtime logging system (`minecraft_runtime.log` + stderr redirect)
- [x] Added signal handlers for SIGSEGV/SIGABRT during init
- [x] Set working directory to Contents/MacOS/ (where assets live)
- [x] Added null-safety for `m_mediaArchive` in loadStringTable, getArchiveFile, hasArchiveFile, getArchiveFileSize
- [x] Added Apple case in loadMediaArchive (Common/Media/MediaWindows64.arc)
- [x] Thread storage initialization via AppleInitThreadStorage wrapper
- [x] Added fprintf(stderr) debug logging in Minecraft::main() and MinecraftWorld_RunStaticCtors
- [x] Redirected stderr to runtime log file via dup2()
- [x] Fixed Metal shader library loading (search Contents/MacOS/default.metallib)
- [x] Added zero-dimension validation in TextureData() to prevent Metal assertion
- [x] Added backslash→forward slash conversion in CreateFileA, GetFileAttributesA, fopen_s, LoadTextureData

### Current crash:
- All 14 init steps pass through step 10
- `Minecraft::main()` → `MinecraftWorld_RunStaticCtors()` runs all static constructors OK
- Then game proceeds to `Minecraft::start()` → `Minecraft::init()` which creates textures
- Crashes when loading `Common\res\1_2_2\misc\pumpkinblur.png` with zero dimensions
- Root cause: texture files exist with backslash paths, need forward slash conversion (BEING FIXED)
- Also: Metal shader library wasn't loading (BEING FIXED)

### What still needs to happen:
- [ ] Fix all remaining Windows backslash paths throughout the codebase (file I/O, texture loading, archive paths)
- [ ] Get past Minecraft::init() without crashing
- [ ] Verify game loop runs (StartFrame → tick → render → Present)
- [ ] Verify Metal renderer draws something (not just blue screen)

## Phase 4: Media Archive & Assets (NOT STARTED)
The main game media archive (`MediaWindows64.arc`) is missing.

### What needs to happen:
- [ ] Determine if MediaWindows64.arc needs to be built from loose files (using a build tool)
- [ ] OR modify the game to load assets from loose filesystem files instead of .arc archives
- [ ] Ensure `languages.loc` (string table) is available - game currently runs without it
- [ ] Verify all texture paths resolve correctly with forward slashes
- [ ] Ensure font files load (Common/Media/font/)
- [ ] Ensure sound files load (Windows64Media/Sound/)

## Phase 5: Rendering (NOT STARTED)
Metal renderer exists but needs real-world testing.

### What exists:
- `Apple/Metal/MetalRenderer.mm` (2200+ lines) - Full C4JRender implementation
- `Apple/Metal/MetalShaders.metal` (409 lines) - 4 vertex + 4 fragment shaders
- Supports: matrix stacks, texture management, lighting, fog, alpha test, blend modes, split-screen viewports, command buffers, texture coordinate generation

### What needs to happen:
- [ ] Fix Metal shader library loading path
- [ ] Verify DrawVertices correctly renders triangles/quads
- [ ] Test texture loading and binding (PNG/JPEG via CoreImage)
- [ ] Test depth buffer and stencil operations
- [ ] Verify matrix math (perspective projection, modelview transforms)
- [ ] Test fog rendering
- [ ] Test lighting (2 directional lights + ambient)
- [ ] Test alpha testing and blending
- [ ] Test split-screen viewport modes
- [ ] Implement screen capture (CaptureThumbnail, CaptureScreen - currently TODO)
- [ ] Test command buffer record/replay

## Phase 6: Iggy Flash UI (NOT STARTED)
The game uses Iggy (RAD Game Tools) for Flash-based UI. Currently fully stubbed.

### What needs to happen:
- [ ] Either implement a Flash/SWF renderer for Metal, OR
- [ ] Port the UI to a custom system (e.g., native UIKit/AppKit controls), OR
- [ ] Find a compatible Iggy library for Apple, OR
- [ ] Implement a minimal SWF interpreter for the game's UI .swf files
- [ ] Without this, menus/HUD/inventory screens won't display

## Phase 7: Audio (PARTIALLY DONE)
MiniAudio library is integrated. Sound engine compiles.

### What needs to happen:
- [ ] Verify miniaudio CoreAudio backend works on macOS
- [ ] Test sound effect playback (WAV files)
- [ ] Test music streaming (OGG via stb_vorbis)
- [ ] Verify 3D positional audio
- [ ] Test CD/music disc playback

## Phase 8: Input (PARTIALLY DONE)
GameController framework and keyboard/mouse input framework exist.

### What needs to happen:
- [ ] Wire up keyboard/mouse events (currently connected but `DefineActions()` is empty)
- [ ] Implement `DefineActions()` - map gamepad buttons to MINECRAFT_ACTION_* enums
- [ ] Test GameController framework with MFi/Xbox/DualSense controllers
- [ ] Implement `Minecraft::applyFrameMouseLook()` for mouse-look camera control
- [ ] Implement Mouse::getX/getY with actual cursor position
- [ ] Test keyboard input for chat/signs

## Phase 9: Networking (PARTIALLY DONE)
BSDNetLayer with POSIX sockets exists.

### What needs to happen:
- [ ] Set up IQNet player slots (currently skipped)
- [ ] Test LAN discovery (UDP broadcast)
- [ ] Test TCP client/server connections
- [ ] Test multiplayer gameplay
- [ ] Handle NAT traversal or document requirements

## Phase 10: Save/Load (PARTIALLY DONE)
AppleStorage.mm and lce_filesystem exist.

### What needs to happen:
- [ ] Test world save/load
- [ ] Verify save file format compatibility with Windows64 saves
- [ ] Test profile settings persistence
- [ ] Set up proper save directory (~/Library/Application Support/MinecraftLCE/)

## Phase 11: DLC System (STUBBED)
RegisterDLCData is a no-op. DLC .arc files exist.

### What needs to happen:
- [ ] Implement DLC scanning from filesystem
- [ ] Test texture pack loading from DLC archives
- [ ] Test skin pack loading
- [ ] Test mash-up pack loading

## Phase 12: Polish & Distribution (NOT STARTED)
### What needs to happen:
- [ ] App icon
- [ ] Proper Info.plist metadata
- [ ] Code signing for distribution
- [ ] Debug build support
- [ ] iOS port (separate from macOS but shares most code)
- [ ] Performance optimization
- [ ] Memory profiling
- [ ] Crash reporting integration

---

## Build System Notes
- CMake 3.24+ with Xcode generator
- Build command: `./build_macos.sh release arm64`
- Auto-build: `./build_watcher.sh` on build machine watches for trigger file
- Error log: `build/macos-arm64/build_errors.log`
- Runtime log: `minecraft_runtime.log` next to .app bundle
- LTO disabled (causes ODR issues with 170+ static const members)
- Code signing disabled for development

## Key Files
| File | Purpose |
|------|---------|
| `Apple/AppleTypes.h` | Windows API compatibility (~1100 lines) |
| `Apple/Apple_App.cpp` | App instance, stubs, global variables |
| `Apple/Metal/MetalRenderer.mm` | Full Metal C4JRender implementation |
| `Apple/Metal/MetalShaders.metal` | GPU shaders |
| `macOS/macOS_Minecraft.mm` | macOS entry point, game loop |
| `Apple/Extras/AppleODRDefs.cpp` | Static const ODR definitions |
| `Apple/Extras/ShutdownManager.h` | Stub shutdown manager |
| `Minecraft.World/AppleLevelHelper.cpp` | Wrappers for complex headers |
