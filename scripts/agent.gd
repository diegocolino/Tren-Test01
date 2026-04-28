extends CharacterBody2D

# ========== ENUMS ==========
enum AgentState {
	PATROL,
	ALERT,
	GUARD_STANCE,
	WINDUP,
	ATTACK_RELEASE,
	ATTACK_RECOVERY,
	PARRY,
	HIT,
	STUNT,
	AIRTIME,
	KO,
	DEAD,
	FALLEN
}

# ========== EXPORTS ==========
@export_group("Patrol")
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 240.0
@export var patrol_marker_a: NodePath
@export var patrol_marker_b: NodePath

@export_group("Deteccion")
@export var hearing_radius_walking: float = 400.0
@export var hearing_radius_running: float = 1600.0
@export var hearing_radius_idle: float = 40.0
@export var hearing_radius_crouched: float = 4.0
@export var movement_detect_threshold: float = 10.0
@export var turn_reaction_time: float = 0.4

@export_group("Vision")
@export var vision_cone_angle: float = 70.0
@export var vision_cone_range: float = 600.0

@export_group("Alert")
@export var alert_lose_detection_time: float = 4.0

@export_group("Combat")
@export var attack_range_horizontal: float = 170.0
@export var ideal_combat_distance: float = 110.0
@export var combat_distance_tolerance: float = 30.0
@export var guard_walk_speed: float = 120.0
@export var guard_min_attack_delay: float = 2.0
@export var guard_max_attack_delay: float = 2.5
@export var windup_duration: float = 0.6
@export var attack_release_duration: float = 0.2
@export var attack_recovery_duration: float = 0.5
@export var stunt_duration: float = 2.0
@export var ko_duration: float = 3.0
@export var fallen_duration: float = 1.5
@export var fallen_knockback_duration: float = 0.3
@export var kick_push_distance: float = 120.0
@export var kick_push_duration: float = 0.2
@export var parry_duration: float = 0.3
@export var hit_reaction_duration: float = 0.3
@export var guard_exit_hysteresis: float = 1.5
@export var attack_hitbox_linger: float = 0.6

@export_group("Dive Knockback")
@export var dive_ground_knockback_vertical: float = 600.0
@export var dive_ground_knockback_horizontal: float = 200.0
@export var dive_air_knockback_horizontal: float = 800.0
@export var dive_air_knockback_vertical: float = 200.0

@export_group("Airtime")
@export var airtime_push_horizontal: float = 400.0
@export var airtime_push_vertical: float = 500.0

@export_group("Posicion")
@export var behind_threshold: float = 30.0

@export_group("Maestro Flash")
@export var maestro_flash_duration: float = 0.3
@export var maestro_flash_alpha: float = 0.8

@export_group("Gravedad")
@export var gravity: float = 2400.0

const step_height: float = 80.0

# ========== STATE ==========
var state: AgentState = AgentState.PATROL
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
var player_in_vision: bool = false
var _turn_cooldown: float = 0.0

# Guard pacing
var _guard_attack_delay: float = 3.0
var _ko_type: String = "normal"
var _airtime_kill_on_land: bool = true  # true = Uppercut (W=DEATH), false = air_launch (Q=KO)

# Animation chain system
var _anim_queue: Array[String] = []

# Flag para push del kick
var _pending_kick_push_velocity: float = 0.0
var _pending_kick_push_frames: int = 0
var _fallen_knockback_frames: int = 0

# Intro musical
var _waiting_for_intro: bool = true

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

	var music_node: Node = null
	await get_tree().process_frame
	music_node = get_tree().current_scene.get_node_or_null("KiveMusic")
	if music_node and music_node.has_signal("intro_finished"):
		music_node.intro_finished.connect(_on_intro_finished)


