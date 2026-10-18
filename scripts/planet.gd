extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc returns to space.

# Generation settings, from Unity's TileGridManager.
@export var grid_radius: int = 5
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.15

@onready var _tiles: TileGridView = $HexBoard/TileGridView


func _ready() -> void:
	var location := Game.state.current_location
	if location != null:
		_tiles.grid = Game.state.get_or_generate_grid(location.id, grid_radius, empty_tile_probability)
	else:
		# Scene run directly from the editor (F6): nothing to remember it under.
		_tiles.grid = TileGridGenerator.generate(grid_radius, empty_tile_probability)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.leave_location()
