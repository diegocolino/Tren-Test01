## Base class for all Flai HUD states. Same contract as player State:
## enter(), exit(), update(delta). Lighter — no physics_update or
## on_animation_finished (those come if needed in V0.3+).
class_name FlaiState extends Node

var len_flai: Node


func enter(_prev_state: StringName, _msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass
