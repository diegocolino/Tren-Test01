## Estado temporal que gestiona dive, combat, crouch, hide.
## Se ira vaciando conforme extraemos mas estados.
class_name AllInOne extends State

var kive: Kive


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive


func physics_update(delta: float) -> StringName:
	if not kive.control_enabled:
		return &""

	# Si estamos en suelo, sin nada activo, sin crouch ni hide → delegar a movimiento
	# (NO comprobamos jump_state porque es legacy y puede quedarse atascado.
	# Los nuevos estados de jump gestionan jump_state ellos mismos.)
	if kive.is_on_floor() and not kive.is_attacking and not kive.is_punch_charging \
		and not kive.is_diving and not kive.is_crouched and not kive.is_hidden:
		var dir_input: float = Input.get_axis("move_left", "move_right")
		if dir_input == 0:
			return &"Idle"
		elif Input.is_action_pressed("run"):
			return &"Walk"
		else:
			return &"Run"

	kive.run_legacy_physics(delta)
	return &""
