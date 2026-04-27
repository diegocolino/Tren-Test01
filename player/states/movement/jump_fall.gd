class_name JumpFall extends State

var kive: Kive
var stats: KiveStats
var is_short_jump: bool = false


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	is_short_jump = _msg.get("is_short_jump", false)

	# Saltos cortos: jump_precontact ya viene puesto desde JumpAnticipation
	# Saltos normales: asegurar jump_air (excepto si JumpAnticipation ya lo puso)
	if not is_short_jump and _prev != &"JumpAnticipation":
		kive.sprite.play("jump_air")


func physics_update(delta: float) -> StringName:
	kive.velocity.y += stats.gravity * delta
	kive.apply_horizontal_input(true)

	if Input.is_action_just_pressed("attack_punch"):
		var chain_next: StringName = kive.get_w_chain_next()
		return chain_next if chain_next != &"" else &"Jab"
	if Input.is_action_just_pressed("attack_kick"):
		return &"FrontalKick"
	if Input.is_action_just_pressed("dash"):
		return &"Dash"
	if Input.is_action_just_pressed("jump") and kive._air_jumps_left > 0:
		return &"AirJump"
	if Input.is_action_just_pressed("dive"):
		return &"DiveAir"

	if kive.is_on_floor() and kive.velocity.y >= 0:
		return &"JumpLanding"

	# Sprite segun tipo de salto y velocidad
	if is_short_jump:
		if kive.sprite.animation != "jump_precontact":
			kive.sprite.play("jump_precontact")
	else:
		if kive.velocity.y > 200:
			if kive.sprite.animation != "jump_precontact":
				kive.sprite.play("jump_precontact")
		else:
			if kive.sprite.animation != "jump_air":
				kive.sprite.play("jump_air")

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""
