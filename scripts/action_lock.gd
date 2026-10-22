class_name ActionLock
extends Node

# Blocks gameplay input while an action plays out: hand run() the action's Tween and every key
# or button press except the allowed actions (the inventory) is swallowed until it finishes.
# Filters in _input, which runs before any _unhandled_input, so input handlers need no checks of
# their own. Pauses with the tree, like the tweens it waits on, so an open (pausing) inventory
# freezes the lock along with the action.

signal busy_changed(busy: bool)

## Actions that still get through while busy.
@export var allowed_actions: Array[StringName] = [&"inventory"]

var busy: bool:
	get:
		return _running > 0

var _running := 0


# Locks input until tween finishes. Overlapping runs keep the lock until the last one ends.
func run(tween: Tween) -> void:
	_running += 1
	if _running == 1:
		busy_changed.emit(true)
	await tween.finished
	_running -= 1
	if _running == 0:
		busy_changed.emit(false)


func _input(event: InputEvent) -> void:
	if not busy or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	for action in allowed_actions:
		if event.is_action(action):
			return
	get_viewport().set_input_as_handled()
