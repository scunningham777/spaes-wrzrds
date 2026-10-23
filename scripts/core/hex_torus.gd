class_name HexTorus
extends RefCounted

# A hex grid that wraps both ways, like a planet's surface: width columns around, height rows
# down. Coords off the torus are the same tile as their canonical() copy, the one that gets stored.
#
# Wraps by two translations: (width, -width / 2) and (0, height) in axial coords. With flat-top
# hexes (the planet's layout) those are straight right and straight up on screen, so the map
# wraps horizontally and vertically. width must be even for the first to land on a whole hex.

var width: int
var height: int


func _init(p_width: int, p_height: int) -> void:
	assert(p_width > 0 and p_width % 2 == 0, "HexTorus width must be even and positive")
	assert(p_height > 0, "HexTorus height must be positive")
	width = p_width
	height = p_height


# The stored copy of coord: q in [0, width), r in [0, height).
func canonical(coord: Vector2i) -> Vector2i:
	var laps := floori(float(coord.x) / width)
	var q := coord.x - laps * width
	var r := coord.y + laps * (width / 2)
	return Vector2i(q, posmod(r, height))


# The copy of coord nearest reference (by hex distance), for drawing and for measuring from
# reference across the wrap. Ties go to whichever copy is found first.
func nearest(coord: Vector2i, reference: Vector2i) -> Vector2i:
	var offset := canonical(coord - reference)
	var best := offset
	# Try the copy a lap left, then the rows around each one's nearest vertical lap.
	for across in [offset, offset - Vector2i(width, -width / 2)]:
		var laps := roundi(float(across.y) / height)
		for b in range(laps - 1, laps + 2):
			var candidate: Vector2i = across - Vector2i(0, height * b)
			if Hex.distance(candidate) < Hex.distance(best):
				best = candidate
	return reference + best
