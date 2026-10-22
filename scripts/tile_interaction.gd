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


func _try_extract() -> void:
	var coord := player.mover.coord
	var extracted := tiles.grid.try_extract(coord)
	var item := Items.from_tile(extracted)
	if item.is_empty():
		print("Nothing to extract at %s" % coord)
		return
	Game.state.inventory.add(item)
	print("Extracted %s (%s) at %s" % [TileGrid.TileType.keys()[extracted], item, coord])


func _try_swap() -> void:
	var here := player.mover.coord
	var front := here + player.mover.facing
	if not tiles.grid.try_swap(here, front):
		print("Can't swap tiles %s and %s" % [here, front])
		return
	print("Swapped tiles %s and %s" % [here, front])
	lock.run(tiles.animate_swap(here, front, swap_seconds))
