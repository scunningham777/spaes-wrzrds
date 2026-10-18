class_name TileGridGenerator
extends RefCounted

# Random tile generation, ported from Unity's TileGridManager.GenerateGrid: each tile is Empty
# with probability empty_probability, otherwise a uniformly random non-Empty type.


# Pass a seeded rng for reproducible results; otherwise a randomized one is used.
static func generate(radius: int, empty_probability: float,
		rng: RandomNumberGenerator = null) -> TileGrid:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var grid := TileGrid.new(radius)
	var type_count := TileGrid.TileType.size() - 1  # -1 to exclude Empty
	for coord in grid.tiles:
		if rng.randf() < empty_probability:
			grid.set_tile(coord, TileGrid.TileType.EMPTY)
		else:
			grid.set_tile(coord, rng.randi_range(1, type_count) as TileGrid.TileType)  # 1 skips Empty
	return grid
