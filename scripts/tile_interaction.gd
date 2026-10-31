class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: runs the player's actions on the TileGrid
# around them. The player picks an action from the ones that make sense here (shown_actions; the
# scene shows them in the action bar) by its key or a click (select_action), which opens that
# action's phase (mode). Move (M) is the default phase, where the direction keys walk. In the
# others the player stays put:
# - Push (F): the direction keys pick the neighbor to swap the player's tile with; Enter or Space
#   swaps them.
# - Extract (R, from a focus, see Foci): the direction keys pick a line, the player's tile plus the
#   focus's distance that way; Enter or Space extracts the elements its tiles share.
# - Build (B, on a marked ley node): the number keys (or a click, choose_tower) pick a tower;
#   Enter or Space builds it if the tiles around have its elements.
# - Detect (S): see below.
# Mark Ley Node (N, where ley lines the player has seen cross) has no phase: it marks the node at
# once. A finished push, extract or build goes back to Move, and so do M and Esc from any phase;
# another action's key switches straight to that action. Push and extract share one picked
# direction, kept between phases. Animated actions hand their tween to the ActionLock, which blocks
# input until they finish.
#
# Detect mode needs an unknown tile within detect_radius of the player (see Detection). Other
# actions can't be picked there: the direction keys (and S, for the player's own tile) select a
# tile, the number keys guess its elements, Enter or Space submits, and M or Esc leaves. It ends by
# itself once every tile in reach is known.

## The phase changed (mode).
signal mode_changed(mode: StringName)
## The picked direction or tower changed.
signal selection_changed
signal detecting_changed(detecting: bool)

## Action ids, which are also their input action names, in action bar order.
const MOVE := &"move"
const PUSH := &"push"
const EXTRACT := &"extract"
const DETECT := &"detect"
const MARK_NODE := &"mark_node"
const BUILD := &"build_tower"
const ACTIONS: Array[StringName] = [MOVE, PUSH, EXTRACT, DETECT, MARK_NODE, BUILD]
const NAMES: Dictionary[StringName, String] = {
	MOVE: "Move", PUSH: "Push", EXTRACT: "Extract", DETECT: "Detect", MARK_NODE: "Mark Node", BUILD: "Build",
}

@export var player: HexPlayerController
@export var tiles: TileGridView
@export var lock: ActionLock
@export var swap_seconds: float = 0.3
## Detect mode covers the player's tile and every tile up to this many steps away.
@export var detect_radius: int = 1

## The planet being explored; assigned by the scene. tiles shows its grid.
var surface: PlanetSurface
## The open phase: one of ACTIONS other than MARK_NODE.
var mode: StringName = MOVE
## The direction push and extract aim (an axial delta), or null until one is picked.
var direction: Variant = null
## The tower the build phase would build.
var tower: StringName = Towers.BASIC
## The detect mode session, or null outside detect mode.
var detection: Detection
var detecting: bool:
	get:
		return detection != null


func _unhandled_input(event: InputEvent) -> void:
	if detecting:
		if _detect_input(event):
			get_viewport().set_input_as_handled()
		return
	var action: Variant = _action_pressed(event)
	if action != null:
		select_action(action)
		get_viewport().set_input_as_handled()
		return
	if mode == MOVE:
		return  # the player controller walks, and Esc leaves the planet
	var dir: Variant = HexPlayerController.move_direction(event, player.board.pointy_top)
	var number := _guess_index(event)
	if event.is_action_pressed("ui_cancel"):
		_set_mode(MOVE)
	elif event.is_action_pressed("confirm"):
		confirm()
	elif dir != null:
		if mode != BUILD:
			direction = Hex.delta(dir, player.board.pointy_top)
			selection_changed.emit()
	elif number >= 0 and mode == BUILD:
		if number < Towers.NAMES.size():
			choose_tower(Towers.NAMES.keys()[number])
	else:
		return
	get_viewport().set_input_as_handled()


# The actions that make sense here, in ACTIONS order: Move and Push always, Extract with a focus
# that grants it, and the rest where they'd work (or while their phase is open).
func shown_actions() -> Array[StringName]:
	var shown: Array[StringName] = []
	for action in ACTIONS:
		var show := true
		match action:
			EXTRACT: show = not Foci.granting(Game.state.equipped_foci, EXTRACT).is_empty()
			DETECT: show = detecting or can_detect_here()
			MARK_NODE: show = can_mark_node_here()
			BUILD: show = mode == BUILD or can_build_tower_here()
		if show:
			shown.append(action)
	return shown


