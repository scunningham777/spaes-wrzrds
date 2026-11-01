class_name ItemIcon
extends Control

# Icon for an inventory item (a focus): its ICONS cell of icon_sheet, scaled up crisply to fit.
# Draws nothing for no item, or one without a cell. (Started as the Viking demo's colored squares.)

# Item pictures by Foci id: regions in icon_sheet (12px cells, 1px gutters: cell (col, row) is at
# 1 + 13 * col/row), as in TileGridView.ICONS.
const ICONS: Dictionary[StringName, Rect2] = {
	Foci.ORB: Rect2(352, 430, 12, 12),  # Cell (27, 33)
	Foci.SYMBIOTE: Rect2(53, 248, 12, 12),  # Cell (4, 19)
	Foci.STAFF: Rect2(599, 430, 12, 12),  # Cell (46, 33)
}

## Sprite sheet that ICONS regions are cut from; assigned by the owner (see InventoryPanel).
@export var icon_sheet: Texture2D:
	set(value):
		icon_sheet = value
		queue_redraw()
@export var item: StringName = &"":
	set(value):
		item = value
		queue_redraw()


static func has_icon(p_item: StringName) -> bool:
	return ICONS.has(p_item)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art: no blur when scaled


func _draw() -> void:
	if icon_sheet == null or not has_icon(item):
		return
	var region := ICONS[item]
	# Largest whole multiple of the cell that fits, so pixels stay square.
	var scale := maxf(1.0, floorf(minf(size.x / region.size.x, size.y / region.size.y)))
	var icon_size := region.size * scale
	draw_texture_rect_region(icon_sheet, Rect2((size - icon_size) / 2.0, icon_size), region)
