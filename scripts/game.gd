extends Node

# Autoload "Game": holds the cross-scene GameState and switches scenes by destination id, so
# core data (Enterable.destination) never references scene paths.

const SCENES: Dictionary[String, String] = {
	"menu": "res://scenes/main_menu.tscn",
	"space": "res://scenes/play.tscn",
	"planet": "res://scenes/planet.tscn",
}

var state := GameState.new()
## Set when a scene left by fading to black, so the next one fades in from black (take_fade_in).
var fade_in := false


func new_game() -> void:
	state = GameState.new()
	go_to("space")


# faded: space faded to black on its way out, so the location fades in.
func enter(location: Enterable, faded: bool = false) -> void:
	state.current_location = location
	fade_in = faded
	go_to(location.destination)


# faded: the location faded to black on its way out, so space fades in.
func leave_location(faded: bool = false) -> void:
	state.current_location = null
	fade_in = faded
	go_to("space")


# Whether the arriving scene should fade in; clears it, so only that scene does.
func take_fade_in() -> bool:
	var faded := fade_in
	fade_in = false
	return faded


func go_to(destination: String) -> void:
	assert(SCENES.has(destination), "Unknown destination: %s" % destination)
	get_tree().change_scene_to_file(SCENES[destination])
