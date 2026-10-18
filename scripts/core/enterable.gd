class_name Enterable
extends Resource

# A place on a hex map the player can enter (planet, comet, base...). Ported from Unity's
# Enterable component, as data rather than behavior: the scene decides when to offer entry.

## Stable unique key (e.g. &"planet_a"), used to remember per-location state like tile grids.
@export var id: StringName = &""
@export var display_name: String = ""
## Destination id understood by the Game autoload (e.g. "planet"), not a scene path.
@export var destination: String = ""
@export var coord: Vector2i = Vector2i.ZERO
@export var color: Color = Color.WHITE


# Placeholder, as in Unity: no requirements exist yet.
func meets_requirements() -> bool:
	return true


static func find_at(enterables: Array[Enterable], at: Vector2i) -> Enterable:
	for e in enterables:
		if e.coord == at:
			return e
	return null
