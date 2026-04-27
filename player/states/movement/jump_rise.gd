class_name JumpRise extends State

var kive: Kive
var stats: KiveStats


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	kive.sprite.play("jump_air")

	# Resetear air jumps si venimos de un salto nuevo (no desde AirJump)
	if _prev != &"AirJump":
		kive._air_jumps_left = stats.max_air_jumps


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
	if kive.velocity.y > 0:
		return &"JumpFall"

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""
