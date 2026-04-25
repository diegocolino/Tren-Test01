extends CharacterBody2D

# ========== EXPORTS ==========
@export var walk_speed: float = 400.0
@export var run_speed: float = 800.0
@export var gravity: float = 2400.0
@export var air_control_factor: float = 0.8

@export_group("Double Jump")
@export var max_air_jumps: int = 1
@export var air_jump_velocity: float = -800.0

@export_group("Crouch")
@export var crouch_walk_speed: float = 200.0
@export var crouch_height_multiplier: float = 0.7

@export_group("Charged Jump")
@export var jump_charge_time: float = 0.4
@export var jump_velocity_min: float = -800.0
@export var jump_velocity_max: float = -1200.0

@export_group("Dive")
@export var dive_speed: float = 1200.0
@export var dive_max_duration: float = 1.2
@export var dive_friction: float = 800.0

@export_group("Combat")
@export var attack_charge_time: float = 0.4
@export var attack_charge_time_max: float = 2.4

@export_group("Punch timings")
@export var punch_anticipation: float = 0.08
@export var punch_release: float = 0.15
@export var punch_recovery: float = 0.25

@export_group("Kick timings")
@export var kick_anticipation: float = 0.05
@export var kick_release: float = 0.10
@export var kick_recovery: float = 0.15

@export_group("Parry")
@export var parry_window_frames: int = 40

# ========== CONSTANTS ==========
const step_height: float = 80.0
const anticipation_duration: float = 0.04
const charge_threshold: float = 0.14
const charge_cancel_time: float = 4.0
const default_collision_height: float = 200.0

# ========== STATE ==========
var jump_state: String = "none"
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

# Combat state
var is_attacking: bool = false
var current_attack_type: String = "none"
var is_punch_charging: bool = false
var punch_charge_timer: float = 0.0
var attack_phase: String = "none"
var attack_phase_timer: float = 0.0
var is_punch_charged: bool = false
var _parry_window_timer: float = 999.0

# Hitbox flags (desactivacion deterministica sin await)
var _punch_hitbox_active_frames: int = 0
var _kick_hitbox_active_frames: int = 0

# Execution
var is_finisher: bool = false

