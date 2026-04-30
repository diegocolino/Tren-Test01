## LenSoulPassive — Kive frozen during Len-soul mode.
## Player inputs ignored. Gravity preserved. Idle animation.
## Reinforces philosophy: Kive does not participate in Len-soul.
class_name LenSoulPassive extends State

var kive: Kive
var stats: KiveStats
var _state_to_restore: StringName = &"Idle"
var _exiting_normally: bool = false


func enter(prev_state: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	_state_to_restore = prev_state if prev_state != &"" else &"Idle"
	kive.sprite.play("idle")
	if DebugOverlay.show_debug_text:
		print("[LenSoulPassive] enter | from=%s" % prev_state)


func exit() -> void:
	if not _exiting_normally:
		# Forced exit (damage/respawn) — LenFlai didn't initiate the exit.
		# Clean up world state directly. Do NOT emit trigger_exit_len_soul
		# to avoid infinite recursion with _on_len_soul_exit.
		if DebugOverlay.show_debug_text:
			print("[LenFlai] edge case: Kive died during LenSoul — forcing visual exit")
		LenFlai._len_soul_timer = -1.0
		LenFlai.world_overlay_fade_out()
		LenFlai.set_len_movables_highlight(false)
		LenFlai.set_mode(LenFlai.Mode.FLAI)
		LenFlai.force_exit_len_soul_visual.emit()
	_exiting_normally = false
	if DebugOverlay.show_debug_text:
		print("[LenSoulPassive] exit | returning to=%s" % _state_to_restore)


func physics_update(delta: float) -> StringName:
	# Gravity
	kive.velocity.y += stats.gravity * delta

	# Decelerate horizontal velocity smoothly
	kive.velocity.x = move_toward(kive.velocity.x, 0.0, stats.run_speed * 0.15)

	kive.move_and_slide()

	# TODO: autopilot contextual basado en FlaiAlarm.kill_count / current_alarm_level
	# Mismo patron que la IA de Yeri cuando se disene.
	# Por ahora: solo gravedad + idle animation. Sin inputs del jugador.

	return &""


func get_restore_state() -> StringName:
	var valid_states: Array[StringName] = [
		&"Idle", &"Walk", &"Run", &"CrouchIdle", &"CrouchWalk",
	]
	if _state_to_restore in valid_states:
		return _state_to_restore
	return &"Idle"
