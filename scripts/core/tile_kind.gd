class_name TileKind
extends RefCounted

# One kind of tile on a planet: what it's called, what it looks like, and what extraction can
# yield from it. Each planet has its own set (TileGrid.kinds), built when it's generated, so kinds
# are data rather than a fixed enum. More traits (e.g. traversal cost) will join these.

## Tiles with nothing on them. Shared by every grid and not listed in TileGrid.kinds.
static var EMPTY := TileKind.new(&"empty", "Empty")

var id: StringName
var display_name: String
## Picture id, looked up by the view (TileGridView.ICONS); &"" for a plain hex. Logic never reads it.
var icon: StringName
## Items extraction can yield from this kind; empty if it yields nothing.
var elements: Array[StringName] = []


func _init(p_id: StringName, p_display_name: String, p_icon: StringName = &"",
		p_elements: Array[StringName] = []) -> void:
	id = p_id
	display_name = p_display_name
	icon = p_icon
	elements.assign(p_elements)
