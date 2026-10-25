class_name EnterableMarker
extends Node2D

# Draws an Enterable on its hex: its icon if one is set, otherwise a dot in the Enterable's color.
# Must be a child of a HexBoard.

@export var enterable: Enterable
## Picture drawn centered on the hex (e.g. an AtlasTexture cut from the tile sheet).
@export var icon: Texture2D
## Icon pixel scale; matches the wizard sprite's.
@export var icon_scale: float = 4.0
## Dot radius as a fraction of the board's hex size, when there's no icon.
@export var dot_scale: float = 0.35

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	position = board.hex_to_local(enterable.coord)


func _draw() -> void:
	if icon != null:
		var icon_size := icon.get_size() * icon_scale
		draw_texture_rect(icon, Rect2(-icon_size / 2.0, icon_size), false)
	else:
		draw_circle(Vector2.ZERO, board.hex_size * dot_scale, enterable.color)
