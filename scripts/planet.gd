extends Node2D

# Planet surface (Unity's TileExploreScene layout). Esc fades out and returns to space.
#
# The action bar along the bottom of the board shows what the player can do here
# (TileInteraction.shown_actions). The side panel's middle shows the open phase: the direction keys
# to move by, push's or extract's picked direction and what confirming would do, or the towers to
# build. Under its divider it describes a tile: the one push or extract aims at, or the wizard's own.

# Generation settings, from Unity's TileGridManager. They only apply on a planet's first visit.
## Planet size in tiles; the surface wraps around both ways (see HexTorus). Width must be even;
## keep it a multiple of twice the height so ley lines run once around the planet rather than
## winding. How much is revealed on landing comes from the equipped foci (Foci.landing_radius).
@export var planet_width: int = 48
@export var planet_height: int = 24
@export_range(0.0, 1.0) var empty_tile_probability: float = 0.0
## Player actions (moves, extracts; not pushes) an extracted tile stays tapped.
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
@onready var _marker: HexPlayerOutline = $HexBoard/Wizard/Outline
@onready var _camera: Camera2D = $Camera2D
@onready var _side_panel: Control = %SidePanel
@onready var _tile_info: TileInfo = %TileInfo
@onready var _interaction: TileInteraction = $TileInteraction
@onready var _aether_bar: ProgressBar = %AetherBar
@onready var _aether_label: Label = %AetherLabel
@onready var _lock: ActionLock = $ActionLock
@onready var _fade: ScreenFade = $Fade
@onready var _action_bar: ActionBar = %ActionBar
@onready var _direction_keys: DirectionKeys = %DirectionKeys

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
		_surface = Game.state.get_or_create_surface(location.id, planet_width, planet_height,
			empty_tile_probability)
	else:
		# Scene run directly from the editor (F6): nothing to remember it under.
		_surface = PlanetSurface.new(planet_width, planet_height,
			TileGridGenerator.new(empty_tile_probability))
	_surface.reveal_around(TileGridGenerator.START_COORD, Foci.landing_radius(Game.state.equipped_foci))
	_tiles.grid = _surface.grid
	_tiles.ley_lines = _surface.ley_lines
	_tiles.landing = TileGridGenerator.START_COORD
	_interaction.surface = _surface

	# Keep the wizard on the revealed tiles, and the view (camera and wrap) on the wizard. Each step
	# reveals the tiles around where it lands, out to the equipped foci's reveal radius.
	_wizard.mover.can_enter = _tiles.grid.has_tile
	_wizard.mover.moved.connect(func(coord: Vector2i) -> void:
		_surface.reveal_around(coord, Foci.reveal_radius(Game.state.equipped_foci)))
	_follow_wizard()
	_camera.reset_smoothing()
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _follow_wizard())

	# Moving is a player action, so it counts down tapped tiles (TileInteraction ticks its own).
	_tiles.grid.tap_cooldown = tap_cooldown_actions
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _tiles.grid.tick_cooldowns())

	# The side panel and action bar describe the tile under the wizard (or the one an action aims
	# at) and what can be done from here, so they refresh on anything that changes those: moving, the
	# phase and what it has picked, tile changes, and marking nodes.
	_direction_keys.pointy_top = _wizard.board.pointy_top
	_direction_keys.keys = _direction_key_names()
	_surface.ley_lines.node_marked.connect(func(_coord: Vector2i) -> void: _update_side_panel())
	_wizard.mover.moved.connect(func(_coord: Vector2i) -> void: _update_side_panel())
	_interaction.mode_changed.connect(func(_mode: StringName) -> void: _update_side_panel())
	_interaction.selection_changed.connect(_update_side_panel)
	_tiles.grid.tile_changed.connect(func(_coord: Vector2i, _kind: TileKind) -> void: _update_side_panel())
	_tiles.grid.tapped_changed.connect(func(_coord: Vector2i, _remaining: int) -> void: _update_side_panel())
	_tiles.grid.known_changed.connect(func(_kind: TileKind, _known: bool) -> void: _update_side_panel())
	_update_side_panel()
	_interaction.detecting_changed.connect(_on_detecting_changed)
	# Clicking an action's tile works like pressing its key, unless an action is playing out.
	_action_bar.action_pressed.connect(func(action: StringName) -> void:
		if not _lock.busy:
			_interaction.select_action(action))

	# Connected last, so a move that runs out of aether has updated everything else before leaving.
	_wizard.mover.moved.connect(_pay_for_move)

	# Dim the actions while one plays out and input is blocked.
	_lock.busy_changed.connect(func(busy: bool) -> void:
		for list: Control in [_action_bar, %ModePanel]:
			list.modulate.a = 0.35 if busy else 1.0)

	if Game.take_fade_in():
		_fade.fade_in(fade_in_seconds)


