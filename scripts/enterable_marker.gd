class_name EnterableMarker
extends Node2D

# Draws an Enterable as a colored dot on its hex. Must be a child of a HexBoard.

@export var enterable: Enterable
## Dot radius as a fraction of the board's hex size.
@export var dot_scale: float = 0.35

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	position = board.hex_to_local(enterable.coord)


func _draw() -> void:
	draw_circle(Vector2.ZERO, board.hex_size * dot_scale, enterable.color)
