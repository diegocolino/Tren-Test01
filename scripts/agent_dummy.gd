## AgentDummy — saco de boxeo para testing de combate.
## NO hereda de Agent. Duplica las funciones de reacción como deuda técnica documentada.
class_name AgentDummy
extends CharacterBody2D

enum DummyState { IDLE, HIT, STUNT, KO, AIRTIME, DEAD }

# ========== EXPORTS ==========
@export_group("Timings")
@export var hit_reaction_duration: float = 0.4
@export var stunt_duration: float = 2.0
@export var ko_duration: float = 44.0

@export_group("Kick Push")
@export var kick_push_distance: float = 120.0
@export var kick_push_duration: float = 0.2

@export_group("Airtime")
@export var airtime_push_horizontal: float = 800.0
@export var airtime_push_vertical: float = 1600.0

@export_group("Maestro Flash")
@export var maestro_flash_duration: float = 0.3
@export var maestro_flash_alpha: float = 0.8

@export_group("Posicion")
@export var behind_threshold: float = 30.0

@export_group("Gravedad")
@export var gravity: float = 2400.0

# ========== STATE ==========
var state: DummyState = DummyState.IDLE
var state_timer: float = 0.0
var facing_right: bool = true
var last_hit_quality: String = "none"
var _ko_type: String = "normal"
var _airtime_kill_on_land: bool = true  # true = Uppercut (W=DEATH), false = air_launch (Q=KO)

var _pending_kick_push_velocity: float = 0.0
var _pending_kick_push_frames: int = 0
var _anim_queue: Array[String] = []
var _spawn_position: Vector2 = Vector2.ZERO

# ========== REFERENCES ==========
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var debug_label: Label = $DebugLabel

# ========== LIFECYCLE ==========

func _ready() -> void:
	add_to_group("agent")
	_spawn_position = global_position
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# F7 reset
	if Input.is_action_just_pressed("debug_reset_dummy"):
		_reset_to_idle()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# State timer
	state_timer += delta

	# State dispatch (each state sets velocity as it sees fit)
	match state:
		DummyState.IDLE:
			velocity.x = 0
		DummyState.HIT:
			_process_hit(delta)
		DummyState.STUNT:
			_process_stunt(delta)
		DummyState.AIRTIME:
			_process_airtime(delta)
		DummyState.KO:
			_process_ko(delta)
		DummyState.DEAD:
			velocity.x = 0

	# Kick push overrides state velocity — push is something that happens TO you
	if _pending_kick_push_frames > 0:
		velocity.x = _pending_kick_push_velocity
		_pending_kick_push_frames -= 1
		if _pending_kick_push_frames == 0:
			_pending_kick_push_velocity = 0.0

	move_and_slide()

	# Debug label
	if debug_label:
		debug_label.text = "[%s] t=%.2f hit=%s" % [DummyState.keys()[state], state_timer, last_hit_quality]


# ========== RESET ==========

func _reset_to_idle() -> void:
	_anim_queue.clear()
	if sprite.animation_finished.is_connected(_advance_anim_chain):
		sprite.animation_finished.disconnect(_advance_anim_chain)
	state = DummyState.IDLE
	state_timer = 0.0
	velocity = Vector2.ZERO
	global_position = _spawn_position
	last_hit_quality = "none"
	_ko_type = "normal"
	_pending_kick_push_velocity = 0.0
	_pending_kick_push_frames = 0
	sprite.play("idle")
	if DebugOverlay.show_debug_text:
		print("[AgentDummy] RESET to IDLE at spawn position")


# ========== HIT RESOLUTION ==========

func receive_hit_from(attacker: Node2D, hit_type: String) -> void:
	# DEAD: only Q pushes the body. W ignored (gore mechanic reserved for V2).
	if state == DummyState.DEAD:
		if hit_type in ["frontal", "stunt_pie", "ko_suelo", "air_launch"]:
			_apply_kick_push(attacker)
			if DebugOverlay.show_debug_text:
				print("[AgentDummy] Q PUSH on DEAD body | hit_type=%s" % hit_type)
		return

	# Turn towards attacker
	if attacker:
		facing_right = attacker.global_position.x > global_position.x

	if hit_type in ["frontal", "stunt_pie", "ko_suelo", "air_launch"]:
		var pos_tier: String = _get_position_tier(attacker)
		_resolve_q_hit(hit_type, pos_tier, attacker)
	else:
		_resolve_w_hit(hit_type, attacker)


