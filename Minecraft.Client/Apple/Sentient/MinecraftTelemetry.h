#pragma once
// Apple platform telemetry enums - copied from Orbis/Sentient/TelemetryEnum.h

enum ETelem_ModeId
{
	eTelem_ModeId_Undefined = 0,
	eTelem_ModeId_Survival,
	eTelem_ModeId_Creative,
};

enum ETelem_SubModeId
{
	eTelem_SubModeId_Undefined = 0,
	eTelem_SubModeId_Normal,
	eTelem_SubModeId_Tutorial,
};

enum ETelem_LevelId
{
	eTelem_LevelId_Undefined = 0,
	eTelem_LevelId_PlayerGeneratedLevel = 1,
};

enum ETelem_SubLevelId
{
	eTelem_SubLevelId_Undefined = 0,
	eTelem_SubLevelId_Overworld,
	eTelem_SubLevelId_Nether,
	eTelem_SubLevelId_End,
};

enum ETelem_MenuId
{
	eTelemMenuId_Pause = 5,
	eTelemMenuId_HowToPlay = 16,
	eTelemMenuId_MultiGameCreate = 25,
	eTelemMenuId_MultiGameInfo = 27,
	eTelemMenuId_DLCOffers = 31,
	eTelemMenuId_SocialPost = 32,
	eTelemMenuId_LoadSettings = 34,
};

enum ETelemetry_HowToPlay_SubMenuId
{
	eTelemetryHowToPlay_Basics = 0,
	eTelemetryHowToPlay_HUD,
	eTelemetryHowToPlay_Inventory,
	eTelemetryHowToPlay_Chest,
	eTelemetryHowToPlay_LargeChest,
	eTelemetryHowToPlay_InventoryCrafting,
	eTelemetryHowToPlay_CraftTable,
	eTelemetryHowToPlay_Furnace,
	eTelemetryHowToPlay_Dispenser,
	eTelemetryHowToPlay_NetherPortal,
};

enum ETelemetryChallenges
{
	eTelemetryChallenges_Unknown = 0,

	eTelemetryTutorial_TrialStart,
	eTelemetryTutorial_Halfway,
	eTelemetryTutorial_Complete,

	eTelemetryTutorial_Inventory,
	eTelemetryTutorial_Crafting,
	eTelemetryTutorial_Furnace,
	eTelemetryTutorial_Fishing,
	eTelemetryTutorial_Minecart,
	eTelemetryTutorial_Boat,
	eTelemetryTutorial_Bed,

	eTelemetryTutorial_Redstone_And_Pistons,
	eTelemetryTutorial_Portal,
	eTelemetryTutorial_FoodBar,
	eTelemetryTutorial_CreativeMode,
	eTelemetryTutorial_BrewingMenu,

	eTelemetryInGame_Ride_Minecart,
	eTelemetryInGame_Ride_Boat,
	eTelemetryInGame_Ride_Pig,
	eTelemetryInGame_UseBed,

	eTelemetryTutorial_CreativeInventory,

	eTelemetryTutorial_EnchantingMenu,
	eTelemetryTutorial_Brewing,
	eTelemetryTutorial_Enchanting,
	eTelemetryTutorial_Farming,

	eTelemetryPlayerDeathSource_Fall,
	eTelemetryPlayerDeathSource_Lava,
	eTelemetryPlayerDeathSource_Fire,
	eTelemetryPlayerDeathSource_Water,
	eTelemetryPlayerDeathSource_Suffocate,
	eTelemetryPlayerDeathSource_OutOfWorld,
	eTelemetryPlayerDeathSource_Cactus,

	eTelemetryPlayerDeathSource_Player_Weapon,
	eTelemetryPlayerDeathSource_Player_Arrow,

	eTelemetryPlayerDeathSource_Explosion_Tnt,
	eTelemetryPlayerDeathSource_Explosion_Creeper,

	eTelemetryPlayerDeathSource_Wolf,
	eTelemetryPlayerDeathSource_Zombie,
	eTelemetryPlayerDeathSource_Skeleton,
	eTelemetryPlayerDeathSource_Spider,
	eTelemetryPlayerDeathSource_Slime,
	eTelemetryPlayerDeathSource_Ghast,
	eTelemetryPlayerDeathSource_ZombiePigman,

	eTelemetryTutorial_Breeding,
	eTelemetryTutorial_Golem,

	eTelemetryTutorial_Anvil,
	eTelemetryTutorial_AnvilMenu,
	eTelemetryTutorial_Trading,
	eTelemetryTutorial_TradingMenu,
	eTelemetryTutorial_Enderchest,

	eTelemetryTutorial_Horse,
	eTelemetryTutorial_HorseMenu,
	eTelemetryTutorial_FireworksMenu,
	eTelemetryTutorial_BeaconMenu,
	eTelemetryTutorial_Beacon,
	eTelemetryTutorial_Hopper,
	eTelemetryTutorial_NoEvent,
};

// Game events telemetry
enum ETelemetryGameEvent
{
	eTelemetryGameEvent_Load = 0,
};

// Generic telemetry event type
enum ETelemetryEvent
{
	eTelemetryEvent = 0,
};
