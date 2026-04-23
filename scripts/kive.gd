extends CharacterBody2D

# --- Parámetros ajustables desde el editor ---
@export var walk_speed: float = 400.0
@export var run_speed: float = 800.0
@export var gravity: float = 2400.0
@export var air_control_factor: float = 0.8

@export_group("Double Jump")
@export var max_air_jumps: int = 1
@export var air_jump_velocity: float = -800.0

@export_group("Crouch")
@export var crouch_walk_speed: float = 200.4
@export var crouch_height_multiplier: float = 0.7

@export_group("Charged Jump")
@export var jump_charge_time: float = 0.4
@export var jump_velocity_min: float = -800.0
@export var jump_velocity_max: float = -1200.0

@export_group("Dive")
@export var dive_speed: float = 1200.0
@export var dive_max_duration: float = 1.2
@export var dive_friction: float = 800.0

# --- Step climbing ---
const step_height: float = 80.0

# --- Timing del salto ---
const anticipation_duration: float = 0.04
const charge_threshold: float = 0.14
const charge_cancel_time: float = 4.0

# --- Estado interno ---
var jump_state: String = "none"  # none, anticipation, jump_air, air_jump_rise, air_jump_fall, precontact, contact, recovery
var jump_timer: float = 0.0
var control_enabled: bool = true
var is_crouched: bool = false
var is_hidden: bool = false
var is_diving: bool = false
var _air_jumps_left: int = 0
var _nearby_hide_zones: int = 0
var _is_charging_jump: bool = false
var _jump_charge_timer: float = 0.0
var _dive_timer: float = 0.0
var _dive_direction: float = 0.0
var _was_in_air: bool = false
var _was_moving_at_jump: bool = false

# --- Referencias ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	sprite.animation_finished.connect(_on_animation_finished)
	# Conectar señales de HideZones
	for zone in get_tree().get_nodes_in_group("hide_zone"):
		zone.body_entered.connect(_on_hide_zone_entered)
		zone.body_exited.connect(_on_hide_zone_exited)


func _on_animation_finished() -> void:
	match sprite.animation:
		"dive_start":
			sprite.play("dive_slide")
		"dive_end":
			is_diving = false
			_update_collision_shape()
		"jump_recovery":
			jump_state = "none"
		"jump_contact":
			jump_state = "recovery"
			sprite.play("jump_recovery")


func _physics_process(delta: float) -> void:
	if not control_enabled:
		return

	# Si está escondido, salir si hay input de movimiento
	if is_hidden:
		var direction: float = Input.get_axis("move_left", "move_right")
		if direction != 0 or Input.is_action_just_pressed("jump"):
			_unhide()
		else:
			move_and_slide()
			return

	# Crouch toggle/hold (solo en suelo y sin saltar, sin dive)
	if is_on_floor() and jump_state == "none" and not is_diving:
		if PauseMenu.hold_to_crouch:
			var should_crouch: bool = Input.is_action_pressed("crouch")
			if should_crouch != is_crouched:
				is_crouched = should_crouch
				_update_collision_shape()
		else:
			if Input.is_action_just_pressed("crouch"):
				is_crouched = not is_crouched
				_update_collision_shape()

	# Auto-hide: agachado + en zona segura + quieto = esconderse
	if is_crouched and not is_hidden and _nearby_hide_zones > 0 and is_on_floor() and jump_state == "none" and _can_hide():
		var auto_dir: float = Input.get_axis("move_left", "move_right")
		if auto_dir == 0 and abs(velocity.x) < 10:
			_hide()

	# Track air state for dive landing
	_was_in_air = not is_on_floor()

	# Dive processing (parallel state)
	if is_diving:
		_process_dive(delta)
	else:
		match jump_state:
			"anticipation":
				_process_anticipation(delta)
			"contact", "recovery":
				_process_landing(delta)
			_:
				_process_normal_movement(delta)

	move_and_slide()

	# Dive landing check (after move_and_slide)
	if is_diving and is_on_floor() and _was_in_air:
		_on_dive_landed()

	_try_step_up()
	_update_sprite_direction()
	queue_redraw()


func _process_anticipation(delta: float) -> void:
	jump_timer += delta
	velocity.x = 0
	velocity.y = 0

	if jump_timer >= anticipation_duration:
		if Input.is_action_pressed("jump"):
			_jump_charge_timer += delta
			if _jump_charge_timer >= charge_cancel_time:
				# Held too long — cancel jump
				_cancel_charged_jump()
			elif _jump_charge_timer >= charge_threshold:
				# Confirmed charge mode
				_is_charging_jump = true
				sprite.frame = 1  # hold frame 10
				sprite.pause()
		else:
			# Released = launch (instajump o charged)
			_release_jump()


