extends Node

## FlaiAlarm — alarm subsystem of Flai (the train's AI).
## Tracks kill/ko counts and current alarm level.
## Part of the scripts/flai/ namespace. Full Flai system lives alongside.

var kill_count: int = 0
var ko_count: int = 0

# Alarm level del vagón actual.
# 0 = patrol, 1 = suspicious, 2 = alert, 3 = combat, 4 = lockdown.
var current_alarm_level: int = 0


func register_kill() -> void:
	var old_alarm: int = current_alarm_level
	kill_count += 1
	current_alarm_level += 2  # TUNABLE: alarm increment per kill
	if DebugOverlay.show_debug_text:
		print("[FlaiAlarm] kill registered | alarm: %d → %d" % [old_alarm, current_alarm_level])


func register_ko() -> void:
	var old_alarm: int = current_alarm_level
	ko_count += 1
	current_alarm_level += 1  # TUNABLE: alarm increment per ko
	if DebugOverlay.show_debug_text:
		print("[FlaiAlarm] ko registered | alarm: %d → %d" % [old_alarm, current_alarm_level])


func reset_alarm() -> void:
	current_alarm_level = 0


func reset_run() -> void:
	kill_count = 0
	ko_count = 0
	reset_alarm()
