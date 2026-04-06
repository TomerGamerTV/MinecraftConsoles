// AppleODRDefs.cpp
// Out-of-line definitions for static const members required by the Clang linker.
// In C++14/17, static const integral members initialized in-class still need
// an out-of-line definition when their address is ODR-used (e.g. passed by
// const-reference). MSVC is lenient about this, but Clang is not.

#include "stdafx.h"

#include "../../../Minecraft.World/AddEntityPacket.h"
#include "../../../Minecraft.World/AnimatePacket.h"
#include "../../../Minecraft.World/ChestTile.h"
#include "../../../Minecraft.World/ClientCommandPacket.h"
#include "../../../Minecraft.World/ContainerOpenPacket.h"
#include "../../../Minecraft.World/EntityEvent.h"
#include "../../../Minecraft.World/GameEventPacket.h"
#include "../../../Minecraft.World/Item.h"
#include "../../../Minecraft.World/Level.h"
#include "../../../Minecraft.World/PotionBrewing.h"
#include "../../../Minecraft.World/QuartzBlockTile.h"
#include "../../../Minecraft.World/Sapling.h"
#include "../../../Minecraft.World/SetEntityLinkPacket.h"
#include "../../../Minecraft.World/SharedConstants.h"
#include "../../../Minecraft.World/SkullTileEntity.h"
#include "../../../Minecraft.World/TallGrass.h"
#include "../../../Minecraft.World/Tile.h"
#include "../../../Minecraft.World/TileEditorOpenPacket.h"
#include "../../../Minecraft.World/TileEntityDataPacket.h"
#include "../../Common/UI/IUIScene_CreativeMenu.h"

// ---------------------------------------------------------------------------
// AddEntityPacket
// ---------------------------------------------------------------------------
const int AddEntityPacket::ARROW;
const int AddEntityPacket::BOAT;
const int AddEntityPacket::EGG;
const int AddEntityPacket::ENDER_CRYSTAL;
const int AddEntityPacket::EYEOFENDERSIGNAL;
const int AddEntityPacket::FALLING;
const int AddEntityPacket::FIREWORKS;
const int AddEntityPacket::FISH_HOOK;
const int AddEntityPacket::ITEM;
const int AddEntityPacket::ITEM_FRAME;
const int AddEntityPacket::LEASH_KNOT;
const int AddEntityPacket::MINECART;
const int AddEntityPacket::PRIMED_TNT;
const int AddEntityPacket::SNOWBALL;
const int AddEntityPacket::THROWN_ENDERPEARL;
const int AddEntityPacket::THROWN_EXPBOTTLE;
const int AddEntityPacket::THROWN_POTION;

// ---------------------------------------------------------------------------
// AnimatePacket
// ---------------------------------------------------------------------------
const int AnimatePacket::CRITICAL_HIT;
const int AnimatePacket::EAT;
const int AnimatePacket::MAGIC_CRITICAL_HIT;
const int AnimatePacket::SWING;
const int AnimatePacket::WAKE_UP;

// ---------------------------------------------------------------------------
// ChestTile
// ---------------------------------------------------------------------------
const int ChestTile::TYPE_TRAP;

// ---------------------------------------------------------------------------
// ClientCommandPacket
// ---------------------------------------------------------------------------
const int ClientCommandPacket::PERFORM_RESPAWN;

// ---------------------------------------------------------------------------
// ContainerOpenPacket
// ---------------------------------------------------------------------------
const int ContainerOpenPacket::BEACON;
const int ContainerOpenPacket::BREWING_STAND;
const int ContainerOpenPacket::DROPPER;
const int ContainerOpenPacket::ENCHANTMENT;
const int ContainerOpenPacket::FIREWORKS;
const int ContainerOpenPacket::FURNACE;
const int ContainerOpenPacket::HOPPER;
const int ContainerOpenPacket::HORSE;
const int ContainerOpenPacket::REPAIR_TABLE;
const int ContainerOpenPacket::TRADER_NPC;
const int ContainerOpenPacket::TRAP;
const int ContainerOpenPacket::WORKBENCH;

// ---------------------------------------------------------------------------
// EntityEvent
// ---------------------------------------------------------------------------
const BYTE EntityEvent::USE_ITEM_COMPLETE;

// ---------------------------------------------------------------------------
// GameEventPacket
// ---------------------------------------------------------------------------
const int GameEventPacket::SUCCESSFUL_BOW_HIT;

