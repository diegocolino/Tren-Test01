extends Camera2D

# Bamboleo sutil de cámara simulando traqueteo del tren sobre los raíles
# Se suma como offset al seguimiento normal de la cámara
@export var shake_amplitude_y: float = 3.0   # px verticales
@export var shake_amplitude_x: float = 1.0   # px horizontales
@export var shake_frequency: float = 0.8     # Hz
@export var shake_enabled: bool = true

# Free camera (God Mode)
var _free_cam_position: Vector2 = Vector2.ZERO
var _cam_detached: bool = false
var _middle_dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var _zoom_target: float = 1.0
var _position_target: Vector2 = Vector2.ZERO
const ZOOM_STEP: float = 0.08
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 3.0
const ZOOM_SMOOTH: float = 5.0
const DRAG_SENSITIVITY: float = 1.5


func _process(delta: float) -> void:
	if DebugOverlay.god_mode:
		if _cam_detached:
			_process_free_camera(delta)
		else:
			_process_shake(delta)
		return

	# Salir de god mode: restaurar cámara
	if _cam_detached:
		_cam_detached = false
		_middle_dragging = false
		top_level = false
		position = Vector2.ZERO
		zoom = Vector2.ONE
		offset = Vector2.ZERO
		return

	_process_shake(delta)


func _process_shake(delta: float) -> void:
	if not shake_enabled:
		offset = Vector2.ZERO
		return

	var time: float = Time.get_ticks_msec() / 1000.0
	var offset_y: float = sin(time * shake_frequency * TAU) * shake_amplitude_y
	# Frecuencia X multiplicada por 0.7 para desfase orgánico
	var offset_x: float = sin(time * shake_frequency * TAU * 0.7) * shake_amplitude_x
	offset = Vector2(offset_x, offset_y)


func _detach_camera() -> void:
	if _cam_detached:
		return
	_free_cam_position = global_position
	_position_target = _free_cam_position
	_zoom_target = zoom.x
	top_level = true
	_cam_detached = true


func _process_free_camera(delta: float) -> void:
	if not _middle_dragging:
		_free_cam_position = _free_cam_position.lerp(_position_target, ZOOM_SMOOTH * delta)

	var smooth_zoom: float = lerpf(zoom.x, _zoom_target, ZOOM_SMOOTH * delta)
	zoom = Vector2.ONE * smooth_zoom
	global_position = _free_cam_position


func _unhandled_input(event: InputEvent) -> void:
	if not DebugOverlay.god_mode:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_detach_camera()
				_middle_dragging = true
				_last_mouse = event.position
			else:
				_middle_dragging = false
				_position_target = _free_cam_position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_detach_camera()
			_zoom_toward_mouse(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_detach_camera()
			_zoom_toward_mouse(event.position, -ZOOM_STEP)

	elif event is InputEventMouseMotion and _middle_dragging:
		var delta_mouse: Vector2 = event.relative * DRAG_SENSITIVITY / zoom
		_free_cam_position -= delta_mouse
		_free_cam_position.x = clampf(_free_cam_position.x, 0, 7680)
		_free_cam_position.y = clampf(_free_cam_position.y, 0, 1080)
		_position_target = _free_cam_position
		global_position = _free_cam_position


func _zoom_toward_mouse(mouse_pos: Vector2, step: float) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var old_zoom: float = _zoom_target
	var new_zoom: float = clampf(old_zoom + step, ZOOM_MIN, ZOOM_MAX)
	var world_point: Vector2 = _free_cam_position + (mouse_pos - vp_size * 0.5) / old_zoom
	_position_target = world_point - (mouse_pos - vp_size * 0.5) / new_zoom
	_position_target.x = clampf(_position_target.x, 0, 7680)
	_position_target.y = clampf(_position_target.y, 0, 1080)
	_zoom_target = new_zoom
