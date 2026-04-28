## Dash (E). Fases: active → recovery.
## Neutral: E alone or E+A/D without target in range.
## Directed: E+A/D with valid target in direction → dash to target.
class_name Dash extends State

var kive: Kive
var stats: KiveStats
var phase: String = "active"
var phase_timer: float = 0.0
var _dash_direction: float = 0.0
var _dash_active_duration: float = 0.0
var _target_mode: bool = false


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	# Direction: A/D pressed → that direction, else facing
	var input_dir: float = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		_dash_direction = sign(input_dir)
	else:
		_dash_direction = -1.0 if kive.sprite.flip_h else 1.0

	# Target detection
	var neutral_speed: float = stats.dash_distance_neutral / stats.dash_duration
	var target: Node2D = kive.find_closest_agent_in_direction(_dash_direction)
	if target and kive.global_position.distance_to(target.global_position) <= stats.dash_target_range:
		var dx: float = target.global_position.x - kive.global_position.x
		var target_x: float = target.global_position.x - sign(dx) * stats.dash_target_offset
		var distance: float = abs(target_x - kive.global_position.x)
		_dash_active_duration = distance / neutral_speed
		_dash_direction = sign(dx)
		_target_mode = true
		# Facing: turn toward target (exception to "nunca mira atrás")
		kive.sprite.flip_h = dx < 0
	else:
		_dash_active_duration = stats.dash_duration
		_target_mode = false

	phase = "active"
	phase_timer = 0.0
	kive.velocity.x = _dash_direction * neutral_speed
	kive.sprite.play("run")

	if DebugOverlay.show_debug_text:
		if _target_mode:
			print("[Dash] enter | TARGET MODE | direction=%.0f | duration=%.3f | in_air=%s" % [
				_dash_direction, _dash_active_duration, kive.is_in_air])
		else:
			print("[Dash] enter | NEUTRAL | direction=%.0f | in_air=%s | vx=%.1f" % [
				_dash_direction, kive.is_in_air, kive.velocity.x])


func physics_update(delta: float) -> StringName:
	phase_timer += delta

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	match phase:
		"active":
			kive.velocity.x = _dash_direction * (stats.dash_distance_neutral / stats.dash_duration)
			if phase_timer >= _dash_active_duration:
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