func _physics_process(delta: float) -> void:
	if not kive_ref:
		kive_ref = GameManager.kive_ref

	if not is_on_floor():
		velocity.y += gravity * delta

	_update_hearing_radius()
	_update_vision()
	_update_detection()

	if _turn_cooldown > 0.0:
		_turn_cooldown -= delta

	state_timer += delta

	match state:
		AgentState.PATROL: _process_patrol(delta)
		AgentState.ALERT: _process_alert(delta)
		AgentState.GUARD_STANCE: _process_guard_stance(delta)
		AgentState.WINDUP: _process_windup(delta)
		AgentState.ATTACK_RELEASE: _process_attack_release(delta)
		AgentState.ATTACK_RECOVERY: _process_attack_recovery(delta)
		AgentState.PARRY: _process_parry(delta)
		AgentState.HIT: _process_hit(delta)
		AgentState.STUNT: _process_stunt(delta)
		AgentState.AIRTIME: _process_airtime(delta)
		AgentState.KO: _process_ko(delta)
		AgentState.DEAD: _process_dead(delta)
		AgentState.FALLEN: _process_fallen(delta)

	if _pending_kick_push_frames > 0:
		velocity.x = _pending_kick_push_velocity
		_pending_kick_push_frames -= 1
		if _pending_kick_push_frames == 0:
			_pending_kick_push_velocity = 0.0

	move_and_slide()
	_try_step_up()
	_update_visuals()

	queue_redraw()


func _try_step_up() -> void:
	if not is_on_wall() or not is_on_floor():
		return
	var dir: float = 1.0 if facing_right else -1.0
	for step: int in range(1, int(step_height / 4.0) + 1):
		var lift: float = step * 4.0
		if test_move(global_transform, Vector2(0, -lift)):
			return
		var elevated: Transform2D = global_transform
		elevated.origin.y -= lift
		if not test_move(elevated, Vector2(dir * 4.0, 0)):
			position.y -= lift
			return


# ========== DETECCION ==========

func _update_hearing_radius() -> void:
	var radius: float = hearing_radius_idle
	if kive_ref:
		if kive_ref.is_crouched:
			radius = hearing_radius_crouched
		elif abs(kive_ref.velocity.x) > movement_detect_threshold:
			if kive_ref.is_sprinting():
				radius = hearing_radius_running
			else:
				radius = hearing_radius_walking
	(hearing_shape.shape as CircleShape2D).radius = max(radius, 1.0)


func _update_vision() -> void:
	player_in_vision = false
	if not kive_ref:
		return
	if kive_ref.is_hidden:
		return

	var eye_pos: Vector2 = global_position + Vector2(0, -100)
	var kive_torso: Vector2 = kive_ref.global_position + Vector2(0, -100)
	var to_kive: Vector2 = kive_torso - eye_pos
	var dist: float = to_kive.length()
	if dist > vision_cone_range:
		return

	var facing_dir: Vector2 = Vector2(1.0 if facing_right else -1.0, 0.0)
	var angle: float = rad_to_deg(facing_dir.angle_to(to_kive.normalized()))
	if absf(angle) > vision_cone_angle:
		return

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		eye_pos,
		kive_torso,
		3
	)
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty() or result.collider == kive_ref:
		player_in_vision = true


