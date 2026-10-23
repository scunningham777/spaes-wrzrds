class_name TileGridGenerator
extends RefCounted

# Random tile generation, ported from Unity's TileGridManager.GenerateGrid: each tile is Empty
# with probability empty_probability, otherwise a uniformly random kind from the planet's kinds.
# Element requirements then override that: the start tile always yields the start elements, and
# each required element is topped up to its minimum tile count on other tiles.

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
## Fewest tiles that yield each element, the start tile included.
const REQUIRED_ELEMENTS: Dictionary[StringName, int] = {Aether.ITEM: 2}


# Fresh TileKinds built from DEFAULT_KINDS.
static func default_kinds() -> Array[TileKind]:
	var result: Array[TileKind] = []
	for data in DEFAULT_KINDS:
		var elements: Array[StringName] = []
		elements.assign(data["elements"])
		result.append(TileKind.new(data["id"], data["name"], data["icon"], elements))
	return result


# Pass a seeded rng for reproducible results; otherwise a randomized one is used. kinds defaults
# to default_kinds(). Every start and required element must be yielded by at least one kind.
static func generate(radius: int, empty_probability: float,
		rng: RandomNumberGenerator = null, kinds: Array[TileKind] = [],
		start_elements: Array[StringName] = START_ELEMENTS,
		required_elements: Dictionary[StringName, int] = REQUIRED_ELEMENTS) -> TileGrid:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if kinds.is_empty():
		kinds = default_kinds()

	var grid := TileGrid.new(radius, kinds)
	for coord in grid.tiles:
		if rng.randf() < empty_probability:
			grid.set_tile(coord, TileKind.EMPTY)
		else:
			grid.set_tile(coord, kinds[rng.randi_range(0, kinds.size() - 1)])

	var start := grid.get_tile(START_COORD)
	if not start_elements.all(func(e: StringName) -> bool: return e in start.elements):
		grid.set_tile(START_COORD, _pick_kind(kinds, start_elements, rng))
	for element in required_elements:
		_require(grid, element, required_elements, rng)
	return grid


# Turns random tiles into kinds yielding element until required_elements[element] tiles yield it.
# Only tiles yielding no required element are turned (and never the start tile), so meeting one
# requirement can't undo another.
static func _require(grid: TileGrid, element: StringName, required_elements: Dictionary[StringName, int],
		rng: RandomNumberGenerator) -> void:
	var missing: int = required_elements[element] - grid.tiles.values().filter(
		func(k: TileKind) -> bool: return element in k.elements).size()
	var open: Array = grid.tiles.keys().filter(func(c: Vector2i) -> bool:
		return c != START_COORD and not grid.get_tile(c).elements.any(
			func(e: StringName) -> bool: return required_elements.has(e)))
	var elements: Array[StringName] = [element]
	while missing > 0 and not open.is_empty():
		grid.set_tile(open.pop_at(rng.randi_range(0, open.size() - 1)), _pick_kind(grid.kinds, elements, rng))
		missing -= 1


# A random kind yielding all of elements.
static func _pick_kind(kinds: Array[TileKind], elements: Array[StringName], rng: RandomNumberGenerator) -> TileKind:
	var matches := kinds.filter(func(k: TileKind) -> bool:
		return elements.all(func(e: StringName) -> bool: return e in k.elements))
	assert(not matches.is_empty(), "No tile kind yields all of %s" % [elements])
	return matches[rng.randi_range(0, matches.size() - 1)]
