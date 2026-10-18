class_name Hex
extends RefCounted

# Pure hex-grid direction math (no nodes, no rendering). Coordinates are axial (q, r) stored in
# a Vector2i, defined y-up: "N" means up the screen regardless of the engine's screen convention.
#
# Flat-top hexes have no E/W neighbors; pointy-top hexes have no N/S neighbors.

enum Compass { N, NE, SE, S, SW, NW, E, W }

# Clockwise direction order, used for turning. Index 0 is the default facing.
const FLAT_TOP_CLOCKWISE: Array[Compass] = [
	Compass.N, Compass.NE, Compass.SE, Compass.S, Compass.SW, Compass.NW
]
const POINTY_TOP_CLOCKWISE: Array[Compass] = [
	Compass.E, Compass.SE, Compass.SW, Compass.W, Compass.NW, Compass.NE
]


static func clockwise_order(pointy_top: bool) -> Array[Compass]:
	return POINTY_TOP_CLOCKWISE if pointy_top else FLAT_TOP_CLOCKWISE


# Axial delta for a compass direction, or ZERO if the direction doesn't exist in this
# orientation. NW/SE happen to share the same delta in both orientations; N/S vs E/W (and the
# diagonals paired with them) do not, since axial coordinates are defined relative to a specific
# pixel formula.
static func delta(dir: Compass, pointy_top: bool) -> Vector2i:
	if pointy_top:
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


# Every coord within `radius` steps of the origin, i.e. a hexagon-shaped board.
static func hexagon(radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			coords.append(Vector2i(q, r))
	return coords


# Angle (degrees, standard math convention: 0 = +X, CCW positive, y-up) of an axial direction.
# Only depends on orientation – size doesn't affect a direction's angle.
static func direction_angle_degrees(direction: Vector2i, pointy_top: bool) -> float:
	var p := HexLayout.new(pointy_top, 1.0).hex_to_point(direction)
	return rad_to_deg(atan2(p.y, p.x))
