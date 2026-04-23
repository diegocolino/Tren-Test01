extends Camera2D

# Bamboleo sutil de cámara simulando traqueteo del tren sobre los raíles
# Se suma como offset al seguimiento normal de la cámara
@export var shake_amplitude_y: float = 3.0   # px verticales
@export var shake_amplitude_x: float = 1.0   # px horizontales
@export var shake_frequency: float = 0.8     # Hz
@export var shake_enabled: bool = true


func _process(_delta: float) -> void:
	if not shake_enabled:
		offset = Vector2.ZERO
		return

	var time: float = Time.get_ticks_msec() / 1000.0
	var offset_y: float = sin(time * shake_frequency * TAU) * shake_amplitude_y
	# Frecuencia X multiplicada por 0.7 para desfase orgánico
	var offset_x: float = sin(time * shake_frequency * TAU * 0.7) * shake_amplitude_x
	offset = Vector2(offset_x, offset_y)
