class_name GameState
extends RefCounted

# State that outlives a single scene (the Unity GameManager's playerPosition, etc.).

## Where the player is on the space map, restored when returning from a location.
var space_coord: Vector2i = Vector2i.ZERO
## The location the player is currently inside, or null when in space.
var current_location: Enterable = null
## Planet surfaces by Enterable.id, made on first visit so revisits keep what was revealed.
var location_surfaces: Dictionary[StringName, PlanetSurface] = {}
var inventory := Inventory.new()
## The foci the wizard has equipped (Foci ids), in side-panel order; they grant extra actions.
var equipped_foci: Array[StringName] = [Foci.STAFF, Foci.ORB]


# Arguments as in PlanetSurface.new; they only apply on the first visit.
func get_or_create_surface(location_id: StringName, width: int, height: int,
		empty_probability: float) -> PlanetSurface:
	assert(location_id != &"", "Location has no id; set Enterable.id")
	if not location_surfaces.has(location_id):
		location_surfaces[location_id] = PlanetSurface.new(width, height,
			TileGridGenerator.new(empty_probability))
	return location_surfaces[location_id]
