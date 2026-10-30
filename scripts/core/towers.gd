class_name Towers
extends RefCounted

# Static tower definitions. A tower is built on a marked ley node (LeyLines.mark_node) and
# replaces the tile there, activating every line through it (LeyLines.activate_at). Instead of
# spending items, it needs known tiles with the right elements on and around the node (see
# has_elements); those tiles stay as they are. Towers can't be pushed. Same structure as Items and
# Foci: ids and data here.

const BASIC := &"basic_tower"

const NAMES: Dictionary[StringName, String] = {
	BASIC: "Basic Tower",
}

## Element -> how many tiles within REACH of the node must have it, per tower. A tile with
## several elements counts toward each.
const REQUIREMENTS: Dictionary[StringName, Dictionary] = {
	BASIC: {&"stone": 3, &"iron": 2},
}
## How far from the node the tiles counted for REQUIREMENTS can be: 1 is the node and the ring
## around it.
const REACH := 1

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


static func requirements(tower: StringName) -> Dictionary:
	return REQUIREMENTS.get(tower, {})


# The requirements as text, e.g. "3 Stone, 2 Iron".
static func requirement_text(tower: StringName) -> String:
	var parts: Array[String] = []
	var elements := requirements(tower)
	for element: StringName in elements:
		parts.append("%d %s" % [elements[element], Items.display_name(element)])
	return ", ".join(parts)


# Whether enough known tiles within REACH of coord (coord's own included) have each required
# element. Unknown tiles count for nothing, as when extracting.
static func has_elements(tower: StringName, grid: TileGrid, coord: Vector2i) -> bool:
	var elements := requirements(tower)
	for element: StringName in elements:
		var count := 0
		for offset in Hex.hexagon(REACH):
			if grid.is_known(coord + offset) and element in grid.get_tile(coord + offset).elements:
				count += 1
		if count < elements[element]:
			return false
	return true


# Whether a tower can go at coord: a marked ley node without a tower on it yet.
static func can_build_at(grid: TileGrid, ley_lines: LeyLines, coord: Vector2i) -> bool:
	return ley_lines != null and ley_lines.is_node(coord) and grid.has_tile(coord) \
		and not NAMES.has(grid.get_tile(coord).id)


# Replaces the tile at coord with the tower. Returns false (no change) if the site isn't valid or
# the tiles around it lack the elements.
static func try_build(tower: StringName, grid: TileGrid, ley_lines: LeyLines, coord: Vector2i) -> bool:
	if not can_build_at(grid, ley_lines, coord) or not has_elements(tower, grid, coord):
		return false
	# Before set_tile, so listeners see the tower and its lines whole.
	grid.set_move_cost(coord, MOVE_COSTS.get(tower, 0))
	ley_lines.activate_at(coord)
	grid.set_tile(coord, kind(tower))
	return true
