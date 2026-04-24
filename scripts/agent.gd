extends CharacterBody2D

# ========== ENUMS ==========
enum State {
	PATROL,
	GUARD_STANCE,
	GUARD_BROKEN,
	WINDUP,
	ATTACK_RELEASE,
	PARRY,
	HIT,
	STUNT,
	AIRTIME,
	FLOORSTUNT,
	DEAD
}

# ========== EXPORTS ==========
@export_group("Patrol")
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 240.0
@export var patrol_marker_a: NodePath
@export var patrol_marker_b: NodePath

@export_group("Deteccion")
@export var hearing_radius_walking: float = 250.0
@export var hearing_radius_running: float = 450.0
@export var hearing_radius_idle: float = 80.0
@export var hearing_radius_crouched: float = 1.0

@export_group("Combat")
@export var attack_range_horizontal: float = 120.0
@export var windup_duration: float = 0.8
@export var attack_release_duration: float = 0.2
@export var guard_to_windup_time: float = 0.8
@export var guard_broken_duration: float = 1.6
@export var guard_broken_chance: float = 0.4
@export var stunt_duration: float = 0.8
@export var floorstunt_duration: float = 4.0
@export var kick_push_distance: float = 120.0
@export var kick_push_duration: float = 0.2

@export_group("Gravedad")
@export var gravity: float = 2400.0

# ========== STATE ==========
var state: State = State.PATROL
var state_timer: float = 0.0
var facing_right: bool = true
var current_target: Vector2 = Vector2.ZERO
var going_to_b: bool = true
var kive_ref: Node2D = null
var player_in_light: bool = false
var player_visible: bool = false
var player_heard: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var last_hit_quality: String = "none"

# Flag para push del kick
var _pending_kick_push_velocity: float = 0.0
var _pending_kick_push_frames: int = 0

# Flag para desactivar hitbox en siguiente frame
var _attack_hitbox_active_frames_left: int = 0

# ========== REFS ==========
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_indicator: Label = $StateIndicator
@onready var flashlight_hand: Node2D = $FlashlightHand
@onready var flashlight_system: Node2D = $FlashlightHand/FlashlightSystem
@onready var flashlight_detector: Area2D = $FlashlightHand/FlashlightConeDetector
@onready var hearing_range: Area2D = $HearingRange
@onready var hearing_shape: CollisionShape2D = $HearingRange/HearingShape
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	add_to_group("agent")
	GameManager.register_enemy(self)

	flashlight_detector.body_entered.connect(_on_flashlight_body_entered)
	flashlight_detector.body_exited.connect(_on_flashlight_body_exited)
	hearing_range.body_entered.connect(_on_hearing_body_entered)
	hearing_range.body_exited.connect(_on_hearing_body_exited)
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

	attack_hitbox.monitoring = false

	if patrol_marker_a:
		current_target = get_node(patrol_marker_a).global_position


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Actualizar deteccion
	_update_hearing_radius()
	_update_detection()

	state_timer += delta

	# Desactivar hitbox en siguiente frame si quedaba activo
	if _attack_hitbox_active_frames_left > 0:
		_attack_hitbox_active_frames_left -= 1
		if _attack_hitbox_active_frames_left == 0:
			attack_hitbox.monitoring = false

	# Dispatch por estado
	match state:
		State.PATROL: _process_patrol(delta)
		State.GUARD_STANCE: _process_guard_stance(delta)
		State.GUARD_BROKEN: _process_guard_broken(delta)
		State.WINDUP: _process_windup(delta)
		State.ATTACK_RELEASE: _process_attack_release(delta)
		State.PARRY: _process_parry(delta)
		State.HIT: _process_hit(delta)
		State.STUNT: _process_stunt(delta)
		State.AIRTIME: _process_airtime(delta)
		State.FLOORSTUNT: _process_floorstunt(delta)
		State.DEAD: _process_dead(delta)

	# Aplicar push del kick DESPUES del estado (para que no lo sobreescriba)
	if _pending_kick_push_frames > 0:
		velocity.x = _pending_kick_push_velocity
		_pending_kick_push_frames -= 1
		if _pending_kick_push_frames == 0:
			_pending_kick_push_velocity = 0.0

	move_and_slide()
	_update_visuals()

	queue_redraw()


