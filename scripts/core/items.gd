class_name Items
extends RefCounted

# Static item (element) definitions: display names. Inventory holds the counts; this holds what
# each item *is*. (Structure from the Viking demo's Items.) The inventory panel shows equipped foci
# (Foci), not these.

const NAMES: Dictionary[StringName, String] = {
	&"gold": "Gold",
	&"aether": "Aether",
	&"iron": "Iron",
	&"wood": "Wood",
	&"stone": "Stone",
}


static func display_name(item: StringName) -> String:
	return NAMES.get(item, String(item).capitalize())


# Display names joined with commas, e.g. "Gold, Iron"; "" for no items.
static func list_names(items: Array[StringName]) -> String:
	return ", ".join(items.map(display_name))
