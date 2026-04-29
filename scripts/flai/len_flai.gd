extends Node

# NOTA: enum simple en V0.1. Refactor a state machine en V0.2 cuando
# aparezca la primera transición real (Flai↔Len-flai).
enum Mode { FLAI, LEN_FLAI, LEN_SOUL, LEN_ETHER }
var current_mode: Mode = Mode.FLAI


func set_mode(mode: Mode) -> void:
	current_mode = mode


func is_flai_pure() -> bool:
	return current_mode == Mode.FLAI
