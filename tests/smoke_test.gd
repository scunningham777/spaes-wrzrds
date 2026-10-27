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
	(menu.get_node("%CreditsButton") as Button).pressed.emit()
	_check(menu.get_node("%Credits").visible and not menu.get_node("Center").visible, "menu: Credits shows the credits")
	_check((menu.get_node("%Version") as Label).text == "Version %s" % ProjectSettings.get_setting("application/config/version"),
		"menu: credits show the project version")
	(menu.get_node("%LicensesButton") as Button).pressed.emit()
	var license_text := (menu.get_node("%LicenseText") as RichTextLabel).text
	_check(menu.get_node("%Licenses").visible and license_text.begins_with("This game uses Godot Engine")
		and "FreeType" in license_text, "menu: Licenses shows Godot's and third-party licenses")
	(menu.get_node("%LicensesBackButton") as Button).pressed.emit()
	_check(menu.get_node("%Credits").visible and not menu.get_node("%Licenses").visible, "menu: Back from Licenses returns to the credits")
	(menu.get_node("%BackButton") as Button).pressed.emit()
	_check(menu.get_node("Center").visible and not menu.get_node("%Credits").visible, "menu: Back returns to the menu")
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
	var grid := _hexagon_grid(5)
	_check(grid.tiles.size() == 91 and grid.has_tile(Vector2i(5, -5)) and not grid.has_tile(Vector2i(5, 1)),
		"core: TileGrid holds just the tiles added")
	_check(Hex.distance(Vector2i(2, -1)) == 2 and Hex.distance(Vector2i(3, 3)) == 6
		and Hex.distance(Vector2i(1, 1), Vector2i(1, 1)) == 0, "core: Hex.distance")

	# Wrapping (HexTorus): 8 columns around, 6 rows down.
	var torus := HexTorus.new(8, 6)
	_check(torus.canonical(Vector2i(8, -4)) == Vector2i.ZERO and torus.canonical(Vector2i(0, 6)) == Vector2i.ZERO
		and torus.canonical(Vector2i(-1, 0)) == Vector2i(7, 2), "torus: wrap finds the stored copy")
	_check(torus.nearest(Vector2i(7, 2), Vector2i.ZERO) == Vector2i(-1, 0)
		and torus.nearest(Vector2i(0, 5), Vector2i(0, 1)) == Vector2i(0, -1)
		and torus.nearest(Vector2i(1, 1), Vector2i.ZERO) == Vector2i(1, 1), "torus: nearest copy, across the wrap")
	var flat_layout := HexLayout.new(false, 1.0)
	_check(is_zero_approx(flat_layout.hex_to_point(Vector2i(8, -4)).y) and is_zero_approx(flat_layout.hex_to_point(Vector2i(0, 6)).x),
		"torus: flat-top wraps straight across and straight down")
	var tg := TileGrid.new(torus)
	var revealed_at: Array[Vector2i] = []
	tg.tile_changed.connect(func(c: Vector2i, _k: TileKind) -> void: revealed_at.append(c))
	tg.add_tile(Vector2i(-1, 0), TileKind.EMPTY)
	_check(tg.has_tile(Vector2i(7, 2)) and tg.has_tile(Vector2i(-1, 6)) and tg.tiles.keys() == [Vector2i(7, 2)]
		and revealed_at == [Vector2i(7, 2)], "torus: a grid stores and reports one copy of each tile")

	var a := Enterable.new()
	a.coord = Vector2i(1, 1)
	var list: Array[Enterable] = [a]
	_check(Enterable.find_at(list, Vector2i(1, 1)) == a and Enterable.find_at(list, Vector2i.ZERO) == null,
		"core: Enterable.find_at")

	# Generation (seeded so results are reproducible).
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var g1 := TileGridGenerator.generate(8, 0.15, rng)
	rng.seed = 42
	var g2 := TileGridGenerator.generate(8, 0.15, rng)
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
	var all_empty := TileGridGenerator.generate(8, 1.0, rng)
	_check(all_empty.tiles.values().all(func(k: TileKind) -> bool: return k == TileKind.EMPTY),
		"gen: probability 1 gives all Empty, landing tile included")

	# Kinds for the grid tests below; rusty gold yields two elements.
	var timber := TileKind.new(&"timber", "Timber", &"sapling", [&"wood"])
	var gold := TileKind.new(&"gold_ore", "Gold Ore", &"gold_ore", [&"gold"])
	var iron := TileKind.new(&"iron_deposit", "Iron Deposit", &"iron_deposit", [&"iron"])
	var rusty_gold := TileKind.new(&"rusty_gold", "Rusty Gold", &"gold_ore", [&"gold", &"iron"])

	# Swap (TileGrid.try_swap).
	var pg := _hexagon_grid(2)
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
	_check(Foci.distance(Foci.STAFF) == 1 and Foci.extract_amount(Foci.STAFF) >= 1
		and Foci.distance(&"") == 0 and Foci.extract_amount(&"") == 0, "foci: staff has distance 1 and extracts something")
	_check(Hex.line(Vector2i(1, 1), Vector2i(0, 1), 2) == [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
		"core: Hex.line is the start plus n steps")

	# Extract + inventory.
	var eg := _hexagon_grid(1)
	var at := func(c: Vector2i) -> Array[Vector2i]: return [c]
	eg.set_tile(Vector2i.ZERO, timber)
	_check(eg.try_extract(at.call(Vector2i.ZERO)) == [&"wood"] and eg.get_tile(Vector2i.ZERO) == timber
		and eg.cooldown(Vector2i.ZERO) == 5, "extract: returns the elements and taps the tile for 5 actions")
	_check(eg.try_extract(at.call(Vector2i.ZERO)).is_empty(), "extract: tapped tile yields nothing")
	_check(eg.try_extract(at.call(Vector2i(1, 0))).is_empty(), "extract: Empty tile yields nothing")
	_check(eg.try_extract(at.call(Vector2i(9, 9))).is_empty(), "extract: off-grid yields nothing")
	# Lines: every tile must be free and share an element; success taps them all.
	var lg := _hexagon_grid(2)
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
	var mg := _hexagon_grid(2)
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
	# Known: revealed tiles start unknown and yield nothing; knowing moves with the tile on a swap,
	# and a replaced tile is known.
	var kg := _hexagon_grid(1)
	var stone_kind := TileKind.new(&"stone_outcrop", "Stone Outcrop", &"", [&"stone"] as Array[StringName])
	kg.add_tile(Vector2i(5, 5), stone_kind)
	var known_changes: Array[Vector2i] = []
	kg.known_changed.connect(func(c: Vector2i, _known: bool) -> void: known_changes.append(c))
	_check(not kg.is_known(Vector2i(5, 5)) and not kg.can_extract(at.call(Vector2i(5, 5)))
		and kg.any_unknown(at.call(Vector2i(5, 5))), "known: a revealed tile is unknown and yields nothing")
	kg.set_known(Vector2i(5, 5))
	_check(kg.is_known(Vector2i(5, 5)) and kg.try_extract(at.call(Vector2i(5, 5))) == [&"stone"]
		and known_changes == [Vector2i(5, 5)], "known: once known it yields its element")
	kg.set_known(Vector2i(9, 9))
	_check(not kg.is_known(Vector2i(9, 9)) and known_changes.size() == 1
		and not kg.any_unknown(at.call(Vector2i(9, 9))), "known: off-grid coords are never known or unknown")
	kg.set_tile(Vector2i.ZERO, timber)
	_check(kg.is_known(Vector2i.ZERO) and not kg.is_known(Vector2i(1, 0)), "known: a replaced tile is known")
	# (1, 0) is Empty and unknown; swap it with the known timber.
	_check(kg.try_swap(Vector2i.ZERO, Vector2i(1, 0)) and kg.is_known(Vector2i(1, 0))
		and not kg.is_known(Vector2i.ZERO), "known: state moves with the tile on a swap")
	_check(not kg.any_unknown([Vector2i(1, 0), Vector2i(5, 5)] as Array[Vector2i])
		and kg.any_unknown([Vector2i(1, 0), Vector2i.ZERO] as Array[Vector2i]), "known: any_unknown finds an unknown tile")
	var frozen := HexMover.new(HexLayout.new(false))
	frozen.frozen = true
	var frozen_facing := frozen.facing
	frozen.turn(1)
	_check(not frozen.move(Hex.Compass.N) and frozen.coord == Vector2i.ZERO and frozen.facing != frozen_facing,
		"core: a frozen mover can't move but can turn")
	frozen.frozen = false
	_check(frozen.move(Hex.Compass.N), "core: an unfrozen mover moves again")
	var inv := Inventory.new()
	var inv_changes := [0]
	inv.changed.connect(func() -> void: inv_changes[0] += 1)
	inv.add(&"stone")
	inv.add(&"gold", 2)
	_check(inv.owned() == [&"gold", &"stone"], "inventory: owned() follows Items.ORDER")
	_check(inv.spend(&"gold") and inv.count(&"gold") == 1 and not inv.spend(&"aether"), "inventory: spend")
	# Aether: landing tops up to START, moves spend their cost, and the last one reports empty.
	var purse := Inventory.new()
	Aether.land(purse)
	_check(purse.count(Aether.ITEM) == Aether.START, "aether: landing with none gives START")
	purse.add(Aether.ITEM, 5)
	Aether.land(purse)
	_check(purse.count(Aether.ITEM) == Aether.START + 5, "aether: landing doesn't take away extra")
	purse.spend(Aether.ITEM, purse.count(Aether.ITEM) - 4)
	_check(Aether.pay_move(purse, 0) and purse.count(Aether.ITEM) == 4, "aether: a free move spends nothing")
	_check(Aether.pay_move(purse, 2) and purse.count(Aether.ITEM) == 2, "aether: a move spends its cost")
	_check(Aether.pay_move(purse, 1) and purse.count(Aether.ITEM) == 1, "aether: a move spends 1")
	_check(not Aether.pay_move(purse, 2) and purse.count(Aether.ITEM) == 0, "aether: a cost past what's left spends the rest")
	_check(not Aether.pay_move(purse, 1) and purse.count(Aether.ITEM) == 0, "aether: paying with none stays at 0")
	_check(inv_changes[0] == 3, "inventory: changed fires on add/spend")

	var state := GameState.new()
	var first := state.get_or_create_surface(&"x", 2, 4, 3, 0.15)
	_check(state.get_or_create_surface(&"x", 2, 4, 3, 0.15) == first, "state: same id returns the stored surface")
	_check(state.get_or_create_surface(&"y", 2, 4, 3, 0.15) != first, "state: different id gets its own surface")

	_test_planet_surface()
	_test_ley_lines()


# PlanetSurface: patches revealed by scrying on a wrapping planet.
func _test_planet_surface() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var surface := PlanetSurface.new(2, 4, 3, TileGridGenerator.new(0.0, rng))  # 16 x 18 tiles, 24 patches
	var g := surface.grid
	_check(g.torus.width == 16 and g.torus.height == 18, "surface: torus sized in patches (%dx%d)" % [g.torus.width, g.torus.height])
	_check(g.tiles.size() == 19 and surface.patches.keys() == [Vector2i.ZERO], "surface: lands with one radius-2 patch revealed")
	# The middles of the landing patch's six edges, one step of each PATCH_STEPS direction out.
	var spots := Hex.hexagon(2).filter(surface.can_scry)
	_check(spots == [Vector2i(-2, 1), Vector2i(-1, -1), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(1, 1), Vector2i(2, -1)],
		"surface: scry only from the middle of an edge (%s)" % [spots])
	_check(surface.scry_target(Vector2i(2, -1)) == Vector2i(4, -2), "scry: targets the patch mirrored across the edge")

	var before := g.tiles.duplicate()
	_check(surface.try_scry(Vector2i(2, -1)) and g.tiles.size() == 19 + 16, "scry: reveals a patch sharing one 3-tile edge")
	_check(before.keys().all(func(c: Vector2i) -> bool: return g.get_tile(c) == before[c]),
		"scry: already revealed tiles keep their kinds")
	_check(not surface.can_scry(Vector2i(2, -1)) and not surface.try_scry(Vector2i(2, -1)) and g.tiles.size() == 35,
		"scry: the shared edge is no longer the explored edge")
	_check(surface.can_scry(Vector2i(6, -3)) and surface.can_scry(Vector2i(3, 0)), "scry: works from the new patch's edges")
	_check(not surface.can_scry(Vector2i(9, 9)), "scry: not from off the explored area")

	# Scrying east around the planet: the fourth patch over is the landing one again.
	_check(surface.try_scry(Vector2i(6, -3)) and surface.try_scry(Vector2i(10, -5)), "wrap: scry onward east")
	_check(surface.patches.size() == 4 and g.tiles.size() == 4 * 19 - 4 * 3,
		"wrap: a ring of 4 patches meets the landing one edge to edge (%d tiles)" % g.tiles.size())
	_check(not surface.can_scry(Vector2i(14, -7)) and not surface.can_scry(Vector2i(-2, 1)),
		"wrap: no scry across the seam where the ring closed")
	# Reveal everything: the patches cover the planet exactly once over.
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	while not frontier.is_empty():
		var center: Vector2i = frontier.pop_back()
		for step in PlanetSurface.PATCH_STEPS:
			if surface.reveal_patch(center + step * 2):
				frontier.append(center + step * 2)
	_check(surface.patches.size() == 24 and g.tiles.size() == 16 * 18,
		"wrap: all %d patches cover all %d tiles" % [surface.patches.size(), g.tiles.size()])
	_check(Hex.hexagon(2).all(func(c: Vector2i) -> bool: return not surface.can_scry(c)), "wrap: nothing left to scry")
	# Move costs: aether tiles cost 1 and the rest 1, or occasionally 2.
	var revealed: Array[Vector2i] = g.tiles.keys()
	_check(revealed.all(func(c: Vector2i) -> bool:
		return g.move_cost(c) == (1 if Aether.ITEM in g.get_tile(c).elements else g.move_cost(c)) and g.move_cost(c) in [1, 2]),
		"cost: tiles cost 1, aether ones always")
	_check(revealed.any(func(c: Vector2i) -> bool: return g.move_cost(c) == 2), "cost: some tiles cost 2")
	var rough: Vector2i = revealed.filter(func(c: Vector2i) -> bool: return g.move_cost(c) == 2)[0]
	# A lap across the 16 x 18 torus shifts r back by 8.
	_check(g.move_cost(rough + Vector2i(16, -8)) == 2, "cost: any copy of a coord has its cost")
	var rough_neighbor := g.canonical(rough + Vector2i(1, 0))
	var neighbor_cost := g.move_cost(rough_neighbor)
	g.try_swap(rough, rough_neighbor)
	_check(g.move_cost(rough_neighbor) == 2 and g.move_cost(rough) == neighbor_cost, "cost: travels with the tile in a swap")
	var same := TileGrid.new()
	same.add_tile(Vector2i.ZERO, TileKind.EMPTY, 2)
	same.add_tile(Vector2i(1, 0), TileKind.EMPTY)
	_check(same.try_swap(Vector2i.ZERO, Vector2i(1, 0)) and same.move_cost(Vector2i(1, 0)) == 2
		and same.move_cost(Vector2i.ZERO) == 0, "cost: tiles differing only in cost can swap")
	# Odd radius: edges have 4 tiles, so either middle one scries.
	var odd := PlanetSurface.new(3, 3, 2)
	_check(Hex.hexagon(3).filter(odd.can_scry).size() == 12 and odd.scry_target(Vector2i(3, -1)) == Vector2i(6, -3)
		and odd.scry_target(Vector2i(3, -2)) == Vector2i(6, -3), "surface: odd radius scries from both middle tiles")


# LeyLines: hidden lines along each axis; iron runs along them resonate.
func _test_ley_lines() -> void:
	var torus := HexTorus.new(48, 24)
	var rng := RandomNumberGenerator.new()
	var counts_ok := true
	var lengths_ok := true
	var apart_ok := true
	for seed_value in 20:
		rng.seed = seed_value
		var ley := LeyLines.generate(torus, rng)
		for axis in LeyLines.AXES:
			var on_axis := ley.lines.filter(func(l: LeyLines.Line) -> bool: return l.direction == axis)
			counts_ok = counts_ok and on_axis.size() >= 1 and on_axis.size() <= 2
			for line: LeyLines.Line in on_axis:
				# One lap: the vertical axis is height tiles long, the diagonals width.
				lengths_ok = lengths_ok and line.tiles.size() == (24 if axis == Vector2i(0, 1) else 48)
			if on_axis.size() == 2:
				var first: LeyLines.Line = on_axis[0]
				var second: LeyLines.Line = on_axis[1]
				apart_ok = apart_ok and first.tiles.keys().all(func(c: Vector2i) -> bool:
					return LeyLines.AXES.all(func(a: Vector2i) -> bool:
						return not second.tiles.has(torus.canonical(c + a)) and not second.tiles.has(torus.canonical(c - a))))
	_check(counts_ok, "ley: 1 or 2 lines along each axis, over 20 seeds")
	_check(lengths_ok, "ley: lines run once around a planet sized for it")
	_check(apart_ok, "ley: lines on the same axis never touch")
	var surface := PlanetSurface.new(2, 12, 4)
	_check(surface.ley_lines != null and surface.ley_lines.lines.size() >= 3, "ley: planets get their lines when made")

	# Resonance, with one hand-placed NE line through the origin.
	var ley := LeyLines.new(torus)
	ley.add_line(Vector2i.ZERO, Vector2i(1, 0))
	var on_line := func(c: Vector2i) -> bool: return ley.lines[0].tiles.has(torus.canonical(c))
	_check(on_line.call(Vector2i(5, 0)) and on_line.call(Vector2i(48, -24)) and not on_line.call(Vector2i(0, 1)),
		"ley: add_line covers the line, across the wrap too")
	var iron := TileKind.new(&"iron_deposit", "Iron Deposit", &"iron_deposit", [&"iron"])
	var gold := TileKind.new(&"gold_ore", "Gold Ore", &"gold_ore", [&"gold"])
	var g := TileGrid.new(torus)
	for c in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(5, 0), Vector2i(6, 0)]:
		g.add_tile(c, gold)
	g.set_tile(Vector2i.ZERO, iron)
	_check(not ley.is_resonant(g, Vector2i.ZERO), "ley: a lone iron tile on a line doesn't resonate")
	g.set_tile(Vector2i(0, 1), iron)
	_check(not ley.is_resonant(g, Vector2i.ZERO) and not ley.is_resonant(g, Vector2i(0, 1)),
		"ley: iron next to it off the line doesn't count")
	g.set_tile(Vector2i(1, 0), iron)
	_check(ley.is_resonant(g, Vector2i.ZERO) and ley.is_resonant(g, Vector2i(1, 0))
		and not ley.is_resonant(g, Vector2i(0, 1)) and not ley.is_resonant(g, Vector2i(-1, 0)),
		"ley: two iron in a row along the line both resonate, nothing else")
	g.set_known(Vector2i(1, 0), false)
	_check(not ley.is_resonant(g, Vector2i.ZERO) and not ley.is_resonant(g, Vector2i(1, 0)),
		"ley: iron only counts once it's known")
	g.set_known(Vector2i(1, 0))
	g.set_tile(Vector2i(5, 0), iron)
	g.set_tile(Vector2i(6, 0), iron)
	var off := LeyLines.new(torus)
	off.add_line(Vector2i(0, 3), Vector2i(1, 0))
	_check(not off.is_resonant(g, Vector2i.ZERO), "ley: iron runs off every line don't resonate")
	# A line that has to wrap: the run continues across the seam.
	var seam := TileGrid.new(torus)
	seam.add_tile(Vector2i(47, 0), iron)  # (-1, 0), one step back from (0, 0) along NE, stored across the wrap
	seam.add_tile(Vector2i.ZERO, iron)
	for c: Vector2i in seam.tiles:
		seam.set_known(c)
	_check(ley.is_resonant(seam, Vector2i.ZERO) and ley.is_resonant(seam, Vector2i(-1, 0)),
		"ley: runs carry across the wrap")

	# Towers: built on a detected iron tile where two or more lines cross.
	_check(not ley.is_intersection(Vector2i.ZERO), "ley: one line through a tile is no intersection")
	ley.add_line(Vector2i.ZERO, Vector2i(0, 1))
	_check(ley.is_intersection(Vector2i.ZERO) and ley.is_intersection(Vector2i(48, -24))
		and not ley.is_intersection(Vector2i(1, 0)), "ley: two lines crossing make an intersection, across the wrap too")
	var lone := TileGrid.new(torus)
	lone.add_tile(Vector2i.ZERO, iron)
	_check(Towers.can_build_at(g, ley, Vector2i.ZERO) and not Towers.can_build_at(g, ley, Vector2i(1, 0))
		and not Towers.can_build_at(lone, ley, Vector2i.ZERO) and not Towers.can_build_at(g, null, Vector2i.ZERO),
		"tower: site needs detected iron where lines cross")
	var stock := Inventory.new()
	stock.add(&"wood", 10)
	stock.add(&"stone", 9)
	_check(Towers.cost_text(Towers.BASIC) == "10 Wood, 10 Stone" and not Towers.try_build(Towers.BASIC, g, ley, stock, Vector2i.ZERO)
		and g.get_tile(Vector2i.ZERO) == iron and stock.count(&"wood") == 10, "tower: can't build short of stone, no change")
	stock.add(&"stone", 1)
	_check(not ley.is_active(Vector2i.ZERO), "ley: lines start inactive")
	_check(Towers.try_build(Towers.BASIC, g, ley, stock, Vector2i.ZERO) and g.get_tile(Vector2i.ZERO) == Towers.kind(Towers.BASIC)
		and stock.count(&"wood") == 0 and stock.count(&"stone") == 0, "tower: building spends 10 wood and 10 stone")
	var tower := g.get_tile(Vector2i.ZERO)
	_check(tower.display_name == "Basic Tower" and tower.elements.is_empty() and not tower.movable
		and g.move_cost(Vector2i.ZERO) == 1, "tower: a Basic Tower yields nothing, can't move, and costs 1 to enter")
	_check(not g.try_swap(Vector2i.ZERO, Vector2i(1, 0)) and not g.try_swap(Vector2i(1, 0), Vector2i.ZERO)
		and g.get_tile(Vector2i.ZERO) == tower, "tower: can't be pushed, or have a tile pushed onto it")
	_check(not Towers.can_build_at(g, ley, Vector2i.ZERO), "tower: its tile is no longer a site")
	_check(ley.lines.all(func(l: LeyLines.Line) -> bool: return l.active) and ley.is_active(Vector2i(10, 0))
		and ley.is_active(Vector2i(0, 7)) and ley.is_active(Vector2i(48, -24)) and not ley.is_active(Vector2i(1, 1)),
		"tower: building activates every line through it, and only tiles on them")


