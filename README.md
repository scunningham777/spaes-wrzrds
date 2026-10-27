# spaes wrzrds

A small top-down hex-grid game for **Godot 4.7** (GDScript), ported from a Unity prototype.

## Running it

Open `project.godot` in Godot 4.7.x (standard build, not .NET) and press **F5**.

Controls (flat-top hexes): **Q/W/E/Z/X/C** or numpad move · **A/D** turn · **Enter** enter a planet ·
**R** extract the tile you're on (needs the staff; taps the tile for a few actions) · **F** swap your tile with
the one you face · **S** detect (see below) · **V** scry (from the middle of the explored area's edge) · **B** build a tower (see below) ·
**I** inventory · **Esc** back.

On a planet each move costs the aether (the blue bar) of the tile you step onto, shown as a number
and blue dot in its upper left. Most tiles cost 1, occasionally 2 (never for aether tiles); the
landing tile is outlined in yellow. Pushing a tile takes its cost with it. You land with at least
10; extracting aether refills it, and running out sends you back to space.

When you land, every tile's elements are unknown: their icons are light gray, and only tiles you know can be
extracted. Next to an unknown tile, **S** enters detect mode, a guessing game for the ring of tiles around you
(the rest of the map shrinks away, and your wizard moves up to the side panel's corner). The side panel lists the elements on the ring's unknown tiles, numbered.
Select a tile with the movement keys (**S** / numpad 5 for your own) and toggle element guesses with the number
keys; a guess counts for every tile with that icon. **Enter** or **Space** submits: an icon guessed exactly
becomes known everywhere on the planet (its tiles flash green), one partly right (some of its elements, extras or not) turns gold
until the next submit. **Esc** leaves; detect mode also ends once the whole ring is known.

A planet is a large hex map that wraps around both ways, but you only see what you've explored: you land in a
small hexagon of tiles, and scrying reveals the next hexagon over, sharing the edge you stand on. Tiles are
generated as they're revealed.

Each planet also has hidden ley lines, 1–2 along each hex axis. Two or more known iron tiles in a row along one get a plum
background; the lines themselves are never shown.

Where two or more ley lines cross, a plum iron tile can be turned into a tower with **B** (10 wood and 10
stone). That activates every line through it, lighting up all their tiles. Towers can't be pushed, yield
nothing yet, and cost 1 aether to step onto.

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

Export → *Convert Text Resources to Binary* is off: in 4.7.2 the conversion dropped the ship's override
of the wizard sprite in `play.tscn`, so exports showed the wizard in space. Keep it off.
