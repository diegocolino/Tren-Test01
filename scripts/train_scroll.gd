extends ParallaxLayer

# Desplazamiento continuo del paisaje para simular movimiento del tren
# Se aplica via motion_offset del ParallaxLayer (forma idiomática en Godot 4)
# Para invertir la dirección del scroll, cambiar el signo de scroll_speed
@export var scroll_speed: float = 1920.0  # px/seg (positivo = paisaje va hacia la izquierda = tren avanza a la derecha)


func _process(delta: float) -> void:
	motion_offset.x -= scroll_speed * delta
