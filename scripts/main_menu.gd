extends Control

@onready var quit_button: Button = %QuitButton
@onready var _menu: Control = $Center
@onready var _credits: Control = %Credits


func _ready() -> void:
	# Quitting does nothing in a browser tab.
	quit_button.visible = not OS.has_feature("web")
	%PlayButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _credits.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		show_menu()


func show_credits() -> void:
	_menu.hide()
	_credits.show()
	%BackButton.grab_focus()


func show_menu() -> void:
	_credits.hide()
	_menu.show()
	%CreditsButton.grab_focus()


func _on_play_pressed() -> void:
	Game.new_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
