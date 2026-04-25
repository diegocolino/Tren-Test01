extends Node2D
## Sistema de linterna del Agent.
## Solo gestiona ConeLight y control de parpadeo (flicker).
##
## API publica:
##   set_active(bool)      — enciende / apaga
##   set_alert_mode(bool)  — aumenta la frecuencia e intensidad del parpadeo


@onready var cone_light: PointLight2D = $ConeLight

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


func _ready() -> void:
	cone_light.texture = _generate_cone_texture()
	_base_cone_energy = cone_light.energy
	_schedule_next_flicker()


func _generate_cone_texture() -> ImageTexture:
	var size := Vector2i(1024, 512)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var center_y: float = size.y / 2.0
	var half_x: float = size.x / 2.0
	for x: int in range(size.x):
		for y: int in range(size.y):
			var alpha: float = 0.0
			if x >= int(half_x):
				var dist_x: float = (float(x) - half_x) / half_x
				var cone_width: float = lerpf(0.02, 0.95, dist_x)
				var dist_y: float = abs(float(y) - center_y) / center_y
				if dist_y <= cone_width:
					alpha = pow(1.0 - dist_x, 1.0) * (1.0 - pow(dist_y / cone_width, 2.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


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
	tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.6)

	if do_double:
		tween.tween_interval(0.05)
		tween.tween_property(cone_light, "energy", _base_cone_energy * dip_mult, dip_dur * 0.3)
		tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.4)
