## Dash neutral (E). Fases: active → recovery.
## Straight-line dash in input direction or facing direction. No targeting.
class_name Dash extends State

var kive: Kive
var stats: KiveStats
var phase: String = "active"
var phase_timer: float = 0.0
var _dash_direction: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	# Direction: A/D pressed → that direction, else facing
	var input_dir: float = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		_dash_direction = sign(input_dir)
	else:
		_dash_direction = -1.0 if kive.sprite.flip_h else 1.0

	phase = "active"
	phase_timer = 0.0
	kive.velocity.x = _dash_direction * (stats.dash_distance_neutral / stats.dash_duration)
	kive.sprite.play("run")

	if DebugOverlay.show_debug_text:
		print("[Dash] enter | NEUTRAL | direction=%.0f | in_air=%s | vx=%.1f" % [
			_dash_direction, kive.is_in_air, kive.velocity.x])


func physics_update(delta: float) -> StringName:
	phase_timer += delta

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	match phase:
		"active":
			kive.velocity.x = _dash_direction * (stats.dash_distance_neutral / stats.dash_duration)
			if phase_timer >= stats.dash_duration:
				if kive._pending_finisher == "w":
					var next_state: StringName = kive.get_w_chain_next()
					if next_state == &"":
						next_state = &"Jab"
					if DebugOverlay.show_debug_text:
						print("[Dash] FINISHER W → %s" % next_state)
					kive._pending_finisher = ""
					kive.velocity.x = 0.0
					return next_state
				elif kive._pending_finisher == "q":
					if DebugOverlay.show_debug_text:
						print("[Dash] FINISHER Q → FrontalKick")
					kive._pending_finisher = ""
					kive.velocity.x = 0.0
					return &"FrontalKick"
				phase = "recovery"
				phase_timer = 0.0
		"recovery":
			kive.velocity.x = move_toward(kive.velocity.x, 0, abs(kive.velocity.x) / stats.dash_recovery * delta)
			# Cancels during recovery
			if Input.is_action_just_pressed("jump"):
				if kive.is_on_floor():
					kive._air_jumps_left = stats.max_air_jumps
					kive.velocity.y = stats.jump_velocity_min
					return &"JumpRise"
				elif kive._air_jumps_left > 0:
					return &"AirJump"
			if Input.is_action_just_pressed("attack_punch"):
				var chain_next: StringName = kive.get_w_chain_next()
				return chain_next if chain_next != &"" else &"Jab"
			if Input.is_action_just_pressed("attack_kick"):
				return &"FrontalKick"
			if Input.is_action_just_pressed("crouch") and kive.is_on_floor():
				return &"CrouchIdle"
			if phase_timer >= stats.dash_recovery:
				return _decide_next_state()

	kive.move_and_slide()
	return &""


func _decide_next_state() -> StringName:
	if not kive.is_on_floor():
		return &"JumpFall"
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	return &"Idle"