# ========== REFERENCES ==========
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# ========== LIFECYCLE ==========

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	sprite.animation_finished.connect(_on_animation_finished)
	# Conectar senales de hitboxes de combate
	$PunchHitbox.body_entered.connect(_on_hitbox_body_entered)
	$KickHitbox.body_entered.connect(_on_hitbox_body_entered)
	# Conectar senales de HideZones
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

	# Desactivar hitboxes de forma deterministica
	_update_hitbox_flags()

	# Ejecucion desde hidden (Q)
	if is_hidden and Input.is_action_just_pressed("attack_kick") and not is_attacking and not is_punch_charging:
		is_crouched = false
		_update_collision_shape()
		is_finisher = true
		current_attack_type = "kick"
		is_punch_charged = false
		_start_attack("kick")

	# Crouch toggle/hold (solo en suelo y sin saltar, sin dive, sin combate)
	if is_on_floor() and jump_state == "none" and not is_diving and not is_attacking and not is_punch_charging:
		if PauseMenu.hold_to_crouch:
			var should_crouch: bool = Input.is_action_pressed("crouch")
			if should_crouch != is_crouched:
				is_crouched = should_crouch
				_update_collision_shape()
		else:
			if Input.is_action_just_pressed("crouch"):
				is_crouched = not is_crouched
				_update_collision_shape()

	# Auto-hide: agachado + en zona safe + suelo = hidden automatico
	if not is_hidden:
		if is_crouched and _nearby_hide_zones > 0 and _can_hide() and is_on_floor() and jump_state == "none":
			_hide()
	elif is_hidden:
		if not is_crouched or _nearby_hide_zones <= 0:
			_unhide()

	# === COMBAT INPUT (antes de cualquier otra logica de movimiento) ===

	# Punch (W)
	if control_enabled and not is_diving and jump_state == "none":
		if Input.is_action_just_pressed("attack_punch") and not is_attacking and not is_punch_charging:
			if is_hidden:
				is_crouched = false
				_update_collision_shape()
				_unhide()
			is_punch_charging = true
			current_attack_type = "punch"
			punch_charge_timer = 0.0
			_parry_window_timer = 0.0  # abre ventana de parry
			velocity.x = 0
			# No cambiar sprite aqui — se decide al soltar W

		elif Input.is_action_pressed("attack_punch") and is_punch_charging:
			punch_charge_timer += delta
			sprite.play("attack_charged_casting")

		elif Input.is_action_just_released("attack_punch") and is_punch_charging:
			is_punch_charging = false
			is_punch_charged = punch_charge_timer >= attack_charge_time
			_start_attack("punch")

		# Auto-release al maximo
		if is_punch_charging and punch_charge_timer >= attack_charge_time_max:
			is_punch_charging = false
			is_punch_charged = true
			_start_attack("punch")

		# Kick (Q) - nunca cargable; desde crouch/hidden = ejecucion
		if Input.is_action_just_pressed("attack_kick") and not is_attacking and not is_punch_charging:
			if is_hidden:
				is_finisher = true
			current_attack_type = "kick"
			is_punch_charged = false
			_start_attack("kick")

	# === BLOQUEO TOTAL DURANTE COMBATE ===
	# Charged punch conserva el impulso del lunge
	if is_punch_charging:
		velocity.x = 0
	elif is_attacking and not (is_punch_charged and current_attack_type == "punch"):
		velocity.x = 0

	# Actualizar ventana de parry
	_parry_window_timer += delta

	# Actualizar attack si esta atacando
	if is_attacking:
		if not is_on_floor():
			velocity.y += gravity * delta
		_process_attack(delta)
		move_and_slide()
		# Charged punch: aterrizaje termina el ataque
		if is_punch_charged and current_attack_type == "punch" and is_on_floor() and attack_phase == "recovery":
			is_attacking = false
			is_punch_charged = false
			current_attack_type = "none"
			attack_phase = "none"
			jump_state = "contact"
			jump_timer = 0.0
			sprite.play("jump_contact")
		_update_sprite_direction()
		queue_redraw()
		if is_attacking:
			return  # saltar el resto del procesamiento de movimiento

	if is_punch_charging:
		move_and_slide()
		_update_sprite_direction()
		queue_redraw()
		return  # bloqueado durante charge tambien

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
		_handle_dive_landing()

	_try_step_up()
	_update_sprite_direction()
	queue_redraw()


# ========== COMBAT ==========

@export_group("Charged Punch Lunge")
@export var charged_lunge_speed_x: float = 2400.0
@export var charged_lunge_speed_y: float = -1200.0


func _start_attack(attack_type: String) -> void:
	is_attacking = true
	current_attack_type = attack_type
	attack_phase = "anticipation"
	attack_phase_timer = 0.0

	# Anticipation sprite + lunge
	if attack_type == "punch" and is_punch_charged:
		sprite.play("attack_charged_airtime")  # frame 14 — puno extendido volando
		# Impulso interpolado: 40% en charge minimo, 100% en charge maximo
		var charge_ratio: float = clampf((punch_charge_timer - attack_charge_time) / (attack_charge_time_max - attack_charge_time), 0.0, 1.0)
		var impulse_factor: float = lerpf(0.4, 1.0, charge_ratio)
		var facing: float = -1.0 if sprite.flip_h else 1.0
		velocity.x = facing * charged_lunge_speed_x * impulse_factor
		velocity.y = charged_lunge_speed_y * impulse_factor
	else:
		sprite.play("idle")  # frames de anticipacion no dibujados aun


