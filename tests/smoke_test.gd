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


# Runs the Play scene with the board forced to the given orientation (regardless of what the
# scene file is set to) and drives it with simulated key presses.
func _test_play_scene(pointy_top: bool) -> void:
	var tag := "pointy" if pointy_top else "flat"
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


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
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
