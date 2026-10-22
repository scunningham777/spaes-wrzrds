class_name HexFacingMarker
extends Node2D

# Shows a HexPlayerController's position and facing without a sprite: a white outline around its
# hex, plus a small triangle centered on the faced edge, pointing out of the hex. Attach as a child
# of the controller; it defaults to this node's parent.

@export var controller: HexPlayerController
@export var color: Color = Color.WHITE
@export var line_width: float = 3.0
## Triangle base width and height, in pixels.
@export var triangle_size: Vector2 = Vector2(14.0, 9.0)

var _board: HexBoard


func _ready() -> void:
	if controller == null:
		controller = get_parent() as HexPlayerController
	_board = controller.get_parent() as HexBoard  # controller.board isn't set until its own _ready
	# Children are ready before their parent, so this connects before the controller's
	# initial facing_changed emit.
	controller.facing_changed.connect(_on_facing_changed)


func _on_facing_changed(_facing: Vector2i) -> void:
	queue_redraw()


# Triangle as (base end, base end, tip), local to the hex center.
func triangle_points() -> PackedVector2Array:
	var angle := deg_to_rad(controller.mover.facing_angle_degrees())
	var dir := Vector2(cos(angle), -sin(angle))  # facing angle is y-up; screen is y-down
	var side := dir.orthogonal() * triangle_size.x / 2.0
	# The shared edge with the faced neighbor sits at the hex's inner radius along dir.
	var edge_mid := dir * _board.layout.inner_radius() * _board.tile_scale
	return PackedVector2Array([edge_mid + side, edge_mid - side, edge_mid + dir * triangle_size.y])


func _draw() -> void:
	if controller.mover == null:
		return
	# Outline at the board's tile size so it hugs the tile.
	draw_polyline(_board.corner_points(_board.tile_scale), color, line_width)
	draw_colored_polygon(triangle_points(), color)
