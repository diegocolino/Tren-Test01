extends Node

enum Mode { FLAI, LEN_FLAI, LEN_SOUL, LEN_ETHER }
var current_mode: Mode = Mode.FLAI

# Public data — written by the active state, read by the HUD.
var current_alarm_level: int = 0
var current_status: String = "TRACKED"
var agents_down: int = 0

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
	if _current_state:
		_current_state.update(delta)


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
		print("[FlaiSM] %s → %s" % [old_name, target])
