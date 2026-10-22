extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc returns to space.

# Generation settings, from Unity's TileGridManager.
@export var grid_radius: int = 2
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.0
## Player actions (moves, extracts, swaps) an extracted tile stays tapped.
@export var tap_cooldown_actions: int = 5

@onready var _tiles: TileGridView = $HexBoard/TileGridView
@onready var _wizard: HexPlayerController = $HexBoard/Wizard
@onready var _camera: Camera2D = $Camera2D
@onready var _side_panel: Control = %SidePanel
@onready var _tile_info: TileInfo = %TileInfo


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

	# Moving is a player action, so it counts down tapped tiles (TileInteraction ticks its own).
	_tiles.grid.tap_cooldown = tap_cooldown_actions
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _tiles.grid.tick_cooldowns())

	# Side panel describes the tile under the wizard (what R would extract).
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _update_tile_info())
	_tiles.grid.tile_changed.connect(func(_coord: Vector2i, _type: TileGrid.TileType) -> void: _update_tile_info())
	_tiles.grid.tapped_changed.connect(func(_coord: Vector2i, _remaining: int) -> void: _update_tile_info())
	_update_tile_info()

	_show_focus(Game.state.equipped_focus)

	# Dim the action lists while an action plays out and input is blocked.
	($ActionLock as ActionLock).busy_changed.connect(func(busy: bool) -> void:
		for list: Control in [%Actions, %FocusBox]:
			list.modulate.a = 0.35 if busy else 1.0)


# Fills the outlined focus box with the focus's name and the actions it grants; hidden if none.
func _show_focus(focus: StringName) -> void:
	var box := %FocusBox as Control
	box.visible = not focus.is_empty()
	(%FocusName as Label).text = Foci.display_name(focus)
	var list := %FocusActions as Control
	for child in list.get_children():
		child.queue_free()
	for action in Foci.actions(focus):
		var hint := Label.new()
		hint.add_theme_font_size_override(&"font_size", 20)
		hint.text = "%s – %s" % [_key_name(action), String(action).capitalize()]
		list.add_child(hint)


# The first key bound to an input action, e.g. "R" for extract.
static func _key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			return key.as_text_physical_keycode() if key.physical_keycode else key.as_text_keycode()
	return "?"


func _update_tile_info() -> void:
	var coord := _wizard.mover.coord
	var type := _tiles.grid.get_tile(coord)
	_tile_info.show_tile(type, _tiles.icon_texture(type, _tiles.grid.is_tapped(coord)), _tiles.grid.cooldown(coord))


# The board sits at the world origin; shift the camera so the origin lands in the middle of the
# area left of the side panel instead of the middle of the screen.
func _center_map() -> void:
	var width := get_viewport_rect().size.x
	_camera.offset.x = width / 2.0 - width * _side_panel.anchor_left / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.leave_location()
