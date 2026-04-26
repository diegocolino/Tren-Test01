class_name JumpLanding extends State

var kive: Kive
var stats: KiveStats
var phase: String = "contact"
var timer: float = 0.0

# Timeouts de seguridad — si la animacion no termina, forzamos transicion
const CONTACT_TIMEOUT: float = 0.3
const RECOVERY_TIMEOUT: float = 0.4


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	timer = 0.0

	var start_phase: String = _msg.get("phase", "contact")
	if start_phase == "recovery":
		phase = "recovery"
		kive.sprite.play("jump_recovery")
	else:
		phase = "contact"
		kive.sprite.play("jump_contact")


func physics_update(delta: float) -> StringName:
	timer += delta

	kive.apply_horizontal_input(false)
	kive.velocity.y += stats.gravity * delta
	kive.move_and_slide()
	kive.update_sprite_direction()

	# Fallback de seguridad: si la animacion no termina, forzar transicion
	if phase == "contact" and timer >= CONTACT_TIMEOUT:
		phase = "recovery"
		timer = 0.0
		kive.sprite.play("jump_recovery")
	elif phase == "recovery" and timer >= RECOVERY_TIMEOUT:
		return _decide_next_state()

	return &""


func on_animation_finished(anim_name: String) -> void:
	if anim_name == "jump_contact":
		phase = "recovery"
		timer = 0.0
		kive.sprite.play("jump_recovery")
	elif anim_name == "jump_recovery":
		sm.transition_to(_decide_next_state())


func _decide_next_state() -> StringName:
	kive._air_jumps_left = 0
	var dir_input: float = Input.get_axis("move_left", "move_right")
	if dir_input != 0:
		return &"Walk" if Input.is_action_pressed("run") else &"Run"
	else:
		return &"Idle"
