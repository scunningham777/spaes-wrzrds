class_name TileInfo
extends Control

# Side-panel block describing one tile: its icon, name, and elements (the items it yields), plus its
# tapped state, and a badge under the elements when it's on a ley line the player has found:
# "ley line activated" on an activated line, otherwise "ley line detected" when it resonates. The scene decides which tile to show (e.g. the one under the player) and calls show_tile().

@onready var _icon: TextureRect = %TileIcon
@onready var _name: Label = %TileName
@onready var _tapped: Label = %TileTapped
@onready var _yield: Label = %TileYield
@onready var _ley_line: Label = %TileLeyLine


# cooldown: actions until a tapped tile can be extracted again; 0 if it isn't tapped.
# resonant: the tile resonates with a ley line (LeyLines.is_resonant).
# activated: the tile is on an activated ley line (LeyLines.is_active).
# known: the tile's elements are known (TileGrid.is_known); otherwise they show as unknown.
func show_tile(kind: TileKind, icon: Texture2D, cooldown: int = 0, resonant: bool = false,
		activated: bool = false, known: bool = true) -> void:
	_ley_line.visible = resonant or activated
	_ley_line.text = "ley line activated" if activated else "ley line detected"
	_icon.texture = icon
	_name.text = kind.display_name
	# Tapped affects the whole tile, so it sits beside the name rather than the element.
	_tapped.visible = cooldown > 0
	_tapped.text = "tapped: %d" % cooldown
	if not known:
		_yield.text = "Elements: unknown"
		return
	_yield.text = "%s: %s" % ["Elements" if kind.elements.size() > 1 else "Element",
		Items.list_names(kind.elements) if not kind.elements.is_empty() else "none"]


func shown_name() -> String:
	return _name.text


# The tapped note beside the name, or "" when the tile isn't tapped.
func shown_tapped() -> String:
	return _tapped.text if _tapped.visible else ""


func shown_yield() -> String:
	return _yield.text


# The ley line badge, or "" when it's hidden.
func shown_ley_line() -> String:
	return _ley_line.text if _ley_line.visible else ""
