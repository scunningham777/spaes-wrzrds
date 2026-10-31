class_name HexMover
extends RefCounted

# Position state for something that steps around a hex grid: each move steps one hex in an
# absolute direction.

signal moved(coord: Vector2i)

var layout: HexLayout
var coord: Vector2i

## Optional (Vector2i) -> bool; moves into coords it rejects are refused. Unset = unbounded.
var can_enter: Callable
## While true every move is refused.
var frozen := false


func _init(p_layout: HexLayout, start_coord: Vector2i = Vector2i.ZERO) -> void:
	layout = p_layout
	coord = start_coord


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
