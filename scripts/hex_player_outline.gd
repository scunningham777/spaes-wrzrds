class_name HexPlayerOutline
extends Node2D

# Marks a HexPlayerController's tile with a white outline around its hex. Attach as a child of the
# controller; it defaults to this node's parent.

@export var controller: HexPlayerController
@export var color: Color = Color.WHITE
@export var line_width: float = 3.0

var _board: HexBoard


func _ready() -> void:
	if controller == null:
		controller = get_parent() as HexPlayerController
	_board = controller.get_parent() as HexBoard  # controller.board isn't set until its own _ready


func _draw() -> void:
	# Outline at the board's tile size so it hugs the tile.
	draw_polyline(_board.corner_points(_board.tile_scale), color, line_width)
