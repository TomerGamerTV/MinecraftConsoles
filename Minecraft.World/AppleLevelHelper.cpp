// AppleLevelHelper.cpp - wrapper for game static methods with complex headers
// These headers have dependency chains that can't be included from Minecraft.Client.
// This file compiles in Minecraft.World context where all types are available.
#include "stdafx.h"
#include "Level.h"
#include "Tile.h"
#include "OldChunkStorage.h"

void AppleEnableLightingCache()
{
    Level::enableLightingCache();
}

void AppleTileCreateNewThreadStorage()
{
    Tile::CreateNewThreadStorage();
}

void AppleOldChunkStorageCreateNewThreadStorage()
{
    OldChunkStorage::CreateNewThreadStorage();
}