# A plane grid with a radius-sized hexagon of Empty tiles.
static func _hexagon_grid(radius: int) -> TileGrid:
	var grid := TileGrid.new()
	for c in Hex.hexagon(radius):
		grid.add_tile(c, TileKind.EMPTY)
	return grid


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
	_check(sprite.region_rect == Rect2(1015, 66, 12, 12), "%s: in space the player is the ship, cell (78, 5)" % tag)

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
	var planet_a_icon := (play.get_node("HexBoard/PlanetA") as EnterableMarker).icon as AtlasTexture
	_check(planet_a_icon != null and planet_a_icon.region == Rect2(1106, 248, 12, 12),
		"enter: Planet A drawn with sheet tile (85, 19)")
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

	# Entering fades space to black first, with input blocked, then the planet fades in.
	_press(KEY_ENTER)
	await process_frame
	var space_out_fade: ScreenFade = play.get_node("Fade")
	_press(KEY_X)  # would step off the planet
	_press(KEY_ENTER)
	_check(current_scene == play and _game().state.space_coord == planet_a.coord and _game().state.current_location == null,
		"enter: space stays up, input blocked, while it fades out")
	await create_timer(play.fade_out_seconds / 2.0).timeout
	_check(current_scene == play and space_out_fade.alpha > 0.0 and space_out_fade.alpha < 1.0,
		"enter: space fades to black (%.2f)" % space_out_fade.alpha)
	await _await_scene("res://scenes/planet.tscn")
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/planet.tscn",
		"enter: Enter loads the planet scene")
	if current_scene != null and current_scene.has_node("Fade"):
		var planet_in_fade: ScreenFade = current_scene.get_node("Fade")
		_check(planet_in_fade.alpha > 0.5 and not _game().fade_in,
			"enter: the planet fades in (%.2f)" % planet_in_fade.alpha)
		await create_timer(current_scene.fade_in_seconds + 0.1).timeout
		_check(planet_in_fade.alpha == 0.0, "enter: planet fade-in finishes clear")
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
	_check(tiles.grid.known.is_empty() and (current_scene.get_node("%TileInfo") as TileInfo).shown_yield() == "Elements: unknown",
		"known: every tile's elements are unknown on landing")
	var detect_hint: Label = current_scene.get_node("%DetectHint")
	_check(detect_hint.visible and detect_hint.text == "S – Detect", "detect: hint shows next to unknown tiles")
	# Unknown icons are flat light gray, keeping the icon's shape (alpha).
	var unknown_icon := tiles.icon_texture(tiles.grid.kinds[0], false, false).get_image()
	var unknown_pixels: Array[Color] = []
	for y in unknown_icon.get_height():
		for x in unknown_icon.get_width():
			if unknown_icon.get_pixel(x, y).a > 0.0:
				unknown_pixels.append(unknown_icon.get_pixel(x, y))
	_check(not unknown_pixels.is_empty() and unknown_pixels.all(func(c: Color) -> bool:
		return absf(c.r - tiles.unknown_icon_color.r) < 0.01 and c.r == c.g and c.g == c.b),  # 8-bit channels
		"known: unknown icons draw in light gray")
	var aether_bar: ProgressBar = current_scene.get_node("%AetherBar")
	var aether_label: Label = current_scene.get_node("%AetherLabel")
	var aether := func() -> int: return _game().state.inventory.count(Aether.ITEM)
	_check(aether.call() == 10 and aether_bar.value == 10 and aether_bar.max_value == 10
		and aether_label.text == "Aether: 10", "aether: land with 10, shown on the bar (%s)" % aether_label.text)
	_check(tiles.grid.tiles.keys().all(func(c: Vector2i) -> bool: return tiles.grid.move_cost(c) > 0)
		and tiles.landing == Vector2i.ZERO, "cost: every tile costs aether, and the landing tile is outlined")
	# The checks below count aether spent per step, so make every step cost 1.
	for c in Hex.hexagon(radius):
		tiles.grid.set_move_cost(c, 1)
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
	var amount := Foci.extract_amount(Foci.STAFF)
	_check(tiles.grid.get_tile(Vector2i.ZERO) == iron and inv.count(&"iron") == amount
		and tiles.grid.cooldown(Vector2i.ZERO) == 5 and tiles.grid.cooldown(Vector2i(0, 1)) == 5,
		"planet: R extracts the staff's amount of Iron and taps both tiles in the line for 5 actions")
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
	var general_hints: Array = current_scene.get_node("%Actions").get_children().filter(
		func(l: Label) -> bool: return l.visible).map(func(l: Label) -> String: return l.text)
	_check(general_hints == ["S – Detect", "F – Push"], "focus: Extract moved out of the general actions (%s)" % [general_hints])
	_check(focus_box.global_position.y > (current_scene.get_node("%Actions") as Control).global_position.y
		and focus_box.get_global_rect().end.y < divider.global_position.y, "focus: box sits between Push and the divider")
	_press(KEY_R)
	_check(inv.count(&"iron") == amount and tiles.grid.cooldown(Vector2i.ZERO) == 5,
		"planet: R on a tapped tile adds nothing and isn't an action")
	# Turning doesn't count down; moving does (W to (0,1), X back to (0,0)).
	_press(KEY_D)
	_press(KEY_A)
	_check(tiles.grid.cooldown(Vector2i.ZERO) == 5, "tapped: turning doesn't count down")
	# Pushing doesn't either, or pushing a tapped tile back and forth would untap it for free.
	_press(KEY_D)  # face NE, toward the Gold at (1,0)
	_press(KEY_F)
	await create_timer(0.5).timeout
	_check(tiles.grid.get_tile(Vector2i(1, 0)) == iron and tiles.grid.cooldown(Vector2i(1, 0)) == 5,
		"tapped: pushing a tapped tile doesn't count down")
	_press(KEY_F)  # and back
	await create_timer(0.5).timeout
	_press(KEY_A)
	_check(tiles.grid.get_tile(Vector2i.ZERO) == iron and tiles.grid.cooldown(Vector2i.ZERO) == 5
		and tiles.grid.cooldown(Vector2i(0, 1)) == 5, "tapped: pushing back and forth doesn't count down")
	_press(KEY_W)
	_press(KEY_X)
	_check(tiles.grid.cooldown(Vector2i.ZERO) == 3, "tapped: each move counts down (%d)" % tiles.grid.cooldown(Vector2i.ZERO))
	_check(aether.call() == 8 and aether_bar.value == 8 and aether_label.text == "Aether: 8",
		"aether: each move spends 1, turning is free (%d)" % aether.call())
	tiles.grid.set_move_cost(Vector2i(0, 1), 2)
	_press(KEY_W)
	_check(aether.call() == 6, "aether: a move spends the cost of the tile stepped onto (%d)" % aether.call())
	tiles.grid.set_move_cost(Vector2i(0, 1), 1)
	_press(KEY_X)
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
	_check(inv.count(&"gold") == amount and inv.count(&"iron") == 2 * amount,
		"planet: R extracts the staff's amount of each shared element")
	# Extracted aether goes into the same pool moving spends.
	var aether_before: int = aether.call()
	tiles.grid.set_tile(Vector2i.ZERO, tiles.grid.find_kind(&"aether_spring"))
	tiles.grid.set_tile(Vector2i(0, 1), tiles.grid.find_kind(&"aether_spring"))
	_press(KEY_R)
	_check(aether.call() == aether_before + amount and aether_label.text == "Aether: %d" % (aether_before + amount),
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
	# The wizard sprite stands upright over the tile's icon; the marker shows the facing.
	var planet_sprite := planet_wizard.get_node_or_null("Sprite2D") as Sprite2D
	_check(planet_sprite != null and is_zero_approx(planet_sprite.rotation), "planet: upright wizard sprite on the wizard's tile")
	_check(planet_wizard.get_index() > tiles.get_index(), "planet: wizard sprite drawn over the tile icons")
	# Wizard low on its tile, the tile's icon high; icons elsewhere stay centered.
	_check(planet_sprite != null and planet_sprite.position.y > 0.0 and planet_sprite.scale.x == tiles.icon_scale,
		"planet: wizard sprite sits low, at the icon scale")
	_check(tiles.icon_shift(planet_wizard.mover.coord).y < 0.0, "planet: the wizard's tile icon shifts up")
	_check(tiles.icon_shift(planet_wizard.mover.coord + Vector2i(0, -1)) == Vector2.ZERO,
		"planet: other tiles' icons stay centered")
	_check((tiles.get_node("Overlay") as Node2D).z_index > planet_wizard.z_index,
		"planet: cooldown numbers draw over the wizard")
	var planet_board := current_scene.get_node("HexBoard") as HexBoard
	_check(tiles.landing_scale > planet_board.tile_scale, "planet: landing outline sits outside the wizard's outline")
	_check(is_zero_approx(tri[2].x) and tri[2].y < tri[0].y and tri[0].y < 0.0,
		"planet: facing triangle points N from the top edge (%s)" % tri)
	_press(KEY_D)  # turn clockwise to NE
	tri = marker.triangle_points()
	_check(tri[2].x > 0.0 and tri[2].y < 0.0, "planet: facing triangle follows a turn to NE (%s)" % tri)

	# Detect: next to an unknown tile S enters detect mode. The wizard's outline takes in the ring of
	# tiles around them, and they can't move or take other actions (turning still works) until S or
	# Esc leaves it.
	var interaction: Node = current_scene.get_node("TileInteraction")  # untyped: its script uses the Game autoload
	var single_outline := marker.outline_points()
	_check(interaction.can_detect_here() and detect_hint.visible, "detect: available at the edge, next to unknown tiles")
	_press(KEY_S)
	var ring := marker.outline_points()
	_check(interaction.detecting and planet_wizard.mover.frozen and marker.outline_radius == interaction.detect_radius,
		"detect: S enters detect mode")
	# The 18 outer edges of the wizard's tile and its ring, closed, all clear of the wizard's own tile.
	_check(ring.size() == 19 and ring[0] == ring[18] and Array(ring).all(func(p: Vector2) -> bool:
		return p.length() > planet_board.hex_size * 1.5), "detect: outline takes in the ring around the wizard (%d points)" % ring.size())
	_check(detect_hint.text == "S / Esc – Stop Detecting" and focus_box.modulate.a < 1.0
		and (current_scene.get_node("%PushHint") as Control).modulate.a < 1.0,
		"detect: hint says how to stop, blocked actions dim (%s)" % detect_hint.text)
	var detect_coord := planet_wizard.mover.coord
	var detect_aether: int = aether.call()
	var detect_tiles := tiles.grid.tiles.duplicate()
	var detect_cooldowns := tiles.grid.cooldowns.duplicate()
	for key: Key in [KEY_W, KEY_X, KEY_Q, KEY_E, KEY_Z, KEY_C, KEY_KP_8, KEY_R, KEY_F, KEY_V, KEY_B]:
		_press(key)
	_check(planet_wizard.mover.coord == detect_coord and aether.call() == detect_aether and not lock.busy
		and tiles.grid.tiles == detect_tiles and tiles.grid.cooldowns == detect_cooldowns and interaction.detecting,
		"detect: moves and other actions are blocked")
	var detect_facing := planet_wizard.mover.facing
	_press(KEY_D)
	_check(planet_wizard.mover.facing != detect_facing and interaction.detecting, "detect: turning still works")
	_press(KEY_A)
	_press(KEY_S)
	_check(not interaction.detecting and not planet_wizard.mover.frozen and marker.outline_points() == single_outline
		and focus_box.modulate.a == 1.0 and detect_hint.text == "S – Detect", "detect: S again leaves detect mode")
	_press(KEY_S)
	_press(KEY_ESCAPE)
	_check(not interaction.detecting and current_scene.scene_file_path == "res://scenes/planet.tscn",
		"detect: Esc leaves detect mode without leaving the planet")
	var known_before_detect := tiles.grid.known.duplicate()
	for c in interaction.detect_area():
		tiles.grid.set_known(c)
	_press(KEY_S)
	_check(not interaction.can_detect_here() and not detect_hint.visible and not interaction.detecting,
		"detect: unavailable with nothing unknown around")
	for c in interaction.detect_area():
		tiles.grid.set_known(c, known_before_detect.has(tiles.grid.canonical(c)))

	# Ley lines: hidden, but iron runs along one turn plum.
	_check(tiles.ley_lines != null and tiles.ley_lines.lines.size() >= 3, "ley: the planet view has the planet's lines")
	var planet_ley := tiles.ley_lines
	var test_ley := LeyLines.new(tiles.grid.torus)
	test_ley.add_line(Vector2i.ZERO, Vector2i(0, 1))  # straight N-S through the landing tile
	tiles.ley_lines = test_ley
	for c in [Vector2i(0, -2), Vector2i(0, 1), Vector2i(0, 2)]:  # line tiles that mustn't extend a run
		tiles.grid.set_tile(c, gold)
	tiles.grid.set_tile(Vector2i(0, -1), iron)
	tiles.grid.set_tile(Vector2i.ZERO, gold)
	tiles.grid.set_tile(Vector2i(1, 0), iron)
	_check(tiles.fill_color(Vector2i(0, -1)) == tiles.hex_color and tiles.fill_color(Vector2i(1, 0)) == tiles.hex_color,
		"ley: lines themselves don't show")
	tiles.grid.set_tile(Vector2i.ZERO, iron)
	_check(tiles.fill_color(Vector2i.ZERO) == tiles.ley_color and tiles.fill_color(Vector2i(0, -1)) == tiles.ley_color
		and tiles.ley_color == Color(0.38, 0.03, 0.41) and tiles.fill_color(Vector2i(1, 0)) == tiles.hex_color,
		"ley: an iron run along the line turns plum")
	tiles.grid.set_known(Vector2i(0, -1), false)
	_check(tiles.fill_color(Vector2i.ZERO) == tiles.hex_color and tiles.fill_color(Vector2i(0, -1)) == tiles.hex_color,
		"ley: unknown iron doesn't turn plum")
	tiles.grid.set_known(Vector2i(0, -1))
	# Standing on a resonating tile, the tile info says so, in a plum badge under the elements.
	var ley_info: TileInfo = current_scene.get_node("%TileInfo")
	var ley_badge: Label = current_scene.get_node("%TileLeyLine")
	_check(ley_info.shown_ley_line() == "", "ley: no badge on a tile that doesn't resonate")
	_game().state.inventory.add(Aether.ITEM, 4)  # for the walk there and back
	_press(KEY_X)
	_press(KEY_X)  # (0, 2) -> (0, 0)
	await process_frame
	var yield_label: Label = current_scene.get_node("%TileYield")
	_check(ley_info.shown_ley_line() == "ley line detected"
		and ley_badge.get_global_rect().position.y >= yield_label.get_global_rect().end.y
		and absf(ley_badge.get_global_rect().get_center().x - yield_label.get_global_rect().get_center().x) < 1.0,
		"ley: resonating tile shows the badge, centered under the elements")
	_check((ley_badge.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color == tiles.ley_color
		and ley_badge.get_theme_color(&"font_color") == Color.WHITE, "ley: badge is white on the ley color")
	tiles.grid.set_tile(Vector2i(0, -1), gold)
	_check(ley_info.shown_ley_line() == "", "ley: badge goes when the run is broken")
	tiles.grid.set_tile(Vector2i(0, -1), iron)

	# Tower: where a second line crosses, B turns the detected iron tile into a Basic Tower.
	var build_hint: Label = current_scene.get_node("%BuildHint")
	_check(not build_hint.visible, "tower: no build hint where only one line runs")
	test_ley.add_line(Vector2i.ZERO, Vector2i(1, 0))
	tiles.grid.set_tile(Vector2i.ZERO, iron)  # refreshes the side panel
	_check(build_hint.visible and build_hint.text == "B – Build Tower (needs 10 Wood, 10 Stone)"
		and build_hint.get_index() == (current_scene.get_node("%ScryHint") as Label).get_index() + 1,
		"tower: hint shows where lines cross, with the cost, below Scry (%s)" % build_hint.text)
	var stock: Inventory = _game().state.inventory
	for item: StringName in [&"wood", &"stone"]:
		if stock.count(item) > 0:
			stock.spend(item, stock.count(item))
	stock.add(&"wood", 10)
	stock.add(&"stone", 9)
	_press(KEY_B)
	_check(tiles.grid.get_tile(Vector2i.ZERO) == iron and stock.count(&"wood") == 10,
		"tower: B does nothing without enough stone")
	stock.add(&"stone", 1)
	_press(KEY_B)
	await process_frame
	_check(tiles.grid.get_tile(Vector2i.ZERO).id == Towers.BASIC and stock.count(&"wood") == 0
		and stock.count(&"stone") == 0 and tiles.grid.move_cost(Vector2i.ZERO) == 1,
		"tower: B builds a Basic Tower, spending 10 wood and 10 stone")
	_check(ley_info.shown_name() == "Basic Tower" and ley_info.shown_yield() == "Element: none" and not build_hint.visible,
		"tower: standing on it shows Basic Tower with no elements, and the hint goes")
	_check(tiles.has_icon(tiles.grid.get_tile(Vector2i.ZERO))
		and (tiles.icon_texture(tiles.grid.get_tile(Vector2i.ZERO)) as AtlasTexture).region == Rect2(443, 508, 12, 12),
		"tower: drawn with sprite cell (34, 39)")
	# Both lines through it light up end to end: every tile on them turns plum and shows the badge.
	_check(ley_info.shown_ley_line() == "ley line activated", "tower: its tile shows ley line activated")
	_check(tiles.fill_color(Vector2i.ZERO) == tiles.ley_color and tiles.fill_color(Vector2i(0, 2)) == tiles.ley_color
		and tiles.fill_color(Vector2i(0, -2)) == tiles.ley_color and tiles.fill_color(Vector2i(2, 0)) == tiles.ley_color
		and tiles.fill_color(Vector2i(-2, 0)) == tiles.ley_color and tiles.fill_color(Vector2i(-1, 2)) == tiles.hex_color,
		"tower: every tile on both lines turns plum, not just iron runs")
	_press(KEY_F)
	_check(tiles.grid.get_tile(Vector2i.ZERO).id == Towers.BASIC, "tower: F can't push it")
	tiles.grid.set_tile(Vector2i.ZERO, iron)  # back to iron for the tests below
	_press(KEY_W)
	_press(KEY_W)  # back to (0, 2)
	_check(tiles.grid.get_tile(Vector2i(0, 2)) == gold and ley_info.shown_ley_line() == "ley line activated",
		"tower: a non-iron tile on an activated line shows ley line activated")
	tiles.ley_lines = planet_ley

	# Scry: from the middle of the landing patch's edge, V reveals the next patch over.
	var scry_hint: Label = current_scene.get_node("%ScryHint")
	var actions_box: Control = current_scene.get_node("%Actions")
	_game().state.inventory.add(Aether.ITEM, 10)  # plenty for the walk
	_check(not scry_hint.visible, "scry: no hint away from an edge middle")
	_press(KEY_V)
	_check(tiles.grid.tiles.size() == Hex.hexagon(radius).size(), "scry: V does nothing away from an edge middle")
	for key in [KEY_X, KEY_X, KEY_C, KEY_E]:  # (0, 2) -> (0, 0) -> SE (1, -1) -> NE (2, -1)
		_press(key)
	_check_coord(planet_wizard, Vector2i(2, -1), "scry: walked to the east edge's middle")
	_check(scry_hint.visible and scry_hint.text == "V – Scry"
		and actions_box.get_child(scry_hint.get_index() - 1).name == "PushHint", "scry: hint shows, below Push")
	var camera: Camera2D = current_scene.get_node("Camera2D")
	_check(camera.position == planet_wizard.position and tiles.view_center == planet_wizard.mover.coord,
		"planet: camera and view follow the wizard")
	var known_before_scry := tiles.grid.known.size()
	_press(KEY_V)
	_check(tiles.grid.known.size() == known_before_scry, "known: scried tiles are unknown")
	_check(tiles.grid.tiles.size() == 2 * Hex.hexagon(radius).size() - (radius + 1),
		"scry: V reveals a second patch sharing an edge (%d tiles)" % tiles.grid.tiles.size())
	_check(not scry_hint.visible, "scry: hint hides once the edge is explored")
	_press(KEY_E)  # NE onto (3, -1), only on the new patch
	_check_coord(planet_wizard, Vector2i(3, -1), "scry: can walk onto the revealed patch")
	tiles_snapshot = tiles.grid.tiles.duplicate()  # the revisit should keep the scried patch

	# Esc fades out too, with input blocked, and space fades in.
	var esc_scene := current_scene
	_press(KEY_ESCAPE)
	await process_frame
	var esc_coord := planet_wizard.mover.coord
	_press(KEY_W)
	_check(current_scene == esc_scene and planet_wizard.mover.coord == esc_coord,
		"planet: after Esc, the planet stays up with input blocked while it fades out")
	await create_timer(esc_scene.fade_out_seconds / 2.0).timeout
	var esc_fade: ScreenFade = esc_scene.get_node("Fade")
	_check(current_scene == esc_scene and esc_fade.alpha > 0.0 and esc_fade.alpha < 1.0,
		"planet: Esc fades to black (%.2f)" % esc_fade.alpha)
	await _await_scene("res://scenes/play.tscn")
	_check(current_scene.scene_file_path == "res://scenes/play.tscn", "planet: Esc returns to space")
	_check((current_scene.get_node("Fade") as ScreenFade).alpha > 0.5, "space: fades in after Esc")
	var wizard: HexPlayerController = current_scene.get_node("HexBoard/Wizard")
	_check(wizard.mover.coord == planet_a.coord, "planet: back on the planet's tile (got %s)" % wizard.mover.coord)
	_check((current_scene.get_node("EnterPrompt") as CanvasLayer).is_showing(), "planet: prompt shows again on return")

	# Re-enter: the planet should look exactly the same.
	var first_visit := tiles_snapshot
	_press(KEY_ENTER)
	await _await_scene("res://scenes/planet.tscn")
	await create_timer(current_scene.fade_in_seconds + 0.1).timeout  # the running-out checks watch the fade
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
	# Running out: a message first, with everything (inventory and Esc too) blocked, then a fade.
	var out_scene := current_scene
	var out_message: Label = out_scene.get_node("%OutOfAetherMessage")
	var fade: ScreenFade = out_scene.get_node("Fade")
	var out_wizard: HexPlayerController = out_scene.get_node("HexBoard/Wizard")
	var out_coord := out_wizard.mover.coord
	for key: Key in [KEY_W, KEY_I, KEY_ESCAPE]:
		_press(key)
	await process_frame
	_check(current_scene == out_scene and revisit_inv.count(Aether.ITEM) == 0 and out_message.visible
		and out_message.text.begins_with("Out of aether.") and fade.alpha == 0.0,
		"aether: running out shows a message before leaving")
	_check(out_wizard.mover.coord == out_coord and not (out_scene.get_node("UI/InventoryPanel") as Control).visible,
		"aether: moving, the inventory and Esc are blocked while it shows")
	await create_timer(out_scene.out_of_aether_message_seconds + out_scene.out_of_aether_fade_seconds / 2.0).timeout
	_check(current_scene == out_scene and fade.alpha > 0.0 and fade.alpha < 1.0,
		"aether: then fades to black (%.2f)" % fade.alpha)
	var waited := 0.0
	while current_scene == out_scene and waited < out_scene.out_of_aether_fade_seconds + 0.5:
		await process_frame
		waited += 1.0 / 60.0
	await process_frame
	_check(revisit_inv.count(Aether.ITEM) == 0 and current_scene.scene_file_path == "res://scenes/play.tscn"
		and _game().state.current_location == null, "aether: running out kicks the wizard back to space")
	# Space fades back in from black, just this once.
	var space_fade: ScreenFade = current_scene.get_node("Fade")
	_check(space_fade.alpha > 0.5 and not _game().fade_in, "space: fades in after running out (%.2f)" % space_fade.alpha)
	await create_timer(current_scene.fade_in_seconds + 0.1).timeout
	_check(space_fade.alpha == 0.0, "space: fade-in finishes clear")
	_press(KEY_ENTER)
	await _await_scene("res://scenes/planet.tscn")
	_check(current_scene.scene_file_path == "res://scenes/planet.tscn" and revisit_inv.count(Aether.ITEM) == 10,
		"aether: landing again tops back up to 10")
	current_scene.queue_free()
	await process_frame
	_finished.append("enter_planet")


# Waits (up to 2 seconds) for a scene change that comes after a fade, plus a frame for it to settle.
func _await_scene(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while (current_scene == null or current_scene.scene_file_path != path) and Time.get_ticks_msec() < deadline:
		await process_frame
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
