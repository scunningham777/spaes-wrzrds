# spaes-wrzrds

Godot **4.7** project, **GDScript only** (no C#). Binary: `C:\Tools\Godot_v4.7.2\godot_console.exe`.

- Use Godot 4 APIs and syntax only (`@export`, `@onready`, `await`, `CharacterBody2D`, `TileMapLayer`) – never Godot 3 (`export var`, `yield`, `KinematicBody2D`, `TileMap`).
- Use static typing everywhere (`var x: int`, `func f() -> void`, `:=`).
- Renderer is GL Compatibility so the game can export to web.
- Hex grid: axial coords in `Vector2i(q, r)`; layout (pointy/flat, size) lives on `HexBoard` – grid-positioned nodes are children of the board and convert via `board.hex_to_local()`.
- Input actions are named by key position (`hex_up`, `hex_nw`, ...) because their meaning depends on hex orientation.
- Keep game logic portable (we may later move to 3D, C#, or another engine/framework):
  - Rules, state, and grid math go in plain classes (`extends RefCounted`/`Resource`) that know nothing about nodes, scenes, rendering, or input devices.
  - Nodes are thin adapters: they read input, call into the logic, and present the results (position, rotation, animation). They don't own game rules.
  - Logic talks outward through signals or return values, never by reaching into the scene tree.
  - Logic works in grid/game units (axial hex coords, facings), never pixels; converting to screen space is the view layer's job.
  - Keep tunable data (stats, levels, balance numbers) in data files/resources, not hard-coded in scripts.
  - Logic should be testable headless without instantiating a scene.
  - Note: the ported `HexPlayerController` still mixes input, state, and positioning in one node – split it along these lines when it next grows.
- Smoke test: `godot_console.exe --headless --path . -s res://tests/smoke_test.gd`