// ---------------------------------------------------------------------------
// Item  (static const int _Id members)
// ---------------------------------------------------------------------------
const int Item::apple_Id;
const int Item::arrow_Id;
const int Item::beef_cooked_Id;
const int Item::beef_raw_Id;
const int Item::boat_Id;
const int Item::book_Id;
const int Item::boots_chain_Id;
const int Item::boots_diamond_Id;
const int Item::boots_iron_Id;
const int Item::boots_leather_Id;
const int Item::bread_Id;
const int Item::bucket_lava_Id;
const int Item::bucket_water_Id;
const int Item::chestplate_chain_Id;
const int Item::chestplate_diamond_Id;
const int Item::chestplate_iron_Id;
const int Item::chestplate_leather_Id;
const int Item::chicken_cooked_Id;
const int Item::chicken_raw_Id;
const int Item::clock_Id;
const int Item::coal_Id;
const int Item::compass_Id;
const int Item::cookie_Id;
const int Item::diamond_Id;
const int Item::emerald_Id;
const int Item::enderPearl_Id;
const int Item::expBottle_Id;
const int Item::eyeOfEnder_Id;
const int Item::fish_cooked_Id;
const int Item::fish_raw_Id;
const int Item::fishingRod_Id;
const int Item::flintAndSteel_Id;
const int Item::flint_Id;
const int Item::goldIngot_Id;
const int Item::hatchet_diamond_Id;
const int Item::hatchet_iron_Id;
const int Item::hatchet_wood_Id;
const int Item::helmet_chain_Id;
const int Item::helmet_diamond_Id;
const int Item::helmet_iron_Id;
const int Item::helmet_leather_Id;
const int Item::hoe_diamond_Id;
const int Item::hoe_iron_Id;
const int Item::ironIngot_Id;
const int Item::leggings_chain_Id;
const int Item::leggings_diamond_Id;
const int Item::leggings_iron_Id;
const int Item::leggings_leather_Id;
const int Item::map_Id;
const int Item::melon_Id;
const int Item::minecart_Id;
const int Item::paper_Id;
const int Item::pickAxe_diamond_Id;
const int Item::pickAxe_iron_Id;
const int Item::pickAxe_wood_Id;
const int Item::porkChop_cooked_Id;
const int Item::porkChop_raw_Id;
const int Item::potion_Id;
const int Item::redStone_Id;
const int Item::rotten_flesh_Id;
const int Item::saddle_Id;
const int Item::seeds_melon_Id;
const int Item::seeds_pumpkin_Id;
const int Item::seeds_wheat_Id;
const int Item::shears_Id;
const int Item::shovel_diamond_Id;
const int Item::shovel_iron_Id;
const int Item::shovel_wood_Id;
const int Item::skull_Id;
const int Item::stick_Id;
const int Item::sword_diamond_Id;
const int Item::sword_iron_Id;
const int Item::wheat_Id;

// ---------------------------------------------------------------------------
// Level
// ---------------------------------------------------------------------------
const int Level::maxBuildHeight;

// ---------------------------------------------------------------------------
// PotionBrewing
// ---------------------------------------------------------------------------
const int PotionBrewing::POTION_ID_SPLASH_DAMAGE;

// ---------------------------------------------------------------------------
// QuartzBlockTile
// ---------------------------------------------------------------------------
const int QuartzBlockTile::TYPE_LINES_Y;

// ---------------------------------------------------------------------------
// Sapling
// ---------------------------------------------------------------------------
const int Sapling::TYPE_BIRCH;
const int Sapling::TYPE_DEFAULT;
const int Sapling::TYPE_EVERGREEN;
const int Sapling::TYPE_JUNGLE;

// ---------------------------------------------------------------------------
// SetEntityLinkPacket
// ---------------------------------------------------------------------------
const int SetEntityLinkPacket::LEASH;
const int SetEntityLinkPacket::RIDING;

// ---------------------------------------------------------------------------
// SharedConstants
// ---------------------------------------------------------------------------
const int SharedConstants::NETWORK_PROTOCOL_VERSION;

// ---------------------------------------------------------------------------
// SkullTileEntity
// ---------------------------------------------------------------------------
const int SkullTileEntity::TYPE_WITHER;

// ---------------------------------------------------------------------------
// TallGrass
// ---------------------------------------------------------------------------
const int TallGrass::FERN;

// ---------------------------------------------------------------------------
// Tile  (static const int _Id members)
// ---------------------------------------------------------------------------
const int Tile::bookshelf_Id;
const int Tile::furnace_Id;
const int Tile::glass_Id;
const int Tile::glowstone_Id;
const int Tile::goldenRail_Id;
const int Tile::leaves_Id;
const int Tile::rail_Id;
const int Tile::stoneSlabHalf_Id;
const int Tile::stone_Id;
const int Tile::torch_Id;
const int Tile::wood_Id;
const int Tile::wool_Id;
const int Tile::workBench_Id;

// ---------------------------------------------------------------------------
// TileEditorOpenPacket
// ---------------------------------------------------------------------------
const int TileEditorOpenPacket::SIGN;

// ---------------------------------------------------------------------------
// TileEntityDataPacket
// ---------------------------------------------------------------------------
const int TileEntityDataPacket::TYPE_ADV_COMMAND;
const int TileEntityDataPacket::TYPE_BEACON;
const int TileEntityDataPacket::TYPE_MOB_SPAWNER;
const int TileEntityDataPacket::TYPE_SKULL;

// ---------------------------------------------------------------------------
// IUIScene_CreativeMenu::TabSpec
// ---------------------------------------------------------------------------
const int IUIScene_CreativeMenu::TabSpec::MAX_SIZE;
