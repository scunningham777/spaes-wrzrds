extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc fades out and returns to space.

# Generation settings, from Unity's TileGridManager. They only apply on a planet's first visit.
## Radius of each patch of tiles: the one you land in, and each one scrying reveals.
@export var grid_radius: int = 2
## Planet size in patches; the surface wraps around both ways (see PlanetSurface). Keep across a
## multiple of 3 * down so ley lines run once around the planet rather than winding.
@export var patches_across: int = 12
@export var patches_down: int = 4
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.0
## Player actions (moves, extracts, scrying; not pushes) an extracted tile stays tapped.
@export var tap_cooldown_actions: int = 5
## Running out of aether: how long the message shows, then how long the fade to black takes.
@export var out_of_aether_message_seconds: float = 1.5
@export var out_of_aether_fade_seconds: float = 0.4
## Fade in from black, when arriving from a scene that faded out (Game.fade_in).
@export var fade_in_seconds: float = 0.3
## Fade to black on leaving with Esc.
@export var fade_out_seconds: float = 0.3
## How long the wizard takes to fly between the board and the side panel's corner, entering and
## leaving detect mode.
@export var wizard_fly_seconds: float = 0.3

@onready var _tiles: TileGridView = $HexBoard/TileGridView
@onready var _wizard: HexPlayerController = $HexBoard/Wizard
@onready var _marker: HexFacingMarker = $HexBoard/Wizard/FacingMarker
@onready var _camera: Camera2D = $Camera2D
@onready var _side_panel: Control = %SidePanel
@onready var _tile_info: TileInfo = %TileInfo
@onready var _interaction: TileInteraction = $TileInteraction
@onready var _aether_bar: ProgressBar = %AetherBar
@onready var _aether_label: Label = %AetherLabel
@onready var _lock: ActionLock = $ActionLock
@onready var _fade: ScreenFade = $Fade

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
	_tiles.landing = TileGridGenerator.START_COORD
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
	_tiles.grid.known_changed.connect(func(_kind: TileKind, _known: bool) -> void: _update_side_panel())
	_update_side_panel()
	_interaction.detecting_changed.connect(_on_detecting_changed)

	# Connected last, so a move that runs out of aether has updated everything else before leaving.
	_wizard.mover.moved.connect(_pay_for_move)

	# Dim the action lists while an action plays out and input is blocked.
	_lock.busy_changed.connect(func(busy: bool) -> void:
		for list: Control in [%Actions, %FocusBox]:
			list.modulate.a = 0.35 if busy else 1.0)

	if Game.take_fade_in():
		_fade.fade_in(fade_in_seconds)


# Fills the outlined focus box with the focus's name and the actions it grants; hidden if none.
func _show_focus(focus: StringName) -> void:
	var box := %FocusBox as Control
	box.visible = not focus.is_empty() and not _interaction.detecting
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
	# Ley lines as the map shows them (the plum tiles), so the panel always agrees with the map.
	var ley := _tiles.ley_lines
	var resonant := ley != null and ley.is_resonant(_tiles.grid, coord)
	var activated := ley != null and ley.is_active(coord)
	var known := _tiles.grid.is_known(coord)
	_tile_info.show_tile(kind, _tiles.icon_texture(kind, _tiles.grid.is_tapped(coord), known),
		_tiles.grid.cooldown(coord), resonant, activated, known)
	for action in _focus_hints:
		_focus_hints[action].text = _focus_hint_text(action)
	# Detect is only listed where it works: an unknown tile in reach.
	var detect_hint := %DetectHint as Label
	detect_hint.text = "%s – Detect" % _key_name(&"detect")
	detect_hint.visible = _interaction.can_detect_here()
	# Scry is only listed where it works: the middle of the explored area's edge.
	var scry_hint := %ScryHint as Label
	scry_hint.text = "%s – Scry" % _key_name(&"scry")
	scry_hint.visible = _surface.can_scry(coord)
	# Build is only listed where it works: a detected iron tile where ley lines cross.
	var build_hint := %BuildHint as Label
	build_hint.text = "%s – Build Tower (needs %s)" % [_key_name(&"build_tower"), Towers.cost_text(Towers.BASIC)]
	build_hint.visible = _interaction.can_build_tower_here()


