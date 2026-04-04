// Apple_App.cpp - CConsoleMinecraftApp implementation for Apple platforms
#include "stdafx.h"
#include "Apple_App.h"
#include "../Common/UI/UIController.h"
#include "../Common/UI/UIScene.h"
#include "../Common/Leaderboards/LeaderboardManager.h"
#include "Leaderboards/AppleLeaderboardManager.h"

// Global app instance
CConsoleMinecraftApp app;

CConsoleMinecraftApp::CConsoleMinecraftApp() : m_bShutdown(false) {}

void CConsoleMinecraftApp::SetRichPresenceContext(int iPad, int contextId) {}
void CConsoleMinecraftApp::StoreLaunchData() {}
void CConsoleMinecraftApp::ExitGame() { m_bShutdown = true; }
void CConsoleMinecraftApp::FatalLoadError() {}
void CConsoleMinecraftApp::CaptureSaveThumbnail() {}
void CConsoleMinecraftApp::GetSaveThumbnail(PBYTE*, DWORD*) {}
void CConsoleMinecraftApp::ReleaseSaveThumbnail() {}
void CConsoleMinecraftApp::GetScreenshot(int iPad, PBYTE* pbData, DWORD* pdwSize) {}
int CConsoleMinecraftApp::LoadLocalTMSFile(WCHAR* wchTMSFile) { return 0; }
int CConsoleMinecraftApp::LoadLocalTMSFile(WCHAR* wchTMSFile, eFileExtensionType eExt) { return 0; }
void CConsoleMinecraftApp::FreeLocalTMSFiles(eTMSFileType eType) {}
int CConsoleMinecraftApp::GetLocalTMSFileIndex(WCHAR* wchTMSFile, bool bFilenameIncludesExtension, eFileExtensionType eEXT) { return -1; }
void CConsoleMinecraftApp::TemporaryCreateGameStart() {}

// ---------------------------------------------------------------------------
// Missing UIScene methods
// ---------------------------------------------------------------------------

bool UIScene::handleMouseClick(float x, float y) { return false; }
bool UIScene::isDirectEditBlocking() { return false; }
void UIScene::SetFocusToElement(int iID) {}

// ---------------------------------------------------------------------------
// Missing LeaderboardManager static instance
// ---------------------------------------------------------------------------
static AppleLeaderboardManager s_appleLeaderboardManager;
LeaderboardManager* LeaderboardManager::m_instance = &s_appleLeaderboardManager;

// ---------------------------------------------------------------------------
// MemSect stub - rendering memory section marker (no-op on Apple)
// ---------------------------------------------------------------------------
void MemSect(int) {}

// ---------------------------------------------------------------------------
// Out-of-line definitions for static const members (ODR requirement on Clang)
// MSVC doesn't require these but Clang/LTO does when address is taken
// ---------------------------------------------------------------------------
#include "../../Minecraft.World/AnimatePacket.h"
#include "../../Minecraft.World/ContainerOpenPacket.h"
#include "../../Minecraft.World/AddEntityPacket.h"
const int AnimatePacket::SWING;
const int ContainerOpenPacket::HOPPER;
const int ContainerOpenPacket::DROPPER;
const int AddEntityPacket::BOAT;
const int AddEntityPacket::ITEM;
const int AddEntityPacket::MINECART;
const int AddEntityPacket::PRIMED_TNT;
const int AddEntityPacket::ENDER_CRYSTAL;
const int AddEntityPacket::ARROW;
const int AddEntityPacket::SNOWBALL;
const int AddEntityPacket::EGG;
const int AddEntityPacket::FIREBALL;
const int AddEntityPacket::SMALL_FIREBALL;
const int AddEntityPacket::THROWN_ENDERPEARL;
const int AddEntityPacket::WITHER_SKULL;
const int AddEntityPacket::FALLING;
const int AddEntityPacket::ITEM_FRAME;
const int AddEntityPacket::EYEOFENDERSIGNAL;
const int AddEntityPacket::THROWN_POTION;
const int AddEntityPacket::FALLING_EGG;
const int AddEntityPacket::THROWN_EXPBOTTLE;
const int AddEntityPacket::FIREWORKS;
const int AddEntityPacket::LEASH_KNOT;
const int AddEntityPacket::FISH_HOOK;
const int AddEntityPacket::DRAGON_FIRE_BALL;
