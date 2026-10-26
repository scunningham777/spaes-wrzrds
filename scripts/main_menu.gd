extends Control

@onready var quit_button: Button = %QuitButton
@onready var _menu: Control = $Center
@onready var _credits: Control = %Credits
@onready var _licenses: Control = %Licenses


func _ready() -> void:
	# Quitting does nothing in a browser tab.
	quit_button.visible = not OS.has_feature("web")
	(%Version as Label).text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.0")
	%PlayButton.grab_focus()


# Esc steps back: licenses to credits, credits to the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _licenses.visible:
		get_viewport().set_input_as_handled()
		show_credits()
	elif _credits.visible:
		get_viewport().set_input_as_handled()
		show_menu()


func show_credits() -> void:
	var from_licenses := _licenses.visible
	_menu.hide()
	_licenses.hide()
	_credits.show()
	(%LicensesButton if from_licenses else %BackButton).grab_focus()


func show_licenses() -> void:
	var text := %LicenseText as RichTextLabel
	if text.text.is_empty():
		text.text = license_text()
	_credits.hide()
	_licenses.show()
	%LicensesBackButton.grab_focus()


func show_menu() -> void:
	_credits.hide()
	_licenses.hide()
	_menu.show()
	%CreditsButton.grab_focus()


## Godot's license plus the copyright and license texts of the third-party code built into it,
## read from the engine so they stay current across engine upgrades.
static func license_text() -> String:
	var lines: PackedStringArray = [
		"This game uses Godot Engine, available under the following license:", "",
		Engine.get_license_text().strip_edges(), "", "",
		"Godot Engine includes third-party code under the following copyrights and licenses:", "",
	]
	for component: Dictionary in Engine.get_copyright_info():
		lines.append(component["name"])
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				lines.append("    © %s" % holder)
			lines.append("    License: %s" % part["license"])
		lines.append("")
	var licenses := Engine.get_license_info()
	for license: String in licenses:
		lines.append_array(["", "License: %s" % license, "", String(licenses[license]).strip_edges()])
	return "\n".join(lines)


func _on_play_pressed() -> void:
	Game.new_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
