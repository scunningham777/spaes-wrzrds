class_name TileGridGenerator
extends RefCounted

# Random tile generation, ported from Unity's TileGridManager.GenerateGrid. A planet keeps its
# generator and calls reveal() as the player uncovers more of it, so tiles are rolled when they're
# first seen rather than all up front (what's revealed later can depend on what the player did).
#
# Each new tile is Empty with probability empty_probability, otherwise a uniformly random kind
# from the planet's kinds. Element requirements then override that, per revealed region: the
# start tile always yields the start elements, and each required element is topped up to its
# minimum tile count within the region, by turning tiles the region newly revealed.
#
# Each new tile's move cost is then rolled from its final kind: free within free_move_radius of
# the start tile, so the first steps of exploring don't drain aether; past that, tiles yielding a
# steady element always cost move_cost, and others cost rough_move_cost with probability
# rough_probability (move_cost otherwise).

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
## Elements the start tile always yields, so the player can extract what moving costs.
const START_ELEMENTS: Array[StringName] = [Aether.ITEM]
## Fewest tiles in each revealed region that yield each element, the start tile included.
const REQUIRED_ELEMENTS: Dictionary[StringName, int] = {Aether.ITEM: 2}

var kinds: Array[TileKind] = []
var empty_probability: float
var start_elements: Array[StringName] = []
var required_elements: Dictionary[StringName, int] = {}
var rng: RandomNumberGenerator
## Tiles within this many steps of the start tile cost nothing to step onto.
var free_move_radius: int = 5
## Aether most tiles past free_move_radius cost to step onto.
var move_cost: int = 1
## What the occasional rough tile costs instead, with probability rough_probability.
var rough_move_cost: int = 2
var rough_probability: float = 0.1
## Tiles yielding any of these are never rough.
var steady_elements: Array[StringName] = [Aether.ITEM]


# Pass a seeded rng for reproducible results; otherwise a randomized one is used. p_kinds defaults
# to default_kinds(). Every start and required element must be yielded by at least one kind.
func _init(p_empty_probability: float = 0.0, p_rng: RandomNumberGenerator = null,
		p_kinds: Array[TileKind] = [], p_start_elements: Array[StringName] = START_ELEMENTS,
		p_required_elements: Dictionary[StringName, int] = REQUIRED_ELEMENTS) -> void:
	empty_probability = p_empty_probability
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	kinds.assign(p_kinds if not p_kinds.is_empty() else default_kinds())
	start_elements.assign(p_start_elements)
	required_elements.assign(p_required_elements)


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
		p_rng: RandomNumberGenerator = null, p_kinds: Array[TileKind] = [],
		p_start_elements: Array[StringName] = START_ELEMENTS,
		p_required_elements: Dictionary[StringName, int] = REQUIRED_ELEMENTS) -> TileGrid:
	var generator := TileGridGenerator.new(p_empty_probability, p_rng, p_kinds, p_start_elements, p_required_elements)
	var grid := TileGrid.new(null, generator.kinds)
	generator.reveal(grid, Hex.hexagon(radius))
	return grid


# Adds a tile to grid at every coord of region it doesn't have yet, then applies the element
# requirements to the region. Returns the stored copies of the new tiles.
func reveal(grid: TileGrid, region: Array[Vector2i]) -> Array[Vector2i]:
	# Stored copies, deduplicated: on a small torus a region can overlap itself.
	var area: Array[Vector2i] = []
	for c in region:
		if not grid.canonical(c) in area:
			area.append(grid.canonical(c))
	var rolled: Dictionary[Vector2i, TileKind] = {}
	for key in area:
		if not grid.has_tile(key):
			rolled[key] = TileKind.EMPTY if rng.randf() < empty_probability \
				else kinds[rng.randi_range(0, kinds.size() - 1)]

	var start := grid.canonical(START_COORD)
	if rolled.has(start) and not start_elements.all(func(e: StringName) -> bool: return e in rolled[start].elements):
		rolled[start] = _pick_kind(start_elements)
	for element in required_elements:
		_require(grid, area, rolled, element, start)

	# Added only now, so listeners see each new tile once, in its final kind.
	for key in rolled:
		grid.add_tile(key, rolled[key], _roll_move_cost(grid, key, rolled[key]))
	return rolled.keys()


# Move cost for a new tile of kind at key (a stored copy), measured from the start tile's nearest
# copy so the free area wraps like everything else.
func _roll_move_cost(grid: TileGrid, key: Vector2i, kind: TileKind) -> int:
	if Hex.distance(grid.nearest(key, START_COORD), START_COORD) <= free_move_radius:
		return 0
	if kind.elements.any(func(e: StringName) -> bool: return e in steady_elements):
		return move_cost
	return rough_move_cost if rng.randf() < rough_probability else move_cost


# Turns random newly rolled tiles into kinds yielding element until required_elements[element]
# tiles in area yield it. Only tiles yielding no required element are turned (and never the
# start tile), so meeting one requirement can't undo another.
func _require(grid: TileGrid, area: Array[Vector2i], rolled: Dictionary[Vector2i, TileKind],
		element: StringName, start: Vector2i) -> void:
	var kind_at := func(key: Vector2i) -> TileKind: return rolled[key] if rolled.has(key) else grid.get_tile(key)
	var missing: int = required_elements[element] - area.filter(
		func(key: Vector2i) -> bool: return element in kind_at.call(key).elements).size()
	var open: Array = rolled.keys().filter(func(key: Vector2i) -> bool:
		return key != start and not rolled[key].elements.any(
			func(e: StringName) -> bool: return required_elements.has(e)))
	var elements: Array[StringName] = [element]
	while missing > 0 and not open.is_empty():
		rolled[open.pop_at(rng.randi_range(0, open.size() - 1))] = _pick_kind(elements)
		missing -= 1


# A random kind yielding all of elements.
func _pick_kind(elements: Array[StringName]) -> TileKind:
	var matches := kinds.filter(func(k: TileKind) -> bool:
		return elements.all(func(e: StringName) -> bool: return e in k.elements))
	assert(not matches.is_empty(), "No tile kind yields all of %s" % [elements])
	return matches[rng.randi_range(0, matches.size() - 1)]
