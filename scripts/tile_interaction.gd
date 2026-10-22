class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. R extracts, F swaps the player's tile with the
# one it faces. Animated actions hand their tween to the ActionLock, which blocks input until
# they finish.

@export var player: HexPlayerController
@export var tiles: TileGridView
@export var lock: ActionLock
@export var swap_seconds: float = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("extract"):
		_try_extract()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("push"):
		_try_swap()
		get_viewport().set_input_as_handled()


# Each successful action ticks tapped-tile cooldowns before taking effect, so the action that taps
# a tile doesn't count toward its own cooldown. (Moves tick too; the scene wires that up.)
# Extraction needs the player's tile plus the focus's distance in tiles straight ahead, all the
# same untapped type. Success taps them all but yields the focus's extract amount, not one per tile.
func _try_extract() -> void:
	var focus := Game.state.equipped_focus
	if not Foci.grants(focus, &"extract"):
		print("The equipped focus can't extract")
		return
	var coords := Hex.line(player.mover.coord, player.mover.facing, Foci.distance(focus))
	if not tiles.grid.can_extract(coords):
		print("Nothing to extract along %s" % [coords])
		return
	tiles.grid.tick_cooldowns()
	var extracted := tiles.grid.try_extract(coords)
	var item := Items.from_tile(extracted)
	if not item.is_empty():
		Game.state.inventory.add(item, Foci.extract_amount(focus))
	print("Extracted %s (%s) along %s" % [TileGrid.TileType.keys()[extracted], item, coords])


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
