class_name TileGridView
extends Node2D

# Draws a TileGrid as filled hexes, ported from Unity's TileVisualManager/TileVisual. Must be a
# child of a HexBoard.

@export var radius: int = 5
## Tile size relative to the hex cell; < 1 leaves gaps between tiles (Unity's sprite was 1/1.1).
@export var tile_scale: float = 1.0 / 1.1
@export var empty_color: Color = Color(0.8, 0.8, 0.8, 0.5)

var grid: TileGrid

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	grid = TileGrid.new(radius)
	queue_redraw()


func color_for(type: TileGrid.TileType) -> Color:
	match type:
		TileGrid.TileType.EMPTY: return empty_color
	return Color.WHITE


func _draw() -> void:
	var corners := board.layout.corner_offsets()
	var tile := PackedVector2Array()
	for i in corners.size() - 1:  # drop the closing point; polygons close themselves
		tile.append(Vector2(corners[i].x, -corners[i].y) * tile_scale)
	for coord in grid.tiles:
		var center := board.hex_to_local(coord)
		var points := PackedVector2Array()
		for p in tile:
			points.append(center + p)
		draw_colored_polygon(points, color_for(grid.get_tile(coord)))
