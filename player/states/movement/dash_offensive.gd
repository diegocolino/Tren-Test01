## DashOffensive (E con target). Modos: magnetic (sensible_target) > target (W-marked agent).
## Fases: active → recovery.
class_name DashOffensive extends State

var kive: Kive
var stats: KiveStats
var phase: String = "active"
var phase_timer: float = 0.0
var _dash_direction: float = 0.0
var _dash_active_duration: float = 0.0
var _dash_speed: float = 0.0
var _dash_target: Node2D = null
var _mode: String = ""  # "magnetic" | "target"
var _target_position: Vector2 = Vector2.ZERO


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	kive._w_chain_timer = 0.0
	if DebugOverlay.show_debug_text:
		print("[DashOffensive] chain timer reset on enter (step=%d)" % kive.w_chain_step)

	var neutral_speed: float = stats.dash_distance_neutral / stats.dash_duration

	# Priority: magnetic > target
	if kive._sensible_target != null and is_instance_valid(kive._sensible_target):
		_dash_target = kive._sensible_target
		kive._sensible_target = null  # consume
		_mode = "magnetic"
	else:
		var dir: float = Input.get_axis("move_left", "move_right")
		if dir == 0:
			dir = -1.0 if kive.sprite.flip_h else 1.0
		_dash_target = kive.find_chained_agent_in_direction(dir)

	# Guard: null target fallback to neutral behavior
	if _dash_target == null or not is_instance_valid(_dash_target):
		push_warning("[DashOffensive] no valid target in enter(), fallback to neutral")
		_mode = ""
		_dash_speed = neutral_speed
		_dash_active_duration = stats.dash_duration
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0:
			_dash_direction = sign(input_dir)
		else:
			_dash_direction = -1.0 if kive.sprite.flip_h else 1.0
		phase = "active"
		phase_timer = 0.0
		kive.velocity.x = _dash_direction * _dash_speed
		kive.sprite.play("run")
		if DebugOverlay.show_debug_text:
			print("[DashOffensive] enter | FALLBACK NEUTRAL | direction=%.0f" % _dash_direction)
		return

	# Assign mode for target path (magnetic was already assigned above)
	if _mode != "magnetic":
		_mode = "target"

	# Calculate velocity toward target
	var dx: float = _dash_target.global_position.x - kive.global_position.x
	var target_x: float = _dash_target.global_position.x - sign(dx) * stats.dash_target_offset
	var distance: float = abs(target_x - kive.global_position.x)
	_dash_direction = sign(dx)

	if _mode == "magnetic":
		_dash_speed = neutral_speed * stats.magnetic_speed_multiplier
	else:
		_dash_speed = neutral_speed
	_dash_active_duration = distance / _dash_speed

	# Facing: turn toward target (exception to "nunca mira atrás")
	kive.sprite.flip_h = dx < 0
	_target_position = Vector2(target_x, _dash_target.global_position.y)

	# Vertical impulse fijo, solo en magnetic
	if _mode == "magnetic":
		var dy: float = _dash_target.global_position.y - kive.global_position.y
		if dy < -50.0:
			kive.velocity.y = -400.0 * stats.magnetic_speed_multiplier
		elif dy > 50.0:
			kive.velocity.y = 200.0 * stats.magnetic_speed_multiplier
		else:
			kive.velocity.y = 0.0

	phase = "active"
	phase_timer = 0.0
	kive.velocity.x = _dash_direction * _dash_speed
	kive.sprite.play("run")

	if DebugOverlay.show_debug_text:
		print("[DashOffensive] enter | %s | target=%s | direction=%.0f | duration=%.3f | in_air=%s" % [
			_mode.to_upper(), _dash_target.name, _dash_direction, _dash_active_duration, kive.is_in_air])


func exit() -> void:
	_dash_target = null


func physics_update(delta: float) -> StringName:
	phase_timer += delta

	match phase:
		"active":
			# Update target position if target still valid (tracking)
			if _dash_target != null and is_instance_valid(_dash_target):
				_target_position = Vector2(
					_dash_target.global_position.x - sign(_dash_direction) * stats.dash_target_offset,
					_dash_target.global_position.y
				)

			var progress: float = phase_timer / _dash_active_duration if _dash_active_duration > 0 else 1.0

			if progress < stats.dash_teleport_threshold:
				# Primera mitad: dash puro con gravedad + move_and_slide
				if not kive.is_on_floor():
					kive.velocity.y += stats.gravity * delta
				kive.velocity.x = _dash_direction * _dash_speed
				kive.move_and_slide()
			else:
				# Segunda mitad: teleport progresivo XY, sin gravedad, sin move_and_slide
				var teleport_progress: float = (progress - stats.dash_teleport_threshold) / (1.0 - stats.dash_teleport_threshold)
				var lerp_factor: float = pow(teleport_progress, stats.dash_teleport_curve) * 0.5
				kive.global_position.x = lerp(kive.global_position.x, _target_position.x, lerp_factor)
				kive.global_position.y = lerp(kive.global_position.y, _target_position.y, lerp_factor)
				kive.velocity.x = _dash_direction * _dash_speed * (1.0 - lerp_factor * 2.0)
				kive.velocity.y *= (1.0 - lerp_factor * 2.0)

			if phase_timer >= _dash_active_duration:
				# Snap final + zero velocity + recalc floor detection
				kive.global_position.x = _target_position.x
				kive.global_position.y = _target_position.y
				kive.velocity = Vector2.ZERO
				kive.move_and_slide()
				# Finisher
				if kive._pending_finisher == "w":
					kive._w_chain_timer = 0.0  # ensure chain alive at snap
					var next_state: StringName = kive.get_w_chain_next()
					if next_state == &"":
						next_state = &"Jab"
					if DebugOverlay.show_debug_text:
						print("[DashOffensive] FINISHER W → %s" % next_state)
					kive._pending_finisher = ""
					return next_state
				elif kive._pending_finisher == "q":
					if DebugOverlay.show_debug_text:
						print("[DashOffensive] FINISHER Q → FrontalKick")
					kive._pending_finisher = ""
					return &"FrontalKick"
				phase = "recovery"
				phase_timer = 0.0
		"recovery":
			if not kive.is_on_floor():
				kive.velocity.y += stats.gravity * delta
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
