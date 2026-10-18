class_name TileGridView
extends Node2D

# Draws a TileGrid as filled hexes, ported from Unity's TileVisualManager/TileVisual. Must be a
# child of a HexBoard. Draws nothing until a grid is assigned.

## Tile size relative to the hex cell; < 1 leaves gaps between tiles (Unity's sprite was 1/1.1).
@export var tile_scale: float = 1.0 / 1.1

# Colors from Unity's TileVisual.GetColorForType.
const TILE_COLORS: Dictionary[TileGrid.TileType, Color] = {
	TileGrid.TileType.EMPTY: Color(0.8, 0.8, 0.8, 0.5),  # Transparent gray
	TileGrid.TileType.GOLD_ORE: Color(1.0, 0.84, 0.0),  # Gold
	TileGrid.TileType.WATER_SPRING: Color(0.3, 0.6, 1.0),  # Blue
	TileGrid.TileType.IRON_DEPOSIT: Color(0.65, 0.35, 0.3),  # Rust
	TileGrid.TileType.TIMBER: Color(0.4, 0.6, 0.3),  # Green-brown
	TileGrid.TileType.STONE_OUTCROP: Color(0.6, 0.6, 0.6),  # Gray
}

var grid: TileGrid:
	set(value):
		grid = value
		queue_redraw()

@onready var board: HexBoard = get_parent() as HexBoard


func color_for(type: TileGrid.TileType) -> Color:
	return TILE_COLORS.get(type, Color.WHITE)


func _draw() -> void:
	if grid == null:
		return
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