# Detect mode swaps the side panel's contents (under the planet name) for the elements to guess
# from, and the wizard's outline for the view's selection outline. The wizard flies up to the
# panel's corner, clear of their tile's icon (which moves back to the middle), and back after.
func _on_detecting_changed(detecting: bool) -> void:
	_tiles.detection = _interaction.detection
	_tiles.occupied = null if detecting else _wizard.mover.coord
	_fly_wizard(detecting)
	_marker.visible = not detecting
	for normal: Control in [%AetherBar, %Actions, %TileInfo]:
		normal.visible = not detecting
	(%FocusBox as Control).visible = not detecting and not Game.state.equipped_focus.is_empty()
	(%DetectPanel as Control).visible = detecting
	(%DetectHints as Control).visible = detecting
	var list := %DetectElements as Control
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if not detecting:
		return
	var letters := "QEADZCS" if (_wizard.board as HexBoard).pointy_top else "QWEZXCS"
	(%SelectHint as Label).text = "Numpad / %s – Select" % letters
	(%SubmitHint as Label).text = "Enter / Space – Submit"
	(%LeaveHint as Label).text = "Esc – Leave"
	var detection := _interaction.detection
	for i in mini(detection.elements.size(), Detection.MAX_ELEMENTS):
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", 20)
		label.text = "%s – %s" % [_key_name(StringName("guess_%d" % (i + 1))), Items.display_name(detection.elements[i])]
		list.add_child(label)
	detection.changed.connect(_update_detect_panel)
	_update_detect_panel()


# Elements nothing unknown in reach has any more grey out; the selected tile's guesses are in the
# view's guess color.
func _update_detect_panel() -> void:
	var detection := _interaction.detection
	if detection == null:
		return
	var guessed := detection.guessed(detection.selected)
	var list := %DetectElements as Control
	for i in list.get_child_count():
		var label := list.get_child(i) as Label
		var element := detection.elements[i]
		label.modulate = _tiles.guess_color if element in guessed else Color.WHITE
		label.modulate.a = 1.0 if detection.is_available(element) else 0.35


# Flies a copy of the wizard's sprite from the board to the side panel's wizard icon (to_panel) or
# back, showing the real one at the end. Input is blocked until it lands.
func _fly_wizard(to_panel: bool) -> void:
	var sprite := _wizard.get_node("Sprite2D") as Sprite2D
	var icon := %WizardIcon as TextureRect
	var xf := sprite.get_global_transform_with_canvas()
	var board_size := sprite.region_rect.size * xf.get_scale()
	var board_rect := Rect2(xf.origin - board_size / 2.0, board_size)
	var panel_rect := icon.get_global_rect()
	var from := board_rect if to_panel else panel_rect
	var to := panel_rect if to_panel else board_rect
	var flier := TextureRect.new()
	flier.texture = icon.texture
	flier.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flier.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.position = from.position
	flier.size = from.size
	$UI.add_child(flier)
	sprite.visible = false
	icon.visible = false
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flier, "position", to.position, wizard_fly_seconds)
	tween.tween_property(flier, "size", to.size, wizard_fly_seconds)
	tween.chain().tween_callback(func() -> void:
		flier.queue_free()
		sprite.visible = not to_panel
		icon.visible = to_panel)
	_lock.run(tween)


# The camera tracks the wizard, and the tile view draws the wrapping map around them.
func _follow_wizard() -> void:
	_camera.position = _wizard.position
	_tiles.view_center = _wizard.mover.coord
	_tiles.occupied = _wizard.mover.coord


# Successful moves cost the aether of the tile stepped onto; running out kicks the player back to
# space.
func _pay_for_move(coord: Vector2i) -> void:
	if not Aether.pay_move(Game.state.inventory, _tiles.grid.move_cost(coord)):
		print("Out of aether")
		_leave_out_of_aether()


# Shows the out-of-aether message, then fades to black and returns to space.
func _leave_out_of_aether() -> void:
	(%OutOfAetherMessage as Control).show()
	_fade_out_and_leave(out_of_aether_message_seconds, out_of_aether_fade_seconds)


# After delay seconds, fades to black over seconds and returns to space (which fades in). All
# input is blocked meanwhile, the inventory too (it would pause the fade).
func _fade_out_and_leave(delay: float, seconds: float) -> void:
	_lock.allowed_actions = []
	var tween := _fade.fade_out(seconds, delay)
	tween.tween_callback(Game.leave_location.bind(true))
	_lock.run(tween)


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
		get_viewport().set_input_as_handled()
		_fade_out_and_leave(0.0, fade_out_seconds)