# Axial delta -> key name, for each direction key in this orientation.
func _direction_key_names() -> Dictionary[Vector2i, String]:
	var names: Dictionary[Vector2i, String] = {}
	var pointy_top := _wizard.board.pointy_top
	for dir in Hex.clockwise_order(pointy_top):
		names[Hex.delta(dir, pointy_top)] = ActionBar.key_name(HexPlayerController.direction_action(dir, pointy_top))
	return names


func _update_side_panel() -> void:
	var coord := _interaction.info_coord()
	var kind := _tiles.grid.get_tile(coord)
	# Ley lines as the map shows them (the plum tiles), so the panel always agrees with the map.
	var ley := _tiles.ley_lines
	var resonant := ley != null and ley.is_resonant(_tiles.grid, coord)
	var activated := ley != null and ley.is_active(coord)
	var known := _tiles.grid.is_known(coord)
	_tile_info.show_tile(kind, _tiles.icon_texture(kind, _tiles.grid.is_tapped(coord), known),
		_tiles.grid.cooldown(coord), resonant, activated, known)
	_tiles.targets = _interaction.target_tiles()
	var shown := _interaction.shown_actions()
	var available: Array[StringName] = []
	available.assign(shown.filter(_interaction.can_act))
	_action_bar.show_actions(shown, TileInteraction.NAMES, available, _interaction.mode)
	_update_mode_panel()


# The open phase's title, the direction keys (with push's or extract's pick highlighted), and its
# hint lines: how to pick, what confirming would do, and how to go back.
func _update_mode_panel() -> void:
	var mode := _interaction.mode
	var aims := mode in [TileInteraction.PUSH, TileInteraction.EXTRACT]
	(%ModeTitle as Label).text = TileInteraction.NAMES.get(mode, "")
	_direction_keys.visible = mode == TileInteraction.MOVE or aims
	_direction_keys.selected = _interaction.direction if aims else null
	(%BuildOptions as Control).visible = mode == TileInteraction.BUILD
	var confirm_keys := "%s / %s" % [ActionBar.key_name(&"confirm"), "Space"]
	var back := "%s / Esc – Back to Move" % ActionBar.key_name(TileInteraction.MOVE)
	# [text, whether it's dimmed]
	var lines: Array[Array] = []
	match mode:
		TileInteraction.MOVE:
			lines.append(["Numpad moves too", false])
		TileInteraction.PUSH:
			lines.append(["Direction keys – Pick a tile", false])
			if _interaction.direction == null:
				lines.append(["Pick a tile to push", true])
			elif _interaction.can_push():
				var target := _tiles.grid.get_tile(_interaction.push_target())
				lines.append(["%s – Push %s" % [confirm_keys, target.display_name], false])
			else:
				lines.append(["Can't push that way", true])
			lines.append([back, false])
		TileInteraction.EXTRACT:
			lines.append(["Direction keys – Pick a direction", false])
			var elements := _interaction.extract_preview()
			if _interaction.direction == null:
				lines.append(["Pick a direction to extract", true])
			elif elements.is_empty():
				lines.append(["Extract: no match", true])
			else:
				lines.append(["%s – Extract: %s" % [confirm_keys, Items.list_names(elements)], false])
			lines.append([back, false])
		TileInteraction.BUILD:
			_update_build_options()
			var tower := _interaction.tower
			lines.append(["Needs %s" % Towers.requirement_text(tower), false])
			var met := _interaction.can_afford_tower()
			lines.append(["Requirements met" if met else "Requirements not met", not met])
			lines.append(["%s – Build %s" % [confirm_keys, Towers.display_name(tower)], not met])
			lines.append([back, false])
	var list := %ModeLines as Control
	while list.get_child_count() < lines.size():
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	for i in list.get_child_count():
		var label := list.get_child(i) as Label
		label.visible = i < lines.size()
		if label.visible:
			label.text = lines[i][0]
			label.modulate.a = 0.5 if lines[i][1] else 1.0


