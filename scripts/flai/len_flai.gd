extends Node

# NOTA: enum simple en V0.1. Refactor a state machine en V0.2 cuando
# aparezca la primera transición real (Flai↔Len-flai).
enum Mode { FLAI, LEN_FLAI, LEN_SOUL, LEN_ETHER }
var current_mode: Mode = Mode.FLAI

const DANGEROUS_KILL_THRESHOLD: int = 3

var current_alarm_level: int = 0
var current_status: String = "TRACKED"
var agents_down: int = 0

var _prev_status: String = ""


func _process(_delta: float) -> void:
	current_alarm_level = FlaiAlarm.current_alarm_level
	agents_down = FlaiAlarm.kill_count

	if FlaiAlarm.kill_count >= DANGEROUS_KILL_THRESHOLD:
		current_status = "ARMED \u00b7 DANGEROUS"
	else:
		current_status = "TRACKED"

	if current_status != _prev_status:
		if DebugOverlay.show_debug_text:
			print("[LenFlai] status changed: %s → %s" % [_prev_status, current_status])
		_prev_status = current_status


func set_mode(mode: Mode) -> void:
	current_mode = mode


func is_flai_pure() -> bool:
	return current_mode == Mode.FLAI