# Whether action would do anything from here: Push needs a neighbor it could swap with, Extract a
# direction with something to extract; the others work wherever they show.
func can_act(action: StringName) -> bool:
	var here := player.mover.coord
	match action:
		PUSH:
			return Hex.clockwise_order(player.board.pointy_top).any(func(d: Hex.Compass) -> bool:
				return tiles.grid.can_swap(here, here + Hex.delta(d, player.board.pointy_top)))
		EXTRACT:
			return Hex.clockwise_order(player.board.pointy_top).any(func(d: Hex.Compass) -> bool:
				return tiles.grid.can_extract(extract_line(Hex.delta(d, player.board.pointy_top))))
	return true


# Picks action, as its key does: opens its phase (Move closes the open one), or marks a node right
# away. Does nothing unless it's shown here; in detect mode only Move works, leaving it.
func select_action(action: StringName) -> void:
	if not action in shown_actions():
		return
	if detecting:
		if action == MOVE:
			_end_detect()
		return
	match action:
		MARK_NODE:
			_set_mode(MOVE)
			_try_mark_node()
		DETECT:
			_try_detect()
		_:
			_set_mode(action)


# Runs the open phase's action with what's picked; on success it goes back to Move.
func confirm() -> void:
	var done := false
	match mode:
		PUSH: done = _try_swap()
		EXTRACT: done = _try_extract()
		BUILD: done = _try_build_tower()
	if done:
		_set_mode(MOVE)


func choose_tower(p_tower: StringName) -> void:
	if p_tower != tower and Towers.NAMES.has(p_tower):
		tower = p_tower
		selection_changed.emit()


# The tile push would swap the player's with, or null with no direction picked.
func push_target() -> Variant:
	return player.mover.coord + direction if direction != null else null


# Whether confirming the push phase would swap.
func can_push() -> bool:
	return direction != null and tiles.grid.can_swap(player.mover.coord, player.mover.coord + direction)


# The tiles extract takes from along dir (an axial delta; the picked direction by default): the
# player's tile plus the equipped focus's distance that way. Empty with no direction.
func extract_line(dir: Variant = direction) -> Array[Vector2i]:
	if dir == null:
		return []
	var staff := Foci.granting(Game.state.equipped_foci, EXTRACT)
	return Hex.line(player.mover.coord, dir, Foci.distance(staff))


# The elements extract would give right now; empty if the line shares none (or a tile is unknown or tapped).
func extract_preview() -> Array[StringName]:
	return tiles.grid.extractable_elements(extract_line())


# The tiles the open phase would act on, for the view to outline: push's target, or extract's line.
func target_tiles() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if mode == PUSH and direction != null:
		coords.append(push_target())
	elif mode == EXTRACT:
		coords = extract_line()
	return coords


# The tile the side panel describes: push's or extract's picked neighbor where there's one, or
# the player's own.
func info_coord() -> Vector2i:
	var here := player.mover.coord
	if mode in [PUSH, EXTRACT] and direction != null and tiles.grid.has_tile(here + direction):
		return here + direction
	return here


# Whether marking would mark a ley node on the player's tile. Uses the ley lines as the map shows
# them, so marking agrees with the plum tiles.
func can_mark_node_here() -> bool:
	return tiles.ley_lines != null and tiles.ley_lines.can_mark_node(tiles.grid, player.mover.coord)


# Whether the player's tile is a tower site (affordability aside): a marked node, on the ley lines
# the map shows.
func can_build_tower_here() -> bool:
	return Towers.can_build_at(tiles.grid, tiles.ley_lines, player.mover.coord)


# Whether the tiles on and around the player's tile have the chosen tower's elements.
func can_afford_tower() -> bool:
	return Towers.has_elements(tower, tiles.grid, player.mover.coord)


# The tiles detect mode covers, around the player.
func detect_area() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for offset in Hex.hexagon(detect_radius):
		coords.append(player.mover.coord + offset)
	return coords


# Whether detect mode would open here: an unknown tile is in reach.
func can_detect_here() -> bool:
	return tiles.grid.any_unknown(detect_area())


# The player stays put outside Move.
func _set_mode(p_mode: StringName) -> void:
	if p_mode == mode:
		return
	mode = p_mode
	player.mover.frozen = mode != MOVE
	print("Mode: %s" % mode)
	mode_changed.emit(mode)


