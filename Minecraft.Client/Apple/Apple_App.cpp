// Apple_App.cpp - CConsoleMinecraftApp + misc Apple stubs
#include "stdafx.h"
#include "Apple_App.h"
#include "../Minecraft.h"
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
void CConsoleMinecraftApp::TemporaryCreateGameStart() {}

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
