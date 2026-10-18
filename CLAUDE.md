# spaes-wrzrds

Godot **4.7** project, **GDScript only** (no C#). Binary: `C:\Tools\Godot_v4.7.2\godot_console.exe`.

- Use Godot 4 APIs and syntax only (`@export`, `@onready`, `await`, `CharacterBody2D`, `TileMapLayer`) – never Godot 3 (`export var`, `yield`, `KinematicBody2D`, `TileMap`).
- Use static typing everywhere (`var x: int`, `func f() -> void`, `:=`).
- Renderer is GL Compatibility so the game can export to web.
- Hex grid: axial coords in `Vector2i(q, r)`; layout (pointy/flat, size) lives on `HexBoard` – grid-positioned nodes are children of the board and convert via `board.hex_to_local()`.
- Input actions are named by key position (`hex_up`, `hex_nw`, ...) because their meaning depends on hex orientation.
- Smoke test: `godot_console.exe --headless --path . -s res://tests/smoke_test.gd`
