class_name Aether
extends RefCounted

# Aether is the element spent to move on a planet. The pool is the inventory's aether count, so
# extracting aether refills it. Landing tops it up to START; running out ends the visit. A move
# costs the move cost of the tile it steps onto (TileGrid.move_cost).
#
# Stepping onto a tile known to yield aether collects some by itself (collect), as long as a
# neighbor is one too: whoever runs the moves collects before paying for them, so a step onto an
# aether tile with the last aether in the pool doesn't end the visit.

const ITEM := &"aether"
## Aether a planet visit starts with at least: landing tops the inventory up to this.
const START := 10
## Aether a step gains by collecting (see collect).
const COLLECT_AMOUNT := 2


static func land(inventory: Inventory) -> void:
	if inventory.count(ITEM) < START:
		inventory.add(ITEM, START - inventory.count(ITEM))


# Spends a move's cost in aether (or whatever is left). Returns false once the pool is empty,
# which ends the visit.
static func pay_move(inventory: Inventory, cost: int) -> bool:
	inventory.spend(ITEM, mini(cost, inventory.count(ITEM)))
	return inventory.count(ITEM) > 0


# Collects aether on stepping onto coord: if its tile and at least one neighbor are known to yield
# aether and untapped, taps the tile and one such neighbor (the first in Hex.hexagon order; as
# extracting does, TileGrid.try_extract) and adds COLLECT_AMOUNT to inventory. Returns the stored
# copies of the two tapped tiles, or [] (and changes nothing) if there was nothing to collect.
static func collect(grid: TileGrid, inventory: Inventory, coord: Vector2i) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if not _collectable(grid, coord):
		return coords
	coords.append(grid.canonical(coord))
	for offset in Hex.hexagon(1):
		var c := grid.canonical(coord + offset)
		if not c in coords and _collectable(grid, c):
			coords.append(c)
			break
	if coords.size() < 2:
		coords.clear()
		return coords
	grid.try_extract(coords)
	inventory.add(ITEM, COLLECT_AMOUNT)
	return coords


static func _collectable(grid: TileGrid, coord: Vector2i) -> bool:
	return grid.is_known(coord) and ITEM in grid.get_tile(coord).elements and not grid.is_tapped(coord)
