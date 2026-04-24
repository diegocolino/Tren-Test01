extends CharacterBody2D

# ========== ENUMS ==========
enum State { PATROL, SUSPICIOUS, ALERT }

# ========== EXPORTS ==========
@export var patrol_speed: float = 80.0
@export var alert_speed: float = 280.0
@export var patrol_marker_a: NodePath
@export var patrol_marker_b: NodePath

@export_group("Transiciones de estado (segundos)")
@export var suspicion_to_alert_time: float = 1.2
@export var alert_to_suspicious_time: float = 3.0
@export var suspicious_to_patrol_time: float = 5.0

@export_group("Oido")
@export var hearing_radius_walking: float = 250.0
@export var hearing_radius_running: float = 450.0
@export var hearing_radius_idle: float = 80.0
@export var hearing_radius_crouched: float = 1.0

@export_group("Gravedad")
@export var gravity: float = 2400.0

const step_height: float = 60.0

# ========== STATE ==========
var state: State = State.PATROL
var state_timer: float = 0.0
var current_target: Vector2 = Vector2.ZERO
var going_to_b: bool = true
var player_in_cone: bool = false
var player_visible: bool = false
var player_heard: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var kive_ref: Node2D = null
var facing_right: bool = true

# ========== REFS ==========
@onready var body_rect: Polygon2D = $Body
@onready var head_rect: Polygon2D = $Head
@onready var state_indicator: Label = $StateIndicator
@onready var vision_cone: Area2D = $VisionCone
@onready var vision_polygon: Polygon2D = $VisionCone/VisionPolygon
@onready var line_of_sight: RayCast2D = $LineOfSightRay
@onready var hearing_range: Area2D = $HearingRange
@onready var hearing_shape: CollisionShape2D = $HearingRange/HearingShape


func _ready() -> void:
	GameManager.register_guard(self)

	# Conectar signals
	vision_cone.body_entered.connect(_on_vision_body_entered)
	vision_cone.body_exited.connect(_on_vision_body_exited)
	hearing_range.body_entered.connect(_on_hearing_body_entered)
	hearing_range.body_exited.connect(_on_hearing_body_exited)

	# Configurar target inicial
	if patrol_marker_b:
		current_target = get_node(patrol_marker_b).global_position
	elif patrol_marker_a:
		current_target = get_node(patrol_marker_a).global_position


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Actualizar radio de oido segun estado de Kive
	_update_hearing_radius()

	# Deteccion actualizada cada frame
	_update_detection()

	# Logica de estado
	var player_detected: bool = (player_in_cone and player_visible) or player_heard
	if kive_ref and kive_ref.is_hidden:
		player_detected = false

	match state:
		State.PATROL:
			_process_patrol(delta, player_detected)
		State.SUSPICIOUS:
			_process_suspicious(delta, player_detected)
		State.ALERT:
			_process_alert(delta, player_detected)

	move_and_slide()
	_try_step_up()
	_update_visuals()
	_check_caught_kive()
	if DebugOverlay.debug_enabled:
		queue_redraw()


# ========== DETECCION ==========

func _update_hearing_radius() -> void:
	var radius: float = hearing_radius_idle

	if kive_ref:
		if kive_ref.is_crouched:
			radius = hearing_radius_crouched
		elif abs(kive_ref.velocity.x) > 10:
			if kive_ref.is_sprinting():
				radius = hearing_radius_running
			else:
				radius = hearing_radius_walking
		else:
			radius = hearing_radius_idle

	(hearing_shape.shape as CircleShape2D).radius = max(radius, 1.0)

	# Debug visual del radio
	if has_node("HearingRange/HearingVisual"):
		var visual: Node2D = $HearingRange/HearingVisual
		var current_radius: float = (hearing_shape.shape as CircleShape2D).radius
		visual.scale = Vector2.ONE * (current_radius / 50.0)


func _update_detection() -> void:
	# Kive escondido: no rastrear posicion ni visibilidad
	if kive_ref and kive_ref.is_hidden:
		player_visible = false
		return

	if player_in_cone and kive_ref:
		# Raycast directo via PhysicsServer — mas fiable que el nodo RayCast2D
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position + Vector2(0, -100),  # desde el torso del guardia
			kive_ref.global_position + Vector2(0, -100),  # hacia el torso de Kive
			3,  # mask: Player (1) + Cover (2)
			[get_rid()]  # excluir al propio guardia
		)
		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			# Nada entre guardia y Kive -> lo ve
			player_visible = true
		else:
			# Si golpea a Kive, lo ve; si golpea otra cosa (columna), no lo ve
			player_visible = (result.collider == kive_ref)

		# Actualizar el nodo RayCast2D para el debug visual
		line_of_sight.target_position = line_of_sight.to_local(kive_ref.global_position + Vector2(0, -100))
		line_of_sight.force_raycast_update()
	else:
		player_visible = false

	# Actualizar last_seen_position si lo ve o lo oye
	if player_visible or player_heard:
		if kive_ref:
			last_seen_position = kive_ref.global_position


# ========== ESTADOS ==========

func _process_patrol(_delta: float, player_detected: bool) -> void:
	if player_detected:
		_enter_state(State.SUSPICIOUS)
		return

	# Mover hacia current_target
	var direction: float = sign(current_target.x - global_position.x)
	velocity.x = direction * patrol_speed
	facing_right = direction >= 0

	# Llego?
	if abs(current_target.x - global_position.x) < 5:
		_toggle_patrol_target()


