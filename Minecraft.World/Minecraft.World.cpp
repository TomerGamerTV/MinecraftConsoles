#include "stdafx.h"

#include "net.minecraft.world.item.h"
#include "net.minecraft.world.item.alchemy.h"
#include "net.minecraft.world.item.crafting.h"
#include "net.minecraft.world.item.enchantment.h"
#include "net.minecraft.world.level.chunk.h"
#include "net.minecraft.world.level.chunk.storage.h"
#include "net.minecraft.world.level.levelgen.structure.h"
#include "net.minecraft.world.level.tile.h"
#include "net.minecraft.world.level.tile.entity.h"
#include "net.minecraft.world.entity.h"
#include "net.minecraft.world.entity.monster.h"
#include "net.minecraft.world.entity.npc.h"
#include "net.minecraft.world.effect.h"

#include "Minecraft.World.h"
#include "../Minecraft.Client/ServerLevel.h"

#ifdef _DURANGO
#include "DurangoStats.h"
#else
#include "CommonStats.h"
#endif

void MinecraftWorld_RunStaticCtors()
{
	// The ordering of these static ctors can be important. If they are within statement blocks then
	// DO NOT CHANGE the ordering - 4J Stu

	fprintf(stderr, "[SC] Packet\n"); fflush(stderr);
	Packet::staticCtor();

	{
		fprintf(stderr, "[SC] MaterialColor\n"); fflush(stderr);
		MaterialColor::staticCtor();
		fprintf(stderr, "[SC] Material\n"); fflush(stderr);
		Material::staticCtor();
		fprintf(stderr, "[SC] Tile\n"); fflush(stderr);
		Tile::staticCtor();
		fprintf(stderr, "[SC] HatchetItem\n"); fflush(stderr);
		HatchetItem::staticCtor();
		fprintf(stderr, "[SC] PickaxeItem\n"); fflush(stderr);
		PickaxeItem::staticCtor();
		fprintf(stderr, "[SC] ShovelItem\n"); fflush(stderr);
		ShovelItem::staticCtor();
		fprintf(stderr, "[SC] BlockReplacements\n"); fflush(stderr);
		BlockReplacements::staticCtor();
		fprintf(stderr, "[SC] Biome\n"); fflush(stderr);
		Biome::staticCtor();
		fprintf(stderr, "[SC] MobEffect\n"); fflush(stderr);
		MobEffect::staticCtor();
		fprintf(stderr, "[SC] Item\n"); fflush(stderr);
		Item::staticCtor();
		FurnaceRecipes::staticCtor();
		Recipes::staticCtor();	
#ifdef _DURANGO
		GenericStats::setInstance(new DurangoStats());
#else
		GenericStats::setInstance(new CommonStats());
		Stats::staticCtor();
#endif
		//Achievements::staticCtor(); // 4J Stu - This is now called from within the Stats::staticCtor()
		TileEntity::staticCtor();
		EntityIO::staticCtor();
		MobCategory::staticCtor();

		Item::staticInit();
		LevelChunk::staticCtor();

		LevelType::staticCtor();

		{
			StructureFeatureIO::staticCtor();

			MineShaftPieces::staticCtor();
			StrongholdFeature::staticCtor();
			VillagePieces::Smithy::staticCtor();
			VillageFeature::staticCtor();
			RandomScatteredLargeFeature::staticCtor();
		}
	}
	EnderMan::staticCtor();
	PotionBrewing::staticCtor();
	Enchantment::staticCtor();

	SharedConstants::staticCtor();

	ServerLevel::staticCtor();
	SparseLightStorage::staticCtor();
	CompressedTileStorage::staticCtor();
	SparseDataStorage::staticCtor();
	McRegionChunkStorage::staticCtor();
	Villager::staticCtor();
	GameType::staticCtor();
	BeaconTileEntity::staticCtor();
}