func _process_attack(delta: float) -> void:
	attack_phase_timer += delta

	var anticip_dur: float
	var release_dur: float
	var recovery_dur: float

	if current_attack_type == "punch":
		anticip_dur = punch_anticipation
		release_dur = punch_release
		recovery_dur = punch_recovery
	else:
		anticip_dur = kick_anticipation
		release_dur = kick_release
		recovery_dur = kick_recovery

	# Charged punch en el aire: mantener frame 15 y transicionar a precontact
	if is_punch_charged and current_attack_type == "punch" and not is_on_floor():
		if velocity.y > 200:
			# Cayendo rapido → precontact, terminar ataque
			sprite.play("jump_precontact")
			attack_phase = "none"
			is_attacking = false
			is_punch_charged = false
			current_attack_type = "none"
			jump_state = "precontact"
			return
		elif attack_phase == "recovery":
			# Mantener frame 15 durante toda la parabola
			sprite.play("attack_charged_contact")
			return

	match attack_phase:
		"anticipation":
			if attack_phase_timer >= anticip_dur:
				attack_phase = "release"
				attack_phase_timer = 0.0
				# Release sprite — frame de contacto
				if current_attack_type == "punch":
					if is_punch_charged:
						sprite.play("attack_charged_contact")  # frame 15
					else:
						sprite.play("punch_contact")  # frame 3
				else:
					sprite.play("kick_contact")  # frame 7
				_activate_hitbox()

		"release":
			if attack_phase_timer >= release_dur:
				attack_phase = "recovery"
				attack_phase_timer = 0.0
				if not (current_attack_type == "punch" and is_punch_charged):
					sprite.play("idle")  # recovery normal

		"recovery":
			if current_attack_type == "punch" and is_punch_charged:
				pass  # charged punch: se queda en el aire, gestionado arriba
			elif attack_phase_timer >= recovery_dur:
				attack_phase = "none"
				is_attacking = false
				is_finisher = false
				is_punch_charged = false
				current_attack_type = "none"


func _activate_hitbox() -> void:
	var facing: float = -1.0 if sprite.flip_h else 1.0

	var hitbox: Area2D
	if current_attack_type == "punch":
		hitbox = $PunchHitbox
		hitbox.position = Vector2(facing * 60, -50)
		_punch_hitbox_active_frames = 3
	else:
		hitbox = $KickHitbox
		hitbox.position = Vector2(facing * 70, -30)
		_kick_hitbox_active_frames = 3

	hitbox.monitoring = true


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not is_attacking or attack_phase != "release":
		return
	if body.is_in_group("agent"):
		if is_finisher and body.has_method("receive_execution"):
			body.receive_execution(self)
		elif body.has_method("receive_hit_from"):
			body.receive_hit_from(self, is_punch_charged, current_attack_type)


func _update_hitbox_flags() -> void:
	if _punch_hitbox_active_frames > 0:
		_punch_hitbox_active_frames -= 1
		if _punch_hitbox_active_frames == 0:
			$PunchHitbox.monitoring = false

	if _kick_hitbox_active_frames > 0:
		_kick_hitbox_active_frames -= 1
		if _kick_hitbox_active_frames == 0:
			$KickHitbox.monitoring = false


func is_parry_window_active() -> bool:
	return _parry_window_timer <= (parry_window_frames / 60.0)



func get_charge_ratio() -> float:
	if not is_punch_charged:
		return 0.0
	return clampf((punch_charge_timer - attack_charge_time) / (attack_charge_time_max - attack_charge_time), 0.0, 1.0)


# ========== PARRY / DAMAGE (Fase 9) ==========

func receive_agent_hit(agent: Node2D) -> void:
	if DebugOverlay.show_debug_text:
		print("[Kive hit] parry_timer=%.3f window=%.3f parry=%s" % [
			_parry_window_timer, parry_window_frames / 60.0, str(is_parry_window_active())
		])

	if is_parry_window_active():
		_resolve_parry(agent)
		return

	_receive_damage(agent)


func _resolve_parry(agent: Node2D) -> void:
	if agent.has_method("receive_parry"):
		agent.receive_parry()

	_trigger_parry_flash()
	_parry_window_timer = 999.0  # cerrar ventana


