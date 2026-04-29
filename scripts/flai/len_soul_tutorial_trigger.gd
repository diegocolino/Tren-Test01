class_name LenSoulTutorialTrigger extends Area2D

var _fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	$CollisionShape2D.set_deferred("disabled", true)
	LenFlai.force_len_soul(6.0)
	if DebugOverlay.show_debug_text:
		print("[LenSoulTutorialTrigger] fired — first Len-soul exposure")
