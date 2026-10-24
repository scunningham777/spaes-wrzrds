# spaes wrzrds

A small top-down hex-grid game for **Godot 4.7** (GDScript), ported from a Unity prototype.

## Running it

Open `project.godot` in Godot 4.7.x (standard build, not .NET) and press **F5**.

Controls (flat-top hexes): **Q/W/E/Z/X/C** or numpad move · **A/D** turn · **Enter** enter a planet ·
**R** extract the tile you're on (needs the staff; taps the tile for a few actions) · **F** swap your tile with
the one you face · **V** scry (from the middle of the explored area's edge) · **I** inventory · **Esc** back.

On a planet each move costs 1 aether (the blue bar). You land with at least 10; extracting aether
refills it, and running out sends you back to space. The landing tile always yields aether.

A planet is a large hex map that wraps around both ways, but you only see what you've explored: you land in a
small hexagon of tiles, and scrying reveals the next hexagon over, sharing the edge you stand on. Tiles are
generated as they're revealed.

Each planet also has hidden ley lines, 1–2 along each hex axis. Two or more iron tiles in a row along one get a grey
background; the lines themselves are never shown.

## Tests

```
godot_console.exe --headless --path . -s res://tests/smoke_test.gd    # prints SMOKE TEST PASSED
```

## Builds (itch.io)

`export_presets.cfg` has *Web* (single-threaded, so itch.io needs no special headers) and *Windows Desktop* (one
.exe with the data embedded). With the 4.7.2 export templates installed (Editor → Manage Export Templates):

```
godot --headless --path . --export-release "Web" builds/web/index.html
godot --headless --path . --export-release "Windows Desktop" builds/windows/spaes-wrzrds.exe
```

`builds/` holds a `.gdignore` so Godot doesn't import the exported files back into the project; everything else in
it is git-ignored. For itch.io, zip the *contents* of `builds/web/` (index.html at the root) and upload it as an HTML
game; zip the .exe for the Windows download.
