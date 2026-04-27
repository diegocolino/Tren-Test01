extends Node

## Flai — the train's AI. Awareness system data slots.
## No game logic in V1.1. Connections come in V1.5 (alarm system A)
## and V2 (system B persistent + narrative reactions).

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
