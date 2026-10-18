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

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("%PlayButton") is Button, "menu has Play button")
	menu.queue_free()

	var play: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(play)
	await process_frame

	var board: HexBoard = play.get_node("HexBoard")
	var wizard: HexPlayerController = play.get_node("HexBoard/Wizard")
	var sprite: Sprite2D = play.get_node("HexBoard/Wizard/Sprite2D")
	_check(board.pointy_top, "board is pointy-top")
	_check(wizard.position == Vector2.ZERO, "wizard starts at origin")
	# Pointy-top default facing is E; art faces up, so rotated +90 (clockwise) on screen.
	_check(is_equal_approx(sprite.rotation_degrees, 90.0), "initial sprite faces E (got %s)" % sprite.rotation_degrees)

	_press(KEY_D)
	_check(wizard.current_coord == Vector2i(1, 0), "D moves E (got %s)" % wizard.current_coord)
	_check(wizard.position.x > 0.0 and is_zero_approx(wizard.position.y), "E is screen-right")

	_press(KEY_E)
	_check(wizard.current_coord == Vector2i(1, 1), "E moves NE (got %s)" % wizard.current_coord)
	_check(wizard.position.y < 0.0, "NE is screen-up")

	_press(KEY_KP_1)
	_check(wizard.current_coord == Vector2i(1, 0), "Numpad1 moves SW (got %s)" % wizard.current_coord)

	_press(KEY_W)  # pointy-top: W turns counter-clockwise, E -> NE
	_check(wizard.facing_direction == Vector2i(0, 1), "W turns to NE (got %s)" % wizard.facing_direction)
	_check(is_equal_approx(sprite.rotation_degrees, 30.0), "NE sprite rotation 30 (got %s)" % sprite.rotation_degrees)

	_press(KEY_DOWN)
	_press(KEY_DOWN)  # E -> SE
	_check(wizard.facing_direction == Vector2i(1, -1), "Down x2 turns to SE (got %s)" % wizard.facing_direction)
	_check(wizard.current_coord == Vector2i(1, 0), "turning doesn't move")

	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures else 0)


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
	print(("  ok   " if cond else "  FAIL ") + label)
