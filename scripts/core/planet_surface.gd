class_name PlanetSurface
extends RefCounted

# A planet: a wrapping hex grid (HexTorus) the player uncovers one patch at a time. A patch is a
# patch_radius hexagon; the landing patch is centered on TileGridGenerator.START_COORD, and
# scrying reveals a neighboring one. Neighboring patches share one edge (each edge tile belongs
# to both), so their centers sit on a lattice spanned by PATCH_STEPS: the new patch is the old one
# mirrored across the shared edge. Tiles are generated as they're revealed (TileGridGenerator).
#
# The torus is sized in whole patches (patches_across x patches_down lattice steps), so patches
# fit together seamlessly across the wrap as well. A planet holds 2 * across * down patches.

signal patch_revealed(center: Vector2i)

## Axial steps between neighboring patch centers, for patch radius 1; scale by the radius.
## Each is a whole patch-hexagon edge away, mirrored: (2, -1) is (2R, -R, -R) in cube coords.
const PATCH_STEPS: Array[Vector2i] = [
	Vector2i(2, -1), Vector2i(1, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-1, -1), Vector2i(1, -2),
]

var grid: TileGrid
var generator: TileGridGenerator
var patch_radius: int
## Stored copies of revealed patch centers.
var patches: Dictionary[Vector2i, bool] = {}


# The torus is 2 * patch_radius * patches_across columns by 3 * patch_radius * patches_down rows:
# exactly patches_across and patches_down lattice steps, so the lattice wraps onto itself.
func _init(p_patch_radius: int, patches_across: int, patches_down: int,
		p_generator: TileGridGenerator = null) -> void:
	assert(p_patch_radius >= 1, "Patches need a radius of at least 1")
	patch_radius = p_patch_radius
	generator = p_generator if p_generator != null else TileGridGenerator.new()
	var torus := HexTorus.new(2 * patch_radius * patches_across, 3 * patch_radius * patches_down)
	grid = TileGrid.new(torus, generator.kinds)
	reveal_patch(TileGridGenerator.START_COORD)


# Every coord of the patch centered on center.
func patch_tiles(center: Vector2i) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for offset in Hex.hexagon(patch_radius):
		coords.append(center + offset)
	return coords


func is_patch_revealed(center: Vector2i) -> bool:
	return patches.has(grid.canonical(center))


# Reveals (generating as needed) the patch centered on center; false if it already was.
func reveal_patch(center: Vector2i) -> bool:
	if is_patch_revealed(center):
		return false
	patches[grid.canonical(center)] = true
	generator.reveal(grid, patch_tiles(center))
	patch_revealed.emit(grid.canonical(center))
	return true


# Center of the unrevealed patch that scrying from coord would reveal (its copy nearest coord), or
# null if coord isn't at the middle of an edge between a revealed patch and an unrevealed one.
# With an odd patch radius an edge has an even number of tiles, so either middle tile counts.
func scry_target(coord: Vector2i) -> Variant:
	for center: Vector2i in patches:
		# coord as an offset from center, across the wrap if that's nearer.
		var offset := grid.nearest(coord, center) - center
		if Hex.distance(offset) != patch_radius:
			continue
		for step in PATCH_STEPS:
			var neighbor := step * patch_radius
			# The edge's middle is halfway to the neighbor's center; doubling avoids half steps.
			if Hex.distance(offset * 2, neighbor) <= 1 and not is_patch_revealed(center + neighbor):
				return grid.nearest(center + neighbor, coord)
	return null


func can_scry(coord: Vector2i) -> bool:
	return scry_target(coord) != null


# Reveals the patch scrying from coord would; false (no change) if there's none.
func try_scry(coord: Vector2i) -> bool:
	var target: Variant = scry_target(coord)
	return target != null and reveal_patch(target)
