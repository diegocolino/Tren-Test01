class_name JumpAnticipation extends State

var kive: Kive
var stats: KiveStats
var timer: float = 0.0
var charge_timer: float = 0.0
var is_charging: bool = false
var was_moving: bool = false


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	timer = 0.0
	charge_timer = 0.0
	is_charging = false
	was_moving = abs(kive.velocity.x) > 10

	if kive.is_crouched:
		kive.is_crouched = false
		kive._update_collision_shape()

	kive._air_jumps_left = stats.max_air_jumps
	kive.velocity.x = 0
	kive.velocity.y = 0
	kive.sprite.play("jump_anticipation")


func physics_update(delta: float) -> StringName:
	timer += delta

	if timer < stats.anticipation_duration:
		# Tap rapido + parado: salto estatico sin carga, ejecutar inmediatamente
		if not Input.is_action_pressed("jump") and not was_moving:
			_release_jump()
			sm.transition_to(&"JumpFall", {"is_short_jump": true})
			return &""
		return &""

	if Input.is_action_pressed("jump"):
		charge_timer += delta
		if charge_timer >= stats.charge_cancel_time:
			kive.sprite.play("jump_recovery")
			kive.jump_state = "landing_recovery"
			return &"JumpLanding"
		elif charge_timer >= stats.charge_threshold:
			is_charging = true
			kive.sprite.frame = 1
			kive.sprite.pause()
	else:
		_release_jump()
		if was_moving and not is_charging:
			return &"JumpRise"
		elif is_charging or not was_moving:
			var is_short: bool = not was_moving and not is_charging
			sm.transition_to(&"JumpFall", {"is_short_jump": is_short})
			return &""

	return &""


func _release_jump() -> void:
	kive.sprite.play()

	var charge_ratio: float = 0.0
	if is_charging:
		charge_ratio = clampf(charge_timer / stats.jump_charge_time, 0.0, 1.0)

	var jump_vel: float
	if is_charging:
		jump_vel = lerpf(stats.jump_velocity_min, stats.jump_velocity_max, charge_ratio)
	else:
		jump_vel = stats.jump_velocity_min

	kive.velocity.y = jump_vel

	if not was_moving and not is_charging:
		kive.sprite.play("jump_precontact")
	else:
		kive.sprite.play("jump_air")
