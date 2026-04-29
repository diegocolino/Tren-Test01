extends Node

enum Mode { FLAI, LEN_FLAI, LEN_SOUL, LEN_ETHER }
var current_mode: Mode = Mode.FLAI

# Public data — updated every frame, read by the HUD. Universal across all modes.
var current_alarm_level: int = 0
var current_status: String = "TRACKED"
var agents_down: int = 0

const DANGEROUS_KILL_THRESHOLD: int = 3

# Alarm threshold triggers — TUNABLE
const ALARM_THRESHOLDS: Array[Dictionary] = [
	{"alarm": 3, "duration": 2.0},  # TUNABLE
	{"alarm": 6, "duration": 3.0},  # TUNABLE
	{"alarm": 9, "duration": 4.0},  # TUNABLE
]
var _thresholds_triggered: Array[bool] = [false, false, false]
var _prev_alarm: int = 0
var _auto_return_timer: float = -1.0

# Len-soul safety timer — TUNABLE
const LEN_SOUL_MAX_DURATION: float = 8.0  # TUNABLE
var _len_soul_timer: float = -1.0

# State machine internals.
var _current_state: FlaiState
var _states: Dictionary = {}  # StringName -> FlaiState

# Maps Mode enum to state node names.
const MODE_TO_STATE: Dictionary = {
	Mode.FLAI: &"FlaiKilima",
	Mode.LEN_FLAI: &"LenFlaiState",
	Mode.LEN_SOUL: &"LenSoulState",
	Mode.LEN_ETHER: &"LenEtherState",
}

# Signals for HUD (HUD drives visual transitions).
signal trigger_len_flai(duration: float, threshold_alarm: int)
signal trigger_return_flai()
signal trigger_len_soul()
signal trigger_exit_len_soul()

# World overlay reference — registered by WorldOverlay._ready().
var _world_overlay: Node = null


func _ready() -> void:
	var state_defs: Array[Dictionary] = [
		{"name": "FlaiKilima", "script": FlaiKilima},
		{"name": "LenFlaiState", "script": LenFlaiState},
		{"name": "LenSoulState", "script": LenSoulState},
		{"name": "LenEtherState", "script": LenEtherState},
	]
	for def: Dictionary in state_defs:
		var state: FlaiState = def["script"].new()
		state.name = def["name"]
		state.len_flai = self
		add_child(state)
		_states[StringName(def["name"])] = state

	_transition_to(&"FlaiKilima")


func _process(delta: float) -> void:
	_update_universal_data()
	_check_alarm_thresholds()
	_tick_auto_return(delta)
	_tick_len_soul_timer(delta)
	if _current_state:
		_current_state.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_L:
		_handle_len_soul_input()


func _handle_len_soul_input() -> void:
	if current_mode == Mode.LEN_SOUL:
		# Toggle off
		_len_soul_timer = -1.0
		if DebugOverlay.show_debug_text:
			print("[LenFlai] L pressed — exiting LenSoul")
		trigger_exit_len_soul.emit()
		return

	if current_mode in [Mode.FLAI, Mode.LEN_FLAI]:
		# Cancel any active Len-flai trigger
		cancel_auto_return()
		if DebugOverlay.show_debug_text:
			print("[LenFlai] L pressed — entering LenSoul (from=%s)" % Mode.keys()[current_mode])
		_len_soul_timer = LEN_SOUL_MAX_DURATION
		trigger_len_soul.emit()
		return


func _update_universal_data() -> void:
	current_alarm_level = FlaiAlarm.current_alarm_level
	agents_down = FlaiAlarm.kill_count

	var new_status: String = "TRACKED"
	if FlaiAlarm.kill_count >= DANGEROUS_KILL_THRESHOLD:
		new_status = "ARMED \u00b7 DANGEROUS"

	if new_status != current_status:
		if DebugOverlay.show_debug_text:
			print("[LenFlai] status: %s \u2192 %s" % [current_status, new_status])
		current_status = new_status


