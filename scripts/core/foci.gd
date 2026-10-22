class_name Foci
extends RefCounted

# Static focus definitions. A focus is the wizard's equippable casting item; whichever one is
# equipped (GameState.equipped_focus) grants its own actions on top of the always-available ones.
# Same structure as Items: ids here, the equipped id in GameState.

const STAFF := &"staff"

const NAMES: Dictionary[StringName, String] = {
	STAFF: "Staff",
}

## Action ids (input action names) each focus grants.
const ACTIONS: Dictionary[StringName, Array] = {
	STAFF: [&"extract"],
}


static func display_name(focus: StringName) -> String:
	return NAMES.get(focus, String(focus).capitalize())


static func actions(focus: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ACTIONS.get(focus, []))
	return result


static func grants(focus: StringName, action: StringName) -> bool:
	return action in actions(focus)
