extends Node2D

# Space map: offers entry to any Enterable the wizard is standing on (Unity's Overworld
# Enterable trigger + Enter Button), and remembers the wizard's position across scenes.

## Fade in from black, when arriving from a scene that faded out (Game.fade_in).
@export var fade_in_seconds: float = 0.3

@onready var _board: HexBoard = $HexBoard
@onready var _wizard: HexPlayerController = $HexBoard/Wizard
@onready var _prompt := $EnterPrompt
@onready var _fade: ColorRect = %Fade

var _enterables: Array[Enterable] = []
var _available: Enterable = null


# Runs before children's _ready, so the wizard starts where it was left.
func _enter_tree() -> void:
	($HexBoard/Wizard as HexPlayerController).start_coord = Game.state.space_coord


func _ready() -> void:
	($UI/InventoryPanel as InventoryPanel).inventory = Game.state.inventory
	for child in _board.get_children():
		if child is EnterableMarker:
			_enterables.append(child.enterable)
	_wizard.mover.moved.connect(_on_wizard_moved)
	_prompt.enter_requested.connect(_enter_available)
	_on_wizard_moved(_wizard.mover.coord)
	if Game.fade_in:
		Game.fade_in = false
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.0, fade_in_seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _available != null:
		# Before entering: the scene change removes this node from the tree immediately.
		get_viewport().set_input_as_handled()
		_enter_available()
	elif event.is_action_pressed("ui_cancel"):
		Game.go_to("menu")


func _on_wizard_moved(coord: Vector2i) -> void:
	Game.state.space_coord = coord
	var here := Enterable.find_at(_enterables, coord)
	_available = here if here != null and here.meets_requirements() else null
	if _available != null:
		_prompt.show_prompt(_available)
	else:
		_prompt.hide_prompt()


func _enter_available() -> void:
	if _available != null:
		Game.enter(_available)
