## FrontalKick (Q standalone / Q en contexto W). Fases: anticipation → release → recovery.
class_name FrontalKick extends State

var kive: Kive
var stats: KiveStats
var phase: String = "anticipation"
var phase_timer: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	kive.q_context = kive.get_q_context_from_chain()
	kive.current_attack_type = "kick"
	kive.current_hit_type = "frontal"
	kive.velocity.x = 0

	if DebugOverlay.show_debug_text:
		print("[%s] enter | w_step=%d | q_context=%s | last_w=%s | chain_active=%s" % [
			name, kive.w_chain_step, kive.q_context, kive.last_w_executed, kive.is_chain_active()
		])

	phase = "anticipation"
	phase_timer = 0.0
	kive.sprite.play("idle")


func exit() -> void:
	kive.is_finisher = false
	kive.current_attack_type = "none"
	kive.q_context = ""


func physics_update(delta: float) -> StringName:
	phase_timer += delta

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	match phase:
		"anticipation":
			if phase_timer >= stats.kick_anticipation:
				phase = "release"
				phase_timer = 0.0
				kive.sprite.play("kick_contact")
				kive.activate_hitbox()
		"release":
			if phase_timer >= stats.kick_release:
				phase = "recovery"
				phase_timer = 0.0
				kive.sprite.play("idle")
		"recovery":
			if phase_timer >= stats.kick_recovery:
				return _decide_next_state()

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""


func _decide_next_state() -> StringName:
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	return &"Idle"
