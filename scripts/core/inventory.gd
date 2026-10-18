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


# Items with a non-zero count, in Items.ORDER first, then anything without a definition.
func owned() -> Array[StringName]:
	var result: Array[StringName] = []
	for item in Items.ORDER:
		if count(item) > 0:
			result.append(item)
	for item: StringName in items:
		if item not in result and count(item) > 0:
			result.append(item)
	return result
