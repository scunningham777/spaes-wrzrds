class_name DirectionKeys
extends Control

# Side-panel diagram of the direction keys: a small hex for each neighbor of the player's tile,
# laid out like the board's and labelled with the key that moves (or picks) that way, around an
# empty middle hex for the player. The scene sets the orientation and keys; selected highlights one.

## Hex size (center to corner), in pixels.
@export var hex_size: float = 22.0
@export var line_color: Color = Color(1, 1, 1, 0.5)
@export var key_color: Color = Color.WHITE
@export var key_font_size: int = 18
## Fill of the selected hex.
@export var selected_color: Color = Color(1, 1, 1, 0.3)

var pointy_top := false:
	set(value):
		pointy_top = value
		_resize()
## Axial delta -> the key name shown on that neighbor.
var keys: Dictionary[Vector2i, String] = {}:
	set(value):
		keys = value
		queue_redraw()
## The highlighted neighbor (an axial delta), or null for none.
var selected: Variant = null:
	set(value):
		selected = value
		queue_redraw()


func _ready() -> void:
	_resize()


func _resize() -> void:
	var layout := HexLayout.new(pointy_top, hex_size)
	# Three hexes across the pointed axis, two plus two halves across the flat one.
	var across := 3.0 * 2.0 * layout.inner_radius()
	var along := 2.0 * hex_size + 2.0 * 1.5 * hex_size
	custom_minimum_size = Vector2(across, along) if pointy_top else Vector2(along, across)
	queue_redraw()


func _draw() -> void:
	var layout := HexLayout.new(pointy_top, hex_size)
	var font := ThemeDB.fallback_font
	var corners := layout.corner_offsets()
	var deltas: Array[Vector2i] = [Vector2i.ZERO]
	deltas.append_array(keys.keys())
	for delta in deltas:
		var point := layout.hex_to_point(delta)
		var center := size / 2.0 + Vector2(point.x, -point.y)  # layout is y-up
		var outline := PackedVector2Array()
		for corner in corners:
			outline.append(center + corner * 0.92)
		if selected != null and delta == selected:
			var fill := outline.duplicate()
			fill.remove_at(fill.size() - 1)  # polygons close themselves
			draw_colored_polygon(fill, selected_color)
		draw_polyline(outline, line_color, 2.0)
		if delta == Vector2i.ZERO:
			continue
		var text: String = keys[delta]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(key_font_size) / 2.0 - 2.0)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size, key_color)
