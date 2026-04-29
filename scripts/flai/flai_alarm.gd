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
	kill_count += 1


func register_ko() -> void:
	ko_count += 1


func reset_alarm() -> void:
	current_alarm_level = 0


func reset_run() -> void:
	kill_count = 0
	ko_count = 0
	reset_alarm()
