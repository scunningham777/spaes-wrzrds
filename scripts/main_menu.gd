extends Control

@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Quitting does nothing in a browser tab.
	quit_button.visible = not OS.has_feature("web")
	%PlayButton.grab_focus()


func _on_play_pressed() -> void:
	Game.new_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
