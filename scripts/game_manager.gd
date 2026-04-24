extends Node

# Posicion inicial de Kive en el Vagon 1
var kive_spawn_position: Vector2 = Vector2(200, 700)
var kive_ref: Node2D = null

# Referencia a guardias registrados para resetearlos al respawn
var guards: Array[Node] = []
var _respawning: bool = false

# Fade visual
var fade_rect: ColorRect = null

signal player_respawn_started
signal player_respawn_completed


func register_kive(kive: Node2D) -> void:
	kive_ref = kive


func register_guard(guard: Node) -> void:
	guards.append(guard)


func register_fade(rect: ColorRect) -> void:
	fade_rect = rect


func player_caught() -> void:
	if _respawning or kive_ref == null:
		return
	_respawning = true
	player_respawn_started.emit()
	_do_respawn()


func _do_respawn() -> void:
	# Desactivar control de Kive
	kive_ref.set_control_enabled(false)

	# Fade out
	await _fade_to(1.0)

	# Reposicionar Kive
	kive_ref.global_position = kive_spawn_position
	kive_ref.reset_state()

	# Resetear guardias
	for guard in guards:
		if is_instance_valid(guard) and guard.has_method("reset_to_patrol"):
			guard.reset_to_patrol()

	# Fade in
	await _fade_to(0.0)

	# Reactivar control
	kive_ref.set_control_enabled(true)

	_respawning = false
	player_respawn_completed.emit()


func _fade_to(alpha: float) -> void:
	if fade_rect:
		var tween: Tween = create_tween()
		tween.tween_property(fade_rect, "color:a", alpha, 0.3)
		await tween.finished
