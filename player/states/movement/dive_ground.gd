class_name DiveGround extends State

var kive: Kive
var stats: KiveStats
var dive_timer: float = 0.0
var dive_direction: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	dive_timer = 0.0

	kive.is_diving = true
	kive.jump_state = "none"

	dive_direction = sign(kive.velocity.x) if kive.velocity.x != 0 else (-1.0 if kive.sprite.flip_h else 1.0)

	# Si venimos de DiveAir aterrizando, mantener slide sin resetear velocity
	if _prev == &"DiveAir":
		kive.velocity.x = stats.dive_speed * dive_direction
		kive.sprite.play("dive_slide")
	else:
		kive.velocity.x = stats.dive_speed * dive_direction
		kive._update_collision_shape()
		kive.sprite.play("dive_start")


func exit() -> void:
	pass


func physics_update(delta: float) -> StringName:
	# Jump cancel
	if Input.is_action_just_pressed("jump") and kive.is_on_floor():
		kive.is_diving = false
		kive._update_collision_shape()
		kive._air_jumps_left = stats.max_air_jumps
		kive.velocity.y = stats.jump_velocity_min
		return &"JumpRise"

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta
	else:
		kive.velocity.y = 0

	dive_timer += delta

	# Friction solo durante slide en suelo
	if kive.sprite.animation == "dive_slide" and kive.is_on_floor():
		kive.velocity.x = move_toward(kive.velocity.x, 0, stats.dive_friction * delta)
		if not Input.is_action_pressed("dive") or dive_timer >= stats.dive_max_duration or abs(kive.velocity.x) < 10:
			return &"DiveLanding"

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""


func on_animation_finished(anim_name: String) -> void:
	if anim_name == "dive_start":
		kive.sprite.play("dive_slide")
