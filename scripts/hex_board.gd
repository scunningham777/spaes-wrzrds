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
## Size of a drawn tile relative to its hex cell; < 1 leaves gaps between tiles (Unity's sprite
## was 1/1.1). Shared by everything that draws tile-sized shapes, so they line up.
@export var tile_scale: float = 1.0 / 1.1
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


# A hex's corners in local (y-down) space around its center, scaled by `scale`; closed (first
# point repeated last) for polylines.
func corner_points(scale: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for c in layout.corner_offsets():
		points.append(Vector2(c.x, -c.y) * scale)
	return points


# Closed outline around a group of hexes, in local space around the origin hex's center: the cell
# edges (at full cell size) no other hex in coords shares. coords must form one patch without holes.
func region_outline(coords: Array[Vector2i]) -> PackedVector2Array:
	var corners := corner_points()
	# Corners keyed by rounded position, so neighbors' shared corners match exactly.
	var key := func(p: Vector2) -> Vector2i: return Vector2i((p * 8.0).round())
	var edges: Dictionary[Vector4i, bool] = {}
	for c in coords:
		var center := hex_to_local(c)
		for i in corners.size() - 1:
			var a: Vector2i = key.call(center + corners[i])
			var b: Vector2i = key.call(center + corners[i + 1])
			edges[Vector4i(a.x, a.y, b.x, b.y)] = true
	# Every cell runs its edges the same way round, so neighbors run a shared edge in opposite
	# directions. The rest are the boundary, each corner on it starting exactly one of them.
	var next: Dictionary[Vector2i, Vector2i] = {}
	for e: Vector4i in edges:
		if not edges.has(Vector4i(e.z, e.w, e.x, e.y)):
			next[Vector2i(e.x, e.y)] = Vector2i(e.z, e.w)
	var points := PackedVector2Array()
	if next.is_empty():
		return points
	var at: Vector2i = next.keys()[0]
	for i in next.size():
		points.append(Vector2(at) / 8.0)
		at = next[at]
	points.append(points[0])
	return points


func _draw() -> void:
	if not draw_outlines:
		return
	# Draw every hex whose center falls within the visible area (plus a margin), assuming the
	# board's origin is at the screen center (the Play scene's Camera2D sits at the origin).
	var half := get_viewport_rect().size / 2.0 + Vector2(hex_size, hex_size)
	var n := ceili((half.x + half.y) / hex_size) + 1
	var corners := corner_points()
	var outline := PackedVector2Array()
	outline.resize(corners.size())
	for q in range(-n, n + 1):
		for r in range(-n, n + 1):
			var center := hex_to_local(Vector2i(q, r))
			if absf(center.x) <= half.x and absf(center.y) <= half.y:
				for i in corners.size():
					outline[i] = center + corners[i]
				draw_polyline(outline, line_color, line_width)
