class_name ItemIcon
extends Control

# Placeholder icon for an inventory item: a colored square. Replace _draw() with a TextureRect
# lookup once item sprites exist. (From the Viking demo.) Colors are kept separate from
# TileGridView's on purpose: an item needn't look like the map tile it was extracted from.

# Started as copies of the tile colors TileGridView used to draw.
const ITEM_COLORS: Dictionary[StringName, Color] = {
	&"gold": Color(1.0, 0.84, 0.0),
	&"aether": Color(0.3, 0.6, 1.0),
	&"iron": Color(0.65, 0.35, 0.3),
	&"wood": Color(0.4, 0.6, 0.3),
	&"stone": Color(0.6, 0.6, 0.6),
}

@export var item: StringName = &"":
	set(value):
		item = value
		queue_redraw()


static func color_for(p_item: StringName) -> Color:
	return ITEM_COLORS.get(p_item, Color.MAGENTA)


func _draw() -> void:
	if item.is_empty():
		return
	var side := minf(size.x, size.y) * 0.7
	draw_rect(Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), color_for(item))
