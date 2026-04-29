class_name LenMovable extends RigidBody2D

@export var movable_label: String = "silla"
var is_highlighted: bool = false
var _hovering: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

const HOVER_SIZE := Vector2(80, 80)  # Must match CollisionShape2D size


func _ready() -> void:
	add_to_group("len_movable")
	LenFlai.trigger_exit_len_soul.connect(_force_drop)


func _input(event: InputEvent) -> void:
	if LenFlai.current_mode != LenFlai.Mode.LEN_SOUL:
		return

	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var half: Vector2 = HOVER_SIZE / 2.0
		var was_hovering: bool = _hovering
		_hovering = Rect2(global_position - half, HOVER_SIZE).has_point(mouse_pos)
		if _hovering != was_hovering and DebugOverlay.show_debug_text:
			print("[LenMovable] hover %s | label=%s" % ["ON" if _hovering else "OFF", movable_label])

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _hovering and not _dragging:
			_dragging = true
			_drag_offset = global_position - get_global_mouse_position()
			freeze = true
			if DebugOverlay.show_debug_text:
				print("[LenMovable] drag START | label=%s | pos=%s" % [movable_label, str(global_position)])
		elif not event.pressed and _dragging:
			_end_drag()


func _physics_process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() + _drag_offset


func set_highlight(active: bool) -> void:
	is_highlighted = active
	modulate = Color(2.0, 1.8, 0.5) if active else Color(1, 1, 1)  # TUNABLE
	if not active:
		_hovering = false


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	freeze = false
	if DebugOverlay.show_debug_text:
		print("[LenMovable] drag END | label=%s | new_pos=%s" % [movable_label, str(global_position)])


func _force_drop() -> void:
	if _dragging:
		_end_drag()
