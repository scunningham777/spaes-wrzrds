class_name TileInfo
extends Control

# Side-panel block describing one tile: its icon, name, and element (the item it yields), plus its
# tapped state. The scene decides which tile to show (e.g. the one under the player) and calls
# show_tile().

@onready var _icon: TextureRect = %TileIcon
@onready var _name: Label = %TileName
@onready var _yield: Label = %TileYield


# cooldown: actions until a tapped tile can be extracted again; 0 if it isn't tapped.
func show_tile(type: TileGrid.TileType, icon: Texture2D, cooldown: int = 0) -> void:
	_icon.texture = icon
	_name.text = TileGrid.display_name(type)
	var item := Items.from_tile(type)
	_yield.text = "Element: %s" % (Items.display_name(item) if not item.is_empty() else "none")
	if cooldown > 0:
		_yield.text += " (tapped, %d %s)" % [cooldown, "action" if cooldown == 1 else "actions"]


func shown_name() -> String:
	return _name.text


func shown_yield() -> String:
	return _yield.text
