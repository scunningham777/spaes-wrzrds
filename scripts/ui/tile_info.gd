class_name TileInfo
extends Control

# Side-panel block describing one tile: its icon, name, and the item extracting it yields. The
# scene decides which tile to show (e.g. the one under the player) and calls show_tile().

@onready var _icon: TextureRect = %TileIcon
@onready var _name: Label = %TileName
@onready var _yield: Label = %TileYield


func show_tile(type: TileGrid.TileType, icon: Texture2D) -> void:
	_icon.texture = icon
	_name.text = TileGrid.display_name(type)
	var item := Items.from_tile(type)
	_yield.text = "Extracts: %s" % Items.display_name(item) if not item.is_empty() else "Nothing to extract"


func shown_name() -> String:
	return _name.text


func shown_yield() -> String:
	return _yield.text
