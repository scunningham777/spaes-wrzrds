class_name ItemIcon
extends Control

# Placeholder icon for an inventory item: a square in the color of the tile it comes from.
# Replace _draw() with a TextureRect lookup once item sprites exist. (From the Viking demo.)

@export var item: StringName = &"":
	set(value):
		item = value
		queue_redraw()


static func color_for(p_item: StringName) -> Color:
	for type: TileGrid.TileType in Items.FROM_TILE:
		if Items.FROM_TILE[type] == p_item:
			return TileGridView.TILE_COLORS[type]
	return Color.MAGENTA


func _draw() -> void:
	if item.is_empty():
		return
	var side := minf(size.x, size.y) * 0.7
	draw_rect(Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), color_for(item))
