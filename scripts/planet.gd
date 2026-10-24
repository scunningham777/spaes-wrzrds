extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc returns to space.

# Generation settings, from Unity's TileGridManager. They only apply on a planet's first visit.
## Radius of each patch of tiles: the one you land in, and each one scrying reveals.
@export var grid_radius: int = 2
## Planet size in patches; the surface wraps around both ways (see PlanetSurface). Keep across a
## multiple of 3 * down so ley lines run once around the planet rather than winding.
@export var patches_across: int = 12
@export var patches_down: int = 4
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.0
## Player actions (moves, extracts, swaps) an extracted tile stays tapped.
@export var tap_cooldown_actions: int = 5

@onready var _tiles: TileGridView = $HexBoard/TileGridView
@onready var _wizard: HexPlayerController = $HexBoard/Wizard
@onready var _camera: Camera2D = $Camera2D
@onready var _side_panel: Control = %SidePanel
@onready var _tile_info: TileInfo = %TileInfo
@onready var _interaction: TileInteraction = $TileInteraction
@onready var _aether_bar: ProgressBar = %AetherBar
@onready var _aether_label: Label = %AetherLabel

# Focus action hint labels by action, so their status suffixes can be refreshed.
var _focus_hints: Dictionary[StringName, Label] = {}
var _surface: PlanetSurface


func _ready() -> void:
	($UI/InventoryPanel as InventoryPanel).inventory = Game.state.inventory
	# Moving costs aether (see the end of _ready); the visit starts with at least Aether.START.
	Aether.land(Game.state.inventory)
	Game.state.inventory.changed.connect(_update_aether)
	_update_aether()
	get_viewport().size_changed.connect(_center_map)
	_center_map()

	var location := Game.state.current_location
	(%PlanetName as Label).text = location.display_name if location != null else "Unknown planet"
	if location != null:
		_surface = Game.state.get_or_create_surface(location.id, grid_radius, patches_across, patches_down,
			empty_tile_probability)
	else:
		# Scene run directly from the editor (F6): nothing to remember it under.
		_surface = PlanetSurface.new(grid_radius, patches_across, patches_down,
			TileGridGenerator.new(empty_tile_probability))
	_tiles.grid = _surface.grid
	_tiles.ley_lines = _surface.ley_lines
	_interaction.surface = _surface

	# Keep the wizard on the revealed tiles, and the view (camera and wrap) on the wizard.
	_wizard.mover.can_enter = _tiles.grid.has_tile
	_follow_wizard()
	_camera.reset_smoothing()
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _follow_wizard())

	# Moving is a player action, so it counts down tapped tiles (TileInteraction ticks its own).
	_tiles.grid.tap_cooldown = tap_cooldown_actions
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _tiles.grid.tick_cooldowns())

	# Side panel describes the tile under the wizard and what its focus actions would do from here,
	# so it refreshes on anything that changes those: moving, turning, and tile changes.
	_show_focus(Game.state.equipped_focus)
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _update_side_panel())
	_wizard.facing_changed.connect(func(_facing: Vector2i) -> void: _update_side_panel())
	_tiles.grid.tile_changed.connect(func(_coord: Vector2i, _kind: TileKind) -> void: _update_side_panel())
	_tiles.grid.tapped_changed.connect(func(_coord: Vector2i, _remaining: int) -> void: _update_side_panel())
	_update_side_panel()

	# Connected last, so a move that runs out of aether has updated everything else before leaving.
	_wizard.mover.moved.connect(_pay_for_move)

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
	_focus_hints.clear()
	for action in Foci.actions(focus):
		var hint := Label.new()
		hint.add_theme_font_size_override(&"font_size", 20)
		list.add_child(hint)
		_focus_hints[action] = hint


# "R – Extract", plus what the action would do from here where that's known ("R – Extract: Iron",
# or "R – Extract: Gold, Iron" when the line shares several elements).
func _focus_hint_text(action: StringName) -> String:
	var text := "%s – %s" % [_key_name(action), String(action).capitalize()]
	if action == &"extract":
		var elements := _interaction.extract_preview()
		text += ": %s" % (Items.list_names(elements) if not elements.is_empty() else "no match")
	return text


# The first key bound to an input action, e.g. "R" for extract.
static func _key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			return key.as_text_physical_keycode() if key.physical_keycode else key.as_text_keycode()
	return "?"


func _update_side_panel() -> void:
	var coord := _wizard.mover.coord
	var kind := _tiles.grid.get_tile(coord)
	_tile_info.show_tile(kind, _tiles.icon_texture(kind, _tiles.grid.is_tapped(coord)), _tiles.grid.cooldown(coord))
	for action in _focus_hints:
		_focus_hints[action].text = _focus_hint_text(action)
	# Scry is only listed where it works: the middle of the explored area's edge.
	var scry_hint := %ScryHint as Label
	scry_hint.text = "%s – Scry" % _key_name(&"scry")
	scry_hint.visible = _surface.can_scry(coord)


# The camera tracks the wizard, and the tile view draws the wrapping map around them.
func _follow_wizard() -> void:
	_camera.position = _wizard.position
	_tiles.view_center = _wizard.mover.coord


# Successful moves cost aether; running out kicks the player back to space.
func _pay_for_move(_coord: Vector2i) -> void:
	if not Aether.pay_move(Game.state.inventory):
		print("Out of aether")
		# Deferred: changing scenes takes this one out of the tree at once, and the wizard is still
		# handling the move's input.
		Game.leave_location.call_deferred()


# The bar fills against Aether.START; the label has the exact count, which extraction can push past it.
func _update_aether() -> void:
	var amount := Game.state.inventory.count(Aether.ITEM)
	_aether_bar.max_value = Aether.START
	_aether_bar.value = amount
	_aether_label.text = "Aether: %d" % amount


# The camera sits on the wizard; shift its view so the wizard lands in the middle of the area left
# of the side panel instead of the middle of the screen.
func _center_map() -> void:
	var width := get_viewport_rect().size.x
	_camera.offset.x = width / 2.0 - width * _side_panel.anchor_left / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.leave_location()