func _process_suspicious(delta: float, player_detected: bool) -> void:
	velocity.x = 0  # se para a investigar
	state_timer += delta

	# Mirar hacia ultima posicion conocida
	facing_right = last_seen_position.x > global_position.x

	if player_detected:
		if state_timer >= suspicion_to_alert_time:
			_enter_state(State.ALERT)
	else:
		if state_timer >= suspicious_to_patrol_time:
			_enter_state(State.PATROL)
			_snap_to_closest_marker()


func _process_alert(delta: float, player_detected: bool) -> void:
	state_timer += delta

	# Perseguir hacia last_seen_position
	var direction: float = sign(last_seen_position.x - global_position.x)
	velocity.x = direction * alert_speed
	facing_right = direction >= 0

	if player_detected:
		state_timer = 0.0  # sigue viendolo/oyendolo
	else:
		if state_timer >= alert_to_suspicious_time:
			_enter_state(State.SUSPICIOUS)


func _enter_state(new_state: State) -> void:
	state = new_state
	state_timer = 0.0


func _toggle_patrol_target() -> void:
	going_to_b = !going_to_b
	if going_to_b:
		current_target = get_node(patrol_marker_b).global_position
	else:
		current_target = get_node(patrol_marker_a).global_position


func _snap_to_closest_marker() -> void:
	var pos_a: Vector2 = get_node(patrol_marker_a).global_position
	var pos_b: Vector2 = get_node(patrol_marker_b).global_position
	if global_position.distance_to(pos_a) < global_position.distance_to(pos_b):
		current_target = pos_a
		going_to_b = true
	else:
		current_target = pos_b
		going_to_b = false


# ========== VISUALS ==========

func _update_visuals() -> void:
	# Color del cono segun estado
	match state:
		State.PATROL:
			vision_polygon.color = Color(0.23, 0.66, 0.77, 0.25)
			state_indicator.text = ""
		State.SUSPICIOUS:
			vision_polygon.color = Color(0.43, 0.88, 0.94, 0.40)
			state_indicator.text = "?"
			state_indicator.modulate = Color(1.0, 0.82, 0.38)
		State.ALERT:
			vision_polygon.color = Color(1.0, 0.25, 0.125, 0.50)
			state_indicator.text = "!"
			state_indicator.modulate = Color(1.0, 0.25, 0.125)

	# Flip segun direccion
	var flip_scale: float = 1.0 if facing_right else -1.0
	body_rect.scale.x = flip_scale
	head_rect.scale.x = flip_scale
	vision_cone.scale.x = flip_scale
	hearing_range.scale.x = 1.0  # el oido no se orienta

	# Debug label
	if has_node("DebugLabel"):
		$DebugLabel.text = "S:%s H:%.0f V:%s P:%s" % [
			State.keys()[state],
			(hearing_shape.shape as CircleShape2D).radius,
			"T" if player_visible else "F",
			"T" if player_heard else "F"
		]

	# Debug ray line
	if has_node("RayLine"):
		var ray_line: Line2D = $RayLine
		if player_in_cone and kive_ref:
			ray_line.clear_points()
			ray_line.add_point(Vector2(0, -100))  # torso del guardia
			if line_of_sight.is_colliding():
				ray_line.add_point(line_of_sight.get_collision_point() - global_position)
			else:
				ray_line.add_point(kive_ref.global_position + Vector2(0, -100) - global_position)
			ray_line.default_color = Color(0, 1, 0, 0.6) if player_visible else Color(1, 0, 0, 0.6)
		else:
			ray_line.clear_points()


# ========== STEP CLIMBING ==========

func _try_step_up() -> void:
	if not is_on_wall() or not is_on_floor():
		return
	var dir: float = 1.0 if facing_right else -1.0
	# Hay espacio para subir?
	if test_move(global_transform, Vector2(0, -step_height)):
		return
	# Hay espacio para avanzar a la altura elevada?
	var elevated: Transform2D = global_transform
	elevated.origin.y -= step_height
	if test_move(elevated, Vector2(dir * 4.0, 0)):
		return
	# Subir el escalon
	position.y -= step_height


# ========== CATCH ==========

func _check_caught_kive() -> void:
	if state != State.ALERT:
		return
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_collider() == kive_ref:
			GameManager.player_caught()
			return


# ========== RESPAWN HOOK ==========

func reset_to_patrol() -> void:
	state = State.PATROL
	state_timer = 0.0
	player_in_cone = false
	player_visible = false
	player_heard = false
	# Volver al marker A
	if patrol_marker_a:
		global_position = get_node(patrol_marker_a).global_position
		current_target = get_node(patrol_marker_b).global_position
		going_to_b = true


# ========== SIGNALS ==========

func _on_vision_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		kive_ref = body
		player_in_cone = true

func _on_vision_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_cone = false

func _on_hearing_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		kive_ref = body
		player_heard = true

func _on_hearing_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_heard = false


# ========== DEBUG DRAW ==========

func _draw() -> void:
	if not DebugOverlay.debug_enabled:
		return
	var col_shape: CollisionShape2D = $CollisionShape2D
	var shape: RectangleShape2D = col_shape.shape as RectangleShape2D
	if not shape:
		return
	var offset: Vector2 = col_shape.position
	var rect: Rect2 = Rect2(offset - shape.size / 2.0, shape.size)
	draw_rect(rect, Color(1, 0, 0, 0.35), true)
	draw_rect(rect, Color(1, 0, 0, 0.8), false, 2.0)
