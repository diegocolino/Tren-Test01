class_name Kive
extends CharacterBody2D

@export var stats: KiveStats

# ========== CONSTANTS ==========
const step_height: float = 80.0
const default_collision_height: float = 200.0

# ========== STATE (real variables, set by states) ==========
var control_enabled: bool = true
var is_crouched: bool = false
var is_hidden: bool = false
var is_finisher: bool = false
var current_attack_type: String = "none"
var current_hit_type: String = "none"
var _air_jumps_left: int = 0
var _nearby_hide_zones: int = 0
var _parry_window_timer: float = 999.0
var _punch_hitbox_active_frames: int = 0
var _kick_hitbox_active_frames: int = 0
var w_chain_step: int = 0       # 0=fresh, 1=after Jab, 2=after Cross, 3=after Hook
var _w_chain_timer: float = 999.0
var q_context: String = ""      # "standalone" | "after_jab" | "after_cross" | "after_hook" | "after_uppercut" | ""
var last_w_executed: String = "" # "jab" | "cross" | "hook" | "uppercut" | ""
var _sensible_target: Node2D = null
var _sensible_window_timer: float = 999.0
var _chain_hit_agents: Array[Node2D] = []

# ========== COMPUTED PROPERTIES ==========
var is_attacking: bool:
	get:
		if not state_machine:
			return false
		return state_machine.current_state_name in [&"Jab", &"Cross", &"Hook", &"Uppercut", &"FrontalKick", &"Execution"]

## Stubs — PunchCharging/PunchCharged eliminados en V1.1.
## Se mantienen para compatibilidad con agent.gd y debug_hud.gd.
var is_punch_charging: bool:
	get: return false

var is_punch_charged: bool:
	get: return false

var is_in_air: bool:
	get: return not is_on_floor()

var is_diving: bool:
	get:
		if not state_machine:
			return false
		return state_machine.current_state_name in [&"DiveGround", &"DiveAir"]

var jump_state: String:
	get:
		if not state_machine:
			return "none"
		match state_machine.current_state_name:
			&"JumpAnticipation": return "anticipation"
			&"JumpRise": return "jump_rise"
			&"JumpFall": return "falling"
			&"JumpLanding": return "landing_impact"
			&"AirJump": return "air_jump_rise"
			_: return "none"

# ========== REFERENCES ==========
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine


# ========== LIFECYCLE ==========

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	sprite.animation_finished.connect(_on_animation_finished)
	$PunchHitbox.body_entered.connect(_on_hitbox_body_entered)
	$KickHitbox.body_entered.connect(_on_hitbox_body_entered)
	$DiveHitbox.body_entered.connect(_on_dive_hitbox_body_entered)
	for zone in get_tree().get_nodes_in_group("hide_zone"):
		zone.body_entered.connect(_on_hide_zone_entered)
		zone.body_exited.connect(_on_hide_zone_exited)
	assert(stats != null, "[Kive] Falta asignar KiveStats al nodo Kive")


func _on_animation_finished() -> void:
	if state_machine and state_machine.current_state:
		state_machine.current_state.on_animation_finished(sprite.animation)


func _process(delta: float) -> void:
	_parry_window_timer += delta
	_w_chain_timer += delta
	_sensible_window_timer += delta
	if _sensible_target != null:
		if _sensible_window_timer > stats.sensible_window or not is_instance_valid(_sensible_target):
			_sensible_target = null
	_tick_hitbox_lifetimes()


# ========== COMBAT HELPERS ==========

func activate_hitbox() -> void:
	var facing: float = -1.0 if sprite.flip_h else 1.0
	var hitbox: Area2D
	if current_attack_type == "punch":
		hitbox = $PunchHitbox
		hitbox.position = Vector2(facing * 60, -50)
		_punch_hitbox_active_frames = stats.punch_hitbox_active_frames
	else:
		hitbox = $KickHitbox
		hitbox.position = Vector2(facing * 70, -30)
		_kick_hitbox_active_frames = stats.kick_hitbox_active_frames
	hitbox.monitoring = true


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not is_attacking:
		return
	if body.is_in_group("agent"):
		if is_finisher and body.has_method("receive_execution"):
			body.receive_execution(self)
		elif body.has_method("receive_hit_from"):
			body.receive_hit_from(self, current_hit_type)
			if current_attack_type == "punch":
				register_w_hit(body)


