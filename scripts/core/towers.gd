class_name Towers
extends RefCounted

# Static tower definitions. A tower is built where two or more ley lines cross, on an iron tile
# that's been detected there (resonating with a line), and replaces that tile. Towers can't be
# pushed. Same structure as Items and Foci: ids and data here.

const BASIC := &"basic_tower"

const NAMES: Dictionary[StringName, String] = {
	BASIC: "Basic Tower",
}

## Items building each tower spends.
const COSTS: Dictionary[StringName, Dictionary] = {
	BASIC: {&"wood": 10, &"stone": 10},
}

## Aether it costs to step onto each tower.
const MOVE_COSTS: Dictionary[StringName, int] = {
	BASIC: 1,
}

# One shared TileKind per tower, like TileKind.EMPTY; built on first use.
static var _kinds: Dictionary[StringName, TileKind] = {}


static func display_name(tower: StringName) -> String:
	return NAMES.get(tower, String(tower).capitalize())


# The tile kind a built tower becomes: immovable, yielding nothing, its icon id is its own id.
static func kind(tower: StringName) -> TileKind:
	if not _kinds.has(tower):
		var no_elements: Array[StringName] = []
		_kinds[tower] = TileKind.new(tower, display_name(tower), tower, no_elements, false)
	return _kinds[tower]


static func cost(tower: StringName) -> Dictionary:
	return COSTS.get(tower, {})


# The cost as text, e.g. "10 Wood, 10 Stone".
static func cost_text(tower: StringName) -> String:
	var parts: Array[String] = []
	var items := cost(tower)
	for item: StringName in items:
		parts.append("%d %s" % [items[item], Items.display_name(item)])
	return ", ".join(parts)


static func can_afford(tower: StringName, inventory: Inventory) -> bool:
	var items := cost(tower)
	return items.keys().all(func(item: StringName) -> bool: return inventory.count(item) >= items[item])


# Whether a tower can go at coord: a detected iron tile (LeyLines.is_resonant) where lines cross.
static func can_build_at(grid: TileGrid, ley_lines: LeyLines, coord: Vector2i) -> bool:
	return ley_lines != null and ley_lines.is_resonant(grid, coord) and ley_lines.is_intersection(coord)


# Spends the tower's cost from inventory and replaces the tile at coord with it. Returns false
# (no change) if the site isn't valid or inventory can't afford it.
static func try_build(tower: StringName, grid: TileGrid, ley_lines: LeyLines, inventory: Inventory,
		coord: Vector2i) -> bool:
	if not can_build_at(grid, ley_lines, coord) or not can_afford(tower, inventory):
		return false
	var items := cost(tower)
	for item: StringName in items:
		inventory.spend(item, items[item])
	grid.set_move_cost(coord, MOVE_COSTS.get(tower, 0))  # before set_tile, so listeners see the tower whole
	grid.set_tile(coord, kind(tower))
	return true
