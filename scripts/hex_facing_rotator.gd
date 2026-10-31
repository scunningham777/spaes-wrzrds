extends Node2D

# Ported from Unity TileExplore.HexFacingRotator.
# Rotates a sprite to face the way a HexPlayerController last stepped; until its first step it
# keeps its rest rotation. Attach to the sprite node; the controller defaults to this node's parent.

@export var controller: HexPlayerController

## Screen angle (degrees, CCW from +X) that the sprite art faces at zero rotation. 90 = art drawn facing up.
@export var sprite_rest_angle_degrees: float = 90.0


func _ready() -> void:
	if controller == null:
		controller = get_parent() as HexPlayerController
	controller.stepped.connect(_on_stepped)


func _on_stepped(direction: Vector2i) -> void:
	var angle := Hex.direction_angle_degrees(direction, controller.board.pointy_top)
	# Godot rotation is clockwise-positive (y-down), so the CCW difference is negated.
	rotation_degrees = sprite_rest_angle_degrees - angle
