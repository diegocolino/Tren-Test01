extends Node2D

# Simula paralaje para la capa frontal fuera de ParallaxBackground
# para que z_index funcione correctamente contra otros nodos
@export var motion_scale: Vector2 = Vector2(1.15, 1.0)

var _viewport_size: Vector2


func _ready() -> void:
	_viewport_size = get_viewport_rect().size


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var scroll: Vector2 = camera.get_screen_center_position() - _viewport_size * 0.5
		position = -scroll * (motion_scale - Vector2.ONE)
