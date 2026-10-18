class_name GameState
extends RefCounted

# State that outlives a single scene (the Unity GameManager's playerPosition, etc.).

## Where the player is on the space map, restored when returning from a location.
var space_coord: Vector2i = Vector2i.ZERO
## The location the player is currently inside, or null when in space.
var current_location: Enterable = null
## Tile grids by Enterable.id, generated on first visit so revisits look the same.
var location_grids: Dictionary[StringName, TileGrid] = {}
var inventory := Inventory.new()


func get_or_generate_grid(location_id: StringName, radius: int, empty_probability: float) -> TileGrid:
	assert(location_id != &"", "Location has no id; set Enterable.id")
	if not location_grids.has(location_id):
		location_grids[location_id] = TileGridGenerator.generate(radius, empty_probability)
	return location_grids[location_id]