# A button per tower, numbered for its key; the chosen one is pressed. Clicking one chooses it.
func _update_build_options() -> void:
	var list := %BuildOptions as Control
	var towers: Array[StringName] = Towers.NAMES.keys()
	if list.get_child_count() == 0:
		for i in towers.size():
			var tower := towers[i]
			var button := Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override(&"font_size", 20)
			button.text = "%s – %s" % [ActionBar.key_name(StringName("guess_%d" % (i + 1))), Towers.display_name(tower)]
			button.pressed.connect(func() -> void:
				if not _lock.busy:
					_interaction.choose_tower(tower)
				_update_mode_panel())
			list.add_child(button)
	for i in towers.size():
		(list.get_child(i) as Button).set_pressed_no_signal(towers[i] == _interaction.tower)


# The side panel's hint lines, as shown (for tests).
func mode_lines() -> Array[String]:
	var lines: Array[String] = []
	for label: Label in (%ModeLines as Control).get_children():
		if label.visible:
			lines.append(label.text)
	return lines


# Detect mode swaps the side panel's contents (under the planet name) for the elements to guess
# from, and the wizard's outline for the view's selection outline. The wizard flies up to the
# panel's corner, clear of their tile's icon (which moves back to the middle), and back after.
func _on_detecting_changed(detecting: bool) -> void:
	_tiles.detection = _interaction.detection
	_tiles.occupied = null if detecting else _wizard.mover.coord
	_fly_wizard(detecting)
	_marker.visible = not detecting
	for normal: Control in [%AetherBar, %ModePanel, %TileInfo]:
		normal.visible = not detecting
	(%DetectPanel as Control).visible = detecting
	(%DetectHints as Control).visible = detecting
	var list := %DetectElements as Control
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if not detecting:
		return
	var letters := "QEADZCS" if _wizard.board.pointy_top else "QWEZXCS"
	(%SelectHint as Label).text = "Numpad / %s – Select" % letters
	var detection := _interaction.detection
	for i in mini(detection.elements.size(), Detection.MAX_ELEMENTS):
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", 20)
		label.text = "%s – %s" % [ActionBar.key_name(StringName("guess_%d" % (i + 1))), Items.display_name(detection.elements[i])]
		list.add_child(label)
	detection.changed.connect(_update_detect_panel)
	_update_detect_panel()


# The selected tile's guesses are in the view's guess color.
func _update_detect_panel() -> void:
	var detection := _interaction.detection
	if detection == null:
		return
	var guessed: Array[StringName] = []
	if detection.selected != null:
		guessed = detection.guessed(detection.selected)
	var list := %DetectElements as Control
	for i in list.get_child_count():
		var label := list.get_child(i) as Label
		label.modulate = _tiles.guess_color if detection.elements[i] in guessed else Color.WHITE


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


# Successful moves cost the aether of the tile stepped onto, less any ley line bonus (as the map
# shows it); running out kicks the player back to space.
func _pay_for_move(coord: Vector2i) -> void:
	if not Aether.pay_move(Game.state.inventory, _tiles.move_cost(coord)):
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