func _trigger_parry_flash() -> void:
	sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)


func _receive_damage(_agent: Node2D) -> void:
	sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	await get_tree().create_timer(0.3).timeout
	GameManager.player_caught()


# ========== JUMP / AIR STATES ==========

func _process_anticipation(delta: float) -> void:
	jump_timer += delta
	velocity.x = 0
	velocity.y = 0

	if jump_timer >= anticipation_duration:
		if Input.is_action_pressed("jump"):
			_jump_charge_timer += delta
			if _jump_charge_timer >= charge_cancel_time:
				_cancel_charged_jump()
			elif _jump_charge_timer >= charge_threshold:
				_is_charging_jump = true
				sprite.frame = 1
				sprite.pause()
		else:
			_release_jump()


func _release_jump() -> void:
	sprite.play()
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
		jump_state = "precontact"
		sprite.play("jump_precontact")
	else:
		jump_state = "jump_air"
		sprite.play("jump_air")


func _cancel_charged_jump() -> void:
	sprite.play()
	_is_charging_jump = false
	_jump_charge_timer = 0.0
	_was_moving_at_jump = false
	jump_state = "recovery"
	sprite.play("jump_recovery")


func _process_landing(delta: float) -> void:
	jump_timer += delta
	_apply_horizontal_input(false)


# ========== MOVEMENT ==========

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
			velocity.y = jump_velocity_min
			jump_state = "jump_air"
			sprite.play("jump_air")
		else:
			jump_state = "anticipation"
			jump_timer = 0.0
			_is_charging_jump = false
			_jump_charge_timer = 0.0
			sprite.play("jump_anticipation")
		return

	# Air jump
	if Input.is_action_just_pressed("jump") and not is_on_floor() and _air_jumps_left > 0:
		if is_diving:
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
			and not Input.is_action_pressed("run"):
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

	# Caida sin salto
	if not is_on_floor() and jump_state == "none":
		jump_state = "jump_air"
		sprite.play("jump_air")

	# Actualizar estado aereo
	if not is_on_floor() and jump_state in ["jump_air", "air_jump_rise", "air_jump_fall", "precontact"]:
		if jump_state in ["air_jump_rise", "air_jump_fall"]:
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
			if velocity.y > 200:
				if jump_state != "precontact":
					jump_state = "precontact"
					sprite.play("jump_precontact")
		return

	# Animacion en suelo
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


# ========== DIVE ==========

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
	velocity.x = dive_speed * _dive_direction * 0.8
	velocity.y = minf(velocity.y, -400.0)
	jump_state = "none"
	_update_collision_shape()
	sprite.play("dive_slide")


func _process_dive(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			is_diving = false
			_update_collision_shape()
			_air_jumps_left = max_air_jumps
			velocity.y = jump_velocity_min
			jump_state = "jump_air"
			sprite.play("jump_air")
			return
		elif _air_jumps_left > 0:
			is_diving = false
			_update_collision_shape()
			_air_jumps_left -= 1
			velocity.y = air_jump_velocity
			jump_state = "air_jump_rise"
			sprite.play("air_jump_rise")
			return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	_dive_timer += delta

	if sprite.animation == "dive_slide" and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, dive_friction * delta)
		if not Input.is_action_pressed("dive") or _dive_timer >= dive_max_duration or abs(velocity.x) < 10:
			sprite.play("dive_end")


func _handle_dive_landing() -> void:
	if Input.is_action_pressed("dive"):
		velocity.x = dive_speed * _dive_direction
		_dive_timer = 0.0
		if sprite.animation != "dive_slide":
			sprite.play("dive_slide")
	else:
		sprite.play("dive_end")


func _apply_horizontal_input(in_air: bool) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var is_walking_slow: bool = Input.is_action_pressed("run")
	var speed: float
	if is_crouched:
		speed = crouch_walk_speed
	elif is_walking_slow:
		speed = walk_speed
	else:
		speed = run_speed

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


