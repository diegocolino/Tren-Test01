extends Node

var debug_enabled: bool = true
var show_timeline: bool = true
var show_hitboxes: bool = true
var show_state_info: bool = true
var show_parry_windows: bool = true
var show_distance: bool = true
var show_flashlight_cone: bool = true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			debug_enabled = not debug_enabled
			_toggle_debug_visuals()
		elif event.keycode == KEY_F2 and debug_enabled:
			show_hitboxes = not show_hitboxes
		elif event.keycode == KEY_F3 and debug_enabled:
			show_timeline = not show_timeline
		elif event.keycode == KEY_F4 and debug_enabled:
			show_flashlight_cone = not show_flashlight_cone


func _toggle_debug_visuals() -> void:
	for node in get_tree().get_nodes_in_group("debug_visual"):
		node.visible = debug_enabled
