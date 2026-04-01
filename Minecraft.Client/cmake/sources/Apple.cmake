set(BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Apple/")

# Apple platform source files
set(_MINECRAFT_CLIENT_APPLE_COMMON_AUDIO
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Audio/SoundEngine.cpp"
)
source_group("Common/Audio" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_AUDIO})

set(_MINECRAFT_CLIENT_APPLE_COMMON_RES_AUDIO
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/res/audio/minecraft.xsb"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/res/audio/resident.xwb"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/res/audio/streamed.xwb"
)
source_group("Common/res/audio" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_RES_AUDIO})

set(_MINECRAFT_CLIENT_APPLE_COMMON_NETWORK
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Network/PlatformNetworkManagerStub.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Network/PlatformNetworkManagerStub.h"
)
source_group("Common/Network" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_NETWORK})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UI.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIBitmapFont.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIBitmapFont.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIController.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIController.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIGroup.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIGroup.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UILayer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UILayer.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UITTFFont.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UITTFFont.h"
)
source_group("Common/UI" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_COMPONENTS
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Chat.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Chat.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_DebugUIConsole.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_DebugUIConsole.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_DebugUIMarketingGuide.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_DebugUIMarketingGuide.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Logo.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Logo.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_MenuBackground.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_MenuBackground.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Panorama.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Panorama.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_PressStartToPlay.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_PressStartToPlay.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Tooltips.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_Tooltips.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_TutorialPopup.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIComponent_TutorialPopup.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HUD.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HUD.h"
)
source_group("Common/UI/Components" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_COMPONENTS})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_CONTROLS
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Base.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Base.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_BeaconEffectButton.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_BeaconEffectButton.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_BitmapIcon.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_BitmapIcon.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Button.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Button.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_ButtonList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_ButtonList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_CheckBox.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_CheckBox.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Cursor.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Cursor.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_DLCList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_DLCList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_DynamicLabel.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_DynamicLabel.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_EnchantmentBook.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_EnchantmentBook.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_EnchantmentButton.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_EnchantmentButton.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_HTMLLabel.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_HTMLLabel.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Label.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Label.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_LeaderboardList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_LeaderboardList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_MinecraftHorse.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_MinecraftHorse.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_MinecraftPlayer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_MinecraftPlayer.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_PlayerList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_PlayerList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_PlayerSkinPreview.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_PlayerSkinPreview.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Progress.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Progress.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SaveList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SaveList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Slider.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_Slider.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SlotList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SlotList.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SpaceIndicatorBar.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_SpaceIndicatorBar.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_TextInput.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_TextInput.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_TexturePackList.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIControl_TexturePackList.h"
)
source_group("Common/UI/Controls" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_CONTROLS})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ConnectingProgress.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ConnectingProgress.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FullscreenProgress.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FullscreenProgress.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Keyboard.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Keyboard.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_MessageBox.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_MessageBox.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_QuadrantSignin.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_QuadrantSignin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Timer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Timer.h"
)
source_group("Common/UI/Scenes" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_DEBUG
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugCreateSchematic.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugCreateSchematic.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugOptions.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugOptions.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugOverlay.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugOverlay.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugSetCamera.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DebugSetCamera.h"
)
source_group("Common/UI/Scenes/Debug" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_DEBUG})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_FRONTEND
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/IUIScene_StartGame.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CreateWorldMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CreateWorldMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DLCMainMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DLCMainMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DLCOffersMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DLCOffersMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EULA.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EULA.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Intro.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Intro.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_JoinMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_JoinMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LaunchMoreOptionsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LaunchMoreOptionsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LeaderboardsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LeaderboardsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LoadMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LoadMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LoadOrJoinMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LoadOrJoinMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_MainMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_MainMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_NewUpdateMessage.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_NewUpdateMessage.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SaveMessage.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SaveMessage.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TrialExitUpsell.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TrialExitUpsell.h"
)
source_group("Common/UI/Scenes/Frontend" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_FRONTEND})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_HELPOPTIONS
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ControlsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ControlsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Credits.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_Credits.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HelpAndOptionsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HelpAndOptionsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HowToPlay.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HowToPlay.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HowToPlayMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HowToPlayMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LanguageSelector.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_LanguageSelector.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ReinstallMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ReinstallMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsAudioMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsAudioMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsControlMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsControlMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsGraphicsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsGraphicsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsOptionsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsOptionsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsUIMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SettingsUIMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SkinSelectMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SkinSelectMenu.h"
)
source_group("Common/UI/Scenes/HelpOptions" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_HELPOPTIONS})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_INGAME
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CraftingMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CraftingMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DeathMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DeathMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EndPoem.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EndPoem.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGameHostOptionsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGameHostOptionsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGameInfoMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGameInfoMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGamePlayerOptionsMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InGamePlayerOptionsMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_PauseMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_PauseMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SignEntryMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_SignEntryMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TeleportMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TeleportMenu.h"
)
source_group("Common/UI/Scenes/InGame" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_INGAME})

