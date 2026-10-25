class_name LeyLines
extends RefCounted

# A planet's ley lines: straight lines of tiles, a few along each hex axis, picked when the planet
# is made. They're hidden; the player can only spot one where RESONANT_ELEMENT tiles run along it,
# which makes those tiles resonate (see is_resonant).
#
# A line runs all the way around the torus back to its start. It closes in one lap if the torus
# width is a multiple of twice its height; otherwise the diagonal lines wind around several times
# and show up as several parallel lines.

## The three axes lines run along (each also covers its opposite direction).
const AXES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, -1)]
## Lines picked per axis: a random count in this range.
const LINES_PER_AXIS := Vector2i(1, 2)
## The element whose runs along a line resonate, and the shortest run that does.
const RESONANT_ELEMENT := &"iron"
const MIN_RUN := 2
## Tries to place each line clear of the others on its axis before giving up on it.
const PLACEMENT_TRIES := 50


# One line: its axis, and the stored copy of every tile on it.
class Line:
	var direction: Vector2i
	var tiles: Dictionary[Vector2i, bool] = {}


var torus: HexTorus
var lines: Array[Line] = []


func _init(p_torus: HexTorus) -> void:
	torus = p_torus


# Random lines for torus: LINES_PER_AXIS of them along each axis, none touching another on the
# same axis (so two never read as one thick line).
static func generate(p_torus: HexTorus, rng: RandomNumberGenerator) -> LeyLines:
	var ley := LeyLines.new(p_torus)
	for axis in AXES:
		for i in rng.randi_range(LINES_PER_AXIS.x, LINES_PER_AXIS.y):
			for attempt in PLACEMENT_TRIES:
				var start := Vector2i(rng.randi_range(0, p_torus.width - 1), rng.randi_range(0, p_torus.height - 1))
				if not ley._touches_line(start, axis):
					ley.add_line(start, axis)
					break
	return ley


# Adds the line through start along direction (one of AXES, or its opposite).
func add_line(start: Vector2i, direction: Vector2i) -> void:
	var line := Line.new()
	line.direction = direction
	var c := torus.canonical(start)
	while not line.tiles.has(c):
		line.tiles[c] = true
		c = torus.canonical(c + direction)
	lines.append(line)


# Whether the tile at coord is part of a run of at least MIN_RUN revealed RESONANT_ELEMENT tiles
# in a row along a line through it.
func is_resonant(grid: TileGrid, coord: Vector2i) -> bool:
	var key := torus.canonical(coord)
	if not _yields(grid, key):
		return false
	for line in lines:
		if line.tiles.has(key) and _run_length(grid, key, line.direction) >= MIN_RUN:
			return true
	return false


# Whether two or more lines cross at coord.
func is_intersection(coord: Vector2i) -> bool:
	var key := torus.canonical(coord)
	return lines.filter(func(line: Line) -> bool: return line.tiles.has(key)).size() >= 2


# Length of the run of resonant-element tiles through key along direction, both ways; counts
# stop at MIN_RUN, which is all is_resonant needs (and keeps an all-iron line from looping).
func _run_length(grid: TileGrid, key: Vector2i, direction: Vector2i) -> int:
	var length := 1
	for way in [direction, -direction]:
		var c: Vector2i = key + way
		while length < MIN_RUN and _yields(grid, c):
			length += 1
			c += way
	return length


func _yields(grid: TileGrid, coord: Vector2i) -> bool:
	return grid.has_tile(coord) and RESONANT_ELEMENT in grid.get_tile(coord).elements


# Whether coord is on, or next to, a line along axis.
func _touches_line(coord: Vector2i, axis: Vector2i) -> bool:
	var near: Array[Vector2i] = [coord]
	for a in AXES:
		near.append(coord + a)
		near.append(coord - a)
	for line in lines:
		if line.direction == axis and near.any(func(c: Vector2i) -> bool: return line.tiles.has(torus.canonical(c))):
			return true
	return false
