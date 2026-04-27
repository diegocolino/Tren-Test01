## Cross (W2). Fases internas: anticipation → release → recovery.
class_name Cross extends State

var kive: Kive
var stats: KiveStats
var phase: String = "anticipation"
var phase_timer: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	kive.w_chain_step = 1
	kive._w_chain_timer = 0.0
	if DebugOverlay.show_debug_text:
		print("[%s] enter | chain_step=%d" % [name, kive.w_chain_step])

	kive.is_punch_charged = false
	kive.current_attack_type = "punch"

	phase = "anticipation"
	phase_timer = 0.0
	kive.sprite.play("idle")


func exit() -> void:
	kive.current_attack_type = "none"


func physics_update(delta: float) -> StringName:
	phase_timer += delta

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	match phase:
		"anticipation":
			if phase_timer >= stats.punch_anticipation:
				phase = "release"
				phase_timer = 0.0
				kive.sprite.play("punch_contact")
				kive.activate_hitbox()
		"release":
			if phase_timer >= stats.punch_release:
				phase = "recovery"
				phase_timer = 0.0
				kive.sprite.play("idle")
		"recovery":
			var in_cancel_window: bool = phase_timer >= stats.punch_recovery - stats.w_chain_cancel_window
			if in_cancel_window and Input.is_action_just_pressed("attack_punch"):
				return &"Hook"
			if phase_timer >= stats.punch_recovery:
				return _decide_next_state()

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""


func _decide_next_state() -> StringName:
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	return &"Idle"
