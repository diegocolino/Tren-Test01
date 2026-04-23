extends Node2D

func _ready() -> void:
	GameManager.register_kive($Kive)
	GameManager.register_fade($RespawnFade, $RespawnFade/FadeRect)
