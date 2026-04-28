class_name CrouchWalk extends State

var kive: Kive
var stats: KiveStats


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	kive.is_crouched = true
	kive._update_collision_shape()
	kive.sprite.play("crouch_walk")


func exit() -> void:
	kive.is_crouched = false
	kive._update_collision_shape()


func physics_update(delta: float) -> StringName:
	if not kive.control_enabled:
		return &""

	# Auto-hide: igual que CrouchIdle
	if kive._nearby_hide_zones > 0 and kive.can_hide() and kive.is_on_floor():
		return &"Hidden"

	# Salir de crouch
	if PauseMenu.hold_to_crouch:
		if not Input.is_action_pressed("crouch"):
			return _decide_uncrouched_state()
	else:
		if Input.is_action_just_pressed("crouch"):
			return _decide_uncrouched_state()

	# Sin movimiento → CrouchIdle
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input == 0:
		return &"CrouchIdle"

	# W sale del crouch → Jab (o siguiente del chain)
	if Input.is_action_just_pressed("attack_punch"):
		var chain_next: StringName = kive.get_w_chain_next()
		return chain_next if chain_next != &"" else &"Jab"

	if Input.is_action_just_pressed("dash"):
		return kive.decide_dash_state()

	# Salto sale del crouch
	if Input.is_action_just_pressed("jump") and kive.is_on_floor():
		return &"JumpAnticipation"

	# Movimiento crouched
	kive.velocity.x = dir_input * stats.crouch_walk_speed
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
