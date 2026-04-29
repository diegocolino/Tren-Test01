extends CanvasLayer

@onready var alarm_label: Label = $HUDContainer/HBox/DataLabels/AlarmLabel
@onready var status_label: Label = $HUDContainer/HBox/DataLabels/StatusLabel
@onready var agents_down_label: Label = $HUDContainer/HBox/DataLabels/AgentsDownLabel
@onready var flai_sprite: AnimatedSprite2D = $HUDContainer/HBox/SpriteAnchor/FlaiSprite

var _flai_tex: Texture2D = preload("res://assets/Flai-HUD_Sprite.png")
var _len_flai_tex: Texture2D = preload("res://assets/Len-Flai-HUD_Sprite.png")
var _transition_tex: Texture2D = preload("res://assets/Len-Flai-HUD_Transition_Sprite.png")

var _transitioning: bool = false


func _ready() -> void:
	_build_sprite_frames()
	flai_sprite.play(&"flai_idle")
	flai_sprite.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	alarm_label.text = "ALARM: %d" % LenFlai.current_alarm_level
	status_label.text = "STATUS: %s" % LenFlai.current_status
	agents_down_label.text = "AGENTS DOWN: %d" % LenFlai.agents_down


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if not DebugOverlay.god_mode:
		return

	if event.keycode == KEY_F:
		if _transitioning:
			if DebugOverlay.show_debug_text:
				print("[FlaiSM] toggle ignored — transition in progress")
			return
		if LenFlai.is_flai_kilima():
			_transitioning = true
			flai_sprite.play(&"transition_to_len_flai")
		elif LenFlai.current_mode == LenFlai.Mode.LEN_FLAI:
			_transitioning = true
			flai_sprite.play(&"transition_to_flai")


func _on_animation_finished() -> void:
	match flai_sprite.animation:
		&"transition_to_len_flai":
			flai_sprite.play(&"len_flai_idle")
			LenFlai.set_mode(LenFlai.Mode.LEN_FLAI)
			_transitioning = false
		&"transition_to_flai":
			flai_sprite.play(&"flai_idle")
			LenFlai.set_mode(LenFlai.Mode.FLAI)
			_transitioning = false


func _build_sprite_frames() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	# flai_idle — 1 frame, loop
	sf.add_animation(&"flai_idle")
	sf.set_animation_loop(&"flai_idle", true)
	sf.set_animation_speed(&"flai_idle", 1.0)
	sf.add_frame(&"flai_idle", _flai_tex)

	# len_flai_idle — 1 frame, loop
	sf.add_animation(&"len_flai_idle")
	sf.set_animation_loop(&"len_flai_idle", true)
	sf.set_animation_speed(&"len_flai_idle", 1.0)
	sf.add_frame(&"len_flai_idle", _len_flai_tex)

	# transition_to_len_flai — 5 frames from sheet, order 4→0 (Flai→Len), no loop
	sf.add_animation(&"transition_to_len_flai")
	sf.set_animation_loop(&"transition_to_len_flai", false)
	sf.set_animation_speed(&"transition_to_len_flai", 10.0)
	for i: int in range(4, -1, -1):
		sf.add_frame(&"transition_to_len_flai", _make_atlas_frame(i))

	# transition_to_flai — 5 frames from sheet, order 0→4 (Len→Flai), no loop
	sf.add_animation(&"transition_to_flai")
	sf.set_animation_loop(&"transition_to_flai", false)
	sf.set_animation_speed(&"transition_to_flai", 10.0)
	for i: int in range(0, 5):
		sf.add_frame(&"transition_to_flai", _make_atlas_frame(i))

	flai_sprite.sprite_frames = sf


func _make_atlas_frame(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _transition_tex
	atlas.region = Rect2(index * 256, 0, 256, 256)
	return atlas
