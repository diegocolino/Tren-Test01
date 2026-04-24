# Sistema de combate MVP v3 — Agent + Punch + Kick + Parry + Debug (versión final ejecutable)

> Parche definitivo. Incorpora las 7 correcciones técnicas identificadas en revisión de código, el mapeo real de spritesheets, y las decisiones de diseño cerradas. Parry atado a W (punch), kick con push + 30% RNG guard break + stunt por detrás, hitboxes separadas, debug HUD completo, sprites reales desde el inicio.

---

## ANTES DE EMPEZAR

```
git add .
git commit -m "pre-combat-mvp-v3"
```

Commit obligatorio. Este parche toca 10+ archivos y añade 3 nuevos. Sin red de seguridad no se ejecuta.

---

## CAMBIOS RESPECTO A V1/V2

Lo que cambia del plan v2 original:

1. **Await peligroso eliminado** en `_execute_hit_check()` — ahora flag + desactivación en siguiente `_physics_process`.
2. **Stub de `receive_agent_hit`** añadido en Fase 5 (antes estaba solo en Fase 9).
3. **Sprites reales desde Fase 2** con AnimatedSprite2D, no placeholders Polygon2D.
4. **GameManager**: nueva función `register_enemy()` (genérica). `register_guard()` queda como alias legacy.
5. **Bloqueo total de Kive durante combate**: jump, dive, crouch, movement — todo bloqueado durante cast/attack.
6. **Mapeo real de frames** de los 3 spritesheets incorporado.
7. **Parry atado a W confirmado** como decisión de diseño (compromiso total).

---

## MAPEO DE FRAMES CONFIRMADO

### Agent_Sprite.png (256x256, 1 frame)
- `idle` — el único frame de idle

### Agent_Walk-Run-Guard-Kick-Parry-Kick-Fall_Sprite.png (2048x768, 8x3 grid, 256x256/frame)

| Frames | Animación | Loop | FPS |
|---|---|---|---|
| 1-4 | walk_patrol (linterna en mano) | sí | 8 |
| 5-8 | run_patrol | sí | 12 |
| 9-12 | walk_guard | sí | 8 |
| 13 | kick_windup (casting) | no | 1 |
| 14 | kick_release (contact) | no | 1 |
| 15 | parry_1 | no | 1 |
| 16 | parry_2 (variante aleatoria) | no | 1 |
| 17-18 | hit_light (retroceso) | no | 12 |
| 19-20 | stunt (aturdido de pie) | no | 8 |
| 21-22 | airtime (volando) | no | 10 |
| 23 | floorstunt (tumbado) | sí | 1 |
| 24 | dead | sí | 1 |

### Kive_Punch_Kick_AttackEsp_Sprite.png (2048x512, 8x2 grid, 256x256/frame)

**Nota del usuario:** fila 1 solo tiene frames 3 y 7 dibujados (placeholders los demás). Las anticipaciones/recoveries se animarán después. Testeamos con snap a frames contact.

| Frame | Uso | Notas |
|---|---|---|
| 3 | punch_contact | frame de contact del punch rápido |
| 7 | kick_contact | frame de contact del kick |
| 9-12 | attack_charged_casting | Kive cargando (loop de carga) |
| 13 | attack_charged_release | soltando el puñetazo cargado |
| 14 | attack_charged_airtime | puño extendido en el aire |
| 15 | attack_charged_contact | frame de contact del cargado |
| 16 | attack_charged_recovery | recovery del cargado |

---

## ROADMAP DE FASES

- **FASE 1** — Debug overlay avanzado + DebugHUD
- **FASE 2** — Escena Agent.tscn con sprites reales + linterna
- **FASE 3** — agent.gd: patrol + linterna + oído
- **FASE 4** — Combat states del Agent (sin `receive_agent_hit` todavía)
- **FASE 5** — Inputs Kive + stub de `receive_agent_hit`
- **FASE 6** — Hitboxes precisas punch/kick
- **FASE 7** — Sistema de calidad de golpe
- **FASE 8** — Hit reactions del Agent (las 4 resoluciones + kick extras)
- **FASE 9** — Parry real de Kive (atado a W)
- **FASE 10** — Placeholders visuales rojo/verde
- **FASE 11** — Sustitución Guardia → Agent en Vagon1.tscn
- **FASE 12** — Documentación

Verificar cada fase. Si algo falla, parar.

---

## FASE 1 — Debug overlay avanzado

### 1.1 Extender debug_overlay.gd