set(_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_CONTAINERS
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_AbstractContainerMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_AbstractContainerMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_AnvilMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_AnvilMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_BeaconMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_BeaconMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_BrewingStandMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_BrewingStandMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ContainerMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_ContainerMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CreativeMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_CreativeMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DispenserMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_DispenserMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EnchantingMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_EnchantingMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FireworksMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FireworksMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FurnaceMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_FurnaceMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HopperMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HopperMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HorseInventoryMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_HorseInventoryMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InventoryMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_InventoryMenu.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TradingMenu.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/UI/UIScene_TradingMenu.h"
)
source_group("Common/UI/Scenes/Containers" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_CONTAINERS})

set(_MINECRAFT_CLIENT_APPLE_COMMON_ZLIB
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/adler32.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/compress.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/crc32.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/crc32.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/deflate.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/deflate.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/gzclose.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/gzguts.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/gzlib.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/gzread.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/gzwrite.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/infback.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inffast.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inffast.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inffixed.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inflate.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inflate.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inftrees.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/inftrees.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/trees.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/trees.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/uncompr.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/zconf.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/zlib.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/zutil.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/zlib/zutil.h"
)
source_group("Common/zlib" FILES ${_MINECRAFT_CLIENT_APPLE_COMMON_ZLIB})

# Apple platform-specific code
set(_MINECRAFT_CLIENT_APPLE_PLATFORM
  "${BASE_DIR}/AppleTypes.h"
  "${BASE_DIR}/AppleMaths.h"
  "${BASE_DIR}/Apple_App.h"
)
source_group("Apple" FILES ${_MINECRAFT_CLIENT_APPLE_PLATFORM})

set(_MINECRAFT_CLIENT_APPLE_4JLIBS
  "${BASE_DIR}/4JLibs/inc/4J_Input.h"
  "${BASE_DIR}/4JLibs/inc/4J_Profile.h"
  "${BASE_DIR}/4JLibs/inc/4J_Render.h"
  "${BASE_DIR}/4JLibs/inc/4J_Storage.h"
)
source_group("Apple/4JLibs/inc" FILES ${_MINECRAFT_CLIENT_APPLE_4JLIBS})

set(_MINECRAFT_CLIENT_APPLE_METAL
  "${BASE_DIR}/Metal/MetalRenderer.mm"
  "${BASE_DIR}/Metal/MetalShaders.metal"
)
source_group("Apple/Metal" FILES ${_MINECRAFT_CLIENT_APPLE_METAL})

set(_MINECRAFT_CLIENT_APPLE_INPUT
  "${BASE_DIR}/Input/AppleInput.mm"
  "${BASE_DIR}/Input/AppleKeyboardMouseInput.h"
  "${BASE_DIR}/Input/AppleKeyboardMouseInput.mm"
  "${BASE_DIR}/Input/AppleStorage.mm"
  "${BASE_DIR}/Input/AppleProfile.mm"
)
source_group("Apple/Input" FILES ${_MINECRAFT_CLIENT_APPLE_INPUT})

set(_MINECRAFT_CLIENT_APPLE_IGGY
  "${BASE_DIR}/Iggy/include/iggy.h"
  "${BASE_DIR}/Iggy/include/iggyexpruntime.h"
  "${BASE_DIR}/Iggy/include/iggyperfmon.h"
  "${BASE_DIR}/Iggy/include/gdraw.h"
  "${BASE_DIR}/Iggy/include/rrCore.h"
  "${BASE_DIR}/Iggy/gdraw/gdraw_metal.h"
  "${BASE_DIR}/Iggy/gdraw/gdraw_metal.mm"
  "${BASE_DIR}/Iggy/IggyStubs.mm"
)
source_group("Apple/Iggy" FILES ${_MINECRAFT_CLIENT_APPLE_IGGY})

set(_MINECRAFT_CLIENT_APPLE_NETWORK
  "${BASE_DIR}/Network/BSDNetLayer.h"
  "${BASE_DIR}/Network/BSDNetLayer.cpp"
)
source_group("Apple/Network" FILES ${_MINECRAFT_CLIENT_APPLE_NETWORK})

set(_MINECRAFT_CLIENT_APPLE_UICONTROLLER
  "${BASE_DIR}/UIController/Apple_UIController.h"
  "${BASE_DIR}/UIController/Apple_UIController.mm"
)
source_group("Apple/UIController" FILES ${_MINECRAFT_CLIENT_APPLE_UICONTROLLER})

set(_MINECRAFT_CLIENT_APPLE_SENTIENT
  "${BASE_DIR}/Sentient/MinecraftTelemetry.h"
  "${BASE_DIR}/Sentient/DynamicConfigurations.h"
  "${BASE_DIR}/Sentient/SentientTelemetryCommon.h"
  "${BASE_DIR}/Sentient/SentientManager.h"
)
source_group("Apple/Sentient" FILES ${_MINECRAFT_CLIENT_APPLE_SENTIENT})

