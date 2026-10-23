class_name Items
extends RefCounted

# Static item definitions: display names, descriptions and inventory order. Inventory holds
# the counts; this holds what each item *is*. (Structure from the Viking demo's Items.)

## Inventory display order.
const ORDER: Array[StringName] = [&"gold", &"aether", &"iron", &"wood", &"stone"]

const NAMES: Dictionary[StringName, String] = {
	&"gold": "Gold",
	&"aether": "Aether",
	&"iron": "Iron",
	&"wood": "Wood",
	&"stone": "Stone",
}

const DESCRIPTIONS: Dictionary[StringName, String] = {
	&"gold": "Glittering ore chipped from a gold vein. Valuable, if not especially useful on its own.",
	&"aether": "Shimmering blue essence welling up from a planet's aether springs. Spent to move across a planet's surface.",
	&"iron": "Rust-red iron ore. Heavy, and the backbone of anything worth building.",
	&"wood": "Timber cut from alien trees. Burns, bends, and builds.",
	&"stone": "Chunks of rock from a stone outcrop. Solid and plentiful.",
}


static func display_name(item: StringName) -> String:
	return NAMES.get(item, String(item).capitalize())


static func description(item: StringName) -> String:
	return DESCRIPTIONS.get(item, "")


# Display names joined with commas, e.g. "Gold, Iron"; "" for no items.
static func list_names(items: Array[StringName]) -> String:
	return ", ".join(items.map(display_name))