func _resolve_w_hit(hit_type: String, attacker: Node2D) -> void:
	# Kill selectiva: STUNT/KO/AIRTIME + any W = DEAD
	if state in [DummyState.STUNT, DummyState.KO, DummyState.AIRTIME]:
		if DebugOverlay.show_debug_text:
			print("[AgentDummy] _resolve_w_hit KILL from vulnerable state | state=%s | hit=%s" % [
				DummyState.keys()[state], hit_type])
		last_hit_quality = "kill"
		_enter_state(DummyState.DEAD)
		sprite.play("dead")
		return

	var is_vulnerable: bool = state in [DummyState.STUNT, DummyState.HIT]

	if DebugOverlay.show_debug_text:
		print("[AgentDummy] _resolve_w_hit | hit_type=%s | state=%s | vulnerable=%s" % [
			hit_type, DummyState.keys()[state], is_vulnerable])

	# Uppercut (W4): AIRTIME -> DEAD on landing, independent of guard
	if hit_type == "uppercut":
		last_hit_quality = "maestro"
		_airtime_kill_on_land = true
		_enter_state(DummyState.AIRTIME)
		sprite.play("airtime")
		return

	# Cross (W2) / Hook (W3): KO if vulnerable, HIT otherwise
	if hit_type in ["cross", "hook"]:
		if is_vulnerable:
			last_hit_quality = "golpe_bueno"
			_ko_type = "golpe_bueno"
			_enter_state(DummyState.KO)
			_play_golpe_bueno_sequence(attacker)
			return
		last_hit_quality = "hit"
		_enter_state(DummyState.HIT)
		sprite.play("hit_light")
		return

	# Jab (W1) and fallback: HIT ligero always
	last_hit_quality = "hit"
	_enter_state(DummyState.HIT)
	sprite.play("hit_light")


func _resolve_q_hit(hit_type: String, pos_tier: String, attacker: Node2D) -> void:
	if DebugOverlay.show_debug_text:
		print("[AgentDummy] _resolve_q_hit | hit_type=%s | pos_tier=%s | state=%s" % [
			hit_type, pos_tier, DummyState.keys()[state]])

	match hit_type:
		"frontal":
			last_hit_quality = "push"
			_apply_kick_push(attacker)

		"stunt_pie":
			last_hit_quality = "stunt_pie"
			_apply_kick_push(attacker)
			_enter_state(DummyState.STUNT)
			sprite.play("stunt")

		"ko_suelo":
			last_hit_quality = "ko_suelo"
			_ko_type = "normal"
			_apply_kick_push(attacker)
			_enter_state(DummyState.KO)
			_play_ko_sequence()

		"air_launch":
			last_hit_quality = "air_launch"
			_airtime_kill_on_land = false
			_enter_state(DummyState.AIRTIME)
			sprite.play("airtime")

		_:
			push_warning("Unknown q hit_type: %s" % hit_type)
			last_hit_quality = "push"
			_apply_kick_push(attacker)


# ========== STATE TRANSITIONS ==========

func _enter_state(new_state: DummyState) -> void:
	_anim_queue.clear()
	if sprite.animation_finished.is_connected(_advance_anim_chain):
		sprite.animation_finished.disconnect(_advance_anim_chain)

	state = new_state
	state_timer = 0.0


# ========== STATE PROCESSORS ==========

func _process_hit(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= hit_reaction_duration:
		_enter_state(DummyState.IDLE)
		sprite.play("idle")


func _process_stunt(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= stunt_duration:
		_play_anim_chain(["stunt_recover"])
		sprite.animation_finished.connect(func() -> void:
			_enter_state(DummyState.IDLE)
			sprite.play("idle")
		, CONNECT_ONE_SHOT)
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
			print("[AgentDummy] AIRTIME landing → %s" % outcome)
		if _airtime_kill_on_land:
			_enter_state(DummyState.DEAD)
			sprite.play("dead")
		else:
			_enter_state(DummyState.KO)
			_play_ko_sequence()


func _process_ko(_delta: float) -> void:
	velocity.x = 0
	if state_timer >= ko_duration:
		_enter_state(DummyState.DEAD)
		sprite.play("ko_floor")


# ========== HELPERS ==========

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


# ========== ANIMATION SEQUENCES ==========

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


func _play_ko_sequence() -> void:
	_play_anim_chain(["stunt", "ko_floor"])


func _play_golpe_bueno_sequence(attacker: Node2D) -> void:
	var push_dir: float = sign(global_position.x - attacker.global_position.x)
	if push_dir == 0:
		push_dir = 1.0
	velocity.x = push_dir * airtime_push_horizontal * 0.4
	velocity.y = -airtime_push_vertical * 0.3
	_play_anim_chain(["hit_light", "airtime", "ko_floor"])


func _trigger_maestro_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, maestro_flash_alpha)
	flash.size = Vector2(120, 220)
	flash.position = Vector2(-60, -110)
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, maestro_flash_duration)
	tween.tween_callback(flash.queue_free)
