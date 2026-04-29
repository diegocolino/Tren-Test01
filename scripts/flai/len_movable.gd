class_name LenMovable extends RigidBody2D

@export var movable_label: String = "silla"
var is_highlighted: bool = false


func _ready() -> void:
	add_to_group("len_movable")


func set_highlight(active: bool) -> void:
	is_highlighted = active
	# Golden-bright over grayscale world. TUNABLE.
	modulate = Color(2.0, 1.8, 0.5) if active else Color(1, 1, 1)
