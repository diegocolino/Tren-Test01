## Recibir dano del agente (sin parry activo). Flash rojo + respawn.
class_name Damaged extends State

var kive: Kive
var stats: KiveStats
var timer: float = 0.0

const FLASH_DURATION: float = 0.3


func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
	kive = owner_node as Kive
	stats = kive.stats
	timer = 0.0

	# Flash rojo
	kive.sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tween: Tween = kive.create_tween()
	tween.tween_property(kive.sprite, "modulate", Color.WHITE, FLASH_DURATION)

	kive.velocity = Vector2.ZERO


func physics_update(delta: float) -> StringName:
	timer += delta

	if not kive.is_on_floor():
		kive.velocity.y += stats.gravity * delta

	if timer >= FLASH_DURATION:
		GameManager.player_caught()
		return &"Idle"

	kive.move_and_slide()
	return &""
