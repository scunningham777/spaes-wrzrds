extends Control

const PLAY_SCENE := "res://scenes/play.tscn"

@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Quitting does nothing in a browser tab.
	quit_button.visible = not OS.has_feature("web")
	%PlayButton.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(PLAY_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
