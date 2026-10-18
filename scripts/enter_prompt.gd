extends CanvasLayer

# Bottom-right "enter this location" overlay, ported from the Overworld's Enter Button.
# Clicking it is equivalent to pressing Enter.

signal enter_requested

@onready var _button: Button = $Button


func _ready() -> void:
	_button.pressed.connect(enter_requested.emit)
	hide_prompt()


func show_prompt(location: Enterable) -> void:
	_button.text = "Enter %s  [Enter]" % location.display_name
	_button.visible = true


func hide_prompt() -> void:
	_button.visible = false


func is_showing() -> bool:
	return _button.visible