func _update_detection() -> void:
	if kive_ref and kive_ref.is_hidden:
		player_visible = false
		last_seen_position = Vector2.ZERO
		return
	if player_in_light and kive_ref:
		var from: Vector2 = flashlight_hand.global_position
		var to: Vector2 = kive_ref.global_position + Vector2(0, -100)
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(from, to, 3)
		query.exclude = [get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			player_visible = true
		else:
			player_visible = (result.collider == kive_ref)
	else:
		player_visible = false

	if player_visible or player_heard or player_in_vision:
		if kive_ref:
			last_seen_position = kive_ref.global_position


# ========== PATROL ==========

func _try_face_kive() -> void:
	if not kive_ref:
		return
	var should_face_right: bool = kive_ref.global_position.x > global_position.x
	if should_face_right != facing_right:
		if _turn_cooldown <= 0.0:
			facing_right = should_face_right
			_turn_cooldown = turn_reaction_time


func _is_detected() -> bool:
	var detected: bool = player_in_vision or (player_in_light and player_visible) or player_heard
	if kive_ref and kive_ref.is_hidden:
		detected = false
	return detected


func _process_patrol(_delta: float) -> void:
	if _waiting_for_intro:
		velocity.x = 0
		sprite.play("idle")
		return

	var detected: bool = _is_detected()

	if detected:
		_enter_state(AgentState.ALERT)
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


# ========== ALERT ==========

func _process_alert(_delta: float) -> void:
	if _waiting_for_intro:
		velocity.x = 0
		sprite.play("idle")
		return

	var detected: bool = _is_detected()

	if detected and kive_ref:
		_try_face_kive()
		state_timer = 0.0

	if not detected and state_timer > alert_lose_detection_time:
		_enter_state(AgentState.PATROL)
		_snap_to_closest_marker()
		return

	var in_range: bool = false
	if kive_ref:
		var dist: float = abs(kive_ref.global_position.x - global_position.x)
		in_range = dist < attack_range_horizontal

	if in_range and not (kive_ref and kive_ref.is_hidden):
		_enter_state(AgentState.GUARD_STANCE)
		return

	if kive_ref and (detected or last_seen_position != Vector2.ZERO):
		var target_x: float = kive_ref.global_position.x if detected else last_seen_position.x
		var dist_to_target: float = abs(target_x - global_position.x)
		if dist_to_target > 5.0:
			var direction: float = sign(target_x - global_position.x)
			velocity.x = direction * chase_speed
			var should_face: bool = direction >= 0
			if should_face != facing_right and _turn_cooldown <= 0.0:
				facing_right = should_face
				_turn_cooldown = turn_reaction_time
			sprite.play("run_patrol")
		else:
			velocity.x = 0
			sprite.play("idle")
	else:
		var dir: float = 1.0 if facing_right else -1.0
		velocity.x = dir * chase_speed
		sprite.play("run_patrol")


# ========== GUARD STANCE (pacing) ==========

func _process_guard_stance(_delta: float) -> void:
	var detected: bool = _is_detected()

	if detected and kive_ref:
		_try_face_kive()

	if not detected and kive_ref and kive_ref.is_hidden:
		_enter_state(AgentState.ALERT)
		return

	var in_range: bool = false
	var dist: float = 0.0
	if kive_ref:
		dist = abs(kive_ref.global_position.x - global_position.x)
		in_range = dist < attack_range_horizontal * guard_exit_hysteresis

	if not in_range:
		_enter_state(AgentState.ALERT)
		return

	# Ataque oportunista: Kive está encima, reaccionar rápido
	if kive_ref and dist < 80.0 and state_timer >= 0.4:
		_enter_state(AgentState.WINDUP)
		return

	# Bobbing: perseguir distancia ideal con offset sinusoidal
	if kive_ref:
		var bob_period: float = 1.2
		var bob_offset: float = sin(state_timer * TAU / bob_period) * 25.0
		var target_dist: float = ideal_combat_distance + bob_offset
		var toward_kive: float = sign(kive_ref.global_position.x - global_position.x)
		var dist_error: float = dist - target_dist

		if abs(dist_error) > 10.0:
			velocity.x = toward_kive * guard_walk_speed * signf(dist_error)
		else:
			velocity.x = toward_kive * guard_walk_speed * 0.3 * signf(bob_offset)
		sprite.play("walk_guard")
	else:
		velocity.x = 0
		sprite.play("guard_idle")

	if state_timer >= _guard_attack_delay:
		if kive_ref:
			var attack_dist: float = abs(kive_ref.global_position.x - global_position.x)
			if attack_dist <= 150.0:
				_enter_state(AgentState.WINDUP)
			else:
				state_timer = _guard_attack_delay * 0.7  # reintentar rápido
		else:
			_enter_state(AgentState.WINDUP)


func _return_to_combat_ready() -> void:
	if kive_ref and kive_ref.is_hidden:
		_enter_state(AgentState.ALERT)
		return
	var in_range: bool = false
	if kive_ref:
		var dist: float = abs(kive_ref.global_position.x - global_position.x)
		in_range = dist < attack_range_horizontal * guard_exit_hysteresis
	if in_range:
		_enter_state(AgentState.GUARD_STANCE)
		# Contraataque rápido: delay corto tras recibir un golpe
		_guard_attack_delay = randf_range(0.4, 0.8)
	else:
		_enter_state(AgentState.ALERT)


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


# ========== WINDUP Y ATTACK ==========

func _process_windup(_delta: float) -> void:
	# Rush hacia Kive durante windup
	if kive_ref:
		var rush_dir: float = sign(kive_ref.global_position.x - global_position.x)
		velocity.x = rush_dir * 200.0
	else:
		var lunge_dir: float = 1.0 if facing_right else -1.0
		velocity.x = lunge_dir * 200.0
	sprite.play("windup")

	if state_timer >= windup_duration:
		_enter_state(AgentState.ATTACK_RELEASE)


func _process_attack_release(_delta: float) -> void:
	if state_timer < 0.1:
		if kive_ref:
			var burst_dir: float = sign(kive_ref.global_position.x - global_position.x)
			velocity.x = burst_dir * 180.0
		else:
			var lunge_dir: float = 1.0 if facing_right else -1.0
			velocity.x = lunge_dir * 180.0
	else:
		velocity.x = 0
	sprite.play("attack_release")

	if state_timer < 0.05 and not attack_hitbox.monitoring:
		attack_hitbox.monitoring = true

	if state_timer >= attack_release_duration * attack_hitbox_linger and attack_hitbox.monitoring:
		attack_hitbox.monitoring = false

	if state_timer >= attack_release_duration:
		_enter_state(AgentState.ATTACK_RECOVERY)


func _process_attack_recovery(_delta: float) -> void:
	# Retroceder tras golpear
	var retreat_dir: float = -1.0 if facing_right else 1.0
	velocity.x = retreat_dir * guard_walk_speed * 1.2
	sprite.play("attack_recovery")

	if state_timer >= attack_recovery_duration:
		_return_to_combat_ready()


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("receive_agent_hit"):
		if body.is_hidden:
			return
		body.receive_agent_hit(self)


# ========== PARRY ==========

func _process_parry(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= parry_duration:
		_return_to_combat_ready()


# ========== ENTER STATE ==========

func _enter_state(new_state: AgentState) -> void:
	# Clear animation chain on state change
	_anim_queue.clear()
	if sprite.animation_finished.is_connected(_advance_anim_chain):
		sprite.animation_finished.disconnect(_advance_anim_chain)

	state = new_state
	state_timer = 0.0
	if new_state != AgentState.ATTACK_RELEASE:
		attack_hitbox.monitoring = false

	# Flashlight alert mode
	match new_state:
		AgentState.ALERT, AgentState.GUARD_STANCE, AgentState.WINDUP, AgentState.ATTACK_RELEASE, AgentState.ATTACK_RECOVERY:
			flashlight_system.set_alert_mode(true)
		AgentState.PATROL:
			flashlight_system.set_alert_mode(false)
		AgentState.DEAD:
			flashlight_system.set_active(false)
			set_collision_layer_value(3, false)
			attack_hitbox.monitoring = false

	# Alarm lights
	var alarm_state: String = "patrol"
	match new_state:
		AgentState.GUARD_STANCE, AgentState.WINDUP, AgentState.ATTACK_RELEASE, \
		AgentState.ATTACK_RECOVERY, AgentState.HIT, AgentState.STUNT, AgentState.AIRTIME, AgentState.KO:
			alarm_state = "combat"
		AgentState.ALERT:
			alarm_state = "alert"
	get_tree().call_group("alarm_light", "set_alarm_state", alarm_state)

	match new_state:
		AgentState.PARRY:
			sprite.play("parry_1" if randf() < 0.5 else "parry_2")
		AgentState.GUARD_STANCE:
			_guard_attack_delay = randf_range(guard_min_attack_delay, guard_max_attack_delay)


# ========== VISUALS ==========

func _update_visuals() -> void:
	var flip: bool = not facing_right
	sprite.flip_h = flip
	flashlight_hand.scale.x = -1.0 if flip else 1.0
	flashlight_hand.position.x = -abs(flashlight_hand.position.x) if flip else abs(flashlight_hand.position.x)

	var flashlight_on: bool = (state == AgentState.PATROL or state == AgentState.ALERT) and state != AgentState.DEAD
	flashlight_system.set_active(flashlight_on)

	state_indicator.visible = DebugOverlay.show_debug_text
	if DebugOverlay.show_debug_text:
		state_indicator.text = _get_state_indicator_text()
		state_indicator.modulate = _get_state_color()

	debug_label.visible = DebugOverlay.show_debug_text
	if DebugOverlay.show_debug_text:
		debug_label.text = "[%s] t=%.2f hit=%s" % [AgentState.keys()[state], state_timer, last_hit_quality]


func _get_state_indicator_text() -> String:
	match state:
		AgentState.PATROL: return ""
		AgentState.ALERT: return "A"
		AgentState.GUARD_STANCE: return "G"
		AgentState.WINDUP: return "W"
		AgentState.ATTACK_RELEASE: return "X"
		AgentState.ATTACK_RECOVERY: return "R"
		AgentState.HIT: return "-"
		AgentState.PARRY: return "P"
		AgentState.STUNT: return "~"
		AgentState.AIRTIME: return "^"
		AgentState.KO: return "K"
		AgentState.DEAD: return "X"
		_: return "?"


func _get_state_color() -> Color:
	match state:
		AgentState.ALERT: return Color(1.0, 0.6, 0.0)
		AgentState.GUARD_STANCE: return Color(0.43, 0.88, 0.94)
		AgentState.WINDUP, AgentState.ATTACK_RELEASE: return Color(1.0, 0.25, 0.125)
		AgentState.ATTACK_RECOVERY: return Color(1.0, 0.5, 0.3)
		AgentState.STUNT: return Color(0.8, 0.8, 0.8)
		AgentState.KO: return Color(0.6, 0.4, 0.2)
		AgentState.DEAD: return Color(0.3, 0.3, 0.3)
		_: return Color(1, 1, 1)


# ========== ANIMATION CHAIN SYSTEM ==========

func _play_anim_chain(chain: Array[String]) -> void:
	_anim_queue = chain.duplicate()
	_advance_anim_chain()


func _advance_anim_chain() -> void:
	if _anim_queue.is_empty():
		return
	var next: String = _anim_queue.pop_front()
	sprite.play(next)
	if not _anim_queue.is_empty():
		if not sprite.animation_finished.is_connected(_advance_anim_chain):
			sprite.animation_finished.connect(_advance_anim_chain, CONNECT_ONE_SHOT)


# ========== HIT RESOLUTION ==========

func receive_hit_from(attacker: Node2D, hit_type: String) -> void:
	# DEAD: only Q pushes the body. W ignored (gore mechanic reserved for V2).
	if state == AgentState.DEAD:
		if hit_type in ["frontal", "stunt_pie", "ko_suelo", "air_launch"]:
			_apply_kick_push(attacker)
			if DebugOverlay.show_debug_text:
				print("[Agent] Q PUSH on DEAD body | hit_type=%s" % hit_type)
		return

	# Turn towards attacker
	if attacker:
		facing_right = attacker.global_position.x > global_position.x
		_turn_cooldown = 0.0

	if hit_type in ["frontal", "stunt_pie", "ko_suelo", "air_launch"]:
		var pos_tier: String = _get_position_tier(attacker)
		_resolve_q_hit(hit_type, pos_tier, attacker)
	else:
		_resolve_w_hit(hit_type, attacker)


func _resolve_w_hit(hit_type: String, attacker: Node2D) -> void:
	# Kill selectiva: STUNT/KO/AIRTIME + any W = DEAD
	if state in [AgentState.STUNT, AgentState.KO, AgentState.AIRTIME]:
		if DebugOverlay.show_debug_text:
			print("[Agent] _resolve_w_hit KILL from vulnerable state | state=%s | hit=%s" % [
				AgentState.keys()[state], hit_type])
		last_hit_quality = "kill"
		_enter_state(AgentState.DEAD)
		sprite.play("dead")
		return

	var is_vulnerable: bool = state in [AgentState.WINDUP, AgentState.ATTACK_RELEASE, \
		AgentState.ATTACK_RECOVERY, AgentState.STUNT, AgentState.HIT, AgentState.PATROL]

	# Uppercut (W4): AIRTIME → DEAD on landing, independent of guard
	if hit_type == "uppercut":
		last_hit_quality = "maestro"
		_airtime_kill_on_land = true
		_enter_state(AgentState.AIRTIME)
		sprite.play("airtime")
		if attacker and attacker.has_method("open_sensible_window"):
			attacker.open_sensible_window(self)
		return

	# Cross (W2) / Hook (W3): DEAD if vulnerable, HIT if guard
	if hit_type in ["cross", "hook"]:
		if is_vulnerable:
			last_hit_quality = "golpe_bueno"
			_ko_type = "golpe_bueno"
			_enter_state(AgentState.KO)
			_play_golpe_bueno_sequence(attacker)
			return
		# Guard or other non-vulnerable → HIT ligero
		last_hit_quality = "hit"
		_enter_state(AgentState.HIT)
		sprite.play("hit_light")
		return

	# Jab (W1) and fallback: HIT ligero always
	last_hit_quality = "hit"
	_enter_state(AgentState.HIT)
	sprite.play("hit_light")


func _resolve_q_hit(hit_type: String, pos_tier: String, attacker: Node2D) -> void:
	if DebugOverlay.show_debug_text:
		print("[Agent] _resolve_q_hit | hit_type=%s | pos_tier=%s | state=%s" % [
			hit_type, pos_tier, AgentState.keys()[state]])

	match hit_type:
		"frontal":
			last_hit_quality = "push"
			_apply_kick_push(attacker)

		"stunt_pie":
			last_hit_quality = "stunt_pie"
			_apply_kick_push(attacker)
			_enter_state(AgentState.STUNT)
			sprite.play("stunt")

		"ko_suelo":
			last_hit_quality = "ko_suelo"
			_ko_type = "normal"
			_apply_kick_push(attacker)
			_enter_state(AgentState.KO)
			_play_ko_sequence()

		"air_launch":
			last_hit_quality = "air_launch"
			_airtime_kill_on_land = false
			_enter_state(AgentState.AIRTIME)
			sprite.play("airtime")
			if attacker and attacker.has_method("open_sensible_window"):
				attacker.open_sensible_window(self)

		_:
			push_warning("Unknown q hit_type: %s" % hit_type)
			last_hit_quality = "push"
			_apply_kick_push(attacker)


func _apply_kick_push(attacker: Node2D) -> void:
	if not attacker:
		return
	var push_dir: float = sign(global_position.x - attacker.global_position.x)
	if push_dir == 0:
		push_dir = 1.0 if facing_right else -1.0
	_pending_kick_push_velocity = push_dir * (kick_push_distance / kick_push_duration)
	_pending_kick_push_frames = int(kick_push_duration * 60.0)


func _get_position_tier(attacker: Node2D) -> String:
	var agent_forward: float = 1.0 if facing_right else -1.0
	var to_attacker_x: float = attacker.global_position.x - global_position.x

	if sign(to_attacker_x) != sign(agent_forward) and abs(to_attacker_x) > behind_threshold:
		return "detras"
	return "frente"


func get_position_tier_of(other: Node2D) -> String:
	return _get_position_tier(other)


func is_dash_target() -> bool:
	return state != AgentState.DEAD


# ========== ANIMATION SEQUENCES ==========

func _play_stunt_entry() -> void:
	_play_anim_chain(["hit_light", "stunt"])


func _play_ko_sequence() -> void:
	_play_anim_chain(["stunt", "ko_floor"])


func _play_golpe_bueno_sequence(attacker: Node2D) -> void:
	var push_dir: float = sign(global_position.x - attacker.global_position.x)
	if push_dir == 0:
		push_dir = 1.0
	velocity.x = push_dir * airtime_push_horizontal * 0.4
	velocity.y = -airtime_push_vertical * 0.3
	_play_anim_chain(["hit_light", "airtime", "ko_floor"])


# ========== HIT / STUNT / KO / AIRTIME STATES ==========

func _process_hit(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= hit_reaction_duration:
		_return_to_combat_ready()


func _process_stunt(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= stunt_duration:
		_play_anim_chain(["stunt_recover"])
		sprite.animation_finished.connect(func() -> void: _return_to_combat_ready(), CONNECT_ONE_SHOT)
		# Move to a temporary wait so we don't re-trigger
		state_timer = -999.0


func _process_airtime(_delta: float) -> void:
	if state_timer < 0.05:
		var push_direction: float = 1.0 if facing_right else -1.0
		velocity.x = -push_direction * airtime_push_horizontal
		velocity.y = -airtime_push_vertical
		_trigger_maestro_flash()

	if is_on_floor() and state_timer > 0.2:
		if DebugOverlay.show_debug_text:
			var outcome: String = "DEAD" if _airtime_kill_on_land else "KO"
			print("[Agent] AIRTIME landing → %s" % outcome)
		if _airtime_kill_on_land:
			_enter_state(AgentState.DEAD)
			sprite.play("dead")
		else:
			_enter_state(AgentState.KO)
			_play_ko_sequence()


func _process_ko(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= ko_duration:
		_enter_state(AgentState.DEAD)
		sprite.play("ko_floor")


func _process_dead(_delta: float) -> void:
	velocity.x = 0


func _process_fallen(delta: float) -> void:
	if _fallen_knockback_frames > 0:
		_fallen_knockback_frames -= 1
	else:
		velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
	if state_timer >= fallen_duration:
		_return_to_combat_ready()
		if DebugOverlay.show_debug_text:
			print("[Agent] FALLEN recovered → combat ready")


# ========== RECEIVE DIVE ==========

func receive_dive_from(attacker: Node2D, dive_type: String) -> void:
	if state in [AgentState.DEAD, AgentState.KO, AgentState.AIRTIME, AgentState.STUNT, AgentState.FALLEN]:
		return
	last_hit_quality = "dive_fallen"
	_apply_dive_knockback(attacker, dive_type)
	_enter_state(AgentState.FALLEN)
	_play_anim_chain(["airtime", "ko_floor"])
	if DebugOverlay.show_debug_text:
		print("[Agent] DIVE FALLEN | type=%s | will recover in %.1fs" % [dive_type, fallen_duration])


func _apply_dive_knockback(attacker: Node2D, dive_type: String) -> void:
	if not attacker:
		return
	match dive_type:
		"ground":
			var horizontal_dir: float = sign(global_position.x - attacker.global_position.x)
			if horizontal_dir == 0:
				horizontal_dir = 1.0 if facing_right else -1.0
			velocity.x = horizontal_dir * dive_ground_knockback_horizontal
			velocity.y = -dive_ground_knockback_vertical
		"air":
			var horizontal_dir: float = sign(attacker.velocity.x)
			if horizontal_dir == 0:
				horizontal_dir = sign(global_position.x - attacker.global_position.x)
				if horizontal_dir == 0:
					horizontal_dir = 1.0 if not attacker.sprite.flip_h else -1.0
			velocity.x = horizontal_dir * dive_air_knockback_horizontal
			velocity.y = -dive_air_knockback_vertical * 0.3
	_fallen_knockback_frames = int(fallen_knockback_duration * 60.0)


# ========== RECEIVE PARRY ==========

func receive_parry() -> void:
	last_hit_quality = "maestro"
	attack_hitbox.monitoring = false
	_enter_state(AgentState.AIRTIME)
	sprite.play("airtime")


# ========== TAKEDOWN ==========

func receive_takedown(attacker: Node2D) -> void:
	if state == AgentState.DEAD or state == AgentState.KO:
		return
	last_hit_quality = "takedown"
	_ko_type = "takedown"
	_apply_kick_push(attacker)
	_enter_state(AgentState.KO)
	sprite.play("ko_floor")

	if DebugOverlay.show_debug_text:
		print("[Agent] TAKEDOWN from %s" % attacker.name)


func _trigger_maestro_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, maestro_flash_alpha)
	flash.size = Vector2(120, 220)
	flash.position = Vector2(-60, -110)
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, maestro_flash_duration)
	tween.tween_callback(flash.queue_free)


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


# ========== INTRO MUSICAL ==========

func _on_intro_finished() -> void:
	_waiting_for_intro = false


# ========== RESPAWN HOOK ==========

func reset_to_patrol() -> void:
	_enter_state(AgentState.PATROL)
	set_collision_layer_value(3, true)
	player_in_light = false
	player_visible = false
	player_heard = false
	player_in_vision = false
	_turn_cooldown = 0.0
	last_hit_quality = "none"
	last_seen_position = Vector2.ZERO
	attack_hitbox.monitoring = false
	_ko_type = "normal"
	_anim_queue.clear()
	if patrol_marker_a:
		global_position = get_node(patrol_marker_a).global_position
	if patrol_marker_b:
		current_target = get_node(patrol_marker_b).global_position
		going_to_b = true


# ========== DEBUG DRAW ==========

func _draw() -> void:
	if not DebugOverlay.show_hitboxes:
		return

	var hurt_shape: RectangleShape2D = $Hurtbox/CollisionShape2D.shape
	draw_rect(Rect2($Hurtbox/CollisionShape2D.position - hurt_shape.size / 2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))

	if attack_hitbox.monitoring:
		var atk_shape: RectangleShape2D = $AttackHitbox/CollisionShape2D.shape
		var atk_pos: Vector2 = $AttackHitbox.position + $AttackHitbox/CollisionShape2D.position
		if not facing_right:
			atk_pos.x = -atk_pos.x
		draw_rect(Rect2(atk_pos - atk_shape.size / 2, atk_shape.size), Color(1.0, 0.2, 0.2, 0.5))

	var head_offset := Vector2(0, -100)
	var facing_dir: float = 1.0 if facing_right else -1.0
	var cone_color := Color(1.0, 1.0, 0.0, 0.15) if not player_in_vision else Color(1.0, 1.0, 0.0, 0.35)
	var angle_rad: float = deg_to_rad(vision_cone_angle)
	var dir_angle: float = 0.0 if facing_right else PI
	var arc_points: PackedVector2Array = [head_offset]
	var arc_segments: int = 24
	for i: int in range(arc_segments + 1):
		var t: float = -angle_rad + (2.0 * angle_rad * float(i) / float(arc_segments))
		arc_points.append(head_offset + Vector2(cos(dir_angle + t), sin(dir_angle + t)) * vision_cone_range)
	draw_colored_polygon(arc_points, cone_color)
	draw_line(head_offset, arc_points[1], Color(1.0, 1.0, 0.0, 0.5), 1.0)
	draw_line(head_offset, arc_points[arc_points.size() - 1], Color(1.0, 1.0, 0.0, 0.5), 1.0)

	var radii: Array[Array] = [
		[hearing_radius_crouched, "CROUCH", Color(0.0, 1.0, 0.3)],
		[hearing_radius_idle, "IDLE", Color(0.0, 1.0, 0.0)],
		[hearing_radius_walking, "WALK", Color(0.4, 1.0, 0.0)],
		[hearing_radius_running, "RUN", Color(1.0, 0.6, 0.0)],
	]
	var active_radius: float = (hearing_shape.shape as CircleShape2D).radius
	for r: Array in radii:
		var radius_val: float = r[0]
		var label_text: String = r[1]
		var base_color: Color = r[2]
		if radius_val < 2.0:
			continue
		var is_active: bool = absf(radius_val - active_radius) < 1.0
		var line_alpha: float = 0.9 if is_active else 0.4
		var line_width: float = 3.0 if is_active else 1.5
		var line_color := Color(base_color.r, base_color.g, base_color.b, line_alpha)
		var label_color := Color(base_color.r, base_color.g, base_color.b, 0.9 if is_active else 0.5)
		draw_arc(Vector2.ZERO, radius_val, 0, TAU, 48, line_color, line_width)
		draw_string(ThemeDB.fallback_font, Vector2(radius_val + 4, -4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)

	var facing_end := Vector2(facing_dir * 80.0, 0.0) + head_offset
	draw_line(head_offset, facing_end, Color.WHITE, 2.0)

	if _turn_cooldown > 0.0:
		draw_circle(Vector2(0, -130), 6.0, Color(1.0, 0.5, 0.0, 0.8))
