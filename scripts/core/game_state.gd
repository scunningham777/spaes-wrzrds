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
## The focus the wizard has equipped (a Foci id, or &"" for none); it grants extra actions.
var equipped_focus: StringName = Foci.STAFF


# Arguments as in PlanetSurface.new; they only apply on the first visit.
func get_or_create_surface(location_id: StringName, patch_radius: int, patches_across: int,
		patches_down: int, empty_probability: float) -> PlanetSurface:
	assert(location_id != &"", "Location has no id; set Enterable.id")
	if not location_surfaces.has(location_id):
		location_surfaces[location_id] = PlanetSurface.new(patch_radius, patches_across, patches_down,
			TileGridGenerator.new(empty_probability))
	return location_surfaces[location_id]
