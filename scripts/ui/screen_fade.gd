class_name ScreenFade
extends CanvasLayer

# Full-screen black overlay for fading between scenes: drawn over everything else in the scene,
# never catches the mouse, and starts clear.

var _rect := ColorRect.new()

## 0 is clear, 1 is black.
var alpha: float:
	get:
		return _rect.color.a
	set(value):
		_rect.color.a = value


func _init() -> void:
	layer = 100
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


# Starts black and clears over seconds.
func fade_in(seconds: float) -> Tween:
	alpha = 1.0
	var tween := create_tween()
	tween.tween_property(self, "alpha", 0.0, seconds)
	return tween


# Fades to black over seconds, after delay seconds. Add callbacks to the returned tween for what
# happens once it's black.
func fade_out(seconds: float, delay: float = 0.0) -> Tween:
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "alpha", 1.0, seconds)
	return tween
