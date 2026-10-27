class_name HexMover
extends RefCounted

# Position + facing state for something that steps around a hex grid. Movement and turning are
# independent: moving steps one hex in an absolute direction; turning rotates a separate
# persistent facing used by things like push/extract.

signal moved(coord: Vector2i)
signal facing_changed(facing: Vector2i)

var layout: HexLayout
var coord: Vector2i
var facing: Vector2i

## Optional (Vector2i) -> bool; moves into coords it rejects are refused. Unset = unbounded.
var can_enter: Callable
## While true every move is refused; turning still works.
var frozen := false

var _facing_index: int = 0


func _init(p_layout: HexLayout, start_coord: Vector2i = Vector2i.ZERO) -> void:
	layout = p_layout
	coord = start_coord
	facing = Hex.delta(_clockwise_order()[0], layout.pointy_top)


func facing_compass() -> Hex.Compass:
	return _clockwise_order()[_facing_index]


# Returns false (and does nothing) if frozen, the direction doesn't exist in this orientation, or
# the target is rejected by can_enter.
func move(dir: Hex.Compass) -> bool:
	var d := Hex.delta(dir, layout.pointy_top)
	if frozen or d == Vector2i.ZERO:
		return false
	if can_enter.is_valid() and not can_enter.call(coord + d):
		return false
	coord += d
	moved.emit(coord)
	return true


# step: +1 = clockwise, -1 = counter-clockwise.
func turn(step: int) -> void:
	var order := _clockwise_order()
	_facing_index = posmod(_facing_index + step, order.size())
	facing = Hex.delta(order[_facing_index], layout.pointy_top)
	facing_changed.emit(facing)


func facing_angle_degrees() -> float:
	return Hex.direction_angle_degrees(facing, layout.pointy_top)


func _clockwise_order() -> Array[Hex.Compass]:
	return Hex.clockwise_order(layout.pointy_top)
