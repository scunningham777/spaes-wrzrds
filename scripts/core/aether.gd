class_name Aether
extends RefCounted

# Aether is the element spent to move on a planet. The pool is the inventory's aether count, so
# extracting aether refills it. Landing tops it up to START; running out ends the visit.

const ITEM := &"aether"
## Aether a planet visit starts with at least: landing tops the inventory up to this.
const START := 10
## Aether spent per successful move on a planet.
const MOVE_COST := 1


static func land(inventory: Inventory) -> void:
	if inventory.count(ITEM) < START:
		inventory.add(ITEM, START - inventory.count(ITEM))


# Spends one move's aether (or whatever is left). Returns false once the pool is empty, which
# ends the visit.
static func pay_move(inventory: Inventory) -> bool:
	inventory.spend(ITEM, mini(MOVE_COST, inventory.count(ITEM)))
	return inventory.count(ITEM) > 0
