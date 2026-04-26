class_name DiveLanding extends State

var kive: Kive
var stats: KiveStats
var timer: float = 0.0

const LANDING_TIMEOUT: float = 0.4


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	timer = 0.0

	kive._update_collision_shape()
	kive.sprite.play("dive_end")


func physics_update(delta: float) -> StringName:
	timer += delta

	kive.velocity.y += stats.gravity * delta
	kive.apply_horizontal_input(false)
	kive.move_and_slide()
	kive.update_sprite_direction()

	# Fallback de seguridad
	if timer >= LANDING_TIMEOUT:
		return _decide_next_state()

	return &""


func on_animation_finished(anim_name: String) -> void:
	if anim_name == "dive_end":
		sm.transition_to(_decide_next_state())


func _decide_next_state() -> StringName:
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	else:
		return &"Idle"
