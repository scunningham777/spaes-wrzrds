extends SceneTree

# Headless smoke test:
#   godot_console.exe --headless --path . -s res://tests/smoke_test.gd

var _failures := 0
var _finished: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: StringName in [&"hex_nw", &"hex_ne", &"hex_sw", &"hex_se",
			&"hex_up", &"hex_down", &"hex_left", &"hex_right"]:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() >= 2,
			"input action %s is mapped" % action)

	_test_core_logic()

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("%PlayButton") is Button, "menu has Play button")
	menu.queue_free()

	await _test_play_scene(true)
	await _test_play_scene(false)
	await _test_enter_planet()
	# A script error aborts a test function silently, so make sure each one ran to the end.
	for t in ["play_pointy", "play_flat", "enter_planet"]:
		_check(t in _finished, "test %s ran to completion" % t)

	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures else 0)


# Pure logic (scripts/core) – no scene, nodes, or input involved.
func _test_core_logic() -> void:
	var pointy := HexMover.new(HexLayout.new(true), Vector2i(2, 3))
	var moves: Array[Vector2i] = []
	pointy.moved.connect(func(c: Vector2i) -> void: moves.append(c))
	_check(pointy.facing == Vector2i(1, 0), "core: pointy default facing E")
	_check(not pointy.move(Hex.Compass.N), "core: pointy has no N neighbor")
	_check(pointy.move(Hex.Compass.NW) and pointy.coord == Vector2i(1, 4), "core: pointy NW step")
	_check(moves == [Vector2i(1, 4)], "core: moved signal fires once per step")
	pointy.turn(-1)
	_check(pointy.facing_compass() == Hex.Compass.NE, "core: pointy turn CCW E -> NE")
	pointy.turn(7)
	_check(pointy.facing_compass() == Hex.Compass.E, "core: turn wraps around")

	var flat := HexMover.new(HexLayout.new(false))
	_check(flat.facing_compass() == Hex.Compass.N, "core: flat default facing N")
	_check(not flat.move(Hex.Compass.E), "core: flat has no E neighbor")
	var bounded := HexMover.new(HexLayout.new(false))
	bounded.can_enter = func(c: Vector2i) -> bool: return c.y <= 1
	_check(bounded.move(Hex.Compass.N) and not bounded.move(Hex.Compass.N) and bounded.coord == Vector2i(0, 1),
		"core: can_enter blocks moves")
	bounded.turn(1)
	_check(bounded.facing_compass() == Hex.Compass.NE, "core: turning still works when blocked")
	_check(is_equal_approx(flat.facing_angle_degrees(), 90.0), "core: flat N angle is 90")
	flat.turn(1)
	_check(is_equal_approx(flat.facing_angle_degrees(), 30.0), "core: flat NE angle is 30")

	# Opposite compass directions cancel out in both orientations.
	for pt: bool in [true, false]:
		var order := Hex.clockwise_order(pt)
		for i in 3:
			var sum := Hex.delta(order[i], pt) + Hex.delta(order[i + 3], pt)
			_check(sum == Vector2i.ZERO, "core: %s opposite of %s cancels" % [
				"pointy" if pt else "flat", Hex.Compass.keys()[order[i]]])

	_check(Hex.hexagon(5).size() == 91, "core: radius-5 hexagon has 91 hexes")
	var grid := TileGrid.new(5)
	_check(grid.tiles.size() == 91 and grid.has_tile(Vector2i(5, -5)) and not grid.has_tile(Vector2i(5, 1)),
		"core: TileGrid covers exactly the hexagon")

	var a := Enterable.new()
	a.coord = Vector2i(1, 1)
	var list: Array[Enterable] = [a]
	_check(Enterable.find_at(list, Vector2i(1, 1)) == a and Enterable.find_at(list, Vector2i.ZERO) == null,
		"core: Enterable.find_at")

	# Generation (seeded so results are reproducible).
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var g1 := TileGridGenerator.generate(5, 0.15, rng)
	rng.seed = 42
	var g2 := TileGridGenerator.generate(5, 0.15, rng)
	# Grids get their own kind objects, so compare by id.
	var kind_ids := func(g: TileGrid) -> Array: return g.tiles.values().map(func(k: TileKind) -> StringName: return k.id)
	_check(kind_ids.call(g1) == kind_ids.call(g2), "gen: same seed gives same grid")
	var counts := {}
	for id: StringName in kind_ids.call(g1):
		counts[id] = counts.get(id, 0) + 1
	_check(g1.kinds.size() == TileGridGenerator.DEFAULT_KINDS.size() and counts.size() == g1.kinds.size() + 1,
		"gen: every default kind, plus Empty, appears (%s)" % counts)
	_check(g1.kinds.all(func(k: TileKind) -> bool: return k.elements.size() == 1 and Items.NAMES.has(k.elements[0])),
		"gen: default kinds each yield one known item")
	_check(g1.find_kind(&"timber").elements == [&"wood"] and g1.find_kind(&"empty") == TileKind.EMPTY
		and g1.find_kind(&"nope") == null, "kinds: find_kind by id")
	var no_empty := TileGridGenerator.generate(5, 0.0, rng)
	_check(not no_empty.tiles.values().has(TileKind.EMPTY), "gen: probability 0 gives no Empty")
	var no_rules: Array[StringName] = []
	var no_required: Dictionary[StringName, int] = {}
	var all_empty := TileGridGenerator.generate(5, 1.0, rng, [], no_rules, no_required)
	_check(all_empty.tiles.values().all(func(k: TileKind) -> bool: return k == TileKind.EMPTY),
		"gen: probability 1 without requirements gives all Empty")
	# Element requirements: the start tile yields aether, and at least 2 tiles do in all.
	var yields_aether := func(k: TileKind) -> bool: return Aether.ITEM in k.elements
	var reqs_met := true
	for seed_value in 30:
		rng.seed = seed_value
		var rg := TileGridGenerator.generate(2, 0.15, rng)
		reqs_met = reqs_met and yields_aether.call(rg.get_tile(TileGridGenerator.START_COORD)) \
			and rg.tiles.values().filter(yields_aether).size() >= 2
	_check(reqs_met, "gen: start tile yields aether and 2+ tiles do, over 30 seeds")
	var bare := TileGridGenerator.generate(5, 1.0, rng)
	var bare_aether := bare.tiles.keys().filter(func(c: Vector2i) -> bool: return yields_aether.call(bare.get_tile(c)))
	_check(bare_aether.size() == 2 and TileGridGenerator.START_COORD in bare_aether
		and bare.tiles.values().filter(func(k: TileKind) -> bool: return k != TileKind.EMPTY).size() == 2,
		"gen: probability 1 leaves only the start tile and one more aether tile (%s)" % [bare_aether])
	var stone_rule: Dictionary[StringName, int] = {&"aether": 2, &"stone": 3}
	var multi := TileGridGenerator.generate(3, 1.0, rng, [], TileGridGenerator.START_ELEMENTS, stone_rule)
	var count_of := func(e: StringName) -> int:
		return multi.tiles.values().filter(func(k: TileKind) -> bool: return e in k.elements).size()
	_check(count_of.call(&"aether") == 2 and count_of.call(&"stone") == 3,
		"gen: several required elements are each met (aether %d, stone %d)" % [count_of.call(&"aether"), count_of.call(&"stone")])
	_check(TileGridGenerator.generate(0, 1.0, rng).get_tile(Vector2i.ZERO).id == &"aether_spring",
		"gen: a one-tile planet still gets its start tile, without looping")

	# Kinds for the grid tests below; rusty gold yields two elements.
	var timber := TileKind.new(&"timber", "Timber", &"sapling", [&"wood"])
	var gold := TileKind.new(&"gold_ore", "Gold Ore", &"gold_ore", [&"gold"])
	var iron := TileKind.new(&"iron_deposit", "Iron Deposit", &"iron_deposit", [&"iron"])
	var rusty_gold := TileKind.new(&"rusty_gold", "Rusty Gold", &"gold_ore", [&"gold", &"iron"])

	# Swap (TileGrid.try_swap).
	var pg := TileGrid.new(2)
	var changes: Array[Vector2i] = []
	pg.tile_changed.connect(func(c: Vector2i, _k: TileKind) -> void: changes.append(c))
	pg.set_tile(Vector2i.ZERO, timber)
	pg.set_tile(Vector2i(0, 1), gold)
	changes.clear()
	_check(pg.try_swap(Vector2i.ZERO, Vector2i(0, 1)), "swap: tiles swap")
	_check(pg.get_tile(Vector2i.ZERO) == gold and pg.get_tile(Vector2i(0, 1)) == timber,
		"swap: Timber and Gold traded places")
	_check(changes.size() == 2, "swap: tile_changed fires for both hexes")
	_check(pg.try_swap(Vector2i(0, 1), Vector2i(0, 2)) and pg.get_tile(Vector2i(0, 1)) == TileKind.EMPTY
		and pg.get_tile(Vector2i(0, 2)) == timber, "swap: with an Empty hex moves the tile")
	_check(not pg.try_swap(Vector2i(0, 2), Vector2i(0, 3)) and pg.get_tile(Vector2i(0, 2)) == timber,
		"swap: can't swap off the grid, no change")
	_check(not pg.try_swap(Vector2i(1, 0), Vector2i(2, 0)), "swap: two Empty hexes is no swap")

	# Foci: the staff grants extract, unknown foci grant nothing.
	_check(Foci.display_name(Foci.STAFF) == "Staff" and Foci.grants(Foci.STAFF, &"extract")
		and not Foci.grants(Foci.STAFF, &"push") and Foci.actions(&"").is_empty(), "foci: staff grants extract")
	_check(GameState.new().equipped_focus == Foci.STAFF, "foci: staff equipped by default")
	_check(Foci.distance(Foci.STAFF) == 1 and Foci.extract_amount(Foci.STAFF) == 1
		and Foci.distance(&"") == 0, "foci: staff has distance 1, extract amount 1")
	_check(Hex.line(Vector2i(1, 1), Vector2i(0, 1), 2) == [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
		"core: Hex.line is the start plus n steps")

	# Extract + inventory.
	var eg := TileGrid.new(1)
	var at := func(c: Vector2i) -> Array[Vector2i]: return [c]
	eg.set_tile(Vector2i.ZERO, timber)
	_check(eg.try_extract(at.call(Vector2i.ZERO)) == [&"wood"] and eg.get_tile(Vector2i.ZERO) == timber
		and eg.cooldown(Vector2i.ZERO) == 5, "extract: returns the elements and taps the tile for 5 actions")
	_check(eg.try_extract(at.call(Vector2i.ZERO)).is_empty(), "extract: tapped tile yields nothing")
	_check(eg.try_extract(at.call(Vector2i(1, 0))).is_empty(), "extract: Empty tile yields nothing")
	_check(eg.try_extract(at.call(Vector2i(9, 9))).is_empty(), "extract: off-grid yields nothing")
	# Lines: every tile must be free and share an element; success taps them all.
	var lg := TileGrid.new(2)
	var line := Hex.line(Vector2i.ZERO, Vector2i(0, 1), 2)  # (0,0) (0,1) (0,2)
	for c in line:
		lg.set_tile(c, iron)
	lg.set_tile(Vector2i(0, 2), gold)
	_check(lg.try_extract(line).is_empty() and lg.cooldowns.is_empty(), "extract: a tile sharing nothing in the line, no change")
	lg.set_tile(Vector2i(0, 2), iron)
	lg.try_extract(at.call(Vector2i(0, 2)))
	_check(lg.try_extract(line).is_empty() and lg.cooldowns.keys() == [Vector2i(0, 2)],
		"extract: a tapped tile in the line, no change")
	for i in lg.tap_cooldown:
		lg.tick_cooldowns()
	_check(lg.try_extract(line) == [&"iron"] and line.all(func(c: Vector2i) -> bool: return lg.cooldown(c) == 5),
		"extract: a matching line taps every tile")
	_check(not lg.can_extract(Hex.line(Vector2i(0, 1), Vector2i(0, 1), 2)), "extract: a line running off the grid fails")
	# Multiple elements: the line yields whatever every tile has, in the first tile's order.
	var mg := TileGrid.new(2)
	var pair := Hex.line(Vector2i.ZERO, Vector2i(0, 1), 1)  # (0,0) (0,1)
	mg.set_tile(pair[0], rusty_gold)
	mg.set_tile(pair[1], rusty_gold)
	_check(mg.extractable_elements(pair) == [&"gold", &"iron"], "extract: same multi-element kind yields all its elements")
	mg.set_tile(pair[1], iron)
	_check(mg.extractable_elements(pair) == [&"iron"], "extract: different kinds yield only the overlap")
	mg.set_tile(pair[0], gold)
	mg.set_tile(pair[1], rusty_gold)
	_check(mg.try_extract(pair) == [&"gold"] and mg.cooldown(pair[0]) == 5 and mg.cooldown(pair[1]) == 5,
		"extract: overlap taps every tile")
	mg.set_tile(pair[0], timber)
	_check(mg.extractable_elements(pair).is_empty(), "extract: kinds sharing nothing yield nothing")
	_check(Items.list_names([&"gold", &"iron"]) == "Gold, Iron" and Items.list_names([]) == "",
		"items: list_names joins display names")
	eg.set_tile(Vector2i(1, 0), gold)
	_check(eg.try_swap(Vector2i.ZERO, Vector2i(1, 0)) and eg.cooldown(Vector2i(1, 0)) == 5
		and not eg.is_tapped(Vector2i.ZERO), "tapped: state moves with the tile on a swap")
	for i in 4:
		eg.tick_cooldowns()
	_check(eg.cooldown(Vector2i(1, 0)) == 1 and not eg.can_extract(at.call(Vector2i(1, 0))), "tapped: 4 ticks leave 1")
	var untapped: Array[Vector2i] = []
	eg.tapped_changed.connect(func(c: Vector2i, left: int) -> void: if left == 0: untapped.append(c))
	eg.tick_cooldowns()
	_check(not eg.is_tapped(Vector2i(1, 0)) and untapped == [Vector2i(1, 0)]
		and eg.try_extract(at.call(Vector2i(1, 0))) == [&"wood"], "tapped: 5th tick untaps it, extractable again")
	var inv := Inventory.new()
	var inv_changes := [0]
	inv.changed.connect(func() -> void: inv_changes[0] += 1)
	inv.add(&"stone")
	inv.add(&"gold", 2)
	_check(inv.owned() == [&"gold", &"stone"], "inventory: owned() follows Items.ORDER")
	_check(inv.spend(&"gold") and inv.count(&"gold") == 1 and not inv.spend(&"aether"), "inventory: spend")
	# Aether: landing tops up to START, moves spend MOVE_COST, and the last one reports empty.
	var purse := Inventory.new()
	Aether.land(purse)
	_check(purse.count(Aether.ITEM) == Aether.START, "aether: landing with none gives START")
	purse.add(Aether.ITEM, 5)
	Aether.land(purse)
	_check(purse.count(Aether.ITEM) == Aether.START + 5, "aether: landing doesn't take away extra")
	purse.spend(Aether.ITEM, purse.count(Aether.ITEM) - 2)
	_check(Aether.pay_move(purse) and purse.count(Aether.ITEM) == 1, "aether: a move spends 1")
	_check(not Aether.pay_move(purse) and purse.count(Aether.ITEM) == 0, "aether: spending the last one reports empty")
	_check(not Aether.pay_move(purse) and purse.count(Aether.ITEM) == 0, "aether: paying with none stays at 0")
	_check(inv_changes[0] == 3, "inventory: changed fires on add/spend")

	var state := GameState.new()
	var first := state.get_or_generate_grid(&"x", 5, 0.15)
	_check(state.get_or_generate_grid(&"x", 5, 0.15) == first, "state: same id returns the stored grid")
	_check(state.get_or_generate_grid(&"y", 5, 0.15) != first, "state: different id gets its own grid")


# Runs the Play scene with the board forced to the given orientation (regardless of what the
# scene file is set to) and drives it with simulated key presses.
func _test_play_scene(pointy_top: bool) -> void:
	var tag := "pointy" if pointy_top else "flat"
	_game().state = GameState.new()
	var play: Node = load("res://scenes/play.tscn").instantiate()
	var board: HexBoard = play.get_node("HexBoard")
	board.pointy_top = pointy_top
	root.add_child(play)
	await process_frame

	var wizard: HexPlayerController = play.get_node("HexBoard/Wizard")
	var sprite: Sprite2D = play.get_node("HexBoard/Wizard/Sprite2D")
	_check(board.layout.pointy_top == pointy_top and board.layout.size == board.hex_size,
		"%s: layout matches board settings" % tag)
	_check(wizard.position == Vector2.ZERO, "%s: wizard starts at origin" % tag)

	# Inventory default selection: nothing when empty, the first item once there is one.
	var panel: InventoryPanel = play.get_node("UI/InventoryPanel")
	var name_label: Label = panel.get_node("%NameLabel")
	_check(panel.selected_item == &"" and name_label.text == "Nothing selected",
		"%s: empty inventory shows Nothing selected" % tag)
	_game().state.inventory.add(&"stone")
	_game().state.inventory.add(&"gold")
	_check(panel.selected_item == &"stone" and name_label.text == "Stone",
		"%s: first item gained is selected, and stays selected" % tag)
	_game().state.inventory.spend(&"stone")
	_check(panel.selected_item == &"gold", "%s: selection falls back to the first item" % tag)

	if pointy_top:
		# Default facing is E; art faces up, so rotated +90 (clockwise) on screen.
		_check_rot(sprite, 90.0, "%s: initial sprite faces E" % tag)

		_press(KEY_D)
		_check_coord(wizard, Vector2i(1, 0), "%s: D moves E" % tag)
		_check(wizard.position.x > 0.0 and is_zero_approx(wizard.position.y), "%s: E is screen-right" % tag)
		_press(KEY_E)
		_check_coord(wizard, Vector2i(1, 1), "%s: E moves NE" % tag)
		_check(wizard.position.y < 0.0, "%s: NE is screen-up" % tag)
		_press(KEY_KP_1)
		_check_coord(wizard, Vector2i(1, 0), "%s: Numpad1 moves SW" % tag)

		_press(KEY_W)  # turns counter-clockwise, E -> NE
		_check(wizard.mover.facing == Vector2i(0, 1), "%s: W turns to NE" % tag)
		_check_rot(sprite, 30.0, "%s: NE sprite rotation" % tag)
		_press(KEY_DOWN)
		_press(KEY_DOWN)  # NE -> E -> SE
		_check(wizard.mover.facing == Vector2i(1, -1), "%s: Down x2 turns to SE" % tag)
		_check_coord(wizard, Vector2i(1, 0), "%s: turning doesn't move" % tag)
	else:
		_check_rot(sprite, 0.0, "%s: initial sprite faces N" % tag)

		_press(KEY_W)
		_check_coord(wizard, Vector2i(0, 1), "%s: W moves N" % tag)
		_check(is_zero_approx(wizard.position.x) and wizard.position.y < 0.0, "%s: N is screen-up" % tag)
		_press(KEY_E)
		_check_coord(wizard, Vector2i(1, 1), "%s: E moves NE" % tag)
		_check(wizard.position.x > 0.0, "%s: NE is screen-right" % tag)
		_press(KEY_Z)
		_check_coord(wizard, Vector2i(0, 1), "%s: Z moves SW" % tag)

		_press(KEY_A)  # turns counter-clockwise, N -> NW
		_check(wizard.mover.facing == Vector2i(-1, 1), "%s: A turns to NW" % tag)
		_check_rot(sprite, -60.0, "%s: NW sprite rotation" % tag)
		_press(KEY_RIGHT)
		_press(KEY_RIGHT)  # NW -> N -> NE
		_check(wizard.mover.facing == Vector2i(1, 0), "%s: Right x2 turns to NE" % tag)
		_check_rot(sprite, 60.0, "%s: NE sprite rotation" % tag)
		_check_coord(wizard, Vector2i(0, 1), "%s: turning doesn't move" % tag)

	play.queue_free()
	await process_frame
	_finished.append("play_pointy" if pointy_top else "play_flat")


# Walk onto Planet A in space, enter it, check the planet scene, then Esc back out.
func _test_enter_planet() -> void:
	_game().state = GameState.new()
	var play: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(play)
	current_scene = play
	await process_frame

	var prompt: CanvasLayer = play.get_node("EnterPrompt")
	var planet_a: Enterable = (play.get_node("HexBoard/PlanetA") as EnterableMarker).enterable
	_check(not prompt.is_showing(), "enter: no prompt at start")
	_press(KEY_ENTER)
	await process_frame
	_check(current_scene == play, "enter: Enter does nothing away from a planet")

	# Planet A sits at (1, 1); route depends on the scene's orientation.
	var board: HexBoard = play.get_node("HexBoard")
	if board.pointy_top:
		_press(KEY_E)  # NE -> (0, 1)
		_press(KEY_D)  # E  -> (1, 1)
	else:
		_press(KEY_W)  # N  -> (0, 1)
		_press(KEY_E)  # NE -> (1, 1)
	_check(prompt.is_showing(), "enter: prompt shows on Planet A")
	var label: String = (prompt.get_node("Button") as Button).text
	_check(label.contains(planet_a.display_name), "enter: prompt names the planet (%s)" % label)
	_check(_game().state.space_coord == planet_a.coord, "enter: space position tracked")

	_press(KEY_ENTER)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/planet.tscn",
		"enter: Enter loads the planet scene")
	_check(_game().state.current_location == planet_a, "enter: current location recorded")
	if current_scene == null or current_scene.scene_file_path != "res://scenes/planet.tscn":
		return

	var tiles: TileGridView = current_scene.get_node("HexBoard/TileGridView")
	var bg: ColorRect = current_scene.get_node("Background/ColorRect")
	var radius: int = current_scene.grid_radius
	_check(tiles.grid.tiles.size() == Hex.hexagon(radius).size(),
		"planet: %d tiles for radius %d" % [tiles.grid.tiles.size(), radius])
	_check(tiles.grid.tiles.values().any(func(k: TileKind) -> bool: return k != TileKind.EMPTY),
		"planet: tiles are generated, not all Empty")
	_check(Aether.ITEM in tiles.grid.get_tile(Vector2i.ZERO).elements, "planet: the start tile yields aether")
	var aether_bar: ProgressBar = current_scene.get_node("%AetherBar")
	var aether_label: Label = current_scene.get_node("%AetherLabel")
	var aether := func() -> int: return _game().state.inventory.count(Aether.ITEM)
	_check(aether.call() == 10 and aether_bar.value == 10 and aether_bar.max_value == 10
		and aether_label.text == "Aether: 10", "aether: land with 10, shown on the bar (%s)" % aether_label.text)
	var header: Control = current_scene.get_node("UI/SidePanel/Margin/Layout/Top/Header")
	_check(aether_bar.global_position.y >= header.get_global_rect().end.y
		and aether_bar.get_global_rect().end.y <= (current_scene.get_node("%Actions") as Control).global_position.y,
		"aether: bar sits under the wizard icon and planet name")
	var tiles_snapshot := tiles.grid.tiles.duplicate()
	_check(bg.color.is_equal_approx(Color(0.19215687, 0.3019608, 0.4745098)), "planet: blue background")
	_check(not (current_scene.get_node("HexBoard") as HexBoard).draw_outlines, "planet: no outlines")
	_check(tiles.hex_color == Color.BLACK, "planet: hexes are black")
	for kind in tiles.grid.kinds:
		_check(tiles.has_icon(kind), "planet: %s draws an icon" % kind.display_name)
	_check(not tiles.has_icon(TileKind.EMPTY), "planet: Empty is a plain hex")
	# Icon animations, read from ICON_ANIMS so tuning doesn't break the test: sampled mid-step, each
	# step shows the next value, wrapping after the last; other channels stay at their defaults.
	for icon: StringName in TileGridView.ICON_ANIMS:
		var anim: Dictionary = TileGridView.ICON_ANIMS[icon]
		var values: Array = anim["values"]
		var expected: Array = values + [values[0]]
		var got: Array = []
		for i in expected.size():
			tiles.anim_time = anim["step"] * (i + 0.5)
			got.append(tiles.anim_value(icon, anim["channel"]))
		var others_default := TileGridView.ANIM_DEFAULTS.keys().all(func(channel: StringName) -> bool:
			return channel == anim["channel"] or tiles.anim_value(icon, channel) == TileGridView.ANIM_DEFAULTS[channel])
		_check(got == expected and others_default, "planet: %s %s animation (%s)"
			% [icon, anim["channel"], got])
	var side_panel: Control = current_scene.get_node("%SidePanel")
	_check((current_scene.get_node("%PlanetName") as Label).text == planet_a.display_name,
		"planet: side panel names the planet")
	var board_screen_x := (current_scene.get_node("HexBoard") as Node2D).get_global_transform_with_canvas().origin.x
	_check(is_equal_approx(board_screen_x, side_panel.get_global_rect().position.x / 2.0),
		"planet: map centered left of the side panel (board at x=%s, panel at x=%s)"
		% [board_screen_x, side_panel.get_global_rect().position.x])
	_check(ItemIcon.color_for(&"wood") == Color(0.4, 0.6, 0.3), "inventory: wood is still a green square")

	# Swap with F: wizard at (0,0) faces N on the flat-top planet, so (0,0) <-> (0,1).
	var lock: ActionLock = current_scene.get_node("ActionLock")
	var actions: Control = current_scene.get_node("%Actions")
	var swap_wizard: HexPlayerController = current_scene.get_node("HexBoard/Wizard")
	# The planet's own kinds (generated from the defaults).
	var timber := tiles.grid.find_kind(&"timber")
	var gold := tiles.grid.find_kind(&"gold_ore")
	var iron := tiles.grid.find_kind(&"iron_deposit")
	var stone := tiles.grid.find_kind(&"stone_outcrop")
	tiles.grid.set_tile(Vector2i.ZERO, timber)
	tiles.grid.set_tile(Vector2i(0, 1), gold)
	_press(KEY_F)
	_check(tiles.grid.get_tile(Vector2i.ZERO) == gold
		and tiles.grid.get_tile(Vector2i(0, 1)) == timber, "planet: F swaps with the faced tile")
	_check(lock.busy and actions.modulate.a < 1.0, "lock: busy and actions dimmed during the swap")
	# Everything but the inventory is blocked until the tween ends.
	var facing_before := swap_wizard.mover.facing
	for key: Key in [KEY_W, KEY_D, KEY_F, KEY_R, KEY_ESCAPE]:
		_press(key)
	_check(swap_wizard.mover.coord == Vector2i.ZERO and swap_wizard.mover.facing == facing_before
		and tiles.grid.get_tile(Vector2i.ZERO) == gold
		and current_scene.scene_file_path == "res://scenes/planet.tscn",
		"lock: move, turn, swap, extract and Esc are blocked")
	var swap_inv_panel: InventoryPanel = current_scene.get_node("UI/InventoryPanel")
	_press(KEY_I)
	_check(swap_inv_panel.visible, "lock: inventory still opens")
	_press(KEY_ESCAPE)
	_check(not swap_inv_panel.visible and current_scene.scene_file_path == "res://scenes/planet.tscn",
		"lock: Esc closes the inventory, doesn't leave")
	await create_timer(0.5).timeout
	_check(not lock.busy and actions.modulate.a == 1.0, "lock: released and actions undimmed after the swap")
	_press(KEY_F)  # Gold back to (0,1), Timber to (0,0)
	await create_timer(0.5).timeout
	_check(tiles.grid.get_tile(Vector2i(0, 1)) == gold, "lock: F works again afterwards")
	tiles.grid.set_tile(Vector2i(0, 1), TileKind.EMPTY)
	# Extract with R: the staff (distance 1) needs the wizard's tile and the faced one, (0,1), to
	# match. Both get tapped; the inventory gains the staff's extract amount (1).
	var inv: Inventory = _game().state.inventory
	tiles.grid.set_tile(Vector2i.ZERO, iron)
	var tile_info: TileInfo = current_scene.get_node("%TileInfo")
	var tile_icon: TextureRect = current_scene.get_node("%TileIcon")
	_check(tile_info.shown_name() == "Iron Deposit" and tile_info.shown_yield() == "Element: Iron"
		and tile_icon.texture != null, "tile info: shows the tile under the wizard (%s / %s)"
		% [tile_info.shown_name(), tile_info.shown_yield()])
	var extract_hint := func() -> String: return (current_scene.get_node("%FocusActions").get_child(0) as Label).text
	_check(extract_hint.call() == "R – Extract: no match", "focus: extract hint says no match (%s)" % extract_hint.call())
	_press(KEY_R)  # (0,1) is Empty: no match
	_check(inv.count(&"iron") == 0 and tiles.grid.cooldowns.is_empty(), "planet: R without a matching line does nothing")
	tiles.grid.set_tile(Vector2i(0, 1), iron)
	tiles.grid.set_tile(Vector2i(1, 0), gold)
	_check(extract_hint.call() == "R – Extract: Iron", "focus: extract hint names the matching element (%s)"
		% extract_hint.call())
	_press(KEY_D)  # face NE, toward the Gold at (1,0)
	var turned_hint: String = extract_hint.call()
	_press(KEY_A)  # back to N
	_check(turned_hint == "R – Extract: no match" and extract_hint.call() == "R – Extract: Iron",
		"focus: extract hint follows turning (%s)" % turned_hint)
	_press(KEY_R)
	_check(tiles.grid.get_tile(Vector2i.ZERO) == iron and inv.count(&"iron") == 1
		and tiles.grid.cooldown(Vector2i.ZERO) == 5 and tiles.grid.cooldown(Vector2i(0, 1)) == 5,
		"planet: R extracts 1 Iron and taps both tiles in the line for 5 actions")
	_check(extract_hint.call() == "R – Extract: no match", "focus: tapped tiles make the hint no match")
	_check(tile_info.shown_name() == "Iron Deposit" and tile_info.shown_tapped() == "tapped: 5"
		and tile_info.shown_yield() == "Element: Iron" and tile_icon.texture is ImageTexture,
		"tile info: tapped beside the name, element unchanged, greyscale icon (%s / %s)"
		% [tile_info.shown_tapped(), tile_info.shown_yield()])
	var grey := (tile_icon.texture as ImageTexture).get_image()
	var any_color := false
	for y in grey.get_height():
		for x in grey.get_width():
			var c := grey.get_pixel(x, y)
			any_color = any_color or (c.a > 0.0 and not (is_equal_approx(c.r, c.g) and is_equal_approx(c.g, c.b)))
	_check(not any_color, "tapped: icon is greyscale")
	# Lined up with the header: icon under the wizard icon, name centered under the planet name.
	var wizard_icon: Control = current_scene.get_node("UI/SidePanel/Margin/Layout/Top/Header/WizardIcon")
	var planet_name: Control = current_scene.get_node("%PlanetName")
	var tile_title: Control = current_scene.get_node("%TileTitle")
	_check(is_equal_approx(tile_icon.global_position.x, wizard_icon.global_position.x)
		and tile_icon.size == wizard_icon.size, "tile info: icon aligned with the wizard icon")
	# Name + tapped note, as one centered row under the planet name (laid out a frame after showing).
	await process_frame
	var title_used := Rect2()
	for part: Control in tile_title.get_children():
		if part.visible:
			title_used = part.get_global_rect() if title_used.size == Vector2.ZERO else title_used.merge(part.get_global_rect())
	_check(absf(title_used.get_center().x - planet_name.get_global_rect().get_center().x) < 1.0,
		"tile info: name and tapped note centered under the planet name")
	# The longest name, tapped, still fits without clipping.
	tiles.grid.set_tile(Vector2i(0, -1), stone)
	tile_info.show_tile(stone, null, 5)
	await process_frame
	var title_slot := tile_info.size.x - 2 * 56.0  # between the icon-width margins
	_check(tile_title.get_combined_minimum_size().x <= title_slot,
		"tile info: \"Stone Outcrop  tapped: 5\" fits (%d of %d px)"
		% [tile_title.get_combined_minimum_size().x, title_slot])
	tiles.grid.set_tile(Vector2i(0, -1), TileKind.EMPTY)  # also refreshes the panel back
	var divider: Control = current_scene.get_node("UI/SidePanel/Margin/Layout/Bottom/Divider")
	var split := (divider.global_position.y - 16.0) / (side_panel.size.y - 32.0)  # within the margins
	_check(absf(split - 0.6) < 0.02 and divider.global_position.y < tile_info.global_position.y,
		"tile info: below a divider 60%% of the way down (%.2f)" % split)
	# Focus box: the equipped staff's name, and the actions it grants.
	var focus_box: Control = current_scene.get_node("%FocusBox")
	var focus_hints: Array = current_scene.get_node("%FocusActions").get_children().map(
		func(l: Label) -> String: return l.text)
	_check(focus_box.visible and (current_scene.get_node("%FocusName") as Label).text == "Staff"
		and focus_hints.size() == 1 and focus_hints[0].begins_with("R – Extract"),
		"focus: box shows Staff with R – Extract (%s)" % [focus_hints])
	var general_hints: Array = current_scene.get_node("%Actions").get_children().map(
		func(l: Label) -> String: return l.text)
	_check(general_hints == ["F – Push"], "focus: Extract moved out of the general actions (%s)" % [general_hints])
	_check(focus_box.global_position.y > (current_scene.get_node("%Actions") as Control).global_position.y
		and focus_box.get_global_rect().end.y < divider.global_position.y, "focus: box sits between Push and the divider")
	_press(KEY_R)
	_check(inv.count(&"iron") == 1 and tiles.grid.cooldown(Vector2i.ZERO) == 5,
		"planet: R on a tapped tile adds nothing and isn't an action")
	# Turning doesn't count down; moving does (W to (0,1), X back to (0,0)).
	_press(KEY_D)
	_press(KEY_A)
	_check(tiles.grid.cooldown(Vector2i.ZERO) == 5, "tapped: turning doesn't count down")
	_press(KEY_W)
	_press(KEY_X)
	_check(tiles.grid.cooldown(Vector2i.ZERO) == 3, "tapped: each move counts down (%d)" % tiles.grid.cooldown(Vector2i.ZERO))
	_check(aether.call() == 8 and aether_bar.value == 8 and aether_label.text == "Aether: 8",
		"aether: each move spends 1, turning is free (%d)" % aether.call())
	# Extract comes from the focus: with none equipped, R does nothing.
	tiles.grid.set_tile(Vector2i(0, -1), timber)
	_game().state.equipped_focus = &""
	_press(KEY_X)  # to (0,-1)
	_press(KEY_R)
	_check(not tiles.grid.is_tapped(Vector2i(0, -1)) and inv.count(&"wood") == 0, "focus: no focus, no extract")
	_game().state.equipped_focus = Foci.STAFF
	_press(KEY_W)  # back to (0,0)

	# Inventory panel: I opens and pauses; Esc closes without leaving the planet.
	var panel: InventoryPanel = current_scene.get_node("UI/InventoryPanel")
	_check(not panel.visible, "inventory: hidden at start")
	_press(KEY_I)
	_check(panel.visible and paused, "inventory: I opens it and pauses")
	_check(panel.shown_items() == [&"aether", &"iron"], "inventory: grid shows owned items (%s)" % [panel.shown_items()])
	var planet_wizard_coord: Vector2i = (current_scene.get_node("HexBoard/Wizard") as HexPlayerController).mover.coord
	_press(KEY_W)
	_check((current_scene.get_node("HexBoard/Wizard") as HexPlayerController).mover.coord == planet_wizard_coord,
		"inventory: wizard can't move while it's open")
	_check(panel.selected_item == &"aether" and (panel.get_node("%NameLabel") as Label).text == "Aether",
		"inventory: first item selected by default")
	panel.select(&"iron")
	_check((panel.get_node("%NameLabel") as Label).text == "Iron"
		and (panel.get_node("%DescriptionLabel") as Label).text == Items.description(&"iron"),
		"inventory: selecting shows name and description")
	_press(KEY_ESCAPE)
	await process_frame
	_check(not panel.visible and not paused, "inventory: Esc closes it and unpauses")
	_check(current_scene.scene_file_path == "res://scenes/planet.tscn", "inventory: Esc didn't also leave the planet")

	# Two elements: tiles that both yield gold and iron give the staff's amount (1) of each.
	var rusty_gold := TileKind.new(&"rusty_gold", "Rusty Gold", &"gold_ore", [&"gold", &"iron"])
	tiles.grid.set_tile(Vector2i.ZERO, rusty_gold)  # setting also clears the tapped state
	tiles.grid.set_tile(Vector2i(0, 1), rusty_gold)
	_check(tile_info.shown_yield() == "Elements: Gold, Iron" and extract_hint.call() == "R – Extract: Gold, Iron",
		"focus: multi-element tile and hint list every element (%s / %s)" % [tile_info.shown_yield(), extract_hint.call()])
	_press(KEY_R)
	_check(inv.count(&"gold") == 1 and inv.count(&"iron") == 2, "planet: R extracts 1 of each shared element")
	# Extracted aether goes into the same pool moving spends.
	var aether_before: int = aether.call()
	tiles.grid.set_tile(Vector2i.ZERO, tiles.grid.find_kind(&"aether_spring"))
	tiles.grid.set_tile(Vector2i(0, 1), tiles.grid.find_kind(&"aether_spring"))
	_press(KEY_R)
	_check(aether.call() == aether_before + 1 and aether_label.text == "Aether: %d" % (aether_before + 1),
		"aether: extracting it refills the bar (%s)" % aether_label.text)
	tiles.grid.set_tile(Vector2i(0, 1), iron)
	tiles.grid.set_tile(Vector2i.ZERO, iron)

	tiles_snapshot = tiles.grid.tiles.duplicate()  # pushed/extracted state should survive a revisit

	# Boundary: walking N from (0,0) stops at the grid's edge.
	var planet_wizard: HexPlayerController = current_scene.get_node("HexBoard/Wizard")
	var aether_before_walk: int = aether.call()
	for i in radius + 3:
		_press(KEY_W)
	_check(planet_wizard.mover.coord == Vector2i(0, radius), "planet: wizard stops at the grid edge (got %s)" % planet_wizard.mover.coord)
	_check(aether.call() == aether_before_walk - radius, "aether: bumping the edge costs nothing (%d left)" % aether.call())
	_check(planet_wizard.position == (current_scene.get_node("HexBoard") as HexBoard).hex_to_local(Vector2i(0, radius)),
		"planet: wizard drawn on the edge hex")
	# Facing N on the flat-top planet: the marker's triangle sits on the top edge, tip pointing up.
	var marker: HexFacingMarker = current_scene.get_node("HexBoard/Wizard/FacingMarker")
	var tri := marker.triangle_points()
	_check(not planet_wizard.has_node("Sprite2D"), "planet: wizard shown by a marker, not a sprite")
	_check(is_zero_approx(tri[2].x) and tri[2].y < tri[0].y and tri[0].y < 0.0,
		"planet: facing triangle points N from the top edge (%s)" % tri)
	_press(KEY_D)  # turn clockwise to NE
	tri = marker.triangle_points()
	_check(tri[2].x > 0.0 and tri[2].y < 0.0, "planet: facing triangle follows a turn to NE (%s)" % tri)

	_press(KEY_ESCAPE)
	await process_frame
	await process_frame
	_check(current_scene.scene_file_path == "res://scenes/play.tscn", "planet: Esc returns to space")
	var wizard: HexPlayerController = current_scene.get_node("HexBoard/Wizard")
	_check(wizard.mover.coord == planet_a.coord, "planet: back on the planet's tile (got %s)" % wizard.mover.coord)
	_check((current_scene.get_node("EnterPrompt") as CanvasLayer).is_showing(), "planet: prompt shows again on return")

	# Re-enter: the planet should look exactly the same.
	var first_visit := tiles_snapshot
	_press(KEY_ENTER)
	await process_frame
	await process_frame
	var revisit: TileGridView = current_scene.get_node("HexBoard/TileGridView")
	_check(revisit.grid.tiles == first_visit, "planet: revisit shows the same tiles")
	# Running out: the move that spends the last aether kicks the wizard back to space.
	var revisit_inv: Inventory = _game().state.inventory
	revisit_inv.spend(Aether.ITEM, revisit_inv.count(Aether.ITEM) - 2)
	_press(KEY_W)
	await process_frame
	_check(current_scene.scene_file_path == "res://scenes/planet.tscn", "aether: still on the planet with 1 left")
	_press(KEY_X)
	await process_frame
	await process_frame
	_check(revisit_inv.count(Aether.ITEM) == 0 and current_scene.scene_file_path == "res://scenes/play.tscn"
		and _game().state.current_location == null, "aether: running out kicks the wizard back to space")
	_press(KEY_ENTER)
	await process_frame
	await process_frame
	_check(current_scene.scene_file_path == "res://scenes/planet.tscn" and revisit_inv.count(Aether.ITEM) == 10,
		"aether: landing again tops back up to 10")
	current_scene.queue_free()
	await process_frame
	_finished.append("enter_planet")


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)


func _check_coord(wizard: HexPlayerController, expected: Vector2i, label: String) -> void:
	_check(wizard.mover.coord == expected, "%s (got %s)" % [label, wizard.mover.coord])


func _check_rot(sprite: Sprite2D, expected: float, label: String) -> void:
	_check(is_equal_approx(sprite.rotation_degrees, expected),
		"%s %s (got %s)" % [label, expected, sprite.rotation_degrees])


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
	print(("  ok   " if cond else "  FAIL ") + label)


# The Game autoload can't be referenced by name from a -s script, so look it up at runtime.
func _game() -> Node:
	return root.get_node("Game")
