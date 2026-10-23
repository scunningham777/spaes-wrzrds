class_name TileInfo
extends Control

# Side-panel block describing one tile: its icon, name, and elements (the items it yields), plus its
# tapped state. The scene decides which tile to show (e.g. the one under the player) and calls
# show_tile().

@onready var _icon: TextureRect = %TileIcon
@onready var _name: Label = %TileName
@onready var _tapped: Label = %TileTapped
@onready var _yield: Label = %TileYield


# cooldown: actions until a tapped tile can be extracted again; 0 if it isn't tapped.
func show_tile(kind: TileKind, icon: Texture2D, cooldown: int = 0) -> void:
	_icon.texture = icon
	_name.text = kind.display_name
	# Tapped affects the whole tile, so it sits beside the name rather than the element.
	_tapped.visible = cooldown > 0
	_tapped.text = "tapped: %d" % cooldown
	_yield.text = "%s: %s" % ["Elements" if kind.elements.size() > 1 else "Element",
		Items.list_names(kind.elements) if not kind.elements.is_empty() else "none"]


func shown_name() -> String:
	return _name.text


# The tapped note beside the name, or "" when the tile isn't tapped.
func shown_tapped() -> String:
	return _tapped.text if _tapped.visible else ""


func shown_yield() -> String:
	return _yield.text