```gdscript
extends Node

var debug_enabled: bool = true
var show_timeline: bool = true
var show_hitboxes: bool = true
var show_state_info: bool = true
var show_parry_windows: bool = true
var show_distance: bool = true
var show_flashlight_cone: bool = true


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F1:
            debug_enabled = not debug_enabled
            _toggle_debug_visuals()
        elif event.keycode == KEY_F2 and debug_enabled:
            show_hitboxes = not show_hitboxes
        elif event.keycode == KEY_F3 and debug_enabled:
            show_timeline = not show_timeline
        elif event.keycode == KEY_F4 and debug_enabled:
            show_flashlight_cone = not show_flashlight_cone


func _toggle_debug_visuals() -> void:
    for node in get_tree().get_nodes_in_group("debug_visual"):
        node.visible = debug_enabled
```

### 1.2 DebugHUD

Crear `/scenes/DebugHUD.tscn`:

```
DebugHUD (CanvasLayer, layer=12, add_to_group("debug_visual"))
└── DebugInfoPanel (VBoxContainer, margin 20,20 desde arriba-izquierda)
    ├── FPSLabel (Label)
    ├── KiveStateLabel (Label, multilínea)
    ├── AgentStateLabel (Label, multilínea)
    ├── DistanceLabel (Label)
    └── TimelineLabel (Label)
```

Script `/scripts/debug_hud.gd`:

```gdscript
extends CanvasLayer

@onready var fps_label: Label = $DebugInfoPanel/FPSLabel
@onready var kive_label: Label = $DebugInfoPanel/KiveStateLabel
@onready var agent_label: Label = $DebugInfoPanel/AgentStateLabel
@onready var distance_label: Label = $DebugInfoPanel/DistanceLabel
@onready var timeline_label: Label = $DebugInfoPanel/TimelineLabel


func _process(_delta: float) -> void:
    if not DebugOverlay.debug_enabled:
        visible = false
        return
    visible = true
    
    fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
    
    var kive: Node = GameManager.kive_ref if GameManager.kive_ref else null
    
    if kive:
        var info: String = "KIVE\n"
        info += "  crouch=%s hide=%s\n" % [str(kive.is_crouched), str(kive.is_hidden)]
        info += "  jump=%s dive=%s\n" % [kive.jump_state, str(kive.is_diving)]
        info += "  cast=%s atk=%s\n" % [str(kive.is_casting), str(kive.is_attacking)]
        if kive.is_casting:
            info += "  cast_t=%.2fs (charged=%s)\n" % [kive.cast_timer, str(kive.cast_timer >= kive.attack_charge_time)]
        if kive.has_method("is_parry_window_active"):
            info += "  parry_window=%s\n" % str(kive.is_parry_window_active())
        if DebugOverlay.show_timeline and kive.has_node("AnimatedSprite2D"):
            info += "  anim=%s frame=%d" % [kive.sprite.animation, kive.sprite.frame]
        kive_label.text = info
    else:
        kive_label.text = "KIVE: no ref"
    
    var agents: Array = get_tree().get_nodes_in_group("agent")
    if agents.size() > 0:
        var agent: Node = agents[0]
        var info: String = "AGENT\n"
        info += "  state=%s t=%.2f\n" % [agent.State.keys()[agent.state], agent.state_timer]
        info += "  last_hit=%s\n" % agent.last_hit_quality
        info += "  lit=%s visible=%s heard=%s\n" % [str(agent.player_in_light), str(agent.player_visible), str(agent.player_heard)]
        if agent.has_method("get_position_tier_of") and kive:
            info += "  pos_tier=%s\n" % agent.get_position_tier_of(kive)
        if DebugOverlay.show_timeline and agent.has_node("AnimatedSprite2D"):
            info += "  anim=%s frame=%d" % [agent.sprite.animation, agent.sprite.frame]
        agent_label.text = info
        
        if kive:
            var dist: float = kive.global_position.distance_to(agent.global_position)
            distance_label.text = "Distancia: %.0f px" % dist
    else:
        agent_label.text = "AGENT: no instances"
        distance_label.text = ""
```

Instanciar DebugHUD en Vagon1.tscn.

### 1.3 Colores estándar de hitboxes

- Hurtbox (azul): `Color(0.2, 0.5, 1.0, 0.3)`
- Punch hitbox (rojo): `Color(1.0, 0.2, 0.2, 0.5)`
- Kick hitbox (naranja): `Color(1.0, 0.5, 0.0, 0.5)`
- Detección/áreas: `Color(1.0, 1.0, 0.2, 0.2)`
- Cono linterna: `Color(0.2, 1.0, 0.5, 0.3)`

### Verificación Fase 1
- F1 activa/desactiva debug visual
- DebugHUD visible con FPS + estado Kive + "AGENT: no instances"
- F2/F3/F4 togglean opciones

---

## FASE 2 — Escena Agent.tscn con sprites reales

