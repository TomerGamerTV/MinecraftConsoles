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

## Phase 3: Runtime Initialization (MOSTLY COMPLETE)
Game launches, initializes, enters gameplay, and runs for extended periods on macOS.

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
- [x] Fixed frame pump on macOS so rendering advances reliably instead of stalling on blank pink/blue output
- [x] Fixed zero-size drawable handling in Metal start-of-frame
- [x] Fixed Apple UI no-op crash path around tooltip/HUD calls
- [x] Added control-file polling in `minecraft_control.txt`
  - `status`
  - `dump`
  - `menu`
  - `start`
  - `key ...`
  - `text ...`
  - `mouse move ...`
  - `mouse click ...`
  - `quit`
  - `fullscreen`
  - `windowed`
- [x] Added reliable internal drawable capture dumps
  - startup snapshots: `/tmp/mc_internal_360.png`, `/tmp/mc_internal_600.png`, `/tmp/mc_internal_840.png`
  - on-demand snapshot via control command: `/tmp/mc_control_dump.png`
- [x] Fixed one confirmed Metal object leak in dynamic depth/stencil state creation
- [x] Verified app can stay alive for long runs with audio active and no immediate startup crash
- [x] Stopped bypassing frontend startup with unconditional world auto-start
- [x] Startup now waits at an Apple-side main menu path before launching a world
- [x] Verified startup can stay in frontend/menu mode until a manual start request is made
- [x] Verified world launch can be triggered from the new Apple frontend path
- [x] Fixed Apple world-entry crash caused by fullscreen autosave/timer helper calls dereferencing missing Apple UI state
- [x] Added Apple fallback loading overlay state so frontend stays visible until gameplay is actually ready
- [x] Verified world startup now survives past the first `run_middle()` frame and stays alive in gameplay for over 60 seconds

### What still needs to happen:
- [ ] Keep control-file support and internal dumps working while debugging further rendering issues
- [ ] Continue shutting the app down automatically/manually when it is clearly stuck for too long
- [ ] Add a few more useful control commands if needed for unattended debugging
  - likely candidates: forced screenshot, pause/unpause, simple camera nudges, maybe scripted key hold/release

## Phase 4: Media Archive & Assets (NOT STARTED)
The main game media archive (`MediaWindows64.arc`) is missing.

### What needs to happen:
- [ ] Determine if MediaWindows64.arc needs to be built from loose files (using a build tool)
- [ ] OR modify the game to load assets from loose filesystem files instead of .arc archives
- [ ] Ensure `languages.loc` (string table) is available - game currently runs without it
- [ ] Verify all texture paths resolve correctly with forward slashes
- [ ] Ensure font files load (Common/Media/font/)
- [ ] Ensure sound files load (Windows64Media/Sound/)

## Phase 5: Rendering (IN PROGRESS)
Metal renderer is running real frames, but final visuals are still wrong.

### What exists:
- `Apple/Metal/MetalRenderer.mm` (2200+ lines) - Full C4JRender implementation
- `Apple/Metal/MetalShaders.metal` (409 lines) - 4 vertex + 4 fragment shaders
- Supports: matrix stacks, texture management, lighting, fog, alpha test, blend modes, split-screen viewports, command buffers, texture coordinate generation

### What needs to happen:
- [x] Fixed shader library loading path
- [x] Verified renderer now submits and presents real frames
- [x] Verified DrawVertices path is active with stable frame stats in runtime log
- [x] Fixed startup blank-output frame-loop issue
- [x] Fixed zero-size drawable abort path
- [x] Fixed one display-list/matrix playback bug that broke live camera transforms
- [x] Fixed vertex sampler/light sampler state mix-up
- [x] Fixed face culling winding bug
- [x] Fixed Apple texture loader ARGB / un-premultiply issues enough to move past the earliest corrupted atlas state
- [x] Added internal framebuffer dump support for reliable verification
- [x] Proved geometry is being rendered using internal Metal captures
- [x] Forced Apple chunk rebuilds onto standard vertices instead of the broken compact chunk format
  - runtime log now shows `compressed=0`
  - this removed a major source of broken packed-quad terrain rendering on Apple
- [x] Confirmed base-texture debug output now forms coherent world/room geometry instead of random stripe garbage

### Current rendering state:
- Game no longer shows only pink/blue/black startup screens
- Audio works
- Geometry is present
- Standard chunk path is active on macOS
- Remaining image is still incorrect in normal shading
- Current strongest blocker is texture/shading correctness, especially mip/lighting/final texture state

### Current rendering blockers:
- [ ] Final shaded output is still far too dark / wrong-coloured
- [ ] Terrain/world is still sampling visually incorrect texture content in normal mode
- [ ] Texture state on Apple still needs cleanup
  - sampler / mip behaviour
  - terrain atlas identity / upload correctness
  - light texture interaction
- [ ] Remove temporary shader debug hacks after fixing root cause
  - `DEBUG_DISABLE_LIGHT_TEXTURE`
  - forced `level(0.0)` sampling
  - any other temporary debug toggles left in `MetalShaders.metal`
