extends Node

# Posicion inicial de Kive en el Vagon 1
var kive_spawn_position: Vector2 = Vector2(200, 700)
var kive_ref: Node2D = null

# Referencia a guardias registrados para resetearlos al respawn
var guards: Array[Node] = []

# Fade visual
@onready var fade_layer: CanvasLayer = null
@onready var fade_rect: ColorRect = null

signal player_respawn_started
signal player_respawn_completed


func register_kive(kive: Node2D) -> void:
	kive_ref = kive


func register_guard(guard: Node) -> void:
	guards.append(guard)


func register_fade(layer: CanvasLayer, rect: ColorRect) -> void:
	fade_layer = layer
	fade_rect = rect


func player_caught() -> void:
	if kive_ref == null:
		return
	player_respawn_started.emit()
	_do_respawn()


func _do_respawn() -> void:
	# Desactivar control de Kive
	if kive_ref.has_method("set_control_enabled"):
		kive_ref.set_control_enabled(false)

	# Fade out
	if fade_rect:
		var tween: Tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
		await tween.finished

	# Reposicionar Kive
	kive_ref.global_position = kive_spawn_position
	if kive_ref.has_method("reset_state"):
		kive_ref.reset_state()

	# Resetear guardias
	for guard in guards:
		if is_instance_valid(guard) and guard.has_method("reset_to_patrol"):
			guard.reset_to_patrol()

	# Fade in
	if fade_rect:
		var tween: Tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.3)
		await tween.finished

	# Reactivar control
	if kive_ref.has_method("set_control_enabled"):
		kive_ref.set_control_enabled(true)

	player_respawn_completed.emit()
