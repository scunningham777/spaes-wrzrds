class_name TileGrid
extends RefCounted

# Hexagon-shaped board of tiles, ported from Unity's TileExplore.TileGridManager. Starts all
# Empty; TileGridGenerator fills in the planet's tile kinds.
#
# Extracting along a line of tiles yields the elements they all share.
#
# Extracting from a tile taps it rather than removing it. A tapped tile yields nothing until its
# cooldown, counted in player actions, runs out: whoever runs the actions calls tick_cooldowns()
# once per action.

signal tile_changed(coord: Vector2i, kind: TileKind)
## remaining is 0 when the tile becomes untapped.
signal tapped_changed(coord: Vector2i, remaining: int)

var radius: int
## This planet's tile kinds (TileKind.EMPTY is implied, not listed).
var kinds: Array[TileKind] = []
var tiles: Dictionary[Vector2i, TileKind] = {}
## Player actions a tile stays tapped after extraction.
var tap_cooldown: int = 5
## Tapped tiles -> actions left until they're untapped.
var cooldowns: Dictionary[Vector2i, int] = {}


func _init(p_radius: int = 5, p_kinds: Array[TileKind] = []) -> void:
	radius = p_radius
	kinds.assign(p_kinds)
	for coord in Hex.hexagon(radius):
		tiles[coord] = TileKind.EMPTY


# This planet's kind with the given id (TileKind.EMPTY for its id), or null if it has none.
func find_kind(id: StringName) -> TileKind:
	if id == TileKind.EMPTY.id:
		return TileKind.EMPTY
	for kind in kinds:
		if kind.id == id:
			return kind
	return null


func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)


func get_tile(coord: Vector2i) -> TileKind:
	return tiles[coord]


# Replacing a tile drops any tapped state, which belonged to the old tile.
func set_tile(coord: Vector2i, kind: TileKind) -> void:
	assert(tiles.has(coord), "Coord %s is not on the grid" % coord)
	tiles[coord] = kind
	_set_cooldown(coord, 0)  # before tile_changed, so listeners never see the old tile's state
	tile_changed.emit(coord, kind)


func is_tapped(coord: Vector2i) -> bool:
	return cooldowns.has(coord)


# Actions left until the tile at coord is untapped; 0 if it isn't tapped.
func cooldown(coord: Vector2i) -> int:
	return cooldowns.get(coord, 0)


# The elements every tile at coords yields, in the first tile's order: what extracting them
# together would give. Empty if they share none, or any of them is off the grid or tapped.
func extractable_elements(coords: Array[Vector2i]) -> Array[StringName]:
	var shared: Array[StringName] = []
	if coords.is_empty() or not coords.all(func(c: Vector2i) -> bool: return tiles.has(c) and not is_tapped(c)):
		return shared
	for element in tiles[coords[0]].elements:
		if coords.all(func(c: Vector2i) -> bool: return element in tiles[c].elements):
			shared.append(element)
	return shared


func can_extract(coords: Array[Vector2i]) -> bool:
	return not extractable_elements(coords).is_empty()


# Taps every tile at coords and returns the elements they share, or [] (and changes nothing) if
# they share none. Ported from TileGridManager.TryExtractResource.
func try_extract(coords: Array[Vector2i]) -> Array[StringName]:
	var shared := extractable_elements(coords)
	if not shared.is_empty():
		for c in coords:
			_set_cooldown(c, tap_cooldown)
	return shared


func can_swap(a: Vector2i, b: Vector2i) -> bool:
	return tiles.has(a) and tiles.has(b) and (tiles[a] != tiles[b] or cooldown(a) != cooldown(b))


# Swaps the tiles at a and b, tapped state included. Returns false (no change) if either isn't
# part of the grid, or a swap would change nothing.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if not can_swap(a, b):
		return false
	var a_kind := tiles[a]
	var a_cooldown := cooldown(a)
	var b_cooldown := cooldown(b)
	set_tile(a, tiles[b])
	set_tile(b, a_kind)
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
