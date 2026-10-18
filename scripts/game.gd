extends Node

# Autoload "Game": holds the cross-scene GameState and switches scenes by destination id, so
# core data (Enterable.destination) never references scene paths.

const SCENES: Dictionary[String, String] = {
	"menu": "res://scenes/main_menu.tscn",
	"space": "res://scenes/play.tscn",
	"planet": "res://scenes/planet.tscn",
}

var state := GameState.new()


func new_game() -> void:
	state = GameState.new()
	go_to("space")


func enter(location: Enterable) -> void:
	state.current_location = location
	go_to(location.destination)


func leave_location() -> void:
	state.current_location = null
	go_to("space")


func go_to(destination: String) -> void:
	assert(SCENES.has(destination), "Unknown destination: %s" % destination)
	get_tree().change_scene_to_file(SCENES[destination])
