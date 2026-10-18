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

var radius: int
var tiles: Dictionary[Vector2i, TileType] = {}


func _init(p_radius: int = 5) -> void:
	radius = p_radius
	for coord in Hex.hexagon(radius):
		tiles[coord] = TileType.EMPTY


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


# Pushes the tile at from_coord into to_coord. If to_coord is Empty, the tile simply moves.
# If to_coord already holds something, the two combine (placeholder rule) into to_coord.
# Returns false (no change) if from_coord has nothing to push, or to_coord isn't part of the grid.
func try_push_tile(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if not tiles.has(from_coord) or tiles[from_coord] == TileType.EMPTY:
		return false
	if not tiles.has(to_coord):
		return false

	var from_type := tiles[from_coord]
	var to_type := tiles[to_coord]
	set_tile(to_coord, from_type if to_type == TileType.EMPTY else _combine_placeholder(from_type, to_type))
	set_tile(from_coord, TileType.EMPTY)
	return true


# Pushes the tile directly in front of an actor one more hex along its facing.
func try_push_in_front(actor_coord: Vector2i, facing: Vector2i) -> bool:
	var front := actor_coord + facing
	return try_push_tile(front, front + facing)


# Deterministic stand-in for real combine recipes, which don't exist yet.
static func _combine_placeholder(a: TileType, b: TileType) -> TileType:
	var non_empty_count := TileType.size() - 1
	var combined_index := (a - 1 + b - 1) % non_empty_count
	return (combined_index + 1) as TileType
