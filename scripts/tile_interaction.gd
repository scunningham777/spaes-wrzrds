class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. R extracts, F swaps the player's tile with the
# one it faces, V scries (next to unrevealed tiles, reveals every tile within the orb's scry radius),
# B builds a tower (on a detected iron tile where ley lines cross). Extract and scry come from the
# equipped foci (Foci). Animated actions hand their tween to the ActionLock, which
# blocks input until they finish.
#
# S enters detect mode, where there's an unknown tile within detect_radius of the player (see
# Detection). The player can't move, turn, or take other actions there: the direction keys (and S,
# for the player's own tile) select a tile, the number keys guess its elements, Enter or Space
# submits, and Esc leaves. It ends by itself once every tile in reach is known.

signal detecting_changed(detecting: bool)

@export var player: HexPlayerController
@export var tiles: TileGridView
@export var lock: ActionLock
@export var swap_seconds: float = 0.3
## Detect mode covers the player's tile and every tile up to this many steps away.
@export var detect_radius: int = 1

## The planet being explored, for scrying; assigned by the scene. tiles shows its grid.
var surface: PlanetSurface
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
	if event.is_action_pressed("detect"):
		_try_detect()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("extract"):
		_try_extract()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("push"):
		_try_swap()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scry"):
		_try_scry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_tower"):
		_try_build_tower()
		get_viewport().set_input_as_handled()


# The tiles R would extract: the player's tile plus the equipped focus's distance straight ahead.
func extract_line() -> Array[Vector2i]:
	var staff := Foci.granting(Game.state.equipped_foci, &"extract")
	return Hex.line(player.mover.coord, player.mover.facing, Foci.distance(staff))


# Whether V would scry here: a focus grants it, and a tile next to the player is unrevealed.
func can_scry_here() -> bool:
	return surface != null and not Foci.granting(Game.state.equipped_foci, &"scry").is_empty() \
		and surface.next_to_unrevealed(player.mover.coord)


# Whether the player's tile is a tower site (affordability aside). Uses the ley lines as the map
# shows them, so building agrees with the plum tiles.
func can_build_tower_here() -> bool:
	return Towers.can_build_at(tiles.grid, tiles.ley_lines, player.mover.coord)


# The tiles detect mode covers, around the player.
func detect_area() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for offset in Hex.hexagon(detect_radius):
		coords.append(player.mover.coord + offset)
	return coords


# Whether S would enter detect mode here: an unknown tile is in reach.
func can_detect_here() -> bool:
	return tiles.grid.any_unknown(detect_area())


# The elements R would extract right now; empty if the line shares none (or a tile is unknown or tapped).
func extract_preview() -> Array[StringName]:
	return tiles.grid.extractable_elements(extract_line())


# Each successful action ticks tapped-tile cooldowns before taking effect, so the action that taps
# a tile doesn't count toward its own cooldown. (Moves tick too; the scene wires that up.) Pushes
# don't: pushing a tile back and forth would otherwise untap it for free.
# Extraction needs the player's tile plus the focus's distance in tiles straight ahead, all
# untapped and sharing at least one element. Success taps them all and yields the focus's extract
# amount of each shared element, not one per tile.
func _try_extract() -> void:
	var focus := Foci.granting(Game.state.equipped_foci, &"extract")
	if focus.is_empty():
		print("No equipped focus can extract")
		return
	var coords := extract_line()
	if not tiles.grid.can_extract(coords):
		print("Nothing to extract along %s" % [coords])
		return
	tiles.grid.tick_cooldowns()
	var amount := Foci.extract_amount(focus)
	var elements := tiles.grid.try_extract(coords)
	for element in elements:
		Game.state.inventory.add(element, amount)
	print("Extracted %d each of %s along %s" % [amount, elements, coords])


func _try_swap() -> void:
	var here := player.mover.coord
	var front := here + player.mover.facing
	if not tiles.grid.can_swap(here, front):
		print("Can't swap tiles %s and %s" % [here, front])
		return
	tiles.grid.try_swap(here, front)
	print("Swapped tiles %s and %s" % [here, front])
	lock.run(tiles.animate_swap(here, front, swap_seconds))


# Scrying works next to an unrevealed tile and reveals every tile within the scrying focus's
# scry_radius of the player.
func _try_scry() -> void:
	var here := player.mover.coord
	if not can_scry_here():
		print("Can't scry from %s" % [here])
		return
	tiles.grid.tick_cooldowns()
	var revealed := surface.reveal_around(here, Foci.scry_radius(Foci.granting(Game.state.equipped_foci, &"scry")))
	print("Scried %d tiles around %s" % [revealed.size(), here])


# Replaces the detected iron tile under the player with a tower, spending its cost.
func _try_build_tower() -> void:
	var here := player.mover.coord
	if not can_build_tower_here():
		print("Can't build a tower at %s" % [here])
		return
	if not Towers.can_afford(Towers.BASIC, Game.state.inventory):
		print("Building a tower needs %s" % Towers.cost_text(Towers.BASIC))
		return
	tiles.grid.tick_cooldowns()
	Towers.try_build(Towers.BASIC, tiles.grid, tiles.ley_lines, Game.state.inventory, here)
	print("Built a %s at %s" % [Towers.display_name(Towers.BASIC), here])


func _try_detect() -> void:
	if not can_detect_here():
		print("Nothing unknown to detect around %s" % [player.mover.coord])
		return
	detection = Detection.new(tiles.grid, detect_area())
	player.mover.frozen = true
	print("Detecting %s" % [detection.elements])
	detecting_changed.emit(true)


# Discards the session's guesses and results.
func _end_detect() -> void:
	detection = null
	player.mover.frozen = false
	print("Stopped detecting")
	detecting_changed.emit(false)


# Detect mode's keys; returns whether event was one of them (or one it blocks). The inventory still
# gets through.
func _detect_input(event: InputEvent) -> bool:
	var pointy_top := player.board.pointy_top
	var dir: Variant = HexPlayerController.move_direction(event, pointy_top)
	var guess := _guess_index(event)
	if event.is_action_pressed("ui_cancel"):
		_end_detect()
	elif event.is_action_pressed("submit_guess"):
		var learned := detection.submit()
		print("Detected %s" % [learned.map(func(k: TileKind) -> String: return k.display_name)])
		var colors: Dictionary[Vector2i, Color] = {}
		for c in detection.area:
			if tiles.grid.has_tile(c) and tiles.grid.get_tile(c) in learned:
				colors[c] = tiles.correct_color
		tiles.flash_tiles(colors)
		if detection.is_done():
			_end_detect()
	elif event.is_action_pressed("detect"):
		detection.select(player.mover.coord)
	elif dir != null:
		detection.select(player.mover.coord + Hex.delta(dir, pointy_top))
	elif guess >= 0:
		detection.toggle(guess)
	else:
		return HexPlayerController.turn_step(event, pointy_top) != 0 \
			or [&"extract", &"push", &"scry", &"build_tower"].any(event.is_action_pressed)
	return true


# Index in the element list of the number key pressed (guess_1 ... guess_10, for 1-9 then 0), or -1.
func _guess_index(event: InputEvent) -> int:
	for i in Detection.MAX_ELEMENTS:
		if event.is_action_pressed("guess_%d" % (i + 1)):
			return i
	return -1
