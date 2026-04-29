## FlaiKilima — default state. Flai operating as Kilima's universal assistant.
## The humanity-as-protocol (lore §5.1). Reads alarm data and computes status.
class_name FlaiKilima extends FlaiState

const DANGEROUS_KILL_THRESHOLD: int = 3


func update(_delta: float) -> void:
	len_flai.current_alarm_level = FlaiAlarm.current_alarm_level
	len_flai.agents_down = FlaiAlarm.kill_count

	var new_status: String = "TRACKED"
	if FlaiAlarm.kill_count >= DANGEROUS_KILL_THRESHOLD:
		new_status = "ARMED \u00b7 DANGEROUS"

	if new_status != len_flai.current_status:
		if DebugOverlay.show_debug_text:
			print("[LenFlai] status: %s \u2192 %s" % [len_flai.current_status, new_status])
		len_flai.current_status = new_status