- [ ] Validate whether mip generation / mip upload is corrupting terrain textures
- [ ] Validate whether terrain atlas binding is wrong versus atlas contents themselves being wrong
- [ ] Re-check command buffer replay once final texture state is corrected
- [ ] Implement proper screen capture API (`CaptureThumbnail`, `CaptureScreen`) instead of only debug dump helpers

## Phase 6: Iggy Flash UI (PARTIALLY DONE)
The real Iggy/Flash frontend is still stubbed on Apple, but there is now a temporary native main menu fallback so startup no longer skips the frontend entirely.

### What needs to happen:
- [x] Add a temporary Apple-native fallback main menu so the app starts in frontend flow instead of auto-entering gameplay
  - current buttons: `Play Test World`, `Toggle Fullscreen`, `Quit`
  - world launch now happens from the menu instead of unconditional auto-start
- [x] Verified the fallback startup path works end-to-end at runtime on macOS via frontend/control launch flow
  - app initializes and stays in menu mode instead of auto-starting a world
  - `start` control command exercises the same Apple frontend launch path and reaches `SetGameStarted - true`
- [x] Added Apple-native loading overlay between menu and gameplay
  - menu now switches into a non-interactive loading state during bootstrap
  - overlay only hides after `gameStarted`, valid level/player state, and 3 stable gameplay frames
- [x] Verified live pause overlay still works after world load
  - runtime log shows `Apple overlay shown: pause menu`
  - visual capture confirms the fallback pause menu appears on a running world
- [ ] Visually confirm the native overlay appearance on this machine
- [ ] Decide whether to keep expanding the Apple-native fallback menu or replace it directly with a real Iggy-compatible frontend path
- [ ] Either implement a Flash/SWF renderer for Metal, OR
- [ ] Port the UI to a custom system (e.g., native UIKit/AppKit controls), OR
- [ ] Find a compatible Iggy library for Apple, OR
- [ ] Implement a minimal SWF interpreter for the game's UI .swf files
- [ ] Without this, menus/HUD/inventory screens won't display

### Important note:
- Current visual target is still blocked by missing real frontend/UI implementation
- The provided Minecraft title-screen screenshot is useful as an end-state target, but exact parity is not possible yet while Apple UI remains mostly stubbed
- Main menu/frontend flow now takes priority before further gameplay/input cleanup
- Rendering/world correctness still matters, but it should continue after the startup menu path is usable

## Phase 7: Audio (PARTIALLY DONE)
MiniAudio library is integrated. Sound engine compiles.

### What needs to happen:
- [x] Verified miniaudio/CoreAudio path is alive enough for audible game audio
- [ ] Test sound effect playback (WAV files)
- [ ] Test music streaming (OGG via stb_vorbis)
- [ ] Verify 3D positional audio
- [ ] Test CD/music disc playback

## Phase 8: Input (PARTIALLY DONE)
GameController framework and keyboard/mouse input framework exist.

### What needs to happen:
- [x] Wired basic external control-file input path for unattended debugging
- [ ] Wire up full live keyboard/mouse gameplay input cleanly
- [ ] Implement `DefineActions()` - map gamepad buttons to MINECRAFT_ACTION_* enums
- [ ] Test GameController framework with MFi/Xbox/DualSense controllers
- [ ] Implement `Minecraft::applyFrameMouseLook()` for mouse-look camera control
- [ ] Implement Mouse::getX/getY with actual cursor position
- [ ] Test keyboard input for chat/signs

### Current practical usage:
- `minecraft_control.txt` is now the main remote-debug hook
- Continue using it for:
  - status checks
  - on-demand framebuffer dumps
  - safe app shutdown
  - basic key/mouse injection

## Immediate Next Steps
- [ ] Verify the new Apple fallback main menu at runtime
  - visually confirm menu appears immediately after init
  - [x] visually confirm the native overlay hides once gameplay actually starts
- [ ] If pink/blue flashes are still visible after the overlay hides, debug the first uncovered gameplay frames separately from the frontend path
- [ ] Decide whether the next frontend step is:
  - expanding the native fallback into a fuller title/pause flow
  - or replacing it with a real Apple Iggy/frontend implementation
- [ ] Keep standard chunk vertices on Apple until compact packed-quad path is properly ported or intentionally reimplemented
- [ ] Fix terrain texture correctness in normal shading path
  - confirm terrain atlas being bound is the correct atlas
  - inspect mip upload behaviour and disable/rebuild only if truly needed
  - restore normal shader sampling one debug step at a time
- [ ] Use `dump` control command plus `/tmp/mc_control_dump.png` after each change instead of relying only on desktop screenshots
- [ ] Once world rendering is sane, return to:
  - HUD/frontend/UI work
  - proper input mapping
  - title/menu parity

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
- Error log: `build/macos-arm64/build_errors.log`
- Runtime log: `minecraft_runtime.log` next to .app bundle
- LTO disabled (causes ODR issues with 170+ static const members)
- Code signing disabled for development
- Auto-build script / listener are not required when debugging locally on this machine

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
