class_name TileGridView
extends Node2D

# Draws a TileGrid as filled hexes, ported from Unity's TileVisualManager/TileVisual. Must be a
# child of a HexBoard. Draws nothing until a grid is assigned. Types with an entry in TILE_ICONS
# draw that sprite-sheet icon over an Empty-colored hex; the rest are plain colored hexes.

## Tile size relative to the hex cell; < 1 leaves gaps between tiles (Unity's sprite was 1/1.1).
@export var tile_scale: float = 1.0 / 1.1
## Sprite sheet that TILE_ICONS regions are cut from.
@export var icon_sheet: Texture2D
## Icon pixel scale; matches the wizard sprite's.
@export var icon_scale: float = 4.0
## Seconds per step of the icon bob (0, up, 0, down). 0 turns the bob off.
@export var bob_step_seconds: float = 0.5
## Bob height in sprite pixels (scaled by icon_scale, so it stays on the art's pixel grid).
@export var bob_pixels: float = 1.0

# Colors from Unity's TileVisual.GetColorForType.
const TILE_COLORS: Dictionary[TileGrid.TileType, Color] = {
	TileGrid.TileType.EMPTY: Color.BLACK,  # Opaque so icons keep their contrast
	TileGrid.TileType.GOLD_ORE: Color(1.0, 0.84, 0.0),  # Gold
	TileGrid.TileType.WATER_SPRING: Color(0.3, 0.6, 1.0),  # Blue
	TileGrid.TileType.IRON_DEPOSIT: Color(0.65, 0.35, 0.3),  # Rust
	TileGrid.TileType.TIMBER: Color(0.4, 0.6, 0.3),  # Green-brown
	TileGrid.TileType.STONE_OUTCROP: Color(0.6, 0.6, 0.6),  # Gray
}

# Regions in icon_sheet (12px cells, 1px gutters: cell (col, row) is at 1 + 13 * col/row).
const TILE_ICONS: Dictionary[TileGrid.TileType, Rect2] = {
	TileGrid.TileType.GOLD_ORE: Rect2(105, 612, 12, 12),  # Cell (8, 47)
	TileGrid.TileType.WATER_SPRING: Rect2(378, 196, 12, 12),  # Cell (29, 15)
	TileGrid.TileType.IRON_DEPOSIT: Rect2(378, 40, 12, 12),  # Cell (29, 3)
	TileGrid.TileType.TIMBER: Rect2(144, 118, 12, 12),  # Cell (11, 9): sapling
	TileGrid.TileType.STONE_OUTCROP: Rect2(92, 183, 12, 12),  # Cell (7, 14)
}

# Icon y offsets per bob step, in sprite pixels (screen y-down, so -1 is up).
const BOB_STEPS: Array[float] = [0.0, -1.0, 0.0, 1.0]

var grid: TileGrid:
	set(value):
		if grid != null and grid.tile_changed.is_connected(_on_tile_changed):
			grid.tile_changed.disconnect(_on_tile_changed)
		grid = value
		if grid != null:
			grid.tile_changed.connect(_on_tile_changed)
		queue_redraw()

@onready var board: HexBoard = get_parent() as HexBoard

var bob_step: int = 0
var _bob_elapsed: float = 0.0


func has_icon(type: TileGrid.TileType) -> bool:
	return icon_sheet != null and TILE_ICONS.has(type)


# Hex fill color; icon tiles sit on the Empty color so the icon stands out.
func color_for(type: TileGrid.TileType) -> Color:
	if has_icon(type):
		return TILE_COLORS[TileGrid.TileType.EMPTY]
	return TILE_COLORS.get(type, Color.WHITE)


func _process(delta: float) -> void:
	if bob_step_seconds <= 0.0:
		return
	_bob_elapsed += delta
	if _bob_elapsed >= bob_step_seconds:
		_bob_elapsed = fmod(_bob_elapsed, bob_step_seconds)
		bob_step = (bob_step + 1) % BOB_STEPS.size()
		queue_redraw()


func bob_offset() -> Vector2:
	return Vector2(0.0, BOB_STEPS[bob_step] * bob_pixels * icon_scale)


func _on_tile_changed(_coord: Vector2i, _type: TileGrid.TileType) -> void:
	queue_redraw()


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
		var type := grid.get_tile(coord)
		draw_colored_polygon(points, color_for(type))
		if has_icon(type):
			var region := TILE_ICONS[type]
			var icon_size := region.size * icon_scale
			var icon_pos := center - icon_size / 2.0 + bob_offset()
			draw_texture_rect_region(icon_sheet, Rect2(icon_pos, icon_size), region)
