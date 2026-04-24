extends Node2D
## Sistema de linterna cinematografica del Agent.
## Composicion de ConeLight (proyecta sombras), BulbGlow (lente), GroundSpot (suelo),
## DustParticles (polvo) y control de parpadeo (flicker).
##
## API publica:
##   set_active(bool)      — enciende / apaga todo el sistema
##   set_alert_mode(bool)  — aumenta la frecuencia e intensidad del parpadeo


const ConeTexGen = preload("res://scripts/cone_texture_generator.gd")

@onready var cone_light: PointLight2D = $ConeLight
@onready var bulb_glow: PointLight2D = $BulbGlow
@onready var ground_spot: PointLight2D = $GroundSpot
@onready var dust_particles: GPUParticles2D = $DustParticles

# === Flicker ===
@export_group("Flicker sutil (idle)")
@export var flicker_idle_min_interval: float = 3.0
@export var flicker_idle_max_interval: float = 8.0
@export var flicker_idle_dip_energy: float = 0.75
@export var flicker_idle_dip_duration: float = 0.08

@export_group("Flicker alerta")
@export var flicker_alert_min_interval: float = 0.4
@export var flicker_alert_max_interval: float = 1.2
@export var flicker_alert_dip_energy: float = 0.4
@export var flicker_alert_dip_duration: float = 0.05

var _is_active: bool = true
var _is_alert: bool = false
var _next_flicker_time: float = 0.0
var _time_accumulator: float = 0.0

var _base_cone_energy: float = 0.0
var _base_bulb_energy: float = 0.0
var _base_ground_energy: float = 0.0


func _ready() -> void:
	cone_light.texture = ConeTexGen.generate(Vector2i(1024, 512), 0.02, 0.95, 1.4)

	_base_cone_energy = cone_light.energy
	_base_bulb_energy = bulb_glow.energy
	_base_ground_energy = ground_spot.energy

	_schedule_next_flicker()


func _process(delta: float) -> void:
	if not _is_active:
		return

	_time_accumulator += delta

	if _time_accumulator >= _next_flicker_time:
		_do_flicker()
		_schedule_next_flicker()


func set_active(active: bool) -> void:
	_is_active = active
	visible = active
	cone_light.enabled = active
	bulb_glow.enabled = active
	ground_spot.enabled = active
	dust_particles.emitting = active


func set_alert_mode(alert: bool) -> void:
	_is_alert = alert
	if alert:
		cone_light.energy = _base_cone_energy * 1.15
	else:
		cone_light.energy = _base_cone_energy


func _schedule_next_flicker() -> void:
	var min_i: float = flicker_alert_min_interval if _is_alert else flicker_idle_min_interval
	var max_i: float = flicker_alert_max_interval if _is_alert else flicker_idle_max_interval
	_next_flicker_time = _time_accumulator + randf_range(min_i, max_i)


func _do_flicker() -> void:
	var dip_mult: float = flicker_alert_dip_energy if _is_alert else flicker_idle_dip_energy
	var dip_dur: float = flicker_alert_dip_duration if _is_alert else flicker_idle_dip_duration

	var do_double: bool = randf() < 0.2

	var tween: Tween = create_tween()
	tween.tween_property(cone_light, "energy", _base_cone_energy * dip_mult, dip_dur * 0.4)
	tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy * dip_mult, dip_dur * 0.4)
	tween.parallel().tween_property(ground_spot, "energy", _base_ground_energy * dip_mult, dip_dur * 0.4)

	tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.6)
	tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy, dip_dur * 0.6)
	tween.parallel().tween_property(ground_spot, "energy", _base_ground_energy, dip_dur * 0.6)

	if do_double:
		tween.tween_interval(0.05)
		tween.tween_property(cone_light, "energy", _base_cone_energy * dip_mult, dip_dur * 0.3)
		tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy * dip_mult, dip_dur * 0.3)
		tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.4)
		tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy, dip_dur * 0.4)
