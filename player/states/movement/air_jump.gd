class_name AirJump extends State

var kive: Kive
var stats: KiveStats


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	if kive.is_diving:
		kive.is_diving = false
		kive._update_collision_shape()

	kive._air_jumps_left -= 1
	kive.velocity.y = stats.air_jump_velocity
	kive.jump_state = "air_jump_rise"
	kive.sprite.play("air_jump_rise")


func physics_update(delta: float) -> StringName:
	kive.velocity.y += stats.gravity * delta
	kive.apply_horizontal_input(true)

	if Input.is_action_just_pressed("dive"):
		return &"AllInOne"

	if kive.is_on_floor() and kive.velocity.y >= 0:
		return &"JumpLanding"

	# Actualizar sprite segun velocidad
	if kive.velocity.y < -50:
		kive.jump_state = "air_jump_rise"
		kive.sprite.play("air_jump_rise")
	elif kive.velocity.y > 200:
		return &"JumpFall"
	elif kive.velocity.y > 50:
		kive.jump_state = "air_jump_fall"
		kive.sprite.play("air_jump_fall")

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""
