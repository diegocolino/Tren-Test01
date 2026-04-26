class_name Hidden extends State

var kive: Kive
var stats: KiveStats


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	kive.is_crouched = true
	kive.is_hidden = true
	kive.sprite.modulate.a = 0.35
	kive.sprite.play("crouch_idle")


func exit() -> void:
	kive.is_hidden = false
	kive.sprite.modulate.a = 1.0
	# Resetear crouch siempre; CrouchIdle/CrouchWalk lo re-setean en su enter
	kive.is_crouched = false
	kive._update_collision_shape()


func physics_update(delta: float) -> StringName:
	if not kive.control_enabled:
		return &""

	# Salir de hidden si sale de hide_zone o ya no es safe
	if kive._nearby_hide_zones <= 0 or not kive.can_hide():
		return &"CrouchIdle"

	# Salir de crouch (toggle o hold release)
	if PauseMenu.hold_to_crouch:
		if not Input.is_action_pressed("crouch"):
			return _decide_uncrouched_state()
	else:
		if Input.is_action_just_pressed("crouch"):
			return _decide_uncrouched_state()

	# Q desde Hidden → Execution
	if Input.is_action_just_pressed("attack_kick"):
		return &"Execution"

	# W desde Hidden → unhide + PunchCharging
	if Input.is_action_just_pressed("attack_punch"):
		return &"PunchCharging"

	# Salto sale del crouch
	if Input.is_action_just_pressed("jump") and kive.is_on_floor():
		return &"JumpAnticipation"

	# Movimiento horizontal: permitir y actualizar sprite, mantener Hidden
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		kive.velocity.x = dir_input * stats.crouch_walk_speed
		kive.sprite.play("crouch_walk")
	else:
		kive.velocity.x = 0
		kive.sprite.play("crouch_idle")

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""


func _decide_uncrouched_state() -> StringName:
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	return &"Idle"
