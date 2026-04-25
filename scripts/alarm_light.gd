extends Node2D
## Sistema de luces de alarma del vagon.
## Controla todas las PointLight2D hijas con pulso sincronizado.
##
## API publica:
##   set_alarm_state(state: String)  — "patrol", "alert", "combat"

@export_group("Energy")
@export var alert_energy_mult: float = 1.5
@export var combat_energy_mult: float = 3.0

var _state: String = "patrol"
var _base_energies: Array[float] = []
var _lights: Array[PointLight2D] = []
var _energy_mult: float = 1.0
var _hi_mult: float = 1.0
var _lo_mult: float = 0.7
var _transition_tween: Tween

const PATROL_CYCLE: float = 4.0
const ALERT_CYCLE: float = 1.0
const COMBAT_CYCLE: float = 0.92


func _ready() -> void:
	add_to_group("alarm_light")
	for child: Node in get_children():
		if child is PointLight2D:
			_lights.append(child)
			_base_energies.append(child.energy)


func _process(_delta: float) -> void:
	if _transition_tween and _transition_tween.is_valid():
		return

	var t: float = Time.get_ticks_msec() / 1000.0
	var ratio: float

	match _state:
		"patrol":
			var phase: float = fmod(t, PATROL_CYCLE) / PATROL_CYCLE
			ratio = lerpf(_hi_mult, _lo_mult, (1.0 - cos(phase * TAU)) * 0.5)
		"alert":
			var phase: float = fmod(t, ALERT_CYCLE) / ALERT_CYCLE
			ratio = lerpf(_lo_mult, _hi_mult, (1.0 - cos(phase * TAU)) * 0.5)
		"combat":
			var phase: float = fmod(t, COMBAT_CYCLE)
			if phase < 0.34:
				ratio = _hi_mult
			elif phase < 0.44:
				ratio = _lo_mult
			elif phase < 0.62:
				ratio = _hi_mult
			else:
				ratio = _lo_mult
		_:
			ratio = _hi_mult

	for i: int in range(_lights.size()):
		_lights[i].energy = _base_energies[i] * ratio

	# Tinte alarm en FrontLayer via shader (CanvasLayer aislado, no recibe Light2D)
	var front: CanvasItem = get_tree().get_first_node_in_group("front_layer")
	if front and front.material:
		var tint: Color
		match _state:
			"combat":
				tint = Color(1.2, 0.3, 0.2).lerp(Color.WHITE, 1.0 - ratio / _hi_mult)
			"alert":
				tint = Color(1.05, 0.6, 0.5).lerp(Color.WHITE, 1.0 - ratio / _hi_mult)
			_:
				tint = Color.WHITE
		front.material.set_shader_parameter("alarm_tint", tint)


func set_alarm_state(new_state: String) -> void:
	if new_state == _state:
		return
	var old_state: String = _state
	_state = new_state

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	match new_state:
		"combat":
			_hi_mult = combat_energy_mult
			_lo_mult = _hi_mult * 0.08
			_transition_tween = create_tween()
			_transition_tween.tween_method(_set_all_energies, _energy_mult, _hi_mult, 0.3)
		"alert":
			_hi_mult = alert_energy_mult
			_lo_mult = _hi_mult * 0.25
			var dur: float = 2.0 if old_state == "combat" else 0.5
			_transition_tween = create_tween()
			_transition_tween.tween_method(_set_all_energies, _energy_mult, _hi_mult, dur)
		_:
			_hi_mult = 1.0
			_lo_mult = 0.7
			_set_all_energies(1.0)


func _set_all_energies(mult: float) -> void:
	_energy_mult = mult
	for i: int in range(_lights.size()):
		_lights[i].energy = _base_energies[i] * mult
