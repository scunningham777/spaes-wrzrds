class_name InventoryPanel
extends PanelContainer

# Grid inventory (I) of the wizard's equipped foci. Pauses the game while open. Clicking a slot
# selects it and shows the focus's description and what it does (Foci.effects). Ported from the
# Viking demo's InventoryPanel, minus crafting mode. Aether isn't shown: it has its own meter.

@export var slot_count := 12
@export var slot_size := Vector2(72, 72)
## Sprite sheet the item icons are cut from (see ItemIcon.ICONS).
@export var icon_sheet: Texture2D

var selected_item: StringName = &""
## Assigned by the owning scene (the game state's equipped foci); read again on each open, so
## changes made with assign() show.
var foci: Array[StringName] = []:
	set(value):
		foci = value
		if is_node_ready():
			_refresh()

var _slots: Array[Button] = []
var _slot_group := ButtonGroup.new()

@onready var _detail_icon: ItemIcon = %DetailIcon
@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _effects_label: Label = %EffectsLabel
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # stays interactive while the game is paused
	hide()
	_detail_icon.icon_sheet = icon_sheet
	_build_slots()
	_refresh()


func _exit_tree() -> void:
	# Leaving the scene while open (shouldn't happen, but never leave the tree paused).
	if visible:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed(&"inventory"):
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	_refresh()
	# Focus the selected item's slot; with nothing equipped there's no focusable slot.
	var focus_slot := _slot_for(selected_item)
	if focus_slot:
		focus_slot.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false


func select(item: StringName) -> void:
	selected_item = item
	# set_pressed_no_signal doesn't release the rest of the button group, so set every slot.
	var slot := _slot_for(item)
	for other in _slots:
		other.set_pressed_no_signal(other == slot)
	_show_details()


## Items currently shown in the grid, in slot order.
func shown_items() -> Array[StringName]:
	var items: Array[StringName] = []
	for slot in _slots:
		if not slot.get_meta(&"item", &"").is_empty():
			items.append(slot.get_meta(&"item"))
	return items


func _build_slots() -> void:
	for i in slot_count:
		var slot := Button.new()
		slot.custom_minimum_size = slot_size
		slot.toggle_mode = true
		slot.button_group = _slot_group
		slot.pressed.connect(func() -> void: select(slot.get_meta(&"item", &"")))

		var icon := ItemIcon.new()
		icon.name = "Icon"
		icon.icon_sheet = icon_sheet
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		_grid.add_child(slot)
		_slots.append(slot)


## Fills slots with the equipped foci, in equip order; the rest stay empty.
func _refresh() -> void:
	# Keep a valid selection: default to the first item, or nothing if none is equipped.
	if selected_item not in foci:
		selected_item = foci[0] if not foci.is_empty() else &""
	for i in _slots.size():
		var slot := _slots[i]
		var item: StringName = foci[i] if i < foci.size() else &""
		slot.set_meta(&"item", item)
		slot.disabled = item.is_empty()
		slot.focus_mode = Control.FOCUS_NONE if item.is_empty() else Control.FOCUS_ALL
		slot.tooltip_text = Foci.display_name(item) if not item.is_empty() else ""
		slot.set_pressed_no_signal(not item.is_empty() and item == selected_item)
		(slot.get_node(^"Icon") as ItemIcon).item = item

	_show_details()


func _show_details() -> void:
	var has_item := not selected_item.is_empty()
	_detail_icon.item = selected_item
	_name_label.text = Foci.display_name(selected_item) if has_item else "Nothing selected"
	_status_label.text = "Equipped" if has_item else ""
	_description_label.text = Foci.description(selected_item) if has_item \
			else "Select an item to see what it is."
	_effects_label.text = "\n".join(Foci.effects(selected_item)) if has_item else ""


func _slot_for(item: StringName) -> Button:
	if item.is_empty():
		return null
	for slot in _slots:
		if slot.get_meta(&"item", &"") == item:
			return slot
	return null
