## Ventana de "mantener W" para decidir si es punch normal o cargado.
## Abre la ventana de parry al entrar.
class_name PunchCharging extends State

var kive: Kive
var stats: KiveStats
var charge_timer: float = 0.0


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	charge_timer = 0.0

	# Sincronizar flags legacy
	kive.current_attack_type = "punch"
	kive.punch_charge_timer = 0.0
	kive._parry_window_timer = 0.0  # abre ventana de parry

	kive.velocity.x = 0


func exit() -> void:
	pass


func physics_update(delta: float) -> StringName:
	charge_timer += delta
	kive.punch_charge_timer = charge_timer

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta
	kive.velocity.x = 0

	kive.sprite.play("attack_charged_casting")

	# Auto-release al maximo
	if charge_timer >= stats.attack_charge_time_max:
		kive.is_punch_charged = true
		return &"PunchCharged"

	# Soltar W
	if not Input.is_action_pressed("attack_punch"):
		var charged: bool = charge_timer >= stats.attack_charge_time
		kive.is_punch_charged = charged
		if charged:
			return &"PunchCharged"
		else:
			return &"Jab"

	kive.move_and_slide()
	return &""
