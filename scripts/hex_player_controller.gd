class_name HexPlayerController
extends Node2D

# Ported from Unity TileExplore.HexPlayerController, split so the state lives in HexMover
# (scripts/core) and this node only translates input into mover calls and mirrors the mover's
# coord into a screen position.
#
# 8-key directional control scheme, supporting both flat-top and pointy-top layouts
# (orientation comes from the parent HexBoard). Q/E/Z/C are always the four diagonals
# (NW/NE/SW/SE) in both orientations.
# Flat-top hexes have no E/W neighbors, so W/X are the N/S movement keys and A/D turn.
# Pointy-top hexes have no N/S neighbors, so A/D are the E/W movement keys and W/X turn.
# S / Numpad5 is the detect action (TileInteraction), not movement.
#
# Input actions are named by key position (hex_up = W/Numpad8/Up, etc.) since their meaning
# depends on orientation.

# Relayed from the mover so view nodes (e.g. HexFacingRotator) can connect in their own
# _ready(), which runs before the mover is created here.
signal facing_changed(facing: Vector2i)

@export var start_coord: Vector2i = Vector2i.ZERO

var mover: HexMover

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	mover = HexMover.new(board.layout, start_coord)
	mover.moved.connect(_on_moved)
	mover.facing_changed.connect(_on_facing_changed)

	_on_moved(mover.coord)
	_on_facing_changed(mover.facing)


func _unhandled_input(event: InputEvent) -> void:
	var move_dir: Variant = null  # Hex.Compass, or null
	var turn_step := 0

	# Diagonals: same four compass labels in both orientations.
	if event.is_action_pressed("hex_nw"): move_dir = Hex.Compass.NW
	elif event.is_action_pressed("hex_ne"): move_dir = Hex.Compass.NE
	elif event.is_action_pressed("hex_sw"): move_dir = Hex.Compass.SW
	elif event.is_action_pressed("hex_se"): move_dir = Hex.Compass.SE
	elif board.pointy_top:
		if event.is_action_pressed("hex_left"): move_dir = Hex.Compass.W
		elif event.is_action_pressed("hex_right"): move_dir = Hex.Compass.E
		elif event.is_action_pressed("hex_up"): turn_step = -1
		elif event.is_action_pressed("hex_down"): turn_step = 1
	else:
		if event.is_action_pressed("hex_up"): move_dir = Hex.Compass.N
		elif event.is_action_pressed("hex_down"): move_dir = Hex.Compass.S
		elif event.is_action_pressed("hex_left"): turn_step = -1
		elif event.is_action_pressed("hex_right"): turn_step = 1

	if move_dir != null:
		mover.move(move_dir)
		get_viewport().set_input_as_handled()
	elif turn_step != 0:
		mover.turn(turn_step)
		print("Facing %s (%s)" % [Hex.Compass.keys()[mover.facing_compass()], mover.facing])
		get_viewport().set_input_as_handled()


func _on_moved(coord: Vector2i) -> void:
	position = board.hex_to_local(coord)


func _on_facing_changed(facing: Vector2i) -> void:
	facing_changed.emit(facing)
