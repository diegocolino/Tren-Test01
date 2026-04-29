extends CanvasLayer

@onready var alarm_label: Label = $HUDContainer/HBox/DataLabels/AlarmLabel
@onready var status_label: Label = $HUDContainer/HBox/DataLabels/StatusLabel
@onready var agents_down_label: Label = $HUDContainer/HBox/DataLabels/AgentsDownLabel
@onready var data_labels: VBoxContainer = $HUDContainer/HBox/DataLabels
@onready var flai_sprite: AnimatedSprite2D = $HUDContainer/HBox/SpriteAnchor/FlaiSprite
@onready var dialog_label: Label = $DialogLabel
@onready var white_flash: ColorRect = $WhiteFlash

var _flai_tex: Texture2D = preload("res://assets/Flai-HUD_Sprite.png")
var _len_flai_tex: Texture2D = preload("res://assets/Len-Flai-HUD_Sprite.png")
var _len_soul_tex: Texture2D = preload("res://assets/Len-Soul-HUD_Sprite.png")
var _transition_tex: Texture2D = preload("res://assets/Len-Flai-HUD_Transition_Sprite.png")

var _transitioning: bool = false
var _pending_threshold: int = -1

const FLAI_SCALE: float = 0.4
const LEN_FLAI_SCALE: float = 0.7
const LEN_SOUL_SCALE: float = 0.9  # TUNABLE
const FLAI_POS := Vector2(51, 51)
const LEN_FLAI_POS := Vector2(90, 90)
const LEN_SOUL_POS := Vector2(115, 115)  # TUNABLE — same growth vector as 2.5
const TRANSITION_DURATION: float = 0.5
const DIALOG_FADE_DURATION: float = 0.3  # TUNABLE
const LEN_SOUL_FLASH_HALF: float = 0.15  # TUNABLE — half of the white flash

# TODO: replace with dialog system when available (V1.X+)
const DIALOG_BY_THRESHOLD: Dictionary = {
	3: "deberías llevar cuidado, esto no va a salir bien",
	6: "esto se está yendo de las manos",
	9: "para. por favor.",
}


func _ready() -> void:
	_build_sprite_frames()
	flai_sprite.scale = Vector2(FLAI_SCALE, FLAI_SCALE)
	flai_sprite.position = FLAI_POS
	flai_sprite.play(&"flai_idle")
	flai_sprite.animation_finished.connect(_on_animation_finished)
	LenFlai.trigger_len_flai.connect(_on_trigger_len_flai)
	LenFlai.trigger_return_flai.connect(_on_trigger_return_flai)
	LenFlai.trigger_len_soul.connect(_on_trigger_len_soul)
	LenFlai.trigger_exit_len_soul.connect(_on_trigger_exit_len_soul)
	dialog_label.modulate.a = 0.0
	white_flash.modulate.a = 0.0


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
		if LenFlai.current_mode == LenFlai.Mode.LEN_SOUL:
			if DebugOverlay.show_debug_text:
				print("[LenFlai] F ignored — LenSoul active")
			return
		if _transitioning:
			if DebugOverlay.show_debug_text:
				print("[FlaiSM] toggle ignored — transition in progress")
			return
		if LenFlai.is_flai_kilima():
			LenFlai.cancel_auto_return()
			_pending_threshold = -1
			_start_transition_to_len_flai()
		elif LenFlai.current_mode == LenFlai.Mode.LEN_FLAI:
			LenFlai.cancel_auto_return()
			_start_transition_to_flai()


func _on_trigger_len_flai(_duration: float, threshold_alarm: int) -> void:
	if _transitioning:
		if DebugOverlay.show_debug_text:
			print("[FlaiSM] trigger ignored — transition in progress")
		return
	_pending_threshold = threshold_alarm
	_start_transition_to_len_flai()


func _on_trigger_return_flai() -> void:
	if _transitioning:
		return
	if LenFlai.current_mode == LenFlai.Mode.LEN_FLAI:
		_start_transition_to_flai()


func _on_trigger_len_soul() -> void:
	if _transitioning:
		if DebugOverlay.show_debug_text:
			print("[LenFlai] L ignored — transition in progress")
		return
	trigger_len_soul_visual()


func _on_trigger_exit_len_soul() -> void:
	if _transitioning:
		return
	exit_len_soul_visual()


# ========== Flai ↔ Len-flai transitions ==========

func _start_transition_to_len_flai() -> void:
	_transitioning = true
	flai_sprite.play(&"transition_to_len_flai")
	_tween_sprite(LEN_FLAI_SCALE, LEN_FLAI_POS)
	_tween_labels(0.0)


func _start_transition_to_flai() -> void:
	_transitioning = true
	_fade_dialog_out()
	flai_sprite.play(&"transition_to_flai")
	_tween_sprite(FLAI_SCALE, FLAI_POS)
	_tween_labels(1.0)


