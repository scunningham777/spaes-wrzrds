class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. R extracts, F swaps the player's tile with the
# one it faces, V scries (reveals the next patch of the planet). Animated actions hand their
# tween to the ActionLock, which blocks input until they finish.

@export var player: HexPlayerController
@export var tiles: TileGridView
@export var lock: ActionLock
@export var swap_seconds: float = 0.3

## The planet being explored, for scrying; assigned by the scene. tiles shows its grid.
var surface: PlanetSurface


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("extract"):
		_try_extract()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("push"):
		_try_swap()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scry"):
		_try_scry()
		get_viewport().set_input_as_handled()


# The tiles R would extract: the player's tile plus the equipped focus's distance straight ahead.
func extract_line() -> Array[Vector2i]:
	return Hex.line(player.mover.coord, player.mover.facing, Foci.distance(Game.state.equipped_focus))


# The elements R would extract right now; empty if the line shares none (or a tile is tapped).
func extract_preview() -> Array[StringName]:
	return tiles.grid.extractable_elements(extract_line())


# Each successful action ticks tapped-tile cooldowns before taking effect, so the action that taps
# a tile doesn't count toward its own cooldown. (Moves tick too; the scene wires that up.)
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
	tiles.grid.tick_cooldowns()
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
