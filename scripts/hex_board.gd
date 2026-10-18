class_name HexBoard
extends Node2D

# Owns the hex layout (orientation + size) and draws the grid outlines. Anything positioned on
# the grid (e.g. HexPlayerController) should be a child of the board and convert coordinates
# through it, so layout settings live in exactly one place.
#
# Coordinates are axial (q, r) stored in a Vector2i. The axial math is written y-up to match the
# original Unity code; hex_to_local() flips y for Godot's y-down screen space.

@export var pointy_top: bool = true
@export var hex_size: float = 36.0  # center-to-corner radius, in pixels
@export var line_color: Color = Color.WHITE
@export var line_width: float = 1.0

const SQRT_3 := 1.7320508075688772


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func hex_to_local(coord: Vector2i) -> Vector2:
	var x: float
	var y: float
	if pointy_top:
		x = hex_size * SQRT_3 * (coord.x + coord.y / 2.0)
		y = hex_size * 1.5 * coord.y
	else:
		x = hex_size * 1.5 * coord.x
		y = hex_size * (SQRT_3 / 2.0 * coord.x + SQRT_3 * coord.y)
	return Vector2(x, -y)


func hex_corners(center: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var start_deg := 30.0 if pointy_top else 0.0
	for i in 7:  # 7 points so the polyline closes
		var angle := deg_to_rad(start_deg + 60.0 * i)
		corners.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return corners


func _draw() -> void:
	# Draw every hex whose center falls within the visible area (plus a margin), assuming the
	# board's origin is at the screen center (the Play scene's Camera2D sits at the origin).
	var half := get_viewport_rect().size / 2.0 + Vector2(hex_size, hex_size)
	var n := ceili((half.x + half.y) / hex_size) + 1
	for q in range(-n, n + 1):
		for r in range(-n, n + 1):
			var center := hex_to_local(Vector2i(q, r))
			if absf(center.x) <= half.x and absf(center.y) <= half.y:
				draw_polyline(hex_corners(center), line_color, line_width)