func _release_jump() -> void:
	sprite.play()  # resume if paused
	var is_static: bool = not _was_moving_at_jump and not _is_charging_jump

	var charge_ratio: float = 0.0
	if _is_charging_jump:
		charge_ratio = clampf(_jump_charge_timer / jump_charge_time, 0.0, 1.0)

	var jump_vel: float
	if _is_charging_jump:
		jump_vel = lerpf(jump_velocity_min, jump_velocity_max, charge_ratio)
	else:
		jump_vel = jump_velocity_min

	velocity.y = jump_vel
	_is_charging_jump = false
	_jump_charge_timer = 0.0

	if is_static:
		jump_state = "precontact"  # skip air frame for static jump
		sprite.play("jump_precontact")
	else:
		jump_state = "jump_air"
		sprite.play("jump_air")


func _cancel_charged_jump() -> void:
	sprite.play()  # resume if paused
	_is_charging_jump = false
	_jump_charge_timer = 0.0
	jump_state = "recovery"
	sprite.play("jump_recovery")


func _process_landing(delta: float) -> void:
	jump_timer += delta
	_apply_horizontal_input(false)
	# Animation handled by animation_finished signal (contact → recovery → none)


func _process_normal_movement(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Input horizontal
	var in_air: bool = not is_on_floor()
	_apply_horizontal_input(in_air)

	# Input de salto (ground)
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_state == "none":
		if is_crouched:
			is_crouched = false
			_update_collision_shape()
		_air_jumps_left = max_air_jumps
		var is_running: bool = abs(velocity.x) > 10 and not Input.is_action_pressed("run")
		_was_moving_at_jump = abs(velocity.x) > 10
		if is_running:
			# Corriendo: instajump directo a airtime, sin anticipation
			velocity.y = jump_velocity_min
			jump_state = "jump_air"
			sprite.play("jump_air")
		else:
			# Andando o parado: pasa por anticipation (frame 9)
			jump_state = "anticipation"
			jump_timer = 0.0
			_is_charging_jump = false
			_jump_charge_timer = 0.0
			sprite.play("jump_anticipation")
		return

	# Air jump
	if Input.is_action_just_pressed("jump") and not is_on_floor() and _air_jumps_left > 0:
		if is_diving:
			# Combo: cancel dive, allow air jump
			is_diving = false
			_update_collision_shape()
		_air_jumps_left -= 1
		velocity.y = air_jump_velocity
		jump_state = "air_jump_rise"
		sprite.play("air_jump_rise")
		return

	# Ground dive
	if Input.is_action_just_pressed("dive") and is_on_floor() and not is_crouched \
			and not is_diving and abs(velocity.x) > 10 \
			and not Input.is_action_pressed("run"):  # "run" = walk/Shift
		_start_ground_dive()
		return

	# Air dive
	if Input.is_action_just_pressed("dive") and not is_on_floor() and not is_diving:
		_start_air_dive()
		return

	# Aterrizaje
	if is_on_floor() and jump_state in ["jump_air", "air_jump_rise", "air_jump_fall", "precontact"]:
		jump_state = "contact"
		jump_timer = 0.0
		sprite.play("jump_contact")
		return

	# Caída sin salto (se cayó de una plataforma)
	if not is_on_floor() and jump_state == "none":
		jump_state = "jump_air"
		sprite.play("jump_air")

	# Actualizar estado aéreo
	if not is_on_floor() and jump_state in ["jump_air", "air_jump_rise", "air_jump_fall", "precontact"]:
		if jump_state in ["air_jump_rise", "air_jump_fall"]:
			# Air jump transitions
			if velocity.y < -50:
				if jump_state != "air_jump_rise":
					jump_state = "air_jump_rise"
					sprite.play("air_jump_rise")
			elif velocity.y > 200:
				jump_state = "precontact"
				sprite.play("jump_precontact")
			elif velocity.y > 50:
				if jump_state != "air_jump_fall":
					jump_state = "air_jump_fall"
					sprite.play("air_jump_fall")
		else:
			# Normal jump transitions
			if velocity.y > 200:
				if jump_state != "precontact":
					jump_state = "precontact"
					sprite.play("jump_precontact")
		return

	# Animación en suelo
	if is_on_floor() and jump_state == "none" and not is_diving:
		var dir_input: float = Input.get_axis("move_left", "move_right")
		if is_crouched:
			sprite.play("crouch_walk" if dir_input != 0 else "crouch_idle")
		elif abs(velocity.x) > 10:
			var is_walking_slow: bool = Input.is_action_pressed("run")
			sprite.play("walk" if is_walking_slow else "run")
		else:
			sprite.play("idle")
		sprite.speed_scale = 1.0
		sprite.offset.y = 0.0


func _start_ground_dive() -> void:
	is_diving = true
	_dive_timer = 0.0
	_dive_direction = sign(velocity.x) if velocity.x != 0 else (-1.0 if sprite.flip_h else 1.0)
	velocity.x = dive_speed * _dive_direction
	jump_state = "none"
	_update_collision_shape()
	sprite.play("dive_start")


func _start_air_dive() -> void:
	is_diving = true
	_dive_timer = 0.0
	_dive_direction = (-1.0 if sprite.flip_h else 1.0)
	if abs(velocity.x) > 10:
		_dive_direction = sign(velocity.x)
	# Impulso: mayormente horizontal con boost vertical para potenciar la parábola
	velocity.x = dive_speed * _dive_direction * 0.8
	velocity.y = minf(velocity.y, -400.0)  # garantiza impulso hacia arriba notable
	jump_state = "none"
	_update_collision_shape()
	sprite.play("dive_slide")


func _process_dive(delta: float) -> void:
	# Cancel dive with jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			# Ground: cancel dive → salto directo a airtime
			is_diving = false
			_update_collision_shape()
			_air_jumps_left = max_air_jumps
			velocity.y = jump_velocity_min
			jump_state = "jump_air"
			sprite.play("jump_air")
			return
		elif _air_jumps_left > 0:
			# Air: cancel dive → air jump
			is_diving = false
			_update_collision_shape()
			_air_jumps_left -= 1
			velocity.y = air_jump_velocity
			jump_state = "air_jump_rise"
			sprite.play("air_jump_rise")
			return

	# Gravity still applies if in air
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	_dive_timer += delta

	if sprite.animation == "dive_slide" and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, dive_friction * delta)
		if not Input.is_action_pressed("dive") or _dive_timer >= dive_max_duration or abs(velocity.x) < 10:
			sprite.play("dive_end")