### 2.1 Crear SpriteFrames del Agent

Crear `/resources/agent_frames.tres`:

```
idle → Agent_Sprite.png (1 frame)
walk_patrol → frames 1-4 del spritesheet Walk-Run-Guard, loop, 8 FPS
run_patrol → frames 5-8, loop, 12 FPS
walk_guard → frames 9-12, loop, 8 FPS
kick_windup → frame 13, sin loop, 1 FPS
kick_release → frame 14, sin loop, 1 FPS
parry_1 → frame 15, sin loop, 1 FPS
parry_2 → frame 16, sin loop, 1 FPS
hit_light → frames 17-18, sin loop, 12 FPS
stunt → frames 19-20, sin loop, 8 FPS
airtime → frames 21-22, sin loop, 10 FPS
floorstunt → frame 23, loop, 1 FPS
dead → frame 24, loop, 1 FPS
```

### 2.2 Estructura de nodos Agent.tscn

```
Agent (CharacterBody2D, z_index=4)
│ - collision_layer: 4 (Enemy)
│ - collision_mask: 8 (World)
│ - add_to_group("agent")
├── AnimatedSprite2D
│   │ - sprite_frames = res://resources/agent_frames.tres
│   │ - animation = "idle"
│   │ - autoplay = "idle"
│   │ - centered = true
├── CollisionShape2D (RectangleShape2D 80x200)
├── Hurtbox (Area2D)
│   │ - collision_layer: 4
│   │ - collision_mask: 0
│   │ - z_index: 5
│   └── CollisionShape2D (RectangleShape2D 80x200)
├── FlashlightHand (Node2D, posición relativa donde está la mano en frames 1-8)
│   ├── Flashlight (PointLight2D)
│   │   - texture: GradientTexture2D (white-to-transparent radial, 300x300)
│   │   - color: Color(1, 0.95, 0.8, 1)
│   │   - energy: 1.5
│   │   - shadow_enabled: false
│   └── FlashlightConeDetector (Area2D)
│       │ - collision_layer: 16 (Detection bit 5)
│       │ - collision_mask: 1 (Player)
│       └── CollisionPolygon2D (trapecio: (30,20), (30,-20), (350,-120), (350,120))
├── HearingRange (Area2D)
│   │ - collision_layer: 16
│   │ - collision_mask: 1
│   └── HearingShape (CollisionShape2D, CircleShape2D radius=1)
├── AttackHitbox (Area2D, monitoring=false default)
│   │ - collision_layer: 0
│   │ - collision_mask: 1 (Player)
│   └── CollisionShape2D (RectangleShape2D 120x60, posición relativa (60, 0))
├── StateIndicator (Label, sobre la cabeza, texto grande)
└── DebugLabel (Label, group="debug_visual")
```

### 2.3 Ajuste importante del pivote

Los sprites 256x256 del Agent tienen el pivote centrado. El `CollisionShape2D` físico debe estar alineado a los pies, no al centro:
- `CollisionShape2D.position.y = 0`
- `AnimatedSprite2D.offset.y = -90` (ajustar para que los pies del sprite coincidan con `y=0` del nodo raíz)

Ajustar visualmente al instanciar en Vagon1 si no coincide.

### Verificación Fase 2
- Agent.tscn se abre sin errores
- Al instanciar, Agent aparece en idle
- Linterna visible iluminando hacia la derecha
- Collision shapes correctos

---

## FASE 3 — agent.gd patrol + detección + oído

