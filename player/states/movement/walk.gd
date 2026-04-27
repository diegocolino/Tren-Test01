class_name Walk extends State

var kive: Kive
var stats: KiveStats


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats


func physics_update(delta: float) -> StringName:
	if not kive.control_enabled:
		return &""

	if Input.is_action_just_pressed("jump") and kive.is_on_floor():
		if abs(kive.velocity.x) > 10:
			kive._air_jumps_left = stats.max_air_jumps
			kive.velocity.y = stats.jump_velocity_min
			return &"JumpRise"
		else:
			return &"JumpAnticipation"
	if Input.is_action_just_pressed("attack_punch"):
		var chain_next: StringName = kive.get_w_chain_next()
		return chain_next if chain_next != &"" else &"Jab"
	if Input.is_action_just_pressed("attack_kick"):
		return &"FrontalKick"
	if Input.is_action_just_pressed("dash"):
		return &"Dash"
	if PauseMenu.hold_to_crouch:
		if Input.is_action_pressed("crouch"):
			return &"CrouchWalk"
	else:
		if Input.is_action_just_pressed("crouch"):
			return &"CrouchWalk"
	if not kive.is_on_floor() and kive.velocity.y > 50:
		return &"JumpFall"

	if not Input.is_action_pressed("run"):
		return &"Run"

	kive.velocity.y += stats.gravity * delta
	kive.apply_horizontal_input(false)

	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input == 0:
		return &"Idle"

	kive.sprite.play("walk")
	kive.move_and_slide()
	kive.try_step_up()
	kive.update_sprite_direction()
	return &""
