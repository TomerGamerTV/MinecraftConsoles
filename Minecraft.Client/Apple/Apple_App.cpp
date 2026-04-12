// Apple_App.cpp - CConsoleMinecraftApp + misc Apple stubs
#include "stdafx.h"
#include "Apple_App.h"
#include "../Minecraft.h"
#include "../MinecraftServer.h"
#include "../Common/UI/UIController.h"
#include "../Common/UI/UIScene.h"
#include "../Common/Leaderboards/LeaderboardManager.h"
#include "Leaderboards/AppleLeaderboardManager.h"
#include "Extras/ShutdownManager.h"

// =========================================================================
// Global app instance
// =========================================================================
CConsoleMinecraftApp app;

CConsoleMinecraftApp::CConsoleMinecraftApp() : m_bShutdown(false) {}
void CConsoleMinecraftApp::SetRichPresenceContext(int, int) {}
void CConsoleMinecraftApp::StoreLaunchData() {}
void CConsoleMinecraftApp::ExitGame() { m_bShutdown = true; }
void CConsoleMinecraftApp::FatalLoadError() {}
void CConsoleMinecraftApp::CaptureSaveThumbnail() {}
void CConsoleMinecraftApp::GetSaveThumbnail(PBYTE*, DWORD*) {}
void CConsoleMinecraftApp::ReleaseSaveThumbnail() {}
void CConsoleMinecraftApp::GetScreenshot(int, PBYTE*, DWORD*) {}
int CConsoleMinecraftApp::LoadLocalTMSFile(WCHAR*) { return 0; }
int CConsoleMinecraftApp::LoadLocalTMSFile(WCHAR*, eFileExtensionType) { return 0; }
void CConsoleMinecraftApp::FreeLocalTMSFiles(eTMSFileType) {}
int CConsoleMinecraftApp::GetLocalTMSFileIndex(WCHAR*, bool, eFileExtensionType) { return -1; }
void CConsoleMinecraftApp::TemporaryCreateGameStart()
{
    fprintf(stderr, "[Apple] TemporaryCreateGameStart - auto-starting creative world\n");
    fflush(stderr);

    Minecraft* pMinecraft = Minecraft::GetInstance();
    if (!pMinecraft) {
        fprintf(stderr, "[Apple] ERROR: No Minecraft instance!\n");
        return;
    }

    // Set up game host options for a creative world
    app.SetGameHostOption(eGameHostOption_GameType, 1);     // Creative mode
    app.SetGameHostOption(eGameHostOption_Difficulty, 0);    // Peaceful
    app.SetGameHostOption(eGameHostOption_LevelType, 0);     // Normal terrain (0=default, 1=flat)
    app.SetGameHostOption(eGameHostOption_Structures, 1);
    app.SetGameHostOption(eGameHostOption_BonusChest, 0);
    app.SetGameHostOption(eGameHostOption_PvP, 0);
    app.SetGameHostOption(eGameHostOption_TrustPlayers, 1);
    app.SetGameHostOption(eGameHostOption_FireSpreads, 1);
    app.SetGameHostOption(eGameHostOption_TNT, 1);
    app.SetGameHostOption(eGameHostOption_DoMobSpawning, 0);
    app.SetGameHostOption(eGameHostOption_DoDaylightCycle, 1);

    // Host a local game
    fprintf(stderr, "[Apple] Calling HostGame...\n"); fflush(stderr);
    g_NetworkManager.HostGame(1, false, false, MINECRAFT_NET_MAX_PLAYERS, 0);
    g_NetworkManager.FakeLocalPlayerJoined();

    // Create game start parameters
    NetworkGameInitData *param = new NetworkGameInitData();
    param->seed = 12345;
    param->findSeed = false;
    param->settings = app.GetGameHostOption(eGameHostOption_All);
    param->xzSize = LEVEL_MAX_WIDTH;
    param->hellScale = HELL_LEVEL_MAX_SCALE;
    param->levelName = L"Apple Test World";

    // Start the game on a background thread
    fprintf(stderr, "[Apple] Starting game on background thread...\n"); fflush(stderr);

    static NetworkGameInitData* s_param = param;
    C4JThread* gameThread = new C4JThread(
        [](void* p) -> int {
            fprintf(stderr, "[Apple] Background: RunNetworkGameThreadProc starting\n"); fflush(stderr);
            int result = CGameNetworkManager::RunNetworkGameThreadProc(p);
            fprintf(stderr, "[Apple] Background: RunNetworkGameThreadProc returned %d\n", result); fflush(stderr);
            return result;
        },
        static_cast<void*>(s_param),
        "GameStartThread"
    );
    gameThread->Run();

    fprintf(stderr, "[Apple] TemporaryCreateGameStart done\n"); fflush(stderr);
}

// =========================================================================
// Global variables referenced by Windows64 game code
// =========================================================================
wchar_t g_Win64UsernameW[17] = L"Player";
extern "C" int g_iScreenWidth  = 1920;
extern "C" int g_iScreenHeight = 1080;
extern "C" int g_rScreenWidth  = 1920;
extern "C" int g_rScreenHeight = 1080;

// =========================================================================
// UIScene methods (declared for Apple in UIScene.h)
// =========================================================================
bool UIScene::handleMouseClick(float, float) { return false; }
bool UIScene::isDirectEditBlocking() { return false; }
void UIScene::SetFocusToElement(int) {}