```gdscript
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
@export var windup_duration: float = 0.5
@export var attack_release_duration: float = 0.2
@export var guard_to_windup_time: float = 1.5
@export var guard_broken_duration: float = 0.8
@export var guard_broken_chance: float = 0.3
@export var stunt_duration: float = 0.8
@export var floorstunt_duration: float = 3.0
@export var kick_push_distance: float = 120.0
@export var kick_push_duration: float = 0.2  # tiempo para cubrir la distancia

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

# Flag para push del kick: se aplica en el siguiente _physics_process
var _pending_kick_push_velocity: float = 0.0
var _pending_kick_push_frames: int = 0

# Flag para desactivar hitbox en siguiente frame (evita await peligroso)
var _attack_hitbox_active_frames_left: int = 0

# ========== REFS ==========
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_indicator: Label = $StateIndicator
@onready var flashlight_hand: Node2D = $FlashlightHand
@onready var flashlight: PointLight2D = $FlashlightHand/Flashlight
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
    
    # Actualizar detección
    _update_hearing_radius()
    _update_detection()
    
    state_timer += delta
    
    # Aplicar push pendiente del kick (substituye al await peligroso)
    if _pending_kick_push_frames > 0:
        velocity.x = _pending_kick_push_velocity
        _pending_kick_push_frames -= 1
        if _pending_kick_push_frames == 0:
            _pending_kick_push_velocity = 0.0
    
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
    
    move_and_slide()
    _update_visuals()
    
    if DebugOverlay.debug_enabled and DebugOverlay.show_hitboxes:
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
    sprite.play("walk_guard")
    
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
    # Aleatorizar parry_1 vs parry_2 (decidido al entrar al estado)
    if state_timer >= 0.3:
        _enter_state(State.GUARD_STANCE)


# ========== ENTER STATE ==========

func _enter_state(new_state: State) -> void:
    state = new_state
    state_timer = 0.0
    if new_state != State.ATTACK_RELEASE:
        attack_hitbox.monitoring = false
    
    # Animación específica al entrar
    match new_state:
        State.PARRY:
            sprite.play("parry_1" if randf() < 0.5 else "parry_2")


# ========== VISUALS ==========

func _update_visuals() -> void:
    var flip: bool = not facing_right
    sprite.flip_h = flip
    flashlight_hand.scale.x = -1.0 if flip else 1.0
    
    state_indicator.text = _get_state_indicator_text()
    state_indicator.modulate = _get_state_color()
    
    if DebugOverlay.debug_enabled:
        debug_label.text = "[%s] t=%.2f hit=%s" % [State.keys()[state], state_timer, last_hit_quality]


func _get_state_indicator_text() -> String:
    match state:
        State.PATROL: return ""
        State.GUARD_STANCE: return "G"
        State.GUARD_BROKEN: return "!"
        State.WINDUP: return "⚠"
        State.ATTACK_RELEASE: return "✖"
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


# ========== HIT REACTIONS (implementadas en Fase 8) ==========

func receive_hit_from(_attacker: Node2D, _is_charged: bool, _attack_type: String) -> void:
    pass  # Implementado en Fase 7/8


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
    draw_rect(Rect2($Hurtbox/CollisionShape2D.position - hurt_shape.size/2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))
    
    # Attack hitbox si activo
    if attack_hitbox.monitoring:
        var atk_shape: RectangleShape2D = $AttackHitbox/CollisionShape2D.shape
        var atk_pos: Vector2 = $AttackHitbox.position + $AttackHitbox/CollisionShape2D.position
        if not facing_right:
            atk_pos.x = -atk_pos.x
        draw_rect(Rect2(atk_pos - atk_shape.size/2, atk_shape.size), Color(1.0, 0.2, 0.2, 0.5))


# ========== STUBS (Fase 7-8) ==========

func get_position_tier_of(other: Node2D) -> String:
    var agent_forward: float = 1.0 if facing_right else -1.0
    var to_attacker_x: float = other.global_position.x - global_position.x
    
    if sign(to_attacker_x) != sign(agent_forward) and abs(to_attacker_x) > 30:
        return "detras"
    if abs(to_attacker_x) < 40:
        return "lateral"
    return "frente"
```

### 3.1 Actualizar GameManager

Añadir a `/scripts/game_manager.gd`:

```gdscript
# Array unificado de enemigos (genérico)
var enemies: Array = []

# Alias legacy para compatibilidad con guardia.gd existente
var guards: Array:
    get:
        return enemies


func register_enemy(enemy: Node) -> void:
    if enemy not in enemies:
        enemies.append(enemy)


func register_guard(guard: Node) -> void:
    # Alias legacy
    register_enemy(guard)
```

### Verificación Fase 3
- Agent patrulla entre A y B con sprite `walk_patrol`
- Linterna ilumina en dirección facing
- Kive entra en haz + sin columnas → GUARD_STANCE
- Kive agachado por detrás → no detectado
- Sin crashes al entrar en rango

---

## FASE 4 — Combat states del Agent (ya incluido en Fase 3)

Los estados combat (WINDUP, ATTACK_RELEASE, PARRY, HIT, STUNT, AIRTIME, FLOORSTUNT, DEAD, GUARD_BROKEN) están ya implementados en la Fase 3, pero las lógicas completas de HIT/STUNT/AIRTIME/FLOORSTUNT se completan en Fase 8.

Por ahora en Fase 4, verificar:
- GUARD_STANCE → persigue si Kive fuera de rango, espera si en rango
- WINDUP después de 1.5s en rango → cambia animación
- ATTACK_RELEASE activa hitbox → **pero Kive no tiene `receive_agent_hit` aún**

Para que no crashee al tocar a Kive: **Fase 5 incluye stub**.

### Verificación Fase 4
- Agent entra en combate cuando detecta a Kive
- Pasa de GUARD_STANCE → WINDUP → ATTACK_RELEASE → vuelve a GUARD_STANCE
- Stub de `receive_agent_hit` evita crashes (se implementa en Fase 5)

