extends Node

var debug_enabled: bool = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		debug_enabled = not debug_enabled
		_toggle_debug_visuals()


func _toggle_debug_visuals() -> void:
	for node in get_tree().get_nodes_in_group("debug_visual"):
		node.visible = debug_enabled