// =========================================================================
// LeaderboardManager singleton
// =========================================================================
static AppleLeaderboardManager s_appleLeaderboardManager;
LeaderboardManager* LeaderboardManager::m_instance = &s_appleLeaderboardManager;

// =========================================================================
// DefineActions stub (input action mappings)
// =========================================================================
void DefineActions(void) {}

// =========================================================================
// Minecraft::applyFrameMouseLook stub
// =========================================================================
void Minecraft::applyFrameMouseLook() {}

// =========================================================================
// CMinecraftApp::GetTPConfigVal stub
// =========================================================================
int CMinecraftApp::GetTPConfigVal(wchar_t*) { return 0; }

// =========================================================================
// MemSect stub (rendering debug marker)
// =========================================================================
void MemSect(int) {}

// =========================================================================
// AppleInitThreadStorage - called from macOS_Minecraft.mm
// =========================================================================
#include "../Tesselator.h"
#include "../../Minecraft.World/AABB.h"
#include "../../Minecraft.World/Vec3.h"
#include "../../Minecraft.World/IntCache.h"
#include "../../Minecraft.World/compression.h"

// OldChunkStorage, Level, Tile have complex dependency chains
extern void AppleEnableLightingCache();
extern void AppleTileCreateNewThreadStorage();
extern void AppleOldChunkStorageCreateNewThreadStorage();

extern "C" void AppleInitThreadStorage()
{
    Tesselator::CreateNewThreadStorage(1024 * 1024);
    AABB::CreateNewThreadStorage();
    Vec3::CreateNewThreadStorage();
    IntCache::CreateNewThreadStorage();
    Compression::CreateNewThreadStorage();
    AppleOldChunkStorageCreateNewThreadStorage();
    AppleEnableLightingCache();
    AppleTileCreateNewThreadStorage();
}

// =========================================================================
// Mouse::isButtonDown stub
// =========================================================================
bool Mouse::isButtonDown(int) { return false; }

// =========================================================================
// PostProcesser stubs (D3D11 post-processing - no-op on Apple/Metal)
// =========================================================================
#include "../Common/PostProcesser.h"
PostProcesser::PostProcesser() {}
PostProcesser::~PostProcesser() {}
void PostProcesser::Init() {}
void PostProcesser::Apply() const {}
void PostProcesser::ApplyFromCopied() const {}
void PostProcesser::CopyBackbuffer() {}
void PostProcesser::SetViewport(const D3D11_VIEWPORT&) {}
void PostProcesser::ResetViewport() {}
void PostProcesser::SetGamma(float gamma) { m_gamma = gamma; }
void PostProcesser::Cleanup() {}
bool PostProcesser::IsRunningUnderWine() { return false; }

// =========================================================================
// NetworkPlayerXbox stubs (Xbox-specific, not needed on Apple)
// =========================================================================
#include "../Xbox/Network/NetworkPlayerXbox.h"
NetworkPlayerXbox::NetworkPlayerXbox(IQNetPlayer* p) : m_qnetPlayer(p), m_pSocket(nullptr), m_lastChunkPacketTime(0) {}
IQNetPlayer* NetworkPlayerXbox::GetQNetPlayer() { return m_qnetPlayer; }
unsigned char NetworkPlayerXbox::GetSmallId() { return m_qnetPlayer ? m_qnetPlayer->m_smallId : 0; }
void NetworkPlayerXbox::SendData(INetworkPlayer*, const void*, int, bool, bool) {}
bool NetworkPlayerXbox::IsSameSystem(INetworkPlayer*) { return false; }
int NetworkPlayerXbox::GetOutstandingAckCount() { return 0; }
int NetworkPlayerXbox::GetSendQueueSizeBytes(INetworkPlayer*, bool) { return 0; }
int NetworkPlayerXbox::GetSendQueueSizeMessages(INetworkPlayer*, bool) { return 0; }
int NetworkPlayerXbox::GetCurrentRtt() { return 0; }
bool NetworkPlayerXbox::IsHost() { return m_qnetPlayer ? m_qnetPlayer->m_isHostPlayer : false; }
bool NetworkPlayerXbox::IsGuest() { return false; }
bool NetworkPlayerXbox::IsLocal() { return m_qnetPlayer ? !m_qnetPlayer->m_isRemote : true; }
int NetworkPlayerXbox::GetSessionIndex() { return 0; }
bool NetworkPlayerXbox::IsTalking() { return false; }
bool NetworkPlayerXbox::IsMutedByLocalUser(int) { return false; }
bool NetworkPlayerXbox::HasVoice() { return false; }
bool NetworkPlayerXbox::HasCamera() { return false; }
int NetworkPlayerXbox::GetUserIndex() { return 0; }
void NetworkPlayerXbox::SetSocket(Socket* s) { m_pSocket = s; }
Socket* NetworkPlayerXbox::GetSocket() { return m_pSocket; }
const wchar_t* NetworkPlayerXbox::GetOnlineName() { return L"Player"; }
std::wstring NetworkPlayerXbox::GetDisplayName() { return L"Player"; }
PlayerUID NetworkPlayerXbox::GetUID() { return 0; }
void NetworkPlayerXbox::SentChunkPacket() {}
int NetworkPlayerXbox::GetTimeSinceLastChunkPacket_ms() { return 0; }
