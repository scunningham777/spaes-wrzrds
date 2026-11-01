class_name Foci
extends RefCounted

# Static focus definitions. A focus is one of the wizard's equippable items; the equipped ones
# (GameState.equipped_foci) each grant their own actions on top of the always-available ones, and
# their stats tune others (e.g. the orb's how far steps reveal). Same structure as Items: ids here,
# the equipped ids in GameState.

const STAFF := &"staff"
const ORB := &"orb"
const SYMBIOTE := &"neural_gill_symbiote"

const NAMES: Dictionary[StringName, String] = {
	STAFF: "Staff",
	ORB: "Orb",
	SYMBIOTE: "Neural Gill Symbiote",
}

## Action ids (input action names) each focus grants.
const ACTIONS: Dictionary[StringName, Array] = {
	STAFF: [&"extract"],
	ORB: [],
	SYMBIOTE: [],
}

## Per-focus stats. Staff: distance, tiles ahead of the player that extraction also needs (all
## sharing an element with the player's tile); extract_amount, items gained of each shared element.
## Orb: scry_radius, how far around the player each step reveals (see reveal_radius); landing_radius,
## how far around the landing tile is revealed on landing. Neural Gill Symbiote: collect_distance and
## collect_per_tile, for collecting aether on a step (see Aether.collect).
const STATS: Dictionary[StringName, Dictionary] = {
	STAFF: {"distance": 1, "extract_amount": 2},
	ORB: {"scry_radius": 2, "landing_radius": 2},
	SYMBIOTE: {"collect_distance": 1, "collect_per_tile": 1},
}

## How far around the landing tile is revealed when no equipped focus says (see landing_radius).
const DEFAULT_LANDING_RADIUS := 1
## How far around the player each step reveals when no equipped focus scries (see reveal_radius).
const DEFAULT_REVEAL_RADIUS := 1
## Collecting aether when no equipped focus says (see collect_distance and collect_per_tile): no
## tiles past the one neighbor it needs, and 1 aether a tile.
const DEFAULT_COLLECT_DISTANCE := 0
const DEFAULT_COLLECT_PER_TILE := 1


static func display_name(focus: StringName) -> String:
	return NAMES.get(focus, String(focus).capitalize())


static func actions(focus: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ACTIONS.get(focus, []))
	return result


static func grants(focus: StringName, action: StringName) -> bool:
	return action in actions(focus)


# The first of foci that grants action, or &"" if none does.
static func granting(foci: Array[StringName], action: StringName) -> StringName:
	for focus in foci:
		if grants(focus, action):
			return focus
	return &""


static func distance(focus: StringName) -> int:
	return STATS.get(focus, {}).get("distance", 0)


static func extract_amount(focus: StringName) -> int:
	return STATS.get(focus, {}).get("extract_amount", 0)


static func scry_radius(focus: StringName) -> int:
	return STATS.get(focus, {}).get("scry_radius", 0)


# How far around the landing tile is revealed with foci equipped: the widest any of them gives, or
# DEFAULT_LANDING_RADIUS if none gives one.
static func landing_radius(foci: Array[StringName]) -> int:
	return _widest(foci, "landing_radius", DEFAULT_LANDING_RADIUS)


# How far around the player each step reveals with foci equipped: the widest scry_radius any of
# them gives, or DEFAULT_REVEAL_RADIUS if none scries.
static func reveal_radius(foci: Array[StringName]) -> int:
	return _widest(foci, "scry_radius", DEFAULT_REVEAL_RADIUS)


# How far past the tile stepped onto and its first aether neighbor collecting reaches for more
# aether tiles with foci equipped: the farthest any gives, or DEFAULT_COLLECT_DISTANCE.
static func collect_distance(foci: Array[StringName]) -> int:
	return _widest(foci, "collect_distance", DEFAULT_COLLECT_DISTANCE)


# Aether collected per tile with foci equipped: the most any gives, or DEFAULT_COLLECT_PER_TILE.
static func collect_per_tile(foci: Array[StringName]) -> int:
	return _widest(foci, "collect_per_tile", DEFAULT_COLLECT_PER_TILE)


# The largest value of stat among foci, or fallback if none has it.
static func _widest(foci: Array[StringName], stat: String, fallback: int) -> int:
	var value := -1
	for focus in foci:
		value = maxi(value, STATS.get(focus, {}).get(stat, -1))
	return value if value >= 0 else fallback
