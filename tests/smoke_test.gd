extends SceneTree

# Headless smoke test:
#   godot_console.exe --headless --path . -s res://tests/smoke_test.gd

var _failures := 0


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
	_check(g1.tiles == g2.tiles, "gen: same seed gives same grid")
	var counts := {}
	for t in g1.tiles.values():
		counts[t] = counts.get(t, 0) + 1
	_check(counts.size() == TileGrid.TileType.size(), "gen: every tile type appears (%s)" % counts)
	var no_empty := TileGridGenerator.generate(5, 0.0, rng)
	_check(not no_empty.tiles.values().has(TileGrid.TileType.EMPTY), "gen: probability 0 gives no Empty")
	var all_empty := TileGridGenerator.generate(5, 1.0, rng)
	_check(all_empty.tiles.values().all(func(t: int) -> bool: return t == TileGrid.TileType.EMPTY),
		"gen: probability 1 gives all Empty")

	# Push (TileGrid.try_push_tile, ported from Unity).
	var T := TileGrid.TileType
	var pg := TileGrid.new(2)
	var changes: Array[Vector2i] = []
	pg.tile_changed.connect(func(c: Vector2i, _t: int) -> void: changes.append(c))
	pg.set_tile(Vector2i(0, 1), T.GOLD_ORE)
	changes.clear()
	_check(pg.try_push_in_front(Vector2i.ZERO, Vector2i(0, 1)), "push: tile in front moves")
	_check(pg.get_tile(Vector2i(0, 1)) == T.EMPTY and pg.get_tile(Vector2i(0, 2)) == T.GOLD_ORE,
		"push: Gold moved from (0,1) to (0,2)")
	_check(changes.size() == 2, "push: tile_changed fires for both hexes")
	_check(not pg.try_push_tile(Vector2i(0, 1), Vector2i(0, 2)), "push: nothing to push from Empty")
	_check(not pg.try_push_tile(Vector2i(0, 2), Vector2i(0, 3)) and pg.get_tile(Vector2i(0, 2)) == T.GOLD_ORE,
		"push: can't push off the grid, no change")
	pg.set_tile(Vector2i(1, 0), T.GOLD_ORE)
	pg.set_tile(Vector2i(2, 0), T.WATER_SPRING)
	pg.try_push_tile(Vector2i(1, 0), Vector2i(2, 0))
	_check(pg.get_tile(Vector2i(1, 0)) == T.EMPTY and pg.get_tile(Vector2i(2, 0)) == T.WATER_SPRING,
		"push: Gold + Water combines to Water (placeholder)")
	pg.set_tile(Vector2i(-1, 0), T.TIMBER)
	pg.set_tile(Vector2i(-2, 0), T.STONE_OUTCROP)
	pg.try_push_tile(Vector2i(-1, 0), Vector2i(-2, 0))
	_check(pg.get_tile(Vector2i(-2, 0)) == T.IRON_DEPOSIT, "push: Timber + Stone combines to Iron (placeholder)")

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
	_check(tiles.grid.tiles.size() == 91, "planet: 91 tiles")
	_check(tiles.grid.tiles.values().any(func(t: int) -> bool: return t != TileGrid.TileType.EMPTY),
		"planet: tiles are generated, not all Empty")
	var tiles_snapshot := tiles.grid.tiles.duplicate()
	_check(bg.color.is_equal_approx(Color(0.19215687, 0.3019608, 0.4745098)), "planet: blue background")
	_check(not (current_scene.get_node("HexBoard") as HexBoard).draw_outlines, "planet: no outlines")

	# Push with F: wizard at (0,0) faces N on the flat-top planet, so (0,1) -> (0,2).
	tiles.grid.set_tile(Vector2i(0, 1), TileGrid.TileType.GOLD_ORE)
	tiles.grid.set_tile(Vector2i(0, 2), TileGrid.TileType.EMPTY)
	_press(KEY_F)
	_check(tiles.grid.get_tile(Vector2i(0, 1)) == TileGrid.TileType.EMPTY
		and tiles.grid.get_tile(Vector2i(0, 2)) == TileGrid.TileType.GOLD_ORE, "planet: F pushes the tile in front")
	tiles_snapshot = tiles.grid.tiles.duplicate()  # pushed state should survive a revisit

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
	current_scene.queue_free()
	await process_frame


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
