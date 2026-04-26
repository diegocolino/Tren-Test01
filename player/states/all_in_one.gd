## Estado temporal que contiene toda la logica de _physics_process.
## Se ira vaciando conforme extraemos estados reales.
class_name AllInOne extends State

var kive: Kive


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive


func physics_update(delta: float) -> StringName:
	if not kive.control_enabled:
		return &""
	kive.run_legacy_physics(delta)
	return &""
