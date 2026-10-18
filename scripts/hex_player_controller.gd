class_name HexPlayerController
extends Node2D

# Ported from Unity TileExplore.HexPlayerController.
#
# 8-key directional controller for a hex grid, supporting both flat-top and pointy-top layouts
# (orientation comes from the parent HexBoard). Movement and turning are independent: movement
# keys step the player one hex in an absolute screen direction; turn keys rotate a separate
# persistent facing used by things like push/extract. Q/E/Z/C are always the four diagonals
# (NW/NE/SW/SE) in both orientations.
# Flat-top hexes have no E/W neighbors, so W/X are the N/S movement keys and A/D turn.
# Pointy-top hexes have no N/S neighbors, so A/D are the E/W movement keys and W/X turn.
# S / Numpad5 is intentionally unbound, reserved for a future action.
#
# Input actions are named by key position (hex_up = W/Numpad8/Up, etc.) since their meaning
# depends on orientation.

signal facing_changed(facing: Vector2i)

enum Compass { N, NE, SE, S, SW, NW, E, W }

# Clockwise direction order, used for turning. Index 0 is the default facing.
const FLAT_TOP_CLOCKWISE: Array[Compass] = [
	Compass.N, Compass.NE, Compass.SE, Compass.S, Compass.SW, Compass.NW
]
const POINTY_TOP_CLOCKWISE: Array[Compass] = [
	Compass.E, Compass.SE, Compass.SW, Compass.W, Compass.NW, Compass.NE
]

@export var start_coord: Vector2i = Vector2i.ZERO

var current_coord: Vector2i
var facing_direction: Vector2i

var _facing_index: int = 0

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	current_coord = start_coord
	_facing_index = 0
	facing_direction = _get_delta(_clockwise_order()[_facing_index])

	position = board.hex_to_local(current_coord)

	facing_changed.emit(facing_direction)


func _unhandled_input(event: InputEvent) -> void:
	var move_dir: Variant = null  # Compass, or null
	var turn_step := 0

	# Diagonals: same four compass labels in both orientations.
	if event.is_action_pressed("hex_nw"): move_dir = Compass.NW
	elif event.is_action_pressed("hex_ne"): move_dir = Compass.NE
	elif event.is_action_pressed("hex_sw"): move_dir = Compass.SW
	elif event.is_action_pressed("hex_se"): move_dir = Compass.SE
	elif board.pointy_top:
		if event.is_action_pressed("hex_left"): move_dir = Compass.W
		elif event.is_action_pressed("hex_right"): move_dir = Compass.E
		elif event.is_action_pressed("hex_up"): turn_step = -1
		elif event.is_action_pressed("hex_down"): turn_step = 1
	else:
		if event.is_action_pressed("hex_up"): move_dir = Compass.N
		elif event.is_action_pressed("hex_down"): move_dir = Compass.S
		elif event.is_action_pressed("hex_left"): turn_step = -1
		elif event.is_action_pressed("hex_right"): turn_step = 1

	if move_dir != null:
		_move(_get_delta(move_dir))
		get_viewport().set_input_as_handled()
	elif turn_step != 0:
		_turn(turn_step)
		get_viewport().set_input_as_handled()


func _move(delta: Vector2i) -> void:
	current_coord += delta
	position = board.hex_to_local(current_coord)


func _turn(step: int) -> void:
	var order := _clockwise_order()
	_facing_index = posmod(_facing_index + step, order.size())
	facing_direction = _get_delta(order[_facing_index])

	print("Facing %s (%s)" % [Compass.keys()[order[_facing_index]], facing_direction])
	facing_changed.emit(facing_direction)


# Screen angle (degrees, standard math convention: 0 = +X, CCW positive, y-up) of the current
# facing direction. Only depends on orientation – hex_size doesn't affect a direction's angle.
func get_facing_angle_degrees() -> float:
	var dir := board.hex_to_local(facing_direction) - board.hex_to_local(Vector2i.ZERO)
	return rad_to_deg(atan2(-dir.y, dir.x))  # un-flip Godot's y-down


func _clockwise_order() -> Array[Compass]:
	return POINTY_TOP_CLOCKWISE if board.pointy_top else FLAT_TOP_CLOCKWISE


# Axial delta for a compass direction. NW/SE happen to share the same delta in both
# orientations; N/S vs E/W (and the diagonals paired with them) do not, since axial coordinates
# are defined relative to a specific pixel formula.
func _get_delta(dir: Compass) -> Vector2i:
	if board.pointy_top:
		match dir:
			Compass.E: return Vector2i(1, 0)
			Compass.NE: return Vector2i(0, 1)
			Compass.NW: return Vector2i(-1, 1)
			Compass.W: return Vector2i(-1, 0)
			Compass.SW: return Vector2i(0, -1)
			Compass.SE: return Vector2i(1, -1)
	else:
		match dir:
			Compass.N: return Vector2i(0, 1)
			Compass.NE: return Vector2i(1, 0)
			Compass.SE: return Vector2i(1, -1)
			Compass.S: return Vector2i(0, -1)
			Compass.SW: return Vector2i(-1, 0)
			Compass.NW: return Vector2i(-1, 1)
	return Vector2i.ZERO
