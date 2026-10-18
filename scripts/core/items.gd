class_name Items
extends RefCounted

# Static item definitions: display names, descriptions and inventory order. Inventory holds
# the counts; this holds what each item *is*. (Structure from the Viking demo's Items.)

## Inventory display order.
const ORDER: Array[StringName] = [&"gold", &"water", &"iron", &"wood", &"stone"]

const NAMES: Dictionary[StringName, String] = {
	&"gold": "Gold",
	&"water": "Water",
	&"iron": "Iron",
	&"wood": "Wood",
	&"stone": "Stone",
}

const DESCRIPTIONS: Dictionary[StringName, String] = {
	&"gold": "Glittering ore chipped from a gold vein. Valuable, if not especially useful on its own.",
	&"water": "Clear water drawn from a planet-side spring.",
	&"iron": "Rust-red iron ore. Heavy, and the backbone of anything worth building.",
	&"wood": "Timber cut from alien trees. Burns, bends, and builds.",
	&"stone": "Chunks of rock from a stone outcrop. Solid and plentiful.",
}

# Tile type -> item extracted from it (Unity's TileInteractionManager.ToResourceType).
const FROM_TILE: Dictionary[TileGrid.TileType, StringName] = {
	TileGrid.TileType.GOLD_ORE: &"gold",
	TileGrid.TileType.WATER_SPRING: &"water",
	TileGrid.TileType.IRON_DEPOSIT: &"iron",
	TileGrid.TileType.TIMBER: &"wood",
	TileGrid.TileType.STONE_OUTCROP: &"stone",
}


static func display_name(item: StringName) -> String:
	return NAMES.get(item, String(item).capitalize())


static func description(item: StringName) -> String:
	return DESCRIPTIONS.get(item, "")


# The item a tile yields when extracted, or &"" for tiles that yield nothing (Empty).
static func from_tile(type: TileGrid.TileType) -> StringName:
	return FROM_TILE.get(type, &"")