---

## FASE 5 — Inputs Kive + stub receive_agent_hit

### 5.1 Input Map

Añadir en project.godot:
- `attack_punch` → W
- `attack_kick` → Q

### 5.2 Variables nuevas en kive.gd

```gdscript
@export_group("Combat")
@export var attack_charge_time: float = 0.4

@export_group("Punch timings")
@export var punch_anticipation: float = 0.08
@export var punch_release: float = 0.15
@export var punch_recovery: float = 0.25

@export_group("Kick timings")
@export var kick_anticipation: float = 0.05
@export var kick_release: float = 0.10
@export var kick_recovery: float = 0.15

@export_group("Parry")
@export var parry_window_frames: int = 8  # 8f a 60fps = ~133ms

# Combat state
var is_attacking: bool = false
var current_attack_type: String = "none"
var is_casting: bool = false
var cast_timer: float = 0.0
var attack_phase: String = "none"
var attack_phase_timer: float = 0.0
var attack_is_charged: bool = false
var _parry_window_timer: float = 999.0
```

### 5.3 Stub de receive_agent_hit (PLACEHOLDER PARA FASE 9)

```gdscript
func receive_agent_hit(_agent: Node2D) -> void:
    # STUB — implementación completa en Fase 9
    # Por ahora evita crashes. Cuando se implemente Fase 9, esto se reemplaza.
    pass
```

**Crítico:** este stub debe existir desde Fase 5 para que Agent pueda llamarlo en Fase 4 sin crashear.

### 5.4 Lógica de input + bloqueo total durante combate

En `_physics_process`, justo después del early-return de `control_enabled`:

```gdscript
# === COMBAT INPUT (antes de cualquier otra lógica de movimiento) ===

# Punch (W)
if control_enabled and not is_diving and jump_state == "none":
    if Input.is_action_just_pressed("attack_punch") and not is_attacking and not is_casting:
        is_casting = true
        current_attack_type = "punch"
        cast_timer = 0.0
        _parry_window_timer = 0.0  # abre ventana de parry
        velocity.x = 0
    
    elif Input.is_action_pressed("attack_punch") and is_casting:
        cast_timer += delta
    
    elif Input.is_action_just_released("attack_punch") and is_casting:
        is_casting = false
        attack_is_charged = cast_timer >= attack_charge_time
        _start_attack("punch")
    
    # Kick (Q) - nunca cargable
    if Input.is_action_just_pressed("attack_kick") and not is_attacking and not is_casting:
        current_attack_type = "kick"
        attack_is_charged = false
        _start_attack("kick")

# === BLOQUEO TOTAL DURANTE COMBATE ===
# Si está atacando o casteando, Kive está anclado completamente.
# No se mueve, no salta, no se agacha, no se lanza.
if is_attacking or is_casting:
    velocity.x = 0
    # Si estaba saltando/diving, cancelar
    # (pero esto NO debería pasar porque el check de input combat requiere jump_state == "none" y not is_diving)

# Actualizar ventana de parry
_parry_window_timer += delta

# Actualizar attack si está atacando
if is_attacking:
    _process_attack(delta)
    return  # saltar el resto del procesamiento de movimiento
```

**Clave:** el `return` después de `_process_attack` bloquea todo movimiento normal (jump input, dive input, crouch input, movement horizontal) mientras Kive ataca. Es el bloqueo total que pidió tu hermano.

### 5.5 _start_attack y _process_attack

```gdscript
func _start_attack(attack_type: String) -> void:
    is_attacking = true
    current_attack_type = attack_type
    attack_phase = "anticipation"
    attack_phase_timer = 0.0
    
    # Snap al frame de contact correspondiente
    # (animaciones completas se implementan cuando el usuario las dibuje)
    if attack_type == "punch":
        if attack_is_charged:
            sprite.play("attack_charged_release")  # frame 13
        else:
            # PLACEHOLDER: saltar a frame contact directo
            sprite.play("punch_contact")  # frame 3
    else:  # kick
        sprite.play("kick_contact")  # frame 7


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
    
    match attack_phase:
        "anticipation":
            if attack_phase_timer >= anticip_dur:
                attack_phase = "release"
                attack_phase_timer = 0.0
                _execute_hit_check()
        
        "release":
            if attack_phase_timer >= release_dur:
                attack_phase = "recovery"
                attack_phase_timer = 0.0
        
        "recovery":
            if attack_phase_timer >= recovery_dur:
                attack_phase = "none"
                is_attacking = false
                attack_is_charged = false
                current_attack_type = "none"
```

