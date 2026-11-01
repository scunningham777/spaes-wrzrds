class_name Inventory
extends RefCounted

# Item counts (structure from the Viking demo's GameState inventory).

signal changed

var items: Dictionary[StringName, int] = {}


func count(item: StringName) -> int:
	return items.get(item, 0)


func add(item: StringName, amount: int = 1) -> void:
	items[item] = count(item) + amount
	changed.emit()


func spend(item: StringName, amount: int = 1) -> bool:
	if count(item) < amount:
		return false
	items[item] -= amount
	changed.emit()
	return true