func _tick_hitbox_lifetimes() -> void:
	if _punch_hitbox_active_frames > 0:
		_punch_hitbox_active_frames -= 1
		if _punch_hitbox_active_frames == 0:
			$PunchHitbox.monitoring = false
	if _kick_hitbox_active_frames > 0:
		_kick_hitbox_active_frames -= 1
		if _kick_hitbox_active_frames == 0:
			$KickHitbox.monitoring = false


# ========== DIVE HITBOX ==========

func activate_dive_hitbox() -> void:
	$DiveHitbox.position = Vector2(0, -30)
	$DiveHitbox.monitoring = true


func deactivate_dive_hitbox() -> void:
	$DiveHitbox.monitoring = false


func _on_dive_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("agent"):
		return
	if not body.has_method("receive_dive_from"):
		return

	var dive_type: String = "ground" if state_machine.current_state_name == &"DiveGround" else "air"
	body.receive_dive_from(self, dive_type)

	# Kive feels impact differently per type
	if dive_type == "air":
		velocity.x *= 0.85
		velocity.y = max(velocity.y, 100)
	# DiveGround: no velocity change — Kive almost passes through

	deactivate_dive_hitbox()


# ========== DASH TARGETING ==========

func find_closest_agent_in_direction(direction: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	for agent: Node in get_tree().get_nodes_in_group("agent"):
		if not is_instance_valid(agent):
			continue
		if agent.has_method("is_dash_target") and not agent.is_dash_target():
			continue
		var dx: float = agent.global_position.x - global_position.x
		if sign(dx) != sign(direction):
			continue
		var dist: float = global_position.distance_to(agent.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = agent
	return closest


# ========== SENSIBLE SYSTEM ==========

func is_in_combat() -> bool:
	return is_chain_active() or _sensible_target != null


func open_sensible_window(target: Node2D) -> void:
	_sensible_target = target
	_sensible_window_timer = 0.0
	if DebugOverlay.show_debug_text:
		print("[Kive] open_sensible_window | target=%s" % target.name)


func register_w_hit(agent: Node2D) -> void:
	if agent not in _chain_hit_agents:
		_chain_hit_agents.append(agent)
		if DebugOverlay.show_debug_text:
			print("[Kive] register_w_hit | agent=%s | total=%d" % [agent.name, _chain_hit_agents.size()])


func find_chained_agent_in_direction(direction: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	for agent: Node2D in _chain_hit_agents:
		if not is_instance_valid(agent):
			continue
		if agent.has_method("is_dash_target") and not agent.is_dash_target():
			continue
		var dx: float = agent.global_position.x - global_position.x
		if sign(dx) != sign(direction):
			continue
		var dist: float = global_position.distance_to(agent.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = agent
	return closest


func decide_dash_state() -> StringName:
	if _sensible_target != null:
		return &"DashOffensive"
	var dir: float = Input.get_axis("move_left", "move_right")
	if dir == 0:
		dir = -1.0 if sprite.flip_h else 1.0
	var marked: Node2D = find_chained_agent_in_direction(dir)
	if marked != null and global_position.distance_to(marked.global_position) <= stats.dash_target_range:
		return &"DashOffensive"
	return &"Dash"


# ========== W CHAIN ==========

func is_chain_active() -> bool:
	return _w_chain_timer < stats.w_chain_reset_timeout


func get_w_chain_next() -> StringName:
	if not is_chain_active():
		return &""
	match w_chain_step:
		0: return &"Cross"
		1: return &"Hook"
		2: return &"Uppercut"
		_: return &""


func reset_w_chain() -> void:
	w_chain_step = 0
	_w_chain_timer = 999.0
	_chain_hit_agents.clear()


func get_q_context_from_chain() -> String:
	if not is_chain_active():
		return "standalone"
	match w_chain_step:
		0: return "after_jab"
		1: return "after_cross"
		2: return "after_hook"
		3: return "after_uppercut"
		_: return "standalone"


# ========== PARRY / DAMAGE ==========

func is_parry_window_active() -> bool:
	return _parry_window_timer <= (stats.parry_window_frames / 60.0)


func receive_agent_hit(agent: Node2D) -> void:
	if DebugOverlay.show_debug_text:
		print("[Kive hit] parry_timer=%.3f window=%.3f parry=%s" % [
			_parry_window_timer, stats.parry_window_frames / 60.0, str(is_parry_window_active())
		])
	if is_parry_window_active():
		_resolve_parry(agent)
		return
	state_machine.transition_to(&"Damaged")


func _resolve_parry(agent: Node2D) -> void:
	if agent.has_method("receive_parry"):
		agent.receive_parry()
	_trigger_parry_flash()
	_parry_window_timer = 999.0


func _trigger_parry_flash() -> void:
	sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)


## Stub — charge ratio reactivated in V1.5 (Uppercut hold finisher).
func get_charge_ratio() -> float:
	return 0.0


# ========== MOVEMENT HELPERS ==========

func apply_horizontal_input(in_air: bool) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var is_walking_slow: bool = Input.is_action_pressed("run")
	var speed: float
	if is_crouched:
		speed = stats.crouch_walk_speed
	elif is_walking_slow:
		speed = stats.walk_speed
	else:
		speed = stats.run_speed
	if in_air:
		speed *= stats.air_control_factor
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)


func update_sprite_direction() -> void:
	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true


func try_step_up() -> void:
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


func _update_collision_shape() -> void:
	var shape: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if is_crouched or is_diving:
		shape.size.y = default_collision_height * stats.crouch_height_multiplier
		$CollisionShape2D.position.y = (default_collision_height * (1.0 - stats.crouch_height_multiplier)) / 2
	else:
		shape.size.y = default_collision_height
		$CollisionShape2D.position.y = 0
	queue_redraw()


# ========== PUBLIC API ==========

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		current_attack_type = "none"
		current_hit_type = "none"
		last_w_executed = ""


func reset_state() -> void:
	velocity = Vector2.ZERO
	is_crouched = false
	current_attack_type = "none"
	current_hit_type = "none"
	_parry_window_timer = 999.0
	_punch_hitbox_active_frames = 0
	_kick_hitbox_active_frames = 0
	is_finisher = false
	_air_jumps_left = 0
	reset_w_chain()
	_sensible_target = null
	_sensible_window_timer = 999.0
	q_context = ""
	last_w_executed = ""
	_update_collision_shape()
	if is_hidden:
		is_hidden = false
		sprite.modulate.a = 1.0
	if state_machine:
		state_machine.transition_to(&"Idle")


func is_sprinting() -> bool:
	return not Input.is_action_pressed("run") and abs(velocity.x) > 10


func can_hide() -> bool:
	for enemy: Node in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_position_tier_of"):
			if enemy.state in [enemy.AgentState.DEAD, enemy.AgentState.KO, enemy.AgentState.PATROL, enemy.AgentState.ALERT]:
				continue
			return false
	return true


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
	var hurt_shape: RectangleShape2D = $Hurtbox/CollisionShape2D.shape
	var hurt_pos: Vector2 = $Hurtbox.position + $Hurtbox/CollisionShape2D.position
	draw_rect(Rect2(hurt_pos - hurt_shape.size / 2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))
	if $PunchHitbox.monitoring:
		var p_shape: RectangleShape2D = $PunchHitbox/CollisionShape2D.shape
		var p_pos: Vector2 = $PunchHitbox.position + $PunchHitbox/CollisionShape2D.position
		draw_rect(Rect2(p_pos - p_shape.size / 2, p_shape.size), Color(1.0, 0.2, 0.2, 0.5))
	if $KickHitbox.monitoring:
		var k_shape: RectangleShape2D = $KickHitbox/CollisionShape2D.shape
		var k_pos: Vector2 = $KickHitbox.position + $KickHitbox/CollisionShape2D.position
		draw_rect(Rect2(k_pos - k_shape.size / 2, k_shape.size), Color(1.0, 0.5, 0.0, 0.5))
