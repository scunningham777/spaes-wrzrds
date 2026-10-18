extends Node2D

const MENU_SCENE := "res://scenes/main_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