func _on_animation_finished() -> void:
	match flai_sprite.animation:
		&"transition_to_len_flai":
			flai_sprite.play(&"len_flai_idle")
			LenFlai.set_mode(LenFlai.Mode.LEN_FLAI)
			_transitioning = false
			_show_dialog_if_triggered()
		&"transition_to_flai":
			flai_sprite.play(&"flai_idle")
			LenFlai.set_mode(LenFlai.Mode.FLAI)
			_transitioning = false


# ========== Len-soul visual transitions ==========

func trigger_len_soul_visual() -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_dialog_out()

	var tween: Tween = create_tween()
	# Flash in
	tween.tween_property(white_flash, "modulate:a", 1.0, LEN_SOUL_FLASH_HALF)
	# At peak: swap sprite + start scale tween + world overlay
	tween.tween_callback(_swap_to_len_soul)
	# Flash out
	tween.tween_property(white_flash, "modulate:a", 0.0, LEN_SOUL_FLASH_HALF)
	tween.tween_callback(func() -> void: _transitioning = false)

	LenFlai.world_overlay_fade_in()

	if DebugOverlay.show_debug_text:
		print("[LenFlai] visual transition: → LenSoul")


func exit_len_soul_visual() -> void:
	if _transitioning:
		return
	_transitioning = true

	var tween: Tween = create_tween()
	# Flash in
	tween.tween_property(white_flash, "modulate:a", 1.0, LEN_SOUL_FLASH_HALF)
	# At peak: swap sprite back to Flai + start scale tween + world overlay
	tween.tween_callback(_swap_from_len_soul)
	# Flash out
	tween.tween_property(white_flash, "modulate:a", 0.0, LEN_SOUL_FLASH_HALF)
	tween.tween_callback(func() -> void: _transitioning = false)

	LenFlai.world_overlay_fade_out()

	if DebugOverlay.show_debug_text:
		print("[LenFlai] visual transition: LenSoul → FlaiKilima")


func _swap_to_len_soul() -> void:
	flai_sprite.play(&"len_soul_idle")
	_tween_sprite(LEN_SOUL_SCALE, LEN_SOUL_POS)
	_tween_labels(0.0)
	LenFlai.set_mode(LenFlai.Mode.LEN_SOUL)


func _swap_from_len_soul() -> void:
	flai_sprite.play(&"flai_idle")
	_tween_sprite(FLAI_SCALE, FLAI_POS)
	_tween_labels(1.0)
	LenFlai.set_mode(LenFlai.Mode.FLAI)


# ========== Shared visual helpers ==========

func _show_dialog_if_triggered() -> void:
	if _pending_threshold < 0:
		return
	var text: String = DIALOG_BY_THRESHOLD.get(_pending_threshold, "")
	if text.is_empty():
		_pending_threshold = -1
		return
	dialog_label.text = text
	var tween: Tween = create_tween()
	tween.tween_property(dialog_label, "modulate:a", 1.0, DIALOG_FADE_DURATION)
	if DebugOverlay.show_debug_text:
		print("[LenFlaiState] dialogo activado | trigger=threshold_%d | text=\"%s\"" % [_pending_threshold, text])
	_pending_threshold = -1


func _fade_dialog_out() -> void:
	if dialog_label.modulate.a <= 0.0:
		return
	var tween: Tween = create_tween()
	tween.tween_property(dialog_label, "modulate:a", 0.0, DIALOG_FADE_DURATION)
	tween.tween_callback(func() -> void: dialog_label.text = "")
	if DebugOverlay.show_debug_text:
		print("[LenFlaiState] dialogo desactivado")


func _tween_sprite(target_scale: float, target_pos: Vector2) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(flai_sprite, "scale", Vector2(target_scale, target_scale), TRANSITION_DURATION)
	tween.tween_property(flai_sprite, "position", target_pos, TRANSITION_DURATION)


func _tween_labels(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(data_labels, "modulate:a", target_alpha, TRANSITION_DURATION * 0.5)


# ========== SpriteFrames setup ==========

func _build_sprite_frames() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	sf.add_animation(&"flai_idle")
	sf.set_animation_loop(&"flai_idle", true)
	sf.set_animation_speed(&"flai_idle", 1.0)
	sf.add_frame(&"flai_idle", _flai_tex)

	sf.add_animation(&"len_flai_idle")
	sf.set_animation_loop(&"len_flai_idle", true)
	sf.set_animation_speed(&"len_flai_idle", 1.0)
	sf.add_frame(&"len_flai_idle", _len_flai_tex)

	sf.add_animation(&"len_soul_idle")
	sf.set_animation_loop(&"len_soul_idle", true)
	sf.set_animation_speed(&"len_soul_idle", 1.0)
	sf.add_frame(&"len_soul_idle", _len_soul_tex)

	sf.add_animation(&"transition_to_len_flai")
	sf.set_animation_loop(&"transition_to_len_flai", false)
	sf.set_animation_speed(&"transition_to_len_flai", 10.0)
	for i: int in range(4, -1, -1):
		sf.add_frame(&"transition_to_len_flai", _make_atlas_frame(i))

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