### 5.6 SpriteFrames Kive combat

Añadir al recurso `kive_frames.tres`:

```
punch_contact → frame 3 del Kive_Punch_Kick spritesheet, sin loop
kick_contact → frame 7, sin loop
attack_charged_release → frame 13, sin loop
attack_charged_contact → frame 15, sin loop
attack_charged_recovery → frame 16, sin loop
```

### 5.7 is_parry_window_active público

```gdscript
func is_parry_window_active() -> bool:
    return _parry_window_timer <= (parry_window_frames / 60.0)
```

### Verificación Fase 5
- W tap → Kive ejecuta punch: snap a frame 3, phases anticipation/release/recovery
- W hold >0.4s → `attack_is_charged = true`, snap a frame 13
- Q → Kive ejecuta kick: snap a frame 7
- Durante cast/attack: **Kive no se mueve, no salta, no hace dive, no se agacha**
- Parry window se abre al pulsar W (aún no conectada al Agent completamente)

---

## FASE 6 — Hitboxes precisas punch/kick

### 6.1 Nodos en Kive.tscn

Añadir como hijos de Kive:

```
Hurtbox (Area2D)
│ - collision_layer: 1 (Player)
│ - collision_mask: 0
│ - z_index: 5
└── CollisionShape2D (RectangleShape2D 80x180)

PunchHitbox (Area2D, monitoring=false)
│ - collision_layer: 0
│ - collision_mask: 4 (Enemy)
│ - z_index: 5
└── CollisionShape2D (RectangleShape2D 80x40)

KickHitbox (Area2D, monitoring=false)
│ - collision_layer: 0
│ - collision_mask: 4 (Enemy)
│ - z_index: 5
└── CollisionShape2D (RectangleShape2D 100x40)
```

### 6.2 _execute_hit_check SIN await peligroso

```gdscript
# Flag para desactivar hitbox en siguiente frame
var _punch_hitbox_active_frames: int = 0
var _kick_hitbox_active_frames: int = 0


func _execute_hit_check() -> void:
    var facing: float = -1.0 if sprite.flip_h else 1.0
    
    var hitbox: Area2D
    if current_attack_type == "punch":
        hitbox = $PunchHitbox
        hitbox.position = Vector2(facing * 60, -50)
        _punch_hitbox_active_frames = 3  # 3 frames de duración
    else:
        hitbox = $KickHitbox
        hitbox.position = Vector2(facing * 70, -30)
        _kick_hitbox_active_frames = 3
    
    hitbox.monitoring = true
    
    # Detectar solapamientos INMEDIATAMENTE (no esperar al próximo frame)
    for body in hitbox.get_overlapping_bodies():
        if body.is_in_group("agent") and body.has_method("receive_hit_from"):
            body.receive_hit_from(self, attack_is_charged, current_attack_type)


# En _physics_process, al principio (antes de todo lo demás):
func _update_hitbox_flags() -> void:
    if _punch_hitbox_active_frames > 0:
        _punch_hitbox_active_frames -= 1
        if _punch_hitbox_active_frames == 0:
            $PunchHitbox.monitoring = false
    
    if _kick_hitbox_active_frames > 0:
        _kick_hitbox_active_frames -= 1
        if _kick_hitbox_active_frames == 0:
            $KickHitbox.monitoring = false
```

Llamar `_update_hitbox_flags()` al principio de `_physics_process`.

**Esto elimina el await peligroso.** La hitbox se queda activa 3 frames (~50ms a 60fps), suficiente para detectar hits, y se desactiva deterministicamente en el siguiente frame.

### 6.3 Draw de hitboxes debug en kive.gd

En `_draw()`:

```gdscript
func _draw() -> void:
    if not DebugOverlay.debug_enabled:
        return
    
    # Collision shape verde (ya existente)
    var col: CollisionShape2D = $CollisionShape2D
    var shape: RectangleShape2D = col.shape as RectangleShape2D
    var half: Vector2 = shape.size / 2.0
    var rect := Rect2(col.position - half, shape.size)
    draw_rect(rect, Color(0, 1, 0, 0.35), true)
    draw_rect(rect, Color(0, 1, 0, 0.8), false, 2.0)
    
    if not DebugOverlay.show_hitboxes:
        return
    
    # Hurtbox azul (siempre visible)
    var hurt_shape: RectangleShape2D = $Hurtbox/CollisionShape2D.shape
    var hurt_pos: Vector2 = $Hurtbox.position + $Hurtbox/CollisionShape2D.position
    draw_rect(Rect2(hurt_pos - hurt_shape.size/2, hurt_shape.size), Color(0.2, 0.5, 1.0, 0.3))
    
    # Punch hitbox rojo (solo si activo)
    if $PunchHitbox.monitoring:
        var p_shape: RectangleShape2D = $PunchHitbox/CollisionShape2D.shape
        var p_pos: Vector2 = $PunchHitbox.position + $PunchHitbox/CollisionShape2D.position
        draw_rect(Rect2(p_pos - p_shape.size/2, p_shape.size), Color(1.0, 0.2, 0.2, 0.5))
    
    # Kick hitbox naranja (solo si activo)
    if $KickHitbox.monitoring:
        var k_shape: RectangleShape2D = $KickHitbox/CollisionShape2D.shape
        var k_pos: Vector2 = $KickHitbox.position + $KickHitbox/CollisionShape2D.position
        draw_rect(Rect2(k_pos - k_shape.size/2, k_shape.size), Color(1.0, 0.5, 0.0, 0.5))
```