# ========== DETECCION ==========

func _update_hearing_radius() -> void:
	var radius: float = hearing_radius_idle
	if kive_ref:
		if kive_ref.is_crouched:
			radius = hearing_radius_crouched
		elif abs(kive_ref.velocity.x) > 10:
			if kive_ref.is_running_currently():
				radius = hearing_radius_running
			else:
				radius = hearing_radius_walking
	(hearing_shape.shape as CircleShape2D).radius = max(radius, 1.0)


func _update_detection() -> void:
	if player_in_light and kive_ref:
		var from: Vector2 = flashlight_hand.global_position
		var to: Vector2 = kive_ref.global_position + Vector2(0, -100)
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(from, to, 3)  # Player + Cover
		query.exclude = [get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			player_visible = true
		else:
			player_visible = (result.collider == kive_ref)
	else:
		player_visible = false

	if player_visible or player_heard:
		if kive_ref:
			last_seen_position = kive_ref.global_position


# ========== PATROL ==========

func _process_patrol(_delta: float) -> void:
	var detected: bool = (player_in_light and player_visible) or player_heard
	if kive_ref and kive_ref.is_hidden:
		detected = false

	if detected:
		_enter_state(State.GUARD_STANCE)
		return

	var direction: float = sign(current_target.x - global_position.x)
	velocity.x = direction * patrol_speed
	facing_right = direction >= 0
	sprite.play("walk_patrol")

	if abs(current_target.x - global_position.x) < 5:
		_toggle_patrol_target()


func _toggle_patrol_target() -> void:
	going_to_b = not going_to_b
	current_target = get_node(patrol_marker_b if going_to_b else patrol_marker_a).global_position


# ========== GUARD STANCE ==========

func _process_guard_stance(_delta: float) -> void:
	var detected: bool = (player_in_light and player_visible) or player_heard
	if kive_ref and kive_ref.is_hidden:
		detected = false

	if detected and kive_ref:
		facing_right = kive_ref.global_position.x > global_position.x

	if not detected and state_timer > 2.0:
		_enter_state(State.PATROL)
		_snap_to_closest_marker()
		return

	var in_range: bool = false
	if kive_ref:
		var dist: float = abs(kive_ref.global_position.x - global_position.x)
		in_range = dist < attack_range_horizontal

	if not in_range and kive_ref and detected:
		var direction: float = sign(last_seen_position.x - global_position.x)
		velocity.x = direction * chase_speed
		facing_right = direction >= 0
		sprite.play("walk_guard")
	elif in_range and state_timer >= guard_to_windup_time:
		_enter_state(State.WINDUP)
	else:
		velocity.x = 0
		sprite.play("walk_guard")


func _snap_to_closest_marker() -> void:
	if not patrol_marker_a or not patrol_marker_b:
		return
	var pos_a: Vector2 = get_node(patrol_marker_a).global_position
	var pos_b: Vector2 = get_node(patrol_marker_b).global_position
	if global_position.distance_to(pos_a) < global_position.distance_to(pos_b):
		current_target = pos_a
		going_to_b = true
	else:
		current_target = pos_b
		going_to_b = false


# ========== GUARD BROKEN ==========

func _process_guard_broken(_delta: float) -> void:
	velocity.x = 0
	sprite.play("stunt")

	if state_timer >= guard_broken_duration:
		_enter_state(State.GUARD_STANCE)


# ========== WINDUP Y ATTACK ==========

func _process_windup(_delta: float) -> void:
	velocity.x = 0
	sprite.play("kick_windup")

	if state_timer >= windup_duration:
		_enter_state(State.ATTACK_RELEASE)


func _process_attack_release(_delta: float) -> void:
	velocity.x = 0
	sprite.play("kick_release")

	# Activar hitbox en frame 0 del attack
	if state_timer < 0.05 and not attack_hitbox.monitoring:
		attack_hitbox.monitoring = true

	# Desactivar hitbox a mitad del release
	if state_timer >= attack_release_duration * 0.6 and attack_hitbox.monitoring:
		attack_hitbox.monitoring = false

	if state_timer >= attack_release_duration:
		_enter_state(State.GUARD_STANCE)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("receive_agent_hit"):
		body.receive_agent_hit(self)


# ========== PARRY ==========

func _process_parry(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= 0.3:
		_enter_state(State.GUARD_STANCE)


# ========== ENTER STATE ==========

func _enter_state(new_state: State) -> void:
	state = new_state
	state_timer = 0.0
	if new_state != State.ATTACK_RELEASE:
		attack_hitbox.monitoring = false

	# Flashlight alert mode
	match new_state:
		State.GUARD_STANCE, State.WINDUP, State.ATTACK_RELEASE, State.GUARD_BROKEN:
			flashlight_system.set_alert_mode(true)
		State.PATROL:
			flashlight_system.set_alert_mode(false)
		State.DEAD:
			flashlight_system.set_active(false)

	match new_state:
		State.PARRY:
			sprite.play("parry_1" if randf() < 0.5 else "parry_2")


# ========== VISUALS ==========

func _update_visuals() -> void:
	var flip: bool = not facing_right
	sprite.flip_h = flip
	flashlight_hand.scale.x = -1.0 if flip else 1.0
	flashlight_hand.position.x = -abs(flashlight_hand.position.x) if flip else abs(flashlight_hand.position.x)

	# Linterna activa en PATROL (F4 toggle en debug)
	var flashlight_on: bool = state == State.PATROL and state != State.DEAD
	if DebugOverlay.debug_enabled and not DebugOverlay.show_flashlight_cone:
		flashlight_on = false
	flashlight_system.set_active(flashlight_on)

	state_indicator.text = _get_state_indicator_text()
	state_indicator.modulate = _get_state_color()

	if DebugOverlay.debug_enabled:
		debug_label.text = "[%s] t=%.2f hit=%s" % [State.keys()[state], state_timer, last_hit_quality]


func _get_state_indicator_text() -> String:
	match state:
		State.PATROL: return ""
		State.GUARD_STANCE: return "G"
		State.GUARD_BROKEN: return "!"
		State.WINDUP: return "W"
		State.ATTACK_RELEASE: return "X"
		State.HIT: return "-"
		State.STUNT: return "~"
		State.FLOORSTUNT: return "Z"
		State.DEAD: return "X"
		_: return "?"


func _get_state_color() -> Color:
	match state:
		State.GUARD_STANCE: return Color(0.43, 0.88, 0.94)
		State.GUARD_BROKEN: return Color(1.0, 0.8, 0.3)
		State.WINDUP, State.ATTACK_RELEASE: return Color(1.0, 0.25, 0.125)
		State.STUNT, State.FLOORSTUNT: return Color(0.8, 0.8, 0.8)
		State.DEAD: return Color(0.3, 0.3, 0.3)
		_: return Color(1, 1, 1)


# ========== HIT QUALITY (Fase 7) ==========

func receive_hit_from(attacker: Node2D, is_charged: bool, attack_type: String) -> void:
	if state == State.DEAD or state == State.FLOORSTUNT:
		return

	var quality: String = _calculate_hit_quality(attacker, attack_type)

	# Charged punch sube un nivel
	if is_charged and attack_type == "punch":
		quality = _upgrade_quality(quality)

	last_hit_quality = quality

	# Efectos especificos del kick
	var should_break_guard: bool = false
	var should_force_stunt: bool = false
	var should_push: bool = false

	if attack_type == "kick":
		should_push = true

		# 30% chance de romper guard
		if state == State.GUARD_STANCE:
			if randf() < guard_broken_chance:
				should_break_guard = true

		# Kick por detras -> stunt forzado
		var pos_tier: String = _get_position_tier(attacker)
		if pos_tier == "detras":
			should_force_stunt = true

	# Debug
	if DebugOverlay.debug_enabled:
		print("[Agent hit] type=%s state=%s pos=%s charged=%s -> %s (push=%s, break=%s, stunt=%s)" % [
			attack_type, _get_agent_state_tier(), _get_position_tier(attacker),
			str(is_charged), quality,
			str(should_push), str(should_break_guard), str(should_force_stunt)
		])

	_apply_hit_reaction(quality, should_force_stunt, should_break_guard, should_push, attacker)


func _calculate_hit_quality(attacker: Node2D, attack_type: String) -> String:
	var state_tier: String = _get_agent_state_tier()
	var pos_tier: String = _get_position_tier(attacker)
	var table: Dictionary = _punch_quality_table() if attack_type == "punch" else _kick_quality_table()
	var key: String = "%s_%s" % [state_tier, pos_tier]
	return table.get(key, "mal")


func _get_agent_state_tier() -> String:
	match state:
		State.PATROL: return "desprevenido"
		State.GUARD_STANCE: return "guard"
		State.GUARD_BROKEN: return "broken"
		State.WINDUP: return "windup"
		State.ATTACK_RELEASE: return "release"
		State.STUNT: return "stunt"
		_: return "guard"


func _get_position_tier(attacker: Node2D) -> String:
	var agent_forward: float = 1.0 if facing_right else -1.0
	var to_attacker_x: float = attacker.global_position.x - global_position.x

	if sign(to_attacker_x) != sign(agent_forward) and abs(to_attacker_x) > 30:
		return "detras"
	if abs(to_attacker_x) < 40:
		return "lateral"
	return "frente"


func get_position_tier_of(other: Node2D) -> String:
	return _get_position_tier(other)


func _upgrade_quality(q: String) -> String:
	match q:
		"mal": return "normal"
		"normal": return "bueno"
		"bueno": return "maestro"
		"maestro": return "maestro"
		_: return q


func _punch_quality_table() -> Dictionary:
	return {
		"guard_frente": "mal", "guard_lateral": "mal", "guard_detras": "normal",
		"windup_frente": "normal", "windup_lateral": "normal", "windup_detras": "bueno",
		"release_frente": "bueno", "release_lateral": "bueno", "release_detras": "maestro",
		"stunt_frente": "bueno", "stunt_lateral": "maestro", "stunt_detras": "maestro",
		"broken_frente": "bueno", "broken_lateral": "bueno", "broken_detras": "maestro",
		"desprevenido_frente": "maestro", "desprevenido_lateral": "maestro", "desprevenido_detras": "maestro"
	}


func _kick_quality_table() -> Dictionary:
	return {
		"guard_frente": "mal", "guard_lateral": "mal", "guard_detras": "normal",
		"windup_frente": "normal", "windup_lateral": "normal", "windup_detras": "bueno",
		"release_frente": "bueno", "release_lateral": "bueno", "release_detras": "bueno",
		"stunt_frente": "bueno", "stunt_lateral": "bueno", "stunt_detras": "bueno",
		"broken_frente": "bueno", "broken_lateral": "bueno", "broken_detras": "bueno",
		"desprevenido_frente": "bueno", "desprevenido_lateral": "bueno", "desprevenido_detras": "bueno"
	}


# ========== HIT REACTIONS (Fase 8) ==========

func _apply_hit_reaction(quality: String, force_stunt: bool, break_guard: bool, push: bool, attacker: Node2D) -> void:
	# Push del kick
	if push and attacker:
		var push_dir: float = sign(global_position.x - attacker.global_position.x)
		if push_dir == 0:
			push_dir = 1.0 if attacker.sprite.flip_h else -1.0
		_pending_kick_push_velocity = push_dir * (kick_push_distance / kick_push_duration)
		_pending_kick_push_frames = int(kick_push_duration * 60.0)

	# Guard broken tiene prioridad
	if break_guard:
		_enter_state(State.GUARD_BROKEN)
		sprite.play("hit_light")
		return

	# Marcar stunt forzado por kick-detras
	if force_stunt:
		last_hit_quality = "bueno_forced"

	# Mal = Agent bloquea, muestra parry
	if quality == "mal":
		_enter_state(State.PARRY)
		return

	_enter_state(State.HIT)
	sprite.play("hit_light")


func _process_hit(_delta: float) -> void:
	var hit_duration: float = 0.3

	if state_timer >= hit_duration:
		match last_hit_quality:
			"normal":
				_enter_state(State.GUARD_STANCE)
			"bueno":
				_enter_state(State.STUNT)
				sprite.play("stunt")
			"bueno_forced":
				last_hit_quality = "bueno"
				_enter_state(State.FLOORSTUNT)
				sprite.play("floorstunt")
			"maestro":
				_enter_state(State.AIRTIME)
				sprite.play("airtime")
			_:
				_enter_state(State.GUARD_STANCE)


func _process_stunt(_delta: float) -> void:
	velocity.x = 0
	sprite.play("stunt")
	if state_timer >= stunt_duration:
		if last_hit_quality == "bueno":
			_enter_state(State.FLOORSTUNT)
			sprite.play("floorstunt")
		else:
			_enter_state(State.GUARD_STANCE)


func _process_airtime(_delta: float) -> void:
	if state_timer < 0.05:
		var push_direction: float = 1.0 if facing_right else -1.0
		velocity.x = -push_direction * 400.0
		velocity.y = -500.0
		_trigger_maestro_flash()

	if is_on_floor() and state_timer > 0.2:
		_enter_state(State.DEAD)
		sprite.play("dead")


func _process_floorstunt(_delta: float) -> void:
	velocity.x = 0
	sprite.play("floorstunt")
	if state_timer >= floorstunt_duration:
		_enter_state(State.GUARD_STANCE)


func _process_dead(_delta: float) -> void:
	velocity.x = 0
	sprite.play("dead")
	set_collision_layer_value(3, false)
	attack_hitbox.monitoring = false
	flashlight_system.set_enabled(false)


func _trigger_maestro_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(120, 220)
	flash.position = Vector2(-60, -110)
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func receive_parry() -> void:
	_enter_state(State.STUNT)
	last_hit_quality = "normal"
	attack_hitbox.monitoring = false


# ========== SIGNALS ==========

func _on_flashlight_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		kive_ref = body
		player_in_light = true


func _on_flashlight_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_light = false


func _on_hearing_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		kive_ref = body
		player_heard = true


func _on_hearing_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_heard = false


# ========== RESPAWN HOOK ==========

func reset_to_patrol() -> void:
	state = State.PATROL
	state_timer = 0.0
	player_in_light = false
	player_visible = false
	player_heard = false
	last_hit_quality = "none"
	attack_hitbox.monitoring = false
	if patrol_marker_a:
		global_position = get_node(patrol_marker_a).global_position
	if patrol_marker_b:
		current_target = get_node(patrol_marker_b).global_position
		going_to_b = true


# ========== DEBUG DRAW ==========

func _draw() -> void:
	if not DebugOverlay.debug_enabled or not DebugOverlay.show_hitboxes:
		return

	# Hurtbox azul
	var hurt_shape: RectangleShape2D = $Hurtbox/CollisionShape2D.shape
	draw_rect(Rect2($Hurtbox/CollisionShape2D.position - hurt_shape.size / 2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))

	# Attack hitbox si activo
	if attack_hitbox.monitoring:
		var atk_shape: RectangleShape2D = $AttackHitbox/CollisionShape2D.shape
		var atk_pos: Vector2 = $AttackHitbox.position + $AttackHitbox/CollisionShape2D.position
		if not facing_right:
			atk_pos.x = -atk_pos.x
		draw_rect(Rect2(atk_pos - atk_shape.size / 2, atk_shape.size), Color(1.0, 0.2, 0.2, 0.5))