func _on_dive_landed() -> void:
	if Input.is_action_pressed("dive"):
		# Transition to ground slide
		velocity.x = dive_speed * _dive_direction
		_dive_timer = 0.0
		if sprite.animation != "dive_slide":
			sprite.play("dive_slide")
	else:
		sprite.play("dive_end")


func _apply_horizontal_input(in_air: bool) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var is_walking_slow: bool = Input.is_action_pressed("run")  # Shift = andar
	var speed: float
	if is_crouched:
		speed = crouch_walk_speed
	elif is_walking_slow:
		speed = walk_speed
	else:
		speed = run_speed  # DEFAULT = sprint

	if in_air:
		speed *= air_control_factor

	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)


func _update_sprite_direction() -> void:
	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true


func _update_collision_shape() -> void:
	var shape: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if is_crouched or is_diving:
		shape.size.y = 200 * crouch_height_multiplier
		$CollisionShape2D.position.y = (200 * (1.0 - crouch_height_multiplier)) / 2
	else:
		shape.size.y = 200
		$CollisionShape2D.position.y = 0
	queue_redraw()


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func reset_state() -> void:
	jump_state = "none"
	jump_timer = 0.0
	velocity = Vector2.ZERO
	is_crouched = false
	is_diving = false
	_air_jumps_left = 0
	_is_charging_jump = false
	_jump_charge_timer = 0.0
	_dive_timer = 0.0
	_update_collision_shape()
	if is_hidden:
		_unhide()


func is_running_currently() -> bool:
	return not Input.is_action_pressed("run") and abs(velocity.x) > 10


func _try_step_up() -> void:
	if not is_on_wall() or not is_on_floor():
		return
	var dir: float = -1.0 if sprite.flip_h else 1.0
	if test_move(global_transform, Vector2(0, -step_height)):
		return
	var elevated: Transform2D = global_transform
	elevated.origin.y -= step_height
	if test_move(elevated, Vector2(dir * 4.0, 0)):
		return
	position.y -= step_height


func _can_hide() -> bool:
	for guard in GameManager.guards:
		if is_instance_valid(guard) and guard.state == 2:  # State.ALERT
			return false
	return true


func _hide() -> void:
	is_hidden = true
	velocity = Vector2.ZERO
	sprite.modulate.a = 0.35
	collision_layer = 0
	collision_mask = 0


func _unhide() -> void:
	is_hidden = false
	sprite.modulate.a = 1.0
	collision_layer = 1
	collision_mask = 8  # World


func _on_hide_zone_entered(body: Node2D) -> void:
	if body == self:
		_nearby_hide_zones += 1


func _on_hide_zone_exited(body: Node2D) -> void:
	if body == self:
		_nearby_hide_zones -= 1


func _draw() -> void:
	if not DebugOverlay.debug_enabled:
		return
	var col: CollisionShape2D = $CollisionShape2D
	var shape: RectangleShape2D = col.shape as RectangleShape2D
	var half: Vector2 = shape.size / 2.0
	var rect := Rect2(col.position - half, shape.size)
	draw_rect(rect, Color(0, 1, 0, 0.35), true)
	draw_rect(rect, Color(0, 1, 0, 0.8), false, 2.0)
