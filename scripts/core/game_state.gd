class_name GameState
extends RefCounted

# State that outlives a single scene (the Unity GameManager's playerPosition, etc.).

## Where the player is on the space map, restored when returning from a location.
var space_coord: Vector2i = Vector2i.ZERO
## The location the player is currently inside, or null when in space.
var current_location: Enterable = null
