class_name TileGrid
extends RefCounted

# Hexagon-shaped board of tiles, ported from Unity's TileExplore.TileGridManager. Starts all
# Empty; TileGridGenerator fills in resource types.

signal tile_changed(coord: Vector2i, type: TileType)

enum TileType {
	EMPTY,
	GOLD_ORE,
	WATER_SPRING,
	IRON_DEPOSIT,
	TIMBER,
	STONE_OUTCROP,
}

const TYPE_NAMES: Dictionary[TileType, String] = {
	TileType.EMPTY: "Empty",
	TileType.GOLD_ORE: "Gold Ore",
	TileType.WATER_SPRING: "Water Spring",
	TileType.IRON_DEPOSIT: "Iron Deposit",
	TileType.TIMBER: "Timber",
	TileType.STONE_OUTCROP: "Stone Outcrop",
}

var radius: int
var tiles: Dictionary[Vector2i, TileType] = {}


func _init(p_radius: int = 5) -> void:
	radius = p_radius
	for coord in Hex.hexagon(radius):
		tiles[coord] = TileType.EMPTY


static func display_name(type: TileType) -> String:
	return TYPE_NAMES.get(type, String(TileType.keys()[type]).capitalize())


func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)


func get_tile(coord: Vector2i) -> TileType:
	return tiles[coord]


func set_tile(coord: Vector2i, type: TileType) -> void:
	assert(tiles.has(coord), "Coord %s is not on the grid" % coord)
	tiles[coord] = type
	tile_changed.emit(coord, type)


# Empties the tile at coord and returns the type it held, or EMPTY if there was nothing to
# extract (no tile, or already Empty). Ported from TileGridManager.TryExtractResource.
func try_extract(coord: Vector2i) -> TileType:
	if not tiles.has(coord) or tiles[coord] == TileType.EMPTY:
		return TileType.EMPTY
	var extracted := tiles[coord]
	set_tile(coord, TileType.EMPTY)
	return extracted


# Swaps the tiles at a and b. Returns false (no change) if either isn't part of the grid, or
# both hold the same type so a swap would change nothing.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if not tiles.has(a) or not tiles.has(b) or tiles[a] == tiles[b]:
		return false
	var a_type := tiles[a]
	set_tile(a, tiles[b])
	set_tile(b, a_type)
	return true