# ========== CROUCH / HIDE ==========

func _update_collision_shape() -> void:
	var shape: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if is_crouched or is_diving:
		shape.size.y = default_collision_height * crouch_height_multiplier
		$CollisionShape2D.position.y = (default_collision_height * (1.0 - crouch_height_multiplier)) / 2
	else:
		shape.size.y = default_collision_height
		$CollisionShape2D.position.y = 0
	queue_redraw()


# ========== PUBLIC API ==========

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		is_attacking = false
		is_punch_charging = false
		attack_phase = "none"
		current_attack_type = "none"


func reset_state() -> void:
	jump_state = "none"
	jump_timer = 0.0
	velocity = Vector2.ZERO
	is_crouched = false
	is_diving = false
	is_attacking = false
	is_punch_charging = false
	punch_charge_timer = 0.0
	attack_phase = "none"
	attack_phase_timer = 0.0
	is_punch_charged = false
	current_attack_type = "none"
	_parry_window_timer = 999.0
	_punch_hitbox_active_frames = 0
	_kick_hitbox_active_frames = 0
	is_finisher = false
	_air_jumps_left = 0
	_is_charging_jump = false
	_jump_charge_timer = 0.0
	_dive_timer = 0.0
	_was_moving_at_jump = false
	_update_collision_shape()
	if is_hidden:
		_unhide()


func is_sprinting() -> bool:
	return not Input.is_action_pressed("run") and abs(velocity.x) > 10


func _try_step_up() -> void:
	if not is_on_wall() or not is_on_floor():
		return
	var dir: float = -1.0 if sprite.flip_h else 1.0
	for step: int in range(1, int(step_height / 4.0) + 1):
		var lift: float = step * 4.0
		if test_move(global_transform, Vector2(0, -lift)):
			return
		var elevated: Transform2D = global_transform
		elevated.origin.y -= lift
		if not test_move(elevated, Vector2(dir * 4.0, 0)):
			position.y -= lift
			return


func _can_hide() -> bool:
	for enemy: Node in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_position_tier_of"):
			if enemy.state in [enemy.State.DEAD, enemy.State.KO, enemy.State.PATROL, enemy.State.ALERT]:
				continue
			return false
	return true


func _hide() -> void:
	is_hidden = true
	sprite.modulate.a = 0.35


func _unhide() -> void:
	is_hidden = false
	sprite.modulate.a = 1.0


# ========== SIGNALS ==========

func _on_hide_zone_entered(body: Node2D) -> void:
	if body == self:
		_nearby_hide_zones += 1


func _on_hide_zone_exited(body: Node2D) -> void:
	if body == self:
		_nearby_hide_zones -= 1


# ========== DEBUG ==========

func _draw() -> void:
	if not DebugOverlay.show_hitboxes:
		return

	# Hurtbox azul
	var hurt_shape: RectangleShape2D = $Hurtbox/CollisionShape2D.shape
	var hurt_pos: Vector2 = $Hurtbox.position + $Hurtbox/CollisionShape2D.position
	draw_rect(Rect2(hurt_pos - hurt_shape.size / 2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))

	# Punch hitbox rojo
	if $PunchHitbox.monitoring:
		var p_shape: RectangleShape2D = $PunchHitbox/CollisionShape2D.shape
		var p_pos: Vector2 = $PunchHitbox.position + $PunchHitbox/CollisionShape2D.position
		draw_rect(Rect2(p_pos - p_shape.size / 2, p_shape.size), Color(1.0, 0.2, 0.2, 0.5))

	# Kick hitbox naranja
	if $KickHitbox.monitoring:
		var k_shape: RectangleShape2D = $KickHitbox/CollisionShape2D.shape
		var k_pos: Vector2 = $KickHitbox.position + $KickHitbox/CollisionShape2D.position
		draw_rect(Rect2(k_pos - k_shape.size / 2, k_shape.size), Color(1.0, 0.5, 0.0, 0.5))
