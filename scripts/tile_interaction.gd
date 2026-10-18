class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. R extracts, F pushes.

@export var player: HexPlayerController
@export var tiles: TileGridView


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("extract"):
		_try_extract()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("push"):
		_try_push()
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


func _try_push() -> void:
	var mover := player.mover
	var front := mover.coord + mover.facing
	if tiles.grid.try_push_in_front(mover.coord, mover.facing):
		print("Pushed tile from %s to %s" % [front, front + mover.facing])
	else:
		print("Can't push tile from %s to %s" % [front, front + mover.facing])
