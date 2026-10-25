class_name TileGrid
extends RefCounted

# A planet's tiles, ported from Unity's TileExplore.TileGridManager. Holds only the tiles the
# player has revealed (add_tile); everywhere else is off the grid until something reveals it.
# On a torus, every method takes any copy of a coord and works on its stored copy (torus.canonical),
# and signals report stored copies; with no torus the grid is an unbounded plane.
#
# Extracting along a line of tiles yields the elements they all share.
#
# Extracting from a tile taps it rather than removing it. A tapped tile yields nothing until its
# cooldown, counted in player actions, runs out: whoever runs the actions calls tick_cooldowns()
# once per action.
#
# Each tile also has a move cost: the aether it takes to step onto it. It belongs to the spot, not
# the tile kind, so it stays put when tiles are replaced or swapped.

## Fires for revealed tiles too (add_tile).
signal tile_changed(coord: Vector2i, kind: TileKind)
## remaining is 0 when the tile becomes untapped.
signal tapped_changed(coord: Vector2i, remaining: int)

## The surface's wrapping, or null for an unbounded plane.
var torus: HexTorus
## This planet's tile kinds (TileKind.EMPTY is implied, not listed).
var kinds: Array[TileKind] = []
## Revealed tiles, by stored copy.
var tiles: Dictionary[Vector2i, TileKind] = {}
## Player actions a tile stays tapped after extraction.
var tap_cooldown: int = 5
## Tapped tiles -> actions left until they're untapped.
var cooldowns: Dictionary[Vector2i, int] = {}
## Revealed tiles -> aether it costs to step onto them; tiles that cost nothing are left out.
var move_costs: Dictionary[Vector2i, int] = {}


func _init(p_torus: HexTorus = null, p_kinds: Array[TileKind] = []) -> void:
	torus = p_torus
	kinds.assign(p_kinds)


# The stored copy of coord (coord itself on a plane).
func canonical(coord: Vector2i) -> Vector2i:
	return torus.canonical(coord) if torus != null else coord


# The copy of coord nearest reference (coord itself on a plane).
func nearest(coord: Vector2i, reference: Vector2i) -> Vector2i:
	return torus.nearest(coord, reference) if torus != null else coord


# This planet's kind with the given id (TileKind.EMPTY for its id), or null if it has none.
func find_kind(id: StringName) -> TileKind:
	if id == TileKind.EMPTY.id:
		return TileKind.EMPTY
	for kind in kinds:
		if kind.id == id:
			return kind
	return null


# Whether coord has been revealed.
func has_tile(coord: Vector2i) -> bool:
	return tiles.has(canonical(coord))


func get_tile(coord: Vector2i) -> TileKind:
	return tiles[canonical(coord)]


# Reveals a new tile at coord, costing move_cost aether to step onto.
func add_tile(coord: Vector2i, kind: TileKind, move_cost: int = 0) -> void:
	var key := canonical(coord)
	assert(not tiles.has(key), "Coord %s is already on the grid" % coord)
	tiles[key] = kind
	set_move_cost(key, move_cost)  # before tile_changed, so listeners see the new tile whole
	tile_changed.emit(key, kind)


# Aether it costs to step onto the tile at coord; 0 if it's free (or off the grid).
func move_cost(coord: Vector2i) -> int:
	return move_costs.get(canonical(coord), 0)


func set_move_cost(coord: Vector2i, cost: int) -> void:
	if cost > 0:
		move_costs[canonical(coord)] = cost
	else:
		move_costs.erase(canonical(coord))


# Replacing a tile drops any tapped state, which belonged to the old tile.
func set_tile(coord: Vector2i, kind: TileKind) -> void:
	var key := canonical(coord)
	assert(tiles.has(key), "Coord %s is not on the grid" % coord)
	tiles[key] = kind
	_set_cooldown(key, 0)  # before tile_changed, so listeners never see the old tile's state
	tile_changed.emit(key, kind)


func is_tapped(coord: Vector2i) -> bool:
	return cooldowns.has(canonical(coord))


# Actions left until the tile at coord is untapped; 0 if it isn't tapped.
func cooldown(coord: Vector2i) -> int:
	return cooldowns.get(canonical(coord), 0)


# The elements every tile at coords yields, in the first tile's order: what extracting them
# together would give. Empty if they share none, or any of them is off the grid or tapped.
func extractable_elements(coords: Array[Vector2i]) -> Array[StringName]:
	var shared: Array[StringName] = []
	if coords.is_empty() or not coords.all(func(c: Vector2i) -> bool: return has_tile(c) and not is_tapped(c)):
		return shared
	for element in get_tile(coords[0]).elements:
		if coords.all(func(c: Vector2i) -> bool: return element in get_tile(c).elements):
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
			_set_cooldown(canonical(c), tap_cooldown)
	return shared


func can_swap(a: Vector2i, b: Vector2i) -> bool:
	return has_tile(a) and has_tile(b) and (get_tile(a) != get_tile(b) or cooldown(a) != cooldown(b))


# Swaps the tiles at a and b, tapped state included. Returns false (no change) if either isn't
# part of the grid, or a swap would change nothing.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if not can_swap(a, b):
		return false
	var a_kind := get_tile(a)
	var a_cooldown := cooldown(a)
	var b_cooldown := cooldown(b)
	set_tile(a, get_tile(b))
	set_tile(b, a_kind)
	_set_cooldown(canonical(a), b_cooldown)
	_set_cooldown(canonical(b), a_cooldown)
	return true


# Counts one player action against every tapped tile's cooldown.
func tick_cooldowns() -> void:
	for coord: Vector2i in cooldowns.keys():
		_set_cooldown(coord, cooldowns[coord] - 1)


# key must be a stored copy.
func _set_cooldown(key: Vector2i, remaining: int) -> void:
	if remaining == cooldowns.get(key, 0):
		return
	if remaining > 0:
		cooldowns[key] = remaining
	else:
		cooldowns.erase(key)
	tapped_changed.emit(key, maxi(remaining, 0))
