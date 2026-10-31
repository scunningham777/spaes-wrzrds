# spaes wrzrds

A small top-down hex-grid game for **Godot 4.7** (GDScript), ported from a Unity prototype.

## Running it

Open `project.godot` in Godot 4.7.x (standard build, not .NET) and press **F5**.

Controls (flat-top hexes): **Q/W/E/Z/X/C** or numpad move · **Enter** enter a planet · **I** inventory ·
**Esc** back. In space the ship faces the way it last moved.

On a planet, the action bar along the bottom of the map shows what you can do where you stand, each tile
with its key (or click it): **M** Move, **F** Push, **R** Extract (needs the staff), **S** Detect (next to
unknown tiles), **N** Mark Node and **B** Build (see below). Move comes first and is where you start: the
side panel shows the direction keys laid out like the hexes they move to. Picking another action opens its
phase in the side panel, where you stay put and the direction keys pick what it aims at instead:

- **Push**: pick a neighbor (outlined faintly, and described under the divider); **Enter** or **Space** swaps it with your tile.
- **Extract**: pick a direction; the line it takes from, your tile plus the staff's reach that way, is outlined, and
  the side panel says what **Enter** / **Space** would extract, or "no match". Extracting taps the tiles for a few actions.
- **Build**: pick a tower (number keys, or click); the side panel says what it needs and whether you have it, and
  **Enter** / **Space** builds it.

A push, extract or build goes back to Move when it's done; **M** or **Esc** go back from any phase, and another
action's key switches straight to it. Push and Extract remember the last direction you picked. Mark Node has no
phase: **N** marks the node at once.

On a planet each move costs the aether (the blue bar) of the tile you step onto, shown as a number
and blue dot in its upper left. Most tiles cost 1, occasionally 2 (never for aether tiles); the
landing tile is outlined in yellow. Pushing a tile takes its cost with it. You land with at least
10; extracting aether refills it, and running out sends you back to space.

When you land, every tile's elements are unknown: their icons are light gray and still, and only tiles you
know can be extracted. Next to an unknown tile, **S** enters detect mode, a guessing game for the ring of tiles around you
(the rest of the map shrinks away, and your wizard moves up to the side panel's corner). The side panel lists every element on the planet, numbered (decoys included).
Select a tile with the movement keys (**S** / numpad 5 for your own) and toggle element guesses with the number
keys; a guess counts for every tile with that icon. **Enter** or **Space** submits: an icon guessed exactly
becomes known everywhere on the planet (its tiles flash green), one partly right (some of its elements, extras or not) turns gold
and the rest (all wrong, or not guessed) turn red, both until the next submit. **M** or **Esc** leaves; detect mode also ends once the whole ring is known.

A planet is a large hex map that wraps around both ways, but you only see what you've explored: you land in a
small hexagon of tiles, and every step reveals the tiles around where you land. How far both reach comes from your
orb (without one, a step reveals just the ring around you). Tiles are generated as they're revealed.

Each planet also has hidden ley lines, 1–2 along each hex axis. Two or more known iron tiles in a row along one get a plum
background; the lines themselves are never shown.

Standing where two or more ley lines cross, **N** marks the crossing as a ley node (outlined in plum, over the
yellow landing outline if they share a tile). At least two of the lines through it must be ones you've seen:
two or more of their tiles plum, or already activated. A marked node can be turned into a tower with **B** (Build), if the
node and the six tiles around it include at least 3 known stone tiles and 2 known iron tiles (the node's own
tile can be anything; those tiles are left as they are). That activates every line through it, lighting up all their tiles. Towers can't be pushed, yield
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
