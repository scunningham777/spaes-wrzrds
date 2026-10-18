extends Node2D

# Ported from Unity TileExplore.HexFacingRotator.
# Rotates a sprite to visually reflect HexPlayerController's facing direction. Attach to the
# sprite node; the controller defaults to this node's parent.

@export var controller: HexPlayerController

## Screen angle (degrees, CCW from +X) that the sprite art faces at zero rotation. 90 = art drawn facing up.
@export var sprite_rest_angle_degrees: float = 90.0


func _ready() -> void:
	if controller == null:
		controller = get_parent() as HexPlayerController
	# Children are ready before their parent, so this connects before the controller's
	# initial facing_changed emit.
	controller.facing_changed.connect(_on_facing_changed)


func _on_facing_changed(_facing: Vector2i) -> void:
	var angle := controller.mover.facing_angle_degrees()
	# Godot rotation is clockwise-positive (y-down), so the CCW difference is negated.
	rotation_degrees = sprite_rest_angle_degrees - angle
