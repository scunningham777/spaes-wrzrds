class_name ActionBar
extends HBoxContainer

# Row of small square tiles along the bottom of the board, one per action the player can take
# here, each with its key and name. The scene decides which actions show and keeps them current
# (show_actions); clicking a tile asks for its action (action_pressed), like pressing its key.
# Tiles for actions that wouldn't do anything from here dim; the action whose phase is open is
# highlighted.

signal action_pressed(action: StringName)

## Tile size, and the key and name font sizes.
@export var tile_size: Vector2 = Vector2(84, 76)
@export var key_font_size: int = 24
@export var name_font_size: int = 14
## Tile fill, its outline, and the outline of the active tile.
@export var tile_color: Color = Color(0.08, 0.1, 0.16, 0.92)
@export var border_color: Color = Color(1, 1, 1, 0.35)
@export var active_color: Color = Color.WHITE
## Opacity of tiles for actions that wouldn't do anything from here.
@export var unavailable_alpha: float = 0.4

var _tiles: Dictionary[StringName, Button] = {}


# The first key bound to an input action, e.g. "R" for extract.
static func key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			return key.as_text_physical_keycode() if key.physical_keycode else key.as_text_keycode()
	return "?"


# Shows a tile for each of actions (input action ids), in order, named by names (action -> name).
# Those not in available dim; active (or none, for &"") is highlighted.
func show_actions(actions: Array[StringName], names: Dictionary, available: Array[StringName],
		active: StringName = &"") -> void:
	for action: StringName in _tiles.keys():
		if not action in actions:
			_tiles[action].queue_free()
			remove_child(_tiles[action])
			_tiles.erase(action)
	for i in actions.size():
		var action := actions[i]
		if not _tiles.has(action):
			_tiles[action] = _make_tile(action)
			add_child(_tiles[action])
		var tile := _tiles[action]
		move_child(tile, i)
		(tile.get_node("Layout/Name") as Label).text = names.get(action, String(action).capitalize())
		tile.modulate.a = 1.0 if action in available else unavailable_alpha
		_style(tile, action == active)


# The actions shown, in order.
func actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for child in get_children():
		if not child.is_queued_for_deletion():
			result.append(StringName(child.name))
	return result


# "R Extract": a tile's key and name, or "" if the action isn't shown.
func tile_text(action: StringName) -> String:
	if not _tiles.has(action):
		return ""
	return "%s %s" % [(_tiles[action].get_node("Layout/Key") as Label).text,
		(_tiles[action].get_node("Layout/Name") as Label).text]


func is_available(action: StringName) -> bool:
	return _tiles.has(action) and _tiles[action].modulate.a == 1.0


func is_active(action: StringName) -> bool:
	return _tiles.has(action) and _tiles[action].has_meta(&"active") and _tiles[action].get_meta(&"active")


func tile(action: StringName) -> Button:
	return _tiles.get(action)


# Never takes keyboard focus, so Enter and Space stay the phases' confirm keys.
func _make_tile(action: StringName) -> Button:
	var tile := Button.new()
	tile.name = String(action)
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(func() -> void: action_pressed.emit(action))
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override(&"separation", 2)
	tile.add_child(layout)
	for part: Array in [["Key", key_name(action), key_font_size], ["Name", "", name_font_size]]:
		var label := Label.new()
		label.name = part[0]
		label.text = part[1]
		label.add_theme_font_size_override(&"font_size", part[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(label)
	return tile


func _style(tile: Button, active: bool) -> void:
	tile.set_meta(&"active", active)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = tile_color.lightened(0.15) if state == &"hover" else tile_color
		box.border_color = active_color if active else border_color
		box.set_border_width_all(3 if active else 2)
		box.set_corner_radius_all(6)
		tile.add_theme_stylebox_override(state, box)
