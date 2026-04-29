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
	kive._w_chain_timer = 0.0  # always preserve chain during FrontalKick
	kive.current_attack_type = "kick"
	if not kive.is_in_air:
		kive.velocity.x = 0

	# Map q_context → current_hit_type for agent dispatch
	match kive.q_context:
		"after_jab":
			kive.current_hit_type = "stunt_pie"
		"after_cross":
			kive.current_hit_type = "ko_suelo"
		"after_hook":
			kive.current_hit_type = "air_launch"
		"standalone":
			kive.current_hit_type = "frontal"
		_:
			kive.current_hit_type = "frontal"
			push_warning("Unexpected q_context: %s" % kive.q_context)

	if DebugOverlay.show_debug_text:
		print("[%s] enter | w_step=%d | q_context=%s | last_w=%s | hit_type=%s | chain_active=%s | in_air=%s" % [
			name, kive.w_chain_step, kive.q_context, kive.last_w_executed,
			kive.current_hit_type, kive.is_chain_active(), kive.is_in_air
		])

	phase = "anticipation"
	phase_timer = 0.0
	kive.sprite.play("idle")


func exit() -> void:
	kive.is_takedown = false
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
			var in_cancel_window: bool = phase_timer >= stats.kick_recovery - stats.q_cancel_window
			if in_cancel_window and Input.is_action_just_pressed("attack_punch"):
				if DebugOverlay.show_debug_text:
					print("[FrontalKick] CANCEL TIGHT → W at recovery_t=%.3f" % phase_timer)
				if kive.is_chain_active():
					return kive.get_w_chain_next()
				else:
					return &"Jab"
			if in_cancel_window and Input.is_action_just_pressed("attack_kick"):
				if DebugOverlay.show_debug_text:
					print("[FrontalKick] CANCEL TIGHT → FrontalKick (spam) at recovery_t=%.3f" % phase_timer)
				return &"FrontalKick"
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
