## Punch cargado con lunge aereo. Fases internas: anticipation → release → recovery.
class_name PunchCharged extends State

var kive: Kive
var stats: KiveStats
var phase: String = "anticipation"
var phase_timer: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	phase = "anticipation"
	phase_timer = 0.0

	# Impulso interpolado (40%-100% segun charge_ratio)
	var charge_ratio: float = clampf(
		(kive.punch_charge_timer - stats.attack_charge_time) / (stats.attack_charge_time_max - stats.attack_charge_time),
		0.0, 1.0
	)
	var impulse_factor: float = lerpf(0.4, 1.0, charge_ratio)
	var facing: float = -1.0 if kive.sprite.flip_h else 1.0
	kive.velocity.x = facing * stats.charged_lunge_speed_x * impulse_factor
	kive.velocity.y = stats.charged_lunge_speed_y * impulse_factor

	kive.sprite.play("attack_charged_airtime")


func exit() -> void:
	kive.is_punch_charged = false
	kive.current_attack_type = "none"


func physics_update(delta: float) -> StringName:
	phase_timer += delta
	kive.velocity.y += stats.gravity * delta

	# Cayendo rapido sin aterrizar → cancelar ataque, caer normal
	if not kive.is_on_floor() and kive.velocity.y > 200 and phase == "recovery":
		return &"JumpFall"

	match phase:
		"anticipation":
			if phase_timer >= stats.punch_anticipation:
				phase = "release"
				phase_timer = 0.0
				kive.sprite.play("attack_charged_contact")
				kive.activate_hitbox()
		"release":
			if phase_timer >= stats.punch_release:
				phase = "recovery"
				phase_timer = 0.0
				# Mantener sprite attack_charged_contact durante recovery aereo
		"recovery":
			if kive.is_on_floor() and kive.velocity.y >= 0:
				return &"JumpLanding"

	kive.move_and_slide()
	kive.update_sprite_direction()
	return &""
