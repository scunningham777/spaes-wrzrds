class_name HexBoard
extends Node2D

# View adapter for the hex grid: owns the HexLayout (orientation + size) and draws the grid
# outlines. Anything positioned on the grid should be a child of the board and convert
# coordinates through hex_to_local(), so layout settings live in exactly one place.

@export var pointy_top: bool = true:
	set(value):
		pointy_top = value
		if layout:
			layout.pointy_top = value
		queue_redraw()
@export var hex_size: float = 36.0:  # center-to-corner radius, in pixels
	set(value):
		hex_size = value
		if layout:
			layout.size = value
		queue_redraw()
@export var draw_outlines: bool = true
@export var line_color: Color = Color.WHITE
@export var line_width: float = 1.0

var layout: HexLayout


# Default values don't go through setters, so the layout starts from them here; values assigned
# afterward (from the scene file, the inspector, or code) sync through the setters above. Built
# in _init rather than _ready so it's valid in children's _ready(), which runs first.
func _init() -> void:
	layout = HexLayout.new(pointy_top, hex_size)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


# HexLayout is y-up; Godot's 2D screen space is y-down.
func hex_to_local(coord: Vector2i) -> Vector2:
	var p := layout.hex_to_point(coord)
	return Vector2(p.x, -p.y)


func _draw() -> void:
	if not draw_outlines:
		return
	# Draw every hex whose center falls within the visible area (plus a margin), assuming the
	# board's origin is at the screen center (the Play scene's Camera2D sits at the origin).
	var half := get_viewport_rect().size / 2.0 + Vector2(hex_size, hex_size)
	var n := ceili((half.x + half.y) / hex_size) + 1
	var corners := layout.corner_offsets()
	var outline := PackedVector2Array()
	outline.resize(corners.size())
	for q in range(-n, n + 1):
		for r in range(-n, n + 1):
			var center := hex_to_local(Vector2i(q, r))
			if absf(center.x) <= half.x and absf(center.y) <= half.y:
				for i in corners.size():
					outline[i] = center + Vector2(corners[i].x, -corners[i].y)
				draw_polyline(outline, line_color, line_width)