set(_MINECRAFT_CLIENT_APPLE_MISC
  "${BASE_DIR}/Social/SocialManager.h"
  "${BASE_DIR}/XML/ATGXmlParser.h"
  "${BASE_DIR}/GameConfig/Minecraft.spa.h"
)
source_group("Apple/Misc" FILES ${_MINECRAFT_CLIENT_APPLE_MISC})

# macOS-specific entry point
set(_MINECRAFT_CLIENT_APPLE_MACOS
  "${CMAKE_CURRENT_SOURCE_DIR}/macOS/macOS_Minecraft.mm"
  "${CMAKE_CURRENT_SOURCE_DIR}/macOS/Info.plist"
)
source_group("macOS" FILES ${_MINECRAFT_CLIENT_APPLE_MACOS})

# iOS-specific entry point
set(_MINECRAFT_CLIENT_APPLE_IOS
  "${CMAKE_CURRENT_SOURCE_DIR}/iOS/iOS_Minecraft.mm"
  "${CMAKE_CURRENT_SOURCE_DIR}/iOS/TouchInput.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/iOS/TouchInput.mm"
  "${CMAKE_CURRENT_SOURCE_DIR}/iOS/Info.plist"
  "${CMAKE_CURRENT_SOURCE_DIR}/iOS/LaunchScreen.storyboard"
)
source_group("iOS" FILES ${_MINECRAFT_CLIENT_APPLE_IOS})

# Stubs needed for Apple
set(_MINECRAFT_CLIENT_APPLE_STUBS
  "${CMAKE_CURRENT_SOURCE_DIR}/Extrax64Stubs.cpp"
)
source_group("Stubs" FILES ${_MINECRAFT_CLIENT_APPLE_STUBS})

set(_MINECRAFT_CLIENT_APPLE_MEDIA
  "${CMAKE_CURRENT_SOURCE_DIR}/AppleMedia/strings.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/AppleMedia/4J_strings.h"
)
source_group("AppleMedia" FILES ${_MINECRAFT_CLIENT_APPLE_MEDIA})

set(_MINECRAFT_CLIENT_APPLE_STATS
  "${CMAKE_CURRENT_SOURCE_DIR}/StatsCounter.h"
)
source_group("Stats" FILES ${_MINECRAFT_CLIENT_APPLE_STATS})

set(_MINECRAFT_CLIENT_APPLE_LEADERBOARDS
  "${CMAKE_CURRENT_SOURCE_DIR}/Windows64/Leaderboards/WindowsLeaderboardManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/Windows64/Leaderboards/WindowsLeaderboardManager.h"
)
source_group("Leaderboards" FILES ${_MINECRAFT_CLIENT_APPLE_LEADERBOARDS})

# Combine all into MINECRAFT_CLIENT_APPLE
set(MINECRAFT_CLIENT_APPLE
  ${_MINECRAFT_CLIENT_APPLE_COMMON_AUDIO}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_RES_AUDIO}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_NETWORK}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_COMPONENTS}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_CONTROLS}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_DEBUG}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_FRONTEND}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_HELPOPTIONS}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_INGAME}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_UI_SCENES_CONTAINERS}
  ${_MINECRAFT_CLIENT_APPLE_COMMON_ZLIB}
  ${_MINECRAFT_CLIENT_APPLE_PLATFORM}
  ${_MINECRAFT_CLIENT_APPLE_4JLIBS}
  ${_MINECRAFT_CLIENT_APPLE_METAL}
  ${_MINECRAFT_CLIENT_APPLE_INPUT}
  ${_MINECRAFT_CLIENT_APPLE_IGGY}
  ${_MINECRAFT_CLIENT_APPLE_NETWORK}
  ${_MINECRAFT_CLIENT_APPLE_UICONTROLLER}
  ${_MINECRAFT_CLIENT_APPLE_SENTIENT}
  ${_MINECRAFT_CLIENT_APPLE_MISC}
  ${_MINECRAFT_CLIENT_APPLE_STUBS}
  ${_MINECRAFT_CLIENT_APPLE_MEDIA}
  ${_MINECRAFT_CLIENT_APPLE_STATS}
  ${_MINECRAFT_CLIENT_APPLE_LEADERBOARDS}
)

# Add platform-specific entry point
if(PLATFORM_NAME STREQUAL "macOS")
  list(APPEND MINECRAFT_CLIENT_APPLE ${_MINECRAFT_CLIENT_APPLE_MACOS})
elseif(PLATFORM_NAME STREQUAL "iOS")
  list(APPEND MINECRAFT_CLIENT_APPLE ${_MINECRAFT_CLIENT_APPLE_IOS})
endif()
