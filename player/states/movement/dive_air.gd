class_name DiveAir extends State

var kive: Kive
var stats: KiveStats
var dive_direction: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats

	dive_direction = -1.0 if kive.sprite.flip_h else 1.0
	if abs(kive.velocity.x) > 10:
		dive_direction = sign(kive.velocity.x)

	kive.velocity.x = stats.dive_speed * dive_direction * 0.8
	kive.velocity.y = minf(kive.velocity.y, -400.0)
	kive._update_collision_shape()
	kive.activate_dive_hitbox()
	kive.sprite.play("dive_slide")


func exit() -> void:
	kive.deactivate_dive_hitbox()
	kive._update_collision_shape()


func physics_update(delta: float) -> StringName:
	# Air jump cancel
	if Input.is_action_just_pressed("jump") and kive._air_jumps_left > 0:
		return &"AirJump"

	kive.velocity.y += stats.gravity * delta

	# Aterrizaje
	if kive.is_on_floor() and kive.velocity.y >= 0:
		if Input.is_action_pressed("dive"):
			# Mantener dive → transicionar a DiveGround (sigue deslizando)
			sm.transition_to(&"DiveGround", {})
			return &""
		else:
			return &"DiveLanding"

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""
