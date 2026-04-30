extends CanvasLayer

const LEN_SOUL_TIME_SCALE: float = 0.3  # TUNABLE
const FADE_DURATION: float = 0.3  # TUNABLE
const VIGNETTE_INTENSITY: float = 0.6  # TUNABLE
const VIGNETTE_FADE_IN: float = 0.3  # TUNABLE
const VIGNETTE_FADE_OUT: float = 0.5  # TUNABLE

@onready var grayscale_rect: ColorRect = $GrayscaleRect
@onready var vignette_rect: ColorRect = $VignetteRect
var _shader_mat: ShaderMaterial
var _vignette_mat: ShaderMaterial


func _ready() -> void:
	_shader_mat = grayscale_rect.material as ShaderMaterial
	_shader_mat.set_shader_parameter("intensity", 0.0)
	_vignette_mat = vignette_rect.material as ShaderMaterial
	_vignette_mat.set_shader_parameter("vignette_intensity", 0.0)
	LenFlai.register_world_overlay(self)


func fade_in() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_intensity, 0.0, 1.0, FADE_DURATION)
	tween.tween_property(Engine, "time_scale", LEN_SOUL_TIME_SCALE, FADE_DURATION)
	tween.tween_method(_set_vignette, 0.0, VIGNETTE_INTENSITY, VIGNETTE_FADE_IN)
	if DebugOverlay.show_debug_text:
		print("[LenFlai] world overlay: fade-in (intensity 0→1, time_scale 1.0→%.1f, vignette 0→%.1f)" % [LEN_SOUL_TIME_SCALE, VIGNETTE_INTENSITY])


func fade_out() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_intensity, 1.0, 0.0, FADE_DURATION)
	tween.tween_property(Engine, "time_scale", 1.0, FADE_DURATION)
	tween.tween_method(_set_vignette, VIGNETTE_INTENSITY, 0.0, VIGNETTE_FADE_OUT)
	if DebugOverlay.show_debug_text:
		print("[LenFlai] world overlay: fade-out (intensity 1→0, time_scale %.1f→1.0, vignette %.1f→0)" % [LEN_SOUL_TIME_SCALE, VIGNETTE_INTENSITY])


func _set_intensity(value: float) -> void:
	_shader_mat.set_shader_parameter("intensity", value)


func _set_vignette(value: float) -> void:
	_vignette_mat.set_shader_parameter("vignette_intensity", value)
