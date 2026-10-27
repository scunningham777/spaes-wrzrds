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
# S / Numpad5 is the detect action (TileInteraction), not movement; in detect mode it selects the
# player's own tile.
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


# The direction (Hex.Compass) a key press moves in, or null if it doesn't move.
static func move_direction(event: InputEvent, pointy_top: bool) -> Variant:
	# Diagonals: same four compass labels in both orientations.
	if event.is_action_pressed("hex_nw"): return Hex.Compass.NW
	if event.is_action_pressed("hex_ne"): return Hex.Compass.NE
	if event.is_action_pressed("hex_sw"): return Hex.Compass.SW
	if event.is_action_pressed("hex_se"): return Hex.Compass.SE
	if pointy_top:
		if event.is_action_pressed("hex_left"): return Hex.Compass.W
		if event.is_action_pressed("hex_right"): return Hex.Compass.E
	else:
		if event.is_action_pressed("hex_up"): return Hex.Compass.N
		if event.is_action_pressed("hex_down"): return Hex.Compass.S
	return null


# The turn (+1 clockwise, -1 counter-clockwise) a key press makes, or 0 if it doesn't turn.
static func turn_step(event: InputEvent, pointy_top: bool) -> int:
	var back := &"hex_up" if pointy_top else &"hex_left"
	var on := &"hex_down" if pointy_top else &"hex_right"
	if event.is_action_pressed(back): return -1
	if event.is_action_pressed(on): return 1
	return 0


func _unhandled_input(event: InputEvent) -> void:
	var move_dir: Variant = move_direction(event, board.pointy_top)  # Hex.Compass, or null
	var turn := turn_step(event, board.pointy_top)

	if move_dir != null:
		mover.move(move_dir)
		get_viewport().set_input_as_handled()
	elif turn != 0:
		mover.turn(turn)
		print("Facing %s (%s)" % [Hex.Compass.keys()[mover.facing_compass()], mover.facing])
		get_viewport().set_input_as_handled()


func _on_moved(coord: Vector2i) -> void:
	position = board.hex_to_local(coord)


func _on_facing_changed(facing: Vector2i) -> void:
	facing_changed.emit(facing)