### Verificación Fase 6
- F1+F2: hurtbox azul de Kive visible
- Atacar W: flash rojo punch hitbox (~50ms)
- Atacar Q: flash naranja kick hitbox (~50ms)
- Hitboxes se flipean según facing
- Sin bugs de timing (desaparecen correctamente)

---

## FASE 7 — Sistema de calidad de golpe

### 7.1 Funciones en agent.gd (reemplazar stub de `receive_hit_from`)

```gdscript
func receive_hit_from(attacker: Node2D, is_charged: bool, attack_type: String) -> void:
    if state == State.DEAD or state == State.FLOORSTUNT:
        return
    
    var quality: String = _calculate_hit_quality(attacker, attack_type)
    
    # Charged punch sube un nivel
    if is_charged and attack_type == "punch":
        quality = _upgrade_quality(quality)
    
    last_hit_quality = quality
    
    # Efectos específicos del kick
    var should_break_guard: bool = false
    var should_force_stunt: bool = false
    var should_push: bool = false
    
    if attack_type == "kick":
        should_push = true
        
        # 30% chance de romper guard
        if state == State.GUARD_STANCE:
            if randf() < guard_broken_chance:
                should_break_guard = true
        
        # Kick por detrás → stunt forzado
        var pos_tier: String = _get_position_tier(attacker)
        if pos_tier == "detras":
            should_force_stunt = true
        
        # Kick durante WINDUP cancela el ataque del Agent
        if state == State.WINDUP:
            pass  # El hit reaction cancela naturalmente al cambiar estado
    
    # Debug
    if DebugOverlay.debug_enabled:
        print("[Agent hit] type=%s state=%s pos=%s charged=%s → %s (push=%s, break=%s, stunt=%s)" % [
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
```

### Verificación Fase 7
- Con DebugOverlay activo, cada hit imprime en consola el cálculo
- Punch PATROL → maestro siempre
- Punch tap guard frente → mal
- Punch cargado guard frente → normal (subió)
- Kick frente desprevenido → bueno (kick nunca maestro)
- Kick por detrás windup → bueno + stunt forzado

---

## FASE 8 — Hit reactions del Agent

### 8.1 _apply_hit_reaction

```gdscript
func _apply_hit_reaction(quality: String, force_stunt: bool, break_guard: bool, push: bool, attacker: Node2D) -> void:
    # Push del kick
    if push and attacker:
        var push_dir: float = sign(global_position.x - attacker.global_position.x)
        if push_dir == 0:
            push_dir = 1.0 if attacker.sprite.flip_h else -1.0
        _pending_kick_push_velocity = push_dir * (kick_push_distance / kick_push_duration)
        _pending_kick_push_frames = int(kick_push_duration * 60.0)  # frames a 60fps
    
    # Guard broken tiene prioridad
    if break_guard:
        _enter_state(State.GUARD_BROKEN)
        sprite.play("hit_light")
        return
    
    # Marcar stunt forzado por kick-detrás
    if force_stunt:
        last_hit_quality = "bueno_forced"
    
    _enter_state(State.HIT)
    sprite.play("hit_light")


func _process_hit(_delta: float) -> void:
    var hit_duration: float = 0.3
    
    if state_timer >= hit_duration:
        match last_hit_quality:
            "mal":
                _enter_state(State.GUARD_STANCE)
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
    flashlight.enabled = false


func _trigger_maestro_flash() -> void:
    var flash := ColorRect.new()
    flash.color = Color(1, 1, 1, 0.8)
    flash.size = Vector2(120, 220)
    flash.position = Vector2(-60, -110)
    add_child(flash)
    var tween: Tween = create_tween()
    tween.tween_property(flash, "color:a", 0.0, 0.3)
    tween.tween_callback(flash.queue_free)
```

