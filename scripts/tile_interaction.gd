class_name TileInteraction
extends Node

# Ported from Unity TileExplore.TileInteractionManager: maps interaction keys to TileGrid
# operations at the player's position/facing. Extract (R) comes later.

@export var player: HexPlayerController
@export var tiles: TileGridView


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("push"):
		_try_push()
		get_viewport().set_input_as_handled()


func _try_push() -> void:
	var mover := player.mover
	var front := mover.coord + mover.facing
	if tiles.grid.try_push_in_front(mover.coord, mover.facing):
		print("Pushed tile from %s to %s" % [front, front + mover.facing])
	else:
		print("Can't push tile from %s to %s" % [front, front + mover.facing])
