extends Node

var god_mode: bool = false
var show_hitboxes: bool = false
var show_debug_text: bool = false
var slow_motion: bool = false
var freeze: bool = false

var debug_enabled: bool:
	get: return god_mode or show_hitboxes or show_debug_text


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_F1:
		god_mode = not god_mode
	elif god_mode:
		if event.keycode == KEY_F2:
			show_hitboxes = not show_hitboxes
		elif event.keycode == KEY_F3:
			show_debug_text = not show_debug_text
		elif event.keycode == KEY_F4:
			slow_motion = not slow_motion
			Engine.time_scale = 0.25 if slow_motion else 1.0
		elif event.keycode == KEY_F:
			freeze = not freeze
			get_tree().paused = freeze
		elif event.keycode == KEY_R:
			for agent: Node in get_tree().get_nodes_in_group("agent"):
				agent.reset_to_patrol()
		elif event.keycode == KEY_K:
			FlaiAlarm.register_kill()
			if show_debug_text:
				print("[DEBUG] Manual register_kill | total=%d" % FlaiAlarm.kill_count)