### Verificación Fase 8
- Mal dado: Agent retrocede brevemente, vuelve a GUARD_STANCE
- Bueno: hit → stunt → floorstunt → GUARD_STANCE
- Maestro: hit → airtime (flash blanco) → DEAD permanente
- Kick: Agent se desplaza ~120px en dirección del kick
- Kick por detrás: Agent directo a FLOORSTUNT
- 30% de kicks en guard → GUARD_BROKEN 0.8s
- Durante GUARD_BROKEN, cualquier punch tiene calidad Bueno o Maestro

---

## FASE 9 — Parry real de Kive

### 9.1 Reemplazar stub de receive_agent_hit

```gdscript
func receive_agent_hit(agent: Node2D) -> void:
    if is_parry_window_active():
        _execute_parry(agent)
        return
    
    _receive_damage(agent)


func _execute_parry(agent: Node2D) -> void:
    if agent.has_method("receive_parry"):
        agent.receive_parry()
    
    _trigger_parry_flash()
    _parry_window_timer = 999.0  # cerrar ventana


func _trigger_parry_flash() -> void:
    # PLACEHOLDER: sprite verde
    sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
    var tween: Tween = create_tween()
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)


func _receive_damage(_agent: Node2D) -> void:
    # PLACEHOLDER: sprite rojo
    sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
    var tween: Tween = create_tween()
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
    
    # Respawn tras flash
    await get_tree().create_timer(0.3).timeout
    GameManager.player_caught()
```

### Verificación Fase 9
- Agent ataca Kive, W pulsado en primeros 8 frames del ataque → Agent stunned + flash verde
- Agent ataca Kive, sin W → flash rojo + respawn
- Tras parry, Agent en STUNT → Kive ataca → hit bueno/maestro garantizado

---

## FASE 10 — Placeholders visuales

Ya incluidos:
- Kive rojo al recibir damage (0.3s)
- Kive verde al hacer parry (0.5s)
- Flash blanco sobre Agent al golpe maestro
- Indicadores textuales sobre cabeza Agent

No requiere código adicional. Solo verificar visualmente.

---

## FASE 11 — Sustitución en Vagon1.tscn

1. Abrir Vagon1.tscn
2. Backup mental de Guardia existente
3. Eliminar instancia de Guardia (NO borrar el archivo Guardia.tscn ni guardia.gd)
4. Instanciar Agent.tscn en misma posición
5. Asignar `patrol_marker_a` y `patrol_marker_b`
6. Instanciar DebugHUD.tscn si no está
7. Probar

### Verificación Fase 11
- Vagon1 arranca con Agent patrullando
- Linterna ilumina el vagón
- Sigilo, crouch, hide zones, pause, respawn funcionan
- Combate ejecutable con W y Q

---

## FASE 12 — Documentación

Actualizar README.md con:

**"Sistema de combate"**
- Agent como único enemigo
- Estados del Agent (tabla)
- Inputs: W punch (tap/cargado), Q kick
- Tabla de calidad (punch y kick)
- Parry window 8 frames, atado a W
- Placeholders visuales rojo/verde

**"Debug avanzado"**
- F1 toggle general
- F2 toggle hitboxes
- F3 toggle timeline
- F4 toggle cono linterna
- Panel HUD

---

## VERIFICACIÓN FINAL

1. Juego arranca sin errores
2. Agent patrulla con sprite `walk_patrol` + linterna
3. Linterna detecta + respeta columnas
4. Oído funciona como antes
5. W tap → punch normal (snap a frame 3)
6. W cargado >0.4s → punch cargado (snap a frame 13)
7. Q → kick (snap a frame 7), empuja Agent ~120px
8. 30% de kicks en guard rompen guardia → GUARD_BROKEN 0.8s
9. Kick por detrás → Agent directo a FLOORSTUNT
10. Hitboxes separadas visibles (F1+F2)
11. Calidad de golpe correcta según tabla (print debug en consola)
12. Hit reactions se ramifican: mal→GUARD, bueno→STUNT→FLOORSTUNT, maestro→AIRTIME→DEAD
13. Parry con W en 8 frames iniciales del ataque → Agent stunned
14. Sin parry → Kive flash rojo → respawn
15. Durante cast/attack: Kive totalmente bloqueado (no salto, no dive, no crouch, no movimiento)
16. DebugHUD muestra toda la info
17. Sigilo, crouch, hide zones, pause, respawn siguen funcionando
18. F1/F2/F3/F4 togglean

Commit final: `"combat mvp v3"`

---

## ESTIMACIÓN

4-7 horas ejecución + 2-5 sesiones calibración. Calibrar: timings punch/kick, `guard_to_windup_time`, `windup_duration`, `parry_window_frames`, `guard_broken_chance`, `kick_push_distance`.
