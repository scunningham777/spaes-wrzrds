class_name HexLayout
extends RefCounted

# Hex orientation + size, and the axial -> 2D point math. Pure geometry, y-up, unit-agnostic
# (size can be pixels, world units, etc.); the view layer flips/scales for its own screen space.

var pointy_top: bool
var size: float  # center-to-corner radius

const SQRT_3 := 1.7320508075688772


func _init(p_pointy_top: bool = true, p_size: float = 1.0) -> void:
	pointy_top = p_pointy_top
	size = p_size


func hex_to_point(coord: Vector2i) -> Vector2:
	if pointy_top:
		return Vector2(
			size * SQRT_3 * (coord.x + coord.y / 2.0),
			size * 1.5 * coord.y)
	return Vector2(
		size * 1.5 * coord.x,
		size * (SQRT_3 / 2.0 * coord.x + SQRT_3 * coord.y))


# Corner offsets from a hex center, closed (first point repeated last) for drawing outlines.
func corner_offsets() -> PackedVector2Array:
	var corners := PackedVector2Array()
	var start_deg := 30.0 if pointy_top else 0.0
	for i in 7:
		var angle := deg_to_rad(start_deg + 60.0 * i)
		corners.append(Vector2(cos(angle), sin(angle)) * size)
	return corners
