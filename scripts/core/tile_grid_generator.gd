class_name TileGridGenerator
extends RefCounted

# Random tile generation, ported from Unity's TileGridManager.GenerateGrid: each tile is Empty
# with probability empty_probability, otherwise a uniformly random kind from the planet's kinds.

## Tile kinds every planet uses until generation rolls its own. Fields as in TileKind.
const DEFAULT_KINDS: Array[Dictionary] = [
	{"id": &"gold_ore", "name": "Gold Ore", "icon": &"gold_ore", "elements": [&"gold"]},
	{"id": &"water_spring", "name": "Water Spring", "icon": &"water_spring", "elements": [&"water"]},
	{"id": &"iron_deposit", "name": "Iron Deposit", "icon": &"iron_deposit", "elements": [&"iron"]},
	{"id": &"timber", "name": "Timber", "icon": &"sapling", "elements": [&"wood"]},
	{"id": &"stone_outcrop", "name": "Stone Outcrop", "icon": &"stone_outcrop", "elements": [&"stone"]},
]


# Fresh TileKinds built from DEFAULT_KINDS.
static func default_kinds() -> Array[TileKind]:
	var result: Array[TileKind] = []
	for data in DEFAULT_KINDS:
		var elements: Array[StringName] = []
		elements.assign(data["elements"])
		result.append(TileKind.new(data["id"], data["name"], data["icon"], elements))
	return result


# Pass a seeded rng for reproducible results; otherwise a randomized one is used. kinds defaults
# to default_kinds().
static func generate(radius: int, empty_probability: float,
		rng: RandomNumberGenerator = null, kinds: Array[TileKind] = []) -> TileGrid:
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
	return grid
