class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. R extracts, F swaps the player's tile with the
# one it faces, V scries (reveals the next patch of the planet), B builds a tower (on a detected
# iron tile where ley lines cross). Animated actions hand their tween to the ActionLock, which
# blocks input until they finish.
#
# S enters detect mode, where there's an unknown tile within detect_radius of the player: the
# player can't move or take other actions (turning still works) until S or Esc leaves it.

signal detecting_changed(detecting: bool)

@export var player: HexPlayerController
@export var tiles: TileGridView
@export var lock: ActionLock
@export var swap_seconds: float = 0.3
## Detect mode covers the player's tile and every tile up to this many steps away.
@export var detect_radius: int = 1

## The planet being explored, for scrying; assigned by the scene. tiles shows its grid.
var surface: PlanetSurface
var detecting := false


func _unhandled_input(event: InputEvent) -> void:
	if detecting:
		if event.is_action_pressed("detect") or event.is_action_pressed("ui_cancel"):
			_set_detecting(false)
			get_viewport().set_input_as_handled()
		elif [&"extract", &"push", &"scry", &"build_tower"].any(event.is_action_pressed):
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
	return Hex.line(player.mover.coord, player.mover.facing, Foci.distance(Game.state.equipped_focus))


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
	var focus := Game.state.equipped_focus
	if not Foci.grants(focus, &"extract"):
		print("The equipped focus can't extract")
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


# Scrying works from the middle of the explored area's edge (see PlanetSurface.scry_target) and
# reveals the patch beyond it.
func _try_scry() -> void:
	var here := player.mover.coord
	if surface == null or not surface.can_scry(here):
		print("Nothing to scry from %s" % [here])
		return
	tiles.grid.tick_cooldowns()
	var target: Vector2i = surface.scry_target(here)
	surface.try_scry(here)
	print("Scried the patch around %s" % [target])


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
	_set_detecting(true)


# Detect mode holds the player in place.
func _set_detecting(value: bool) -> void:
	detecting = value
	player.mover.frozen = value
	print("Detect mode %s" % ["on" if value else "off"])
	detecting_changed.emit(value)
