class_name TileGridGenerator
extends RefCounted

# Random tile generation, ported from Unity's TileGridManager.GenerateGrid. A planet keeps its
# generator and calls reveal() as the player uncovers more of it, so tiles are rolled when they're
# first seen rather than all up front (what's revealed later can depend on what the player did).
#
# Each new tile is Empty with probability empty_probability, otherwise a uniformly random kind
# from the planet's kinds. Tiles within free_move_radius of the start tile cost nothing to step
# onto, so the first steps of exploring don't drain aether, and are never rolled a kind yielding
# a free_zone_excluded element, so the player can't wander there extracting aether forever.
#
# Past free_move_radius, tiles yielding a steady element always cost move_cost, and others cost
# rough_move_cost with probability rough_probability (move_cost otherwise).

## Tile kinds every planet uses until generation rolls its own. Fields as in TileKind.
const DEFAULT_KINDS: Array[Dictionary] = [
	{"id": &"gold_ore", "name": "Gold Ore", "icon": &"gold_ore", "elements": [&"gold"]},
	{"id": &"aether_spring", "name": "Aether Spring", "icon": &"water_spring", "elements": [&"aether"]},
	{"id": &"iron_deposit", "name": "Iron Deposit", "icon": &"iron_deposit", "elements": [&"iron"]},
	{"id": &"timber", "name": "Timber", "icon": &"sapling", "elements": [&"wood"]},
	{"id": &"stone_outcrop", "name": "Stone Outcrop", "icon": &"stone_outcrop", "elements": [&"stone"]},
]

## Where the player lands on a planet.
const START_COORD := Vector2i.ZERO

var kinds: Array[TileKind] = []
var empty_probability: float
var rng: RandomNumberGenerator
## Tiles within this many steps of the start tile cost nothing to step onto.
var free_move_radius: int = 0
## Tiles within free_move_radius never yield any of these.
var free_zone_excluded: Array[StringName] = [Aether.ITEM]
## Aether most tiles past free_move_radius cost to step onto.
var move_cost: int = 1
## What the occasional rough tile costs instead, with probability rough_probability.
var rough_move_cost: int = 2
var rough_probability: float = 0.1
## Tiles yielding any of these are never rough.
var steady_elements: Array[StringName] = [Aether.ITEM]


# Pass a seeded rng for reproducible results; otherwise a randomized one is used. p_kinds defaults
# to default_kinds().
func _init(p_empty_probability: float = 0.0, p_rng: RandomNumberGenerator = null,
		p_kinds: Array[TileKind] = []) -> void:
	empty_probability = p_empty_probability
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	kinds.assign(p_kinds if not p_kinds.is_empty() else default_kinds())


# Fresh TileKinds built from DEFAULT_KINDS.
static func default_kinds() -> Array[TileKind]:
	var result: Array[TileKind] = []
	for data in DEFAULT_KINDS:
		var elements: Array[StringName] = []
		elements.assign(data["elements"])
		result.append(TileKind.new(data["id"], data["name"], data["icon"], elements))
	return result


# A plane grid with just a radius-sized hexagon around START_COORD revealed. Arguments as in _init.
static func generate(radius: int, p_empty_probability: float,
		p_rng: RandomNumberGenerator = null, p_kinds: Array[TileKind] = []) -> TileGrid:
	var generator := TileGridGenerator.new(p_empty_probability, p_rng, p_kinds)
	var grid := TileGrid.new(null, generator.kinds)
	generator.reveal(grid, Hex.hexagon(radius))
	return grid


# Adds a tile to grid at every coord of region it doesn't have yet. Returns the stored copies of
# the new tiles.
func reveal(grid: TileGrid, region: Array[Vector2i]) -> Array[Vector2i]:
	var free_kinds := kinds.filter(func(k: TileKind) -> bool:
		return not k.elements.any(func(e: StringName) -> bool: return e in free_zone_excluded))
	var added: Array[Vector2i] = []
	for c in region:
		var key := grid.canonical(c)
		# Also skips repeats: on a small torus a region can overlap itself.
		if grid.has_tile(key):
			continue
		var free := _is_free(grid, key)
		var pool: Array = free_kinds if free else kinds
		var kind: TileKind = TileKind.EMPTY if pool.is_empty() or rng.randf() < empty_probability \
			else pool[rng.randi_range(0, pool.size() - 1)]
		grid.add_tile(key, kind, 0 if free else _roll_move_cost(kind))
		added.append(key)
	return added


# Whether the tile at key (a stored copy) is within free_move_radius, measured from the start
# tile's nearest copy so the free area wraps like everything else.
func _is_free(grid: TileGrid, key: Vector2i) -> bool:
	return Hex.distance(grid.nearest(key, START_COORD), START_COORD) <= free_move_radius


# Move cost for a new tile of kind past free_move_radius.
func _roll_move_cost(kind: TileKind) -> int:
	if kind.elements.any(func(e: StringName) -> bool: return e in steady_elements):
		return move_cost
	return rough_move_cost if rng.randf() < rough_probability else move_cost
