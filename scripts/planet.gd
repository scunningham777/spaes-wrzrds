extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc returns to space.

# Generation settings, from Unity's TileGridManager.
@export var grid_radius: int = 2
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.0

@onready var _tiles: TileGridView = $HexBoard/TileGridView
@onready var _wizard: HexPlayerController = $HexBoard/Wizard
@onready var _camera: Camera2D = $Camera2D
@onready var _side_panel: Control = %SidePanel


func _ready() -> void:
	($UI/InventoryPanel as InventoryPanel).inventory = Game.state.inventory
	get_viewport().size_changed.connect(_center_map)
	_center_map()

	var location := Game.state.current_location
	(%PlanetName as Label).text = location.display_name if location != null else "Unknown planet"
	if location != null:
		_tiles.grid = Game.state.get_or_generate_grid(location.id, grid_radius, empty_tile_probability)
	else:
		# Scene run directly from the editor (F6): nothing to remember it under.
		_tiles.grid = TileGridGenerator.generate(grid_radius, empty_tile_probability)

	# Keep the wizard on the planet's tiles.
	_wizard.mover.can_enter = _tiles.grid.has_tile


# The board sits at the world origin; shift the camera so the origin lands in the middle of the
# area left of the side panel instead of the middle of the screen.
func _center_map() -> void:
	var width := get_viewport_rect().size.x
	_camera.offset.x = width / 2.0 - width * _side_panel.anchor_left / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.leave_location()
