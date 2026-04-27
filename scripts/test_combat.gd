extends Node

func _ready() -> void:
	DebugOverlay.show_debug_text = true
	DebugOverlay.show_hitboxes = true

	var kive: Node = $Kive
	if kive:
		var camera: Camera2D = kive.get_node("Camera2D")
		if camera:
			camera.limit_left = -10000
			camera.limit_right = 10000
