extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc returns to space.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.leave_location()
