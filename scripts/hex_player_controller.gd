class_name HexPlayerController
extends Node2D

# Ported from Unity TileExplore.HexPlayerController, split so the state lives in HexMover
# (scripts/core) and this node only translates input into mover calls and mirrors the mover's
# coord into a screen position.
#
# Directional control scheme, supporting both flat-top and pointy-top layouts (orientation comes
# from the parent HexBoard). Q/E/Z/C are always the four diagonals (NW/NE/SW/SE) in both
# orientations. Flat-top hexes have no E/W neighbors, so W/X are N/S and A/D do nothing;
# pointy-top hexes have no N/S neighbors, so A/D are W/E and W/X do nothing. S / Numpad5 is the
# detect action (TileInteraction), not movement.
#
# Input actions are named by key position (hex_up = W/Numpad8/Up, etc.) since their meaning
# depends on orientation.

## Each successful step, as an axial delta. Relayed from the mover so view nodes (e.g.
## HexFacingRotator) can connect in their own _ready(), which runs before the mover is created here.
signal stepped(direction: Vector2i)

@export var start_coord: Vector2i = Vector2i.ZERO

var mover: HexMover

var _coord: Vector2i

@onready var board: HexBoard = get_parent() as HexBoard


func _ready() -> void:
	mover = HexMover.new(board.layout, start_coord)
	mover.moved.connect(_on_moved)
	_coord = mover.coord
	_on_moved(mover.coord)


# The input action that moves in dir in this orientation, or &"" if dir doesn't exist in it.
static func direction_action(dir: Hex.Compass, pointy_top: bool) -> StringName:
	match dir:
		Hex.Compass.NW: return &"hex_nw"
		Hex.Compass.NE: return &"hex_ne"
		Hex.Compass.SW: return &"hex_sw"
		Hex.Compass.SE: return &"hex_se"
		Hex.Compass.W: return &"hex_left" if pointy_top else &""
		Hex.Compass.E: return &"hex_right" if pointy_top else &""
		Hex.Compass.N: return &"" if pointy_top else &"hex_up"
		Hex.Compass.S: return &"" if pointy_top else &"hex_down"
	return &""


# The direction (Hex.Compass) a key press moves in, or null if it doesn't move.
static func move_direction(event: InputEvent, pointy_top: bool) -> Variant:
	for dir in Hex.clockwise_order(pointy_top):
		if event.is_action_pressed(direction_action(dir, pointy_top)):
			return dir
	return null


func _unhandled_input(event: InputEvent) -> void:
	var move_dir: Variant = move_direction(event, board.pointy_top)  # Hex.Compass, or null
	if move_dir != null:
		mover.move(move_dir)
		get_viewport().set_input_as_handled()


func _on_moved(coord: Vector2i) -> void:
	position = board.hex_to_local(coord)
	if coord != _coord:
		stepped.emit(coord - _coord)
	_coord = coord
