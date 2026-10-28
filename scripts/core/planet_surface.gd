class_name PlanetSurface
extends RefCounted

# A planet: a wrapping hex grid (HexTorus) the player uncovers bit by bit, around where they land
# and wherever they scry (reveal_around). Tiles are generated as they're revealed
# (TileGridGenerator). Ley lines close in one lap around it when width is a multiple of twice the
# height (see LeyLines).

var grid: TileGrid
var generator: TileGridGenerator
## Hidden lines across the planet, picked when it's made.
var ley_lines: LeyLines


# width and height in tiles, as in HexTorus. Nothing is revealed yet.
func _init(width: int, height: int, p_generator: TileGridGenerator = null) -> void:
	generator = p_generator if p_generator != null else TileGridGenerator.new()
	var torus := HexTorus.new(width, height)
	grid = TileGrid.new(torus, generator.kinds)
	ley_lines = LeyLines.generate(torus, generator.rng)


# Reveals (generating) every unrevealed tile within radius of center. Returns the stored copies of
# the new tiles.
func reveal_around(center: Vector2i, radius: int) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	for offset in Hex.hexagon(radius):
		region.append(center + offset)
	return generator.reveal(grid, region)


# Whether a tile next to coord is still unrevealed.
func next_to_unrevealed(coord: Vector2i) -> bool:
	return Hex.hexagon(1).any(func(offset: Vector2i) -> bool: return not grid.has_tile(coord + offset))
