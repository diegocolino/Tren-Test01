## Clase base para todos los estados de cualquier state machine del proyecto.
class_name State extends Node

# Inyectado por StateMachine al _ready
var owner_node: Node
var sm: StateMachine


## Llamado al entrar al estado. msg permite pasar datos del estado anterior.
func enter(_prev_state: StringName, _msg: Dictionary = {}) -> void:
	pass


## Llamado al salir del estado.
func exit() -> void:
	pass


## Cada physics frame. Devuelve StringName del siguiente estado, o &"" para quedarse.
func physics_update(_delta: float) -> StringName:
	return &""


## Llamado por el animator cuando termina una animacion.
func on_animation_finished(_anim_name: String) -> void:
	pass
