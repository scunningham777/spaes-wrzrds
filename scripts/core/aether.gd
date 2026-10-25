class_name Aether
extends RefCounted

# Aether is the element spent to move on a planet. The pool is the inventory's aether count, so
# extracting aether refills it. Landing tops it up to START; running out ends the visit. A move
# costs the move cost of the tile it steps onto (TileGrid.move_cost).

const ITEM := &"aether"
## Aether a planet visit starts with at least: landing tops the inventory up to this.
const START := 10


static func land(inventory: Inventory) -> void:
	if inventory.count(ITEM) < START:
		inventory.add(ITEM, START - inventory.count(ITEM))


# Spends a move's cost in aether (or whatever is left). Returns false once the pool is empty,
# which ends the visit.
static func pay_move(inventory: Inventory, cost: int) -> bool:
	inventory.spend(ITEM, mini(cost, inventory.count(ITEM)))
	return inventory.count(ITEM) > 0