func _check_alarm_thresholds() -> void:
	var alarm: int = FlaiAlarm.current_alarm_level
	for i: int in range(ALARM_THRESHOLDS.size()):
		if _thresholds_triggered[i]:
			continue
		var threshold: int = ALARM_THRESHOLDS[i]["alarm"]
		if _prev_alarm < threshold and alarm >= threshold:
			_thresholds_triggered[i] = true
			var duration: float = ALARM_THRESHOLDS[i]["duration"]
			if DebugOverlay.show_debug_text:
				print("[FlaiSM] threshold reached | alarm=%d | duration=%ss" % [threshold, duration])
			# LenSoul has absolute priority — consume threshold silently
			if current_mode == Mode.LEN_SOUL:
				if DebugOverlay.show_debug_text:
					print("[FlaiSM] threshold consumed silently — LenSoul active")
			else:
				_fire_len_flai_trigger(duration, threshold)
	_prev_alarm = alarm


func _fire_len_flai_trigger(duration: float, threshold_alarm: int) -> void:
	if current_mode == Mode.LEN_FLAI and _auto_return_timer > 0:
		_auto_return_timer = duration
		if DebugOverlay.show_debug_text:
			print("[FlaiSM] trigger refresh | duration=%ss" % duration)
		return

	if current_mode != Mode.FLAI:
		return

	_auto_return_timer = duration
	trigger_len_flai.emit(duration, threshold_alarm)


func _tick_auto_return(delta: float) -> void:
	if _auto_return_timer <= 0:
		return
	_auto_return_timer -= delta
	if _auto_return_timer <= 0:
		_auto_return_timer = -1.0
		if current_mode == Mode.LEN_FLAI:
			if DebugOverlay.show_debug_text:
				print("[FlaiSM] auto-return to FlaiKilima")
			trigger_return_flai.emit()


func _tick_len_soul_timer(delta: float) -> void:
	if _len_soul_timer <= 0:
		return
	_len_soul_timer -= delta
	if _len_soul_timer <= 0:
		_len_soul_timer = -1.0
		if current_mode == Mode.LEN_SOUL:
			if DebugOverlay.show_debug_text:
				print("[LenFlai] LenSoul auto-exit (8s safety)")
			trigger_exit_len_soul.emit()


func force_len_soul(duration: float) -> void:
	cancel_auto_return()
	_len_soul_timer = duration
	if DebugOverlay.show_debug_text:
		print("[LenFlai] force_len_soul | duration=%.1fs" % duration)
	trigger_len_soul.emit()


func cancel_auto_return() -> void:
	_auto_return_timer = -1.0


func register_world_overlay(overlay: Node) -> void:
	_world_overlay = overlay


func world_overlay_fade_in() -> void:
	if _world_overlay and _world_overlay.has_method("fade_in"):
		_world_overlay.fade_in()


func set_len_movables_highlight(active: bool) -> void:
	for obj: Node in get_tree().get_nodes_in_group("len_movable"):
		if obj.has_method("set_highlight"):
			obj.set_highlight(active)


func world_overlay_fade_out() -> void:
	if _world_overlay and _world_overlay.has_method("fade_out"):
		_world_overlay.fade_out()


func set_mode(mode: Mode) -> void:
	if mode == current_mode:
		return
	current_mode = mode
	var target: StringName = MODE_TO_STATE.get(mode, &"FlaiKilima")
	_transition_to(target)


func is_flai_kilima() -> bool:
	return _current_state is FlaiKilima


func _transition_to(target: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(target):
		push_error("[FlaiSM] State not found: %s" % target)
		return

	var old_name: StringName = &""
	if _current_state:
		old_name = StringName(_current_state.name)
		if old_name == target:
			return
		_current_state.exit()

	_current_state = _states[target]
	_current_state.enter(old_name, msg)

	if DebugOverlay.show_debug_text:
		print("[FlaiSM] %s \u2192 %s" % [old_name, target])