# The action whose key event is, or null.
func _action_pressed(event: InputEvent) -> Variant:
	for action in ACTIONS:
		if event.is_action_pressed(action):
			return action
	return null


# Each successful action ticks tapped-tile cooldowns before taking effect, so the action that taps
# a tile doesn't count toward its own cooldown. (Moves tick too; the scene wires that up.) Pushes
# don't: pushing a tile back and forth would otherwise untap it for free.
# Extraction needs the player's tile plus the focus's distance in tiles the picked way, all
# untapped and sharing at least one element. Success taps them all and yields the focus's extract
# amount of each shared element, not one per tile.
func _try_extract() -> bool:
	var focus := Foci.granting(Game.state.equipped_foci, EXTRACT)
	var coords := extract_line()
	if focus.is_empty() or not tiles.grid.can_extract(coords):
		print("Nothing to extract along %s" % [coords])
		return false
	tiles.grid.tick_cooldowns()
	var amount := Foci.extract_amount(focus)
	var elements := tiles.grid.try_extract(coords)
	for element in elements:
		Game.state.inventory.add(element, amount)
	print("Extracted %d each of %s along %s" % [amount, elements, coords])
	return true


func _try_swap() -> bool:
	var here := player.mover.coord
	if not can_push():
		print("Can't push from %s toward %s" % [here, direction])
		return false
	var target: Vector2i = push_target()
	tiles.grid.try_swap(here, target)
	print("Swapped tiles %s and %s" % [here, target])
	lock.run(tiles.animate_swap(here, target, swap_seconds))
	return true


func _try_mark_node() -> void:
	var here := player.mover.coord
	if not can_mark_node_here():
		print("Can't mark a ley node at %s" % [here])
		return
	tiles.grid.tick_cooldowns()
	tiles.ley_lines.mark_node(tiles.grid, here)
	print("Marked a ley node at %s" % [here])


# Replaces the tile on the marked node under the player with the chosen tower, if the tiles on and
# around it have the elements it needs.
func _try_build_tower() -> bool:
	var here := player.mover.coord
	if not can_build_tower_here() or not can_afford_tower():
		print("Can't build a %s at %s (needs %s)" % [Towers.display_name(tower), here, Towers.requirement_text(tower)])
		return false
	tiles.grid.tick_cooldowns()
	Towers.try_build(tower, tiles.grid, tiles.ley_lines, here)
	print("Built a %s at %s" % [Towers.display_name(tower), here])
	return true


func _try_detect() -> void:
	if not can_detect_here():
		print("Nothing unknown to detect around %s" % [player.mover.coord])
		return
	detection = Detection.new(tiles.grid, detect_area())
	print("Detecting %s" % [detection.elements])
	_set_mode(DETECT)
	detecting_changed.emit(true)


# Discards the session's guesses and results.
func _end_detect() -> void:
	detection = null
	print("Stopped detecting")
	_set_mode(MOVE)
	detecting_changed.emit(false)


# Detect mode's keys; returns whether event was one of them (or one it blocks). The inventory still
# gets through.
func _detect_input(event: InputEvent) -> bool:
	var pointy_top := player.board.pointy_top
	var dir: Variant = HexPlayerController.move_direction(event, pointy_top)
	var guess := _guess_index(event)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(MOVE):
		_end_detect()
	elif event.is_action_pressed("confirm"):
		var learned := detection.submit()
		print("Detected %s" % [learned.map(func(k: TileKind) -> String: return k.display_name)])
		var colors: Dictionary[Vector2i, Color] = {}
		for c in detection.area:
			if tiles.grid.has_tile(c) and tiles.grid.get_tile(c) in learned:
				colors[c] = tiles.correct_color
		tiles.flash_tiles(colors)
		if detection.is_done():
			_end_detect()
	elif event.is_action_pressed(DETECT):
		detection.select(player.mover.coord)
	elif dir != null:
		detection.select(player.mover.coord + Hex.delta(dir, pointy_top))
	elif guess >= 0:
		detection.toggle(guess)
	else:
		return _action_pressed(event) != null
	return true


# Index of the number key pressed (guess_1 ... guess_10, for 1-9 then 0), or -1. Detect mode guesses
# with them, the build phase picks a tower.
func _guess_index(event: InputEvent) -> int:
	for i in Detection.MAX_ELEMENTS:
		if event.is_action_pressed("guess_%d" % (i + 1)):
			return i
	return -1
