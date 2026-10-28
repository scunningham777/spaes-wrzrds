class_name FocusBox
extends PanelContainer

# Side-panel box for one equipped focus (Foci): its name, over a hint line for each action it
# grants. The scene keeps the hints current (set_hint).

## The focus shown.
var focus: StringName

var _hints: Dictionary[StringName, Label] = {}


# Fills the box in for p_focus; call once it's in the tree.
func show_focus(p_focus: StringName) -> void:
	focus = p_focus
	(%FocusName as Label).text = Foci.display_name(focus)
	for action in Foci.actions(focus):
		var hint := Label.new()
		hint.add_theme_font_size_override(&"font_size", 20)
		%FocusActions.add_child(hint)
		_hints[action] = hint


func actions() -> Array[StringName]:
	return _hints.keys()


# Sets an action's hint line; ones that won't work from here dim.
func set_hint(action: StringName, text: String, available: bool = true) -> void:
	_hints[action].text = text
	_hints[action].modulate.a = 1.0 if available else 0.35


func hint(action: StringName) -> Label:
	return _hints[action]
