extends CharacterBody2D

# --- Parámetros ajustables desde el editor ---
@export var walk_speed: float = 300.0
@export var run_speed: float = 850.0
@export var jump_velocity: float = -900.0
@export var gravity: float = 2400.0
@export var air_control_factor: float = 0.7

# --- Timing del salto ---
const ANTICIPATION_DURATION: float = 0.08
const LANDING_DURATION: float = 0.1

# --- Estado interno ---
var jump_state: String = "none"  # none, anticipation, rising, peak, falling, landing
var jump_timer: float = 0.0

# --- Referencias ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	match jump_state:
		"anticipation":
			_process_anticipation(delta)
		"landing":
			_process_landing(delta)
		_:
			_process_normal_movement(delta)
	
	move_and_slide()
	_update_sprite_direction()


func _process_anticipation(delta: float) -> void:
	jump_timer += delta
	velocity.x = 0  # no se mueve horizontalmente durante el wind-up
	velocity.y = 0
	sprite.play("jump_anticipation")
	
	if jump_timer >= ANTICIPATION_DURATION:
		velocity.y = jump_velocity
		jump_state = "rising"


func _process_landing(delta: float) -> void:
	jump_timer += delta
	_apply_horizontal_input(false)
	sprite.play("jump_land")
	
	if jump_timer >= LANDING_DURATION:
		jump_state = "none"


func _process_normal_movement(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Input horizontal
	var in_air: bool = not is_on_floor()
	_apply_horizontal_input(in_air)
	
	# Input de salto
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_state == "none":
		jump_state = "anticipation"
		jump_timer = 0.0
		return
	
	# Aterrizaje
	if is_on_floor() and (jump_state == "rising" or jump_state == "peak" or jump_state == "falling"):
		jump_state = "landing"
		jump_timer = 0.0
		return
	
	# Caída sin salto (se cayó de una plataforma)
	if not is_on_floor() and jump_state == "none":
		jump_state = "falling"
	
	# Actualizar estado aéreo
	if not is_on_floor() and jump_state in ["rising", "peak", "falling"]:
		if velocity.y < -50:
			jump_state = "rising"
			sprite.play("jump_rise")
		elif velocity.y > 50:
			jump_state = "falling"
			sprite.play("jump_fall")
		else:
			jump_state = "peak"
			sprite.play("jump_peak")
		return
	
	# Animación en suelo
	if is_on_floor() and jump_state == "none":
		if abs(velocity.x) > 10:
			sprite.play("walk")
			var is_running: bool = Input.is_action_pressed("run")
			sprite.speed_scale = 1.4 if is_running else 1.0
		else:
			sprite.play("idle")
			sprite.speed_scale = 1.0


func _apply_horizontal_input(in_air: bool) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var is_running: bool = Input.is_action_pressed("run")
	var speed: float = run_speed if is_running else walk_speed
	
	if in_air:
		speed *= air_control_factor
	
	if direction != 0:
		velocity.x = direction * speed
	else:
		# Deceleración suave cuando no hay input
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)


func _update_sprite_direction() -> void:
	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true
