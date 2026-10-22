class_name TileGrid
extends RefCounted

# Hexagon-shaped board of tiles, ported from Unity's TileExplore.TileGridManager. Starts all
# Empty; TileGridGenerator fills in resource types.
#
# Extracting from a tile taps it rather than removing it. A tapped tile yields nothing until its
# cooldown, counted in player actions, runs out: whoever runs the actions calls tick_cooldowns()
# once per action.

signal tile_changed(coord: Vector2i, type: TileType)
## remaining is 0 when the tile becomes untapped.
signal tapped_changed(coord: Vector2i, remaining: int)

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
## Player actions a tile stays tapped after extraction.
var tap_cooldown: int = 5
## Tapped tiles -> actions left until they're untapped.
var cooldowns: Dictionary[Vector2i, int] = {}


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


# Replacing a tile drops any tapped state, which belonged to the old tile.
func set_tile(coord: Vector2i, type: TileType) -> void:
	assert(tiles.has(coord), "Coord %s is not on the grid" % coord)
	tiles[coord] = type
	_set_cooldown(coord, 0)  # before tile_changed, so listeners never see the old tile's state
	tile_changed.emit(coord, type)


func is_tapped(coord: Vector2i) -> bool:
	return cooldowns.has(coord)


# Actions left until the tile at coord is untapped; 0 if it isn't tapped.
func cooldown(coord: Vector2i) -> int:
	return cooldowns.get(coord, 0)


func can_extract(coord: Vector2i) -> bool:
	return tiles.has(coord) and tiles[coord] != TileType.EMPTY and not is_tapped(coord)


# Taps the tile at coord and returns its type, or EMPTY if there was nothing to extract (no tile,
# Empty, or already tapped). Ported from TileGridManager.TryExtractResource.
func try_extract(coord: Vector2i) -> TileType:
	if not can_extract(coord):
		return TileType.EMPTY
	_set_cooldown(coord, tap_cooldown)
	return tiles[coord]


func can_swap(a: Vector2i, b: Vector2i) -> bool:
	return tiles.has(a) and tiles.has(b) and (tiles[a] != tiles[b] or cooldown(a) != cooldown(b))


# Swaps the tiles at a and b, tapped state included. Returns false (no change) if either isn't
# part of the grid, or a swap would change nothing.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if not can_swap(a, b):
		return false
	var a_type := tiles[a]
	var a_cooldown := cooldown(a)
	var b_cooldown := cooldown(b)
	set_tile(a, tiles[b])
	set_tile(b, a_type)
	_set_cooldown(a, b_cooldown)
	_set_cooldown(b, a_cooldown)
	return true


# Counts one player action against every tapped tile's cooldown.
func tick_cooldowns() -> void:
	for coord: Vector2i in cooldowns.keys():
		_set_cooldown(coord, cooldowns[coord] - 1)


func _set_cooldown(coord: Vector2i, remaining: int) -> void:
	if remaining == cooldown(coord):
		return
	if remaining > 0:
		cooldowns[coord] = remaining
	else:
		cooldowns.erase(coord)
	tapped_changed.emit(coord, maxi(remaining, 0))
