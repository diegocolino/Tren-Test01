# Refactor de Kive a State Machine — Plan Completo

> **Documento vivo.** Léelo entero antes de empezar.
> **Audiencia:** Claude Code (ejecutor) + tú (revisor humano).
> **Objetivo:** Refactorizar `kive.gd` (~817 líneas) a una arquitectura de State Machine modular y extensible, sin cambiar el feel del juego.
> **Pre-requisito:** La limpieza de nomenclatura previa (cast→charge, jump_air→jump_rise, etc.) debe estar completada y commiteada con tag `pre-state-machine`. Si no lo está, parar y avisar.

---

## 🎯 Reglas de oro (no negociables)

1. **Esto es un refactor, no un rediseño.** El feel del juego debe ser **idéntico** al final de cada fase. Si algo cambia de comportamiento, es un bug.
2. **`kive.gd` es el dueño de las físicas.** Posee `velocity`, expone `move_and_slide()` para que los estados lo llamen.
3. **Los estados llaman `kive.move_and_slide()` al final de su `physics_update()`.** La state machine NO lo llama por su cuenta.
4. **Una fase, un commit (mínimo).** Verificar el juego después de cada fase con la checklist (`MANUAL_TESTING_CHECKLIST.md`).
5. **Si algo es ambiguo, preguntar antes de implementar.** No inventar funcionalidad nueva.
6. **Convención de nombres:** prefijo `kive_*` SOLO para archivos específicos no reutilizables (`kive.gd`, `kive_stats.gd`, `kive_animator.gd`). Estados y clases base SIN prefijo.
7. **`class_name State` y `class_name StateMachine`** (sin prefijo Kive — son reutilizables para Yeri y enemigos en el futuro).

---

## 📜 Contrato externo (lo que tiene que seguir funcionando)

Después del refactor, los siguientes scripts NO se tocan (excepto `debug_hud.gd` en FASE 7):

### `agent.gd` lee:
- `is_crouched`, `is_hidden`, `velocity.x`, `global_position`
- llama `is_sprinting()`

### `occluder_sync.gd` lee:
- `is_hidden`, `sprite` (vía `get_parent()`)

### `game_manager.gd` llama:
- `set_control_enabled(bool)`, `reset_state()`
- asigna `global_position`

**Estos puntos son SAGRADOS.** Después del refactor deben funcionar exactamente igual sin tocar esos scripts.

### Eliminados:
- `guardia.gd` → legacy, se borra en FASE 0.

### Actualizados:
- `debug_hud.gd` → rework completo en FASE 7 para leer del nuevo sistema.

---

## 🗂️ Arquitectura objetivo

```
res://player/
├── kive.tscn
├── kive.gd                              ← orquestador, ~200 líneas
├── stats/
│   ├── kive_stats.gd                    ← Resource con todos los @export
│   └── kive_stats_default.tres          ← valores por defecto
├── state_machine/
│   ├── state.gd                         ← clase base State (genérica)
│   └── state_machine.gd                 ← StateMachine (genérica)
├── states/
│   ├── movement/
│   │   ├── idle.gd
│   │   ├── walk.gd                      ← walk + run (mismo estado, speed distinta)
│   │   ├── crouch_idle.gd
│   │   ├── crouch_walk.gd
│   │   ├── jump_anticipation.gd
│   │   ├── jump_rise.gd
│   │   ├── jump_fall.gd
│   │   ├── jump_landing.gd
│   │   ├── air_jump.gd
│   │   ├── dive_ground.gd
│   │   ├── dive_air.gd
│   │   └── dive_landing.gd
│   ├── combat/
│   │   ├── punch.gd
│   │   ├── punch_charging.gd
│   │   ├── punch_charged.gd             ← caso complejo (lunge aéreo)
│   │   ├── kick.gd
│   │   ├── execution.gd                 ← desde hidden
│   │   └── damaged.gd
│   └── stealth/
│       └── hidden.gd
└── components/
    └── kive_animator.gd                  ← stub inicial
```

### Escena `kive.tscn` (después del refactor)

```
Kive (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── Camera2D
├── DustParticles
├── Hurtbox (Area2D)
├── PunchHitbox (Area2D)
├── KickHitbox (Area2D)
├── LightOccluder2D
├── Animator (Node)
└── StateMachine (Node) [initial_state=Idle]
    ├── Idle
    ├── Walk
    ├── CrouchIdle
    ├── CrouchWalk
    ├── JumpAnticipation
    ├── JumpRise
    ├── JumpFall
    ├── JumpLanding
    ├── AirJump
    ├── DiveGround
    ├── DiveAir
    ├── DiveLanding
    ├── Punch
    ├── PunchCharging
    ├── PunchCharged
    ├── Kick
    ├── Execution
    ├── Damaged
    └── Hidden
```

Los estados son **hijos planos** del StateMachine (no anidados en sub-Nodes). La estructura de carpetas `states/movement/`, `states/combat/`, `states/stealth/` es solo organización de archivos `.gd`.

---

## 🔄 Mapa de transiciones

```
GROUND
──────
Idle ←→ Walk
  ↕        ↕
CrouchIdle ←→ CrouchWalk
  ↓
Hidden (auto: crouch + zone + safe)
  └→ Execution (Q desde hidden)

AIR
───
Idle/Walk → JumpAnticipation (space, standing)
Walk → JumpRise (space, running = jump inmediato)
JumpAnticipation → JumpRise (release space)
JumpRise → JumpFall (velocity.y > 0)
JumpFall → JumpLanding (is_on_floor)
JumpLanding → Idle/Walk (timer)
Any air → AirJump (space + air_jumps_left > 0)
AirJump → JumpFall (velocity.y > 0)

DIVE
────
Walk → DiveGround (dive + moving)
Any air → DiveAir (dive)
DiveGround/DiveAir → DiveLanding (stops/lands)
DiveGround/DiveAir → JumpRise/AirJump (space cancela dive)

COMBAT
──────
Idle/Walk/CrouchIdle → PunchCharging (W press)
PunchCharging → Punch (W release, no charged)
PunchCharging → PunchCharged (W release, charged)
PunchCharged → JumpFall/JumpLanding (al aterrizar)
Idle/Walk/CrouchIdle → Kick (Q press)
Hidden → Execution (Q press)
Cualquier estado → Damaged (receive_agent_hit sin parry activo)

EDGE FALL
─────────
Idle/Walk → JumpFall (se cae del borde)
```

**Regla:** cada estado chequea sus propias condiciones de salida en `physics_update()` y devuelve el `StringName` del siguiente estado, o `&""` para quedarse.

---

## 📊 Shared state — ¿Dónde vive cada cosa?

| Dato | Vive en | Tipo | Por qué |
|---|---|---|---|
| `velocity`, `global_position` | kive.gd | built-in | Son de CharacterBody2D / Node2D |
| `is_crouched` | kive.gd | var pública | Leído por agent.gd, debug_hud |
| `is_hidden` | kive.gd | var pública | Leído por agent.gd, occluder_sync, debug_hud |
| `control_enabled` | kive.gd | var pública | Set externo desde GameManager |
| `_air_jumps_left` | kive.gd | var pública | Persiste entre JumpRise → JumpFall → AirJump |
| `_nearby_hide_zones` | kive.gd | var | Signal-driven, persistente |
| `parry_window_timer` | kive.gd | var | Tick en `_process`, leído por `is_parry_window_active()` |
| `_punch_hitbox_active_frames`, `_kick_hitbox_active_frames` | kive.gd | var | Vida de hitboxes, gestionado por kive |
| `is_attacking` | kive.gd | **computed property** | Traduce del estado actual |
| `is_punch_charging` | kive.gd | **computed property** | Traduce del estado actual |
| `is_diving` | kive.gd | **computed property** | Traduce del estado actual |
| `jump_state` (string) | kive.gd | **computed property** | Compat con debug_hud |
| `punch_charge_timer` | dentro de PunchCharging | var del estado | Solo existe durante ese estado |
| `attack_phase`, `current_attack_type` | dentro de cada estado de combat | var local | Detalles internos del estado |
| `is_finisher` | dentro de Execution | var local | Solo aplica en ejecución |

**Patrón:** los flags públicos como `is_crouched` los seteán los estados en `enter()` y los limpian en `exit()`. Los flags computed se calculan al vuelo desde el estado actual de la state machine.

---

## 🧠 Caso complejo: PunchCharged (lunge aéreo)

El punch cargado es un ataque que aplica impulso, vuela por el aire, y aterriza. Es el estado más complejo:

1. `enter()`: aplica lunge velocity (interpolado 40%-100% por charge_ratio), setea flags
2. `physics_update()`: gestiona fases internas (anticipation → release → recovery), aplica gravedad
3. En aire durante recovery: mantiene sprite de contacto, espera aterrizaje
4. `is_on_floor()` durante recovery → transición a `&"JumpLanding"`
5. Si cae demasiado rápido sin aterrizar → transición a `&"JumpFall"`

**Las fases internas (anticipation/release/recovery) se gestionan con vars locales del estado, NO como estados separados.** Son micro-fases de 80-250ms, demasiado cortas y acopladas para justificar estados propios.

---

## 🚦 FASES DE IMPLEMENTACIÓN

> **Cada fase = un commit mínimo. Verificar la checklist manual entre fases.**

---

### FASE 0 — Limpieza inicial e infraestructura

#### 0.1 Borrar `guardia.gd`
1. Eliminar el archivo.
2. Si alguna escena lo referencia, actualizar para usar `agent.gd` o eliminarla.
3. Grep en todo el proyecto buscando `guardia` para verificar que no queden referencias huérfanas.

#### 0.2 Crear estructura de carpetas
```
res://player/
├── stats/
├── state_machine/
├── states/
│   ├── movement/
│   ├── combat/
│   └── stealth/
└── components/
```

#### 0.3 Crear `stats/kive_stats.gd`

Un único Resource con TODOS los `@export` actuales de `kive.gd`, organizados con `@export_group` y `@export_subgroup`. Usar `@export_range` donde tenga sentido.

```gdscript
class_name KiveStats extends Resource

# ============ MOVEMENT ============
@export_group("Movement")
@export_subgroup("Horizontal")
## Velocidad cuando se mantiene "run" presionado (Kive corre por defecto).
@export var walk_speed: float = 400.0
@export var run_speed: float = 800.0
@export var crouch_walk_speed: float = 200.0
@export_range(0.0, 1.0, 0.05) var air_control_factor: float = 0.8

@export_subgroup("Physics")
@export var gravity: float = 2400.0

@export_subgroup("Crouch")
@export_range(0.1, 1.0, 0.05) var crouch_height_multiplier: float = 0.7

# ============ JUMP ============
@export_group("Jump")
@export_subgroup("Standard")
@export var jump_velocity_min: float = -800.0
@export var jump_velocity_max: float = -1200.0
@export var jump_charge_time: float = 0.4

@export_subgroup("Air")
@export_range(0, 5) var max_air_jumps: int = 1
@export var air_jump_velocity: float = -800.0

# ============ DIVE ============
@export_group("Dive")
@export var dive_speed: float = 1200.0
@export var dive_max_duration: float = 1.2
@export var dive_friction: float = 800.0

# ============ COMBAT ============
@export_group("Combat")
@export_subgroup("Charge")
@export var attack_charge_time: float = 0.4
@export var attack_charge_time_max: float = 2.4

@export_subgroup("Punch Timings")
@export var punch_anticipation: float = 0.08
@export var punch_release: float = 0.15
@export var punch_recovery: float = 0.25

@export_subgroup("Kick Timings")
@export var kick_anticipation: float = 0.05
@export var kick_release: float = 0.10
@export var kick_recovery: float = 0.15

@export_subgroup("Charged Punch Lunge")
@export var charged_lunge_speed_x: float = 2400.0
@export var charged_lunge_speed_y: float = -1200.0

@export_subgroup("Parry")
@export_range(1, 120) var parry_window_frames: int = 40
```

**Importante:** Copiar valores por defecto exactos de `kive.gd`. Las constantes (`step_height`, `anticipation_duration`, `charge_threshold`, `charge_cancel_time`, `default_collision_height`) se quedan como `const` en `kive.gd` por ahora.

#### 0.4 Crear `kive_stats_default.tres`

Desde el editor:
1. Click derecho en `res://player/stats/` → New Resource
2. Tipo: `KiveStats`
3. Nombre: `kive_stats_default.tres`
4. Verificar que se guarda con todos los valores por defecto.

#### 0.5 Crear `state_machine/state.gd`

```gdscript
## Clase base para todos los estados de cualquier state machine del proyecto.
## Reutilizable para Kive, Yeri (futuro), enemigos (futuro).
class_name State extends Node

# Inyectado por StateMachine al _ready
var owner_node: Node
var sm: StateMachine

## Llamado al entrar al estado. msg permite pasar datos del estado anterior.
func enter(_prev_state: StringName, _msg: Dictionary = {}) -> void:
    pass

## Llamado al salir del estado.
func exit() -> void:
    pass

## Cada physics frame. Devuelve StringName del siguiente estado, o &"" para quedarse.
func physics_update(_delta: float) -> StringName:
    return &""

## Llamado por el animator cuando termina una animación.
func on_animation_finished(_anim_name: String) -> void:
    pass
```

#### 0.6 Crear `state_machine/state_machine.gd`

```gdscript
class_name StateMachine extends Node

signal state_changed(old_state: StringName, new_state: StringName)

@export var initial_state: NodePath

var owner_node: Node
var current_state: State
var current_state_name: StringName = &""
var states: Dictionary = {}  # StringName -> State

func _ready() -> void:
    owner_node = get_parent()

    for child in get_children():
        if child is State:
            child.owner_node = owner_node
            child.sm = self
            states[StringName(child.name)] = child

    var start: State = null
    if initial_state and not initial_state.is_empty():
        start = get_node(initial_state) as State
    elif states.size() > 0:
        start = states.values()[0]

    if start:
        current_state = start
        current_state_name = StringName(start.name)
        start.enter(&"", {})

func _physics_process(delta: float) -> void:
    if current_state:
        var next: StringName = current_state.physics_update(delta)
        if next != &"" and next != current_state_name:
            transition_to(next)

func transition_to(target: StringName, msg: Dictionary = {}) -> void:
    if not states.has(target):
        push_error("[StateMachine] Estado inexistente: %s" % target)
        return

    var old_name: StringName = current_state_name
    if current_state:
        current_state.exit()

    current_state = states[target]
    current_state_name = target
    current_state.enter(old_name, msg)
    state_changed.emit(old_name, target)

func is_in_state(state_name: StringName) -> bool:
    return current_state_name == state_name
```

#### 0.7 Crear `components/kive_animator.gd` (stub)

```gdscript
## Componente que gestionará animaciones cross-state.
## Por ahora es un stub. Se rellenará en fases posteriores si hace falta.
class_name KiveAnimator extends Node

var kive: Node

func _ready() -> void:
    kive = get_parent()
```

#### 0.8 Modificar mínimamente `kive.gd`

**SOLO esto:**

1. Añadir al inicio:
   ```gdscript
   class_name Kive
   ```

2. Añadir cerca del top:
   ```gdscript
   @export var stats: KiveStats
   ```

3. **NO borrar nada.** Los `@export var walk_speed` etc. siguen ahí coexistiendo.

4. Añadir al final del `_ready()`:
   ```gdscript
   assert(stats != null, "[Kive] Falta asignar KiveStats al nodo Kive")
   ```

#### Verificación FASE 0
- El juego sigue funcionando idéntico (los nuevos archivos no se usan aún).
- En el inspector de Kive aparece el campo "Stats".
- Asignar `kive_stats_default.tres` desde el editor.
- `guardia.gd` no existe ni hay referencias rotas.
- Pasar checklist manual completa.

**Commit:** `feat(player): scaffold state machine infrastructure + remove legacy guardia`

---

### FASE 1 — Shim AllInOne (juego idéntico vía state machine)

#### 1.1 Añadir `StateMachine` a `kive.tscn`

```
Kive
├── ... (nodos existentes sin tocar)
└── StateMachine (Node) ← state_machine.gd
    └── AllInOne (Node) ← states/all_in_one.gd  [TEMPORAL]
```

Configurar `StateMachine.initial_state` apuntando a `AllInOne`.

#### 1.2 Crear `states/all_in_one.gd`

Estado temporal que contiene **TODA la lógica actual de `_physics_process` de `kive.gd`**. Se irá vaciando conforme extraemos estados reales.

```gdscript
## Estado temporal que contiene toda la lógica de _physics_process.
## Se irá vaciando conforme extraemos estados reales.
class_name AllInOne extends State

var kive: Kive

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
    kive = owner_node as Kive

func physics_update(delta: float) -> StringName:
    if not kive.control_enabled:
        return &""
    kive.run_legacy_physics(delta)
    return &""
```

#### 1.3 Refactorizar `kive.gd`

1. Renombrar `_physics_process(delta)` → `run_legacy_physics(delta)` (público, sin `_`).
2. **Borrar** `_physics_process` de `kive.gd`. La state machine procesa por su cuenta.
3. Mover el tick de `parry_window_timer` y `_tick_hitbox_lifetimes()` a un nuevo `_process(delta)`:
   ```gdscript
   func _process(delta: float) -> void:
       if not control_enabled:
           return
       parry_window_timer += delta
       _tick_hitbox_lifetimes()
   ```

#### Verificación FASE 1
- El juego funciona EXACTAMENTE igual que antes.
- La diferencia es que ahora la lógica se ejecuta desde `AllInOne.physics_update`.
- Pasar checklist manual completa.

**Commit:** `refactor(kive): wire state machine via AllInOne shim`

---

### FASE 2 — Extraer Idle, Walk

#### Estados a crear

`states/movement/idle.gd`:
```gdscript
class_name Idle extends State

var kive: Kive
var stats: KiveStats

func enter(_prev: StringName, _msg: Dictionary = {}) -> void:
    kive = owner_node as Kive
    stats = kive.stats
    kive.sprite.play("idle")

func physics_update(delta: float) -> StringName:
    if not kive.control_enabled:
        return &""

    # Si ocurre cualquier cosa que Idle no gestiona → volver a AllInOne
    if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dive") \
        or Input.is_action_just_pressed("attack_punch") or Input.is_action_just_pressed("attack_kick") \
        or Input.is_action_just_pressed("crouch") or not kive.is_on_floor():
        return &"AllInOne"

    # Gravedad
    kive.velocity.y += stats.gravity * delta
    # Input horizontal
    kive.apply_horizontal_input(false)

    var dir_input: float = Input.get_axis("move_left", "move_right")
    if dir_input != 0:
        return &"Walk"

    kive.move_and_slide()
    kive.update_sprite_direction()
    return &""
```

`states/movement/walk.gd`: similar, gestiona walk + run según `Input.is_action_pressed("run")`.

#### Cambios en `kive.gd`

Mover funciones helper a métodos públicos:
- `_apply_horizontal_input` → `apply_horizontal_input` (público)
- `_update_sprite_direction` → `update_sprite_direction` (público)
- `_try_step_up` → `try_step_up` (público)

#### Cambios en `AllInOne`

Detectar si toca Idle/Walk y delegar:
```gdscript
func physics_update(delta: float) -> StringName:
    if not kive.control_enabled:
        return &""

    if kive.is_on_floor() and not kive.is_attacking and not kive.is_punch_charging \
        and not kive.is_diving and kive.jump_state == "none" and not kive.is_crouched:
        var dir_input: float = Input.get_axis("move_left", "move_right")
        return &"Walk" if dir_input != 0 else &"Idle"

    kive.run_legacy_physics(delta)
    return &""
```

#### Verificación FASE 2
- Idle y Walk funcionan vía estados nuevos.
- TODO lo demás (jump, dive, combat, crouch) sigue funcionando vía AllInOne.
- Pasar checklist manual completa.

**Commit:** `refactor(kive): extract Idle and Walk states`

---

### FASE 3 — Extraer CrouchIdle, CrouchWalk, Hidden

Crear los tres estados. Mover lógica de:
- Crouch toggle/hold (líneas ~134-144)
- Auto-hide / unhide (líneas ~146-152)
- Ejecución desde hidden con Q (líneas ~125-132)

`AllInOne` deja de gestionar lo relacionado con crouch/hide.

**Importante:** `is_crouched` y `is_hidden` siguen siendo variables públicas en `kive.gd`. Los estados las setean en `enter()` y las limpian en `exit()`. Esto garantiza que `agent.gd` y `occluder_sync.gd` sigan funcionando sin tocarlos.

#### Verificación FASE 3
- Crouch toggle/hold funciona (con ambos modos del PauseMenu).
- Auto-hide en zonas funciona.
- Unhide al levantarse o salir de zona funciona.
- agent.gd sigue detectando correctamente.
- Pasar checklist manual completa.

**Commit:** `refactor(kive): extract CrouchIdle, CrouchWalk, Hidden states`

---

### FASE 4 — Extraer estados de Jump

Crear:
- `JumpAnticipation` (líneas ~438-454)
- `JumpRise` (parte de `_process_normal_movement` cuando subiendo)
- `JumpFall` (parte aérea cayendo)
- `JumpLanding` (líneas ~491-494, gestiona contact + recovery)
- `AirJump` (parte de double jump)

`jump_state` (string) deja de ser una variable real. Como `debug_hud` lo lee, se convierte en propiedad **computed**:

```gdscript
# en kive.gd
var jump_state: String:
    get:
        match state_machine.current_state_name:
            &"JumpAnticipation": return "anticipation"
            &"JumpRise": return "jump_rise"
            &"JumpFall": return "falling"
            &"JumpLanding": return "landing_impact"
            &"AirJump": return "air_jump_rise"
            _: return "none"
```

Así `debug_hud` sigue mostrando lo mismo sin tocar nada hasta FASE 7.

#### Verificación FASE 4
- Salto estático con carga (corto/medio/largo).
- Running jump (sin charge).
- Aterrizajes.
- Air jump.
- Salto cancelado (mantener jump > 4s).
- Pasar checklist manual completa.

**Commit:** `refactor(kive): extract Jump states (Anticipation, Rise, Fall, Landing, AirJump)`

---

### FASE 5 — Extraer estados de Dive

Crear:
- `DiveGround`
- `DiveAir`
- `DiveLanding`

Mover lógica de `_start_ground_dive`, `_start_air_dive`, `_process_dive`, `_handle_dive_landing`.

`is_diving` se convierte en computed:
```gdscript
var is_diving: bool:
    get:
        return state_machine.current_state_name in [&"DiveGround", &"DiveAir", &"DiveLanding"]
```

#### Verificación FASE 5
- Ground dive con jump cancel.
- Air dive con landing slide.
- Dive de larga duración (cancelar al máximo timeout).
- Pasar checklist manual completa.

**Commit:** `refactor(kive): extract Dive states`

---

### FASE 6 — Extraer estados de Combat

> **Recomendación:** dividir esta fase en sub-commits por la complejidad.
> - 6a: `Punch` + `Kick`
> - 6b: `PunchCharging` + `PunchCharged`
> - 6c: `Execution` + `Damaged`

Crear:
- `Punch` — punch normal
- `PunchCharging` — mantener W (gestiona también la apertura de la ventana de parry)
- `PunchCharged` — release con lunge aéreo (ver caso complejo abajo)
- `Kick`
- `Execution` — desde Hidden + Q
- `Damaged` — recibir hit sin parry activo

#### Caso especial: PunchCharged

Es el estado más complejo. Tiene fases internas (anticipation → release → recovery) que **NO se separan en estados propios** — son micro-fases gestionadas con vars locales del estado.

```gdscript
class_name PunchCharged extends State

var kive: Kive
var stats: KiveStats
var phase: String = "anticipation"  # anticipation, release, recovery
var phase_timer: float = 0.0
var charge_ratio: float = 0.0

func enter(_prev: StringName, msg: Dictionary = {}) -> void:
    kive = owner_node as Kive
    stats = kive.stats
    charge_ratio = msg.get("charge_ratio", 1.0)

    # Aplicar lunge inicial (interpolado 40%-100%)
    var impulse: float = lerpf(0.4, 1.0, charge_ratio)
    var facing: float = -1.0 if kive.sprite.flip_h else 1.0
    kive.velocity.x = facing * stats.charged_lunge_speed_x * impulse
    kive.velocity.y = stats.charged_lunge_speed_y * impulse

    kive.sprite.play("attack_charged_airtime")
    phase = "anticipation"
    phase_timer = 0.0

func physics_update(delta: float) -> StringName:
    kive.velocity.y += stats.gravity * delta
    phase_timer += delta

    match phase:
        "anticipation":
            if phase_timer >= stats.punch_anticipation:
                phase = "release"
                phase_timer = 0.0
                kive.sprite.play("attack_charged_contact")
                kive.activate_punch_hitbox()
        "release":
            if phase_timer >= stats.punch_release:
                phase = "recovery"
                phase_timer = 0.0
        "recovery":
            if kive.is_on_floor():
                return &"JumpLanding"
            if kive.velocity.y > 200:
                return &"JumpFall"

    kive.move_and_slide()
    return &""
```

#### Flags computed adicionales

```gdscript
# en kive.gd
var is_attacking: bool:
    get:
        return state_machine.current_state_name in [
            &"Punch", &"PunchCharged", &"Kick", &"Execution"
        ]

var is_punch_charging: bool:
    get:
        return state_machine.current_state_name == &"PunchCharging"
```

`punch_charge_timer` vive dentro del estado `PunchCharging` como variable local. `debug_hud` se actualizará en FASE 7 para leerlo desde ahí.

#### Parry: NO es un estado

La ventana de parry es un timer (`parry_window_timer` en `kive.gd`). Sigue tickeándose en `_process`. El estado `PunchCharging` lo abre en su `enter()`.

```gdscript
# en kive.gd
func receive_agent_hit(agent: Node2D) -> void:
    if is_parry_window_active():
        _resolve_parry(agent)
    else:
        state_machine.transition_to(&"Damaged", {"agent": agent})
```

#### Verificación FASE 6
- Punch normal.
- Punch cargado mínimo (justo al pasar threshold).
- Punch cargado al máximo.
- Punch cargado en el aire (lunge → aterrizaje correcto).
- Kick.
- Ejecución desde Hidden (Q sin levantarse).
- Recibir daño normal → game over.
- Parry exitoso (recibir golpe durante PunchCharging).
- Pasar checklist manual completa.

**Commit:** `refactor(kive): extract Combat states (Punch, PunchCharged, Kick, Execution, Damaged)`

---

### FASE 7 — Limpieza final + actualizar debug_hud.gd

#### 7.1 Eliminar AllInOne

A estas alturas, `AllInOne` debería estar vacío o casi vacío. Eliminarlo del proyecto y de la escena.

#### 7.2 Limpiar `kive.gd`

**Eliminar funciones muertas:**
- `_process_normal_movement`, `_process_anticipation`, `_release_jump`, `_cancel_charged_jump`, `_process_landing`
- `_process_dive`, `_handle_dive_landing`, `_start_ground_dive`, `_start_air_dive`
- `_start_attack`, `_process_attack`, `_activate_hitbox` (ya gestionado por estados)
- `run_legacy_physics` (ya no existe lógica legacy)

**Eliminar variables muertas:**
- `jump_timer`, `_is_charging_jump`, `_jump_charge_timer`, `_dive_timer`, `_dive_direction`, `_was_in_air`, `_was_moving_at_jump`
- `is_punch_charging` real (ahora computed), `punch_charge_timer` (vive en estado)
- `attack_phase`, `attack_phase_timer`, `is_punch_charged`, `current_attack_type`
- `is_attacking` real (ahora computed), `is_diving` real (ahora computed)
- `is_finisher` (ya solo dentro de Execution)

**Mantener:**
- `is_crouched`, `is_hidden`, `control_enabled`
- `_air_jumps_left`, `_nearby_hide_zones`
- `_punch_hitbox_active_frames`, `_kick_hitbox_active_frames`
- `parry_window_timer`

**Mantener funciones públicas (API externa):**
- `set_control_enabled`, `reset_state`
- `is_sprinting`, `is_parry_window_active`, `get_charge_ratio`, `receive_agent_hit`
- `apply_horizontal_input`, `update_sprite_direction`, `try_step_up`, `update_collision_shape`

**Verificar:** `kive.gd` debe estar entre 180-220 líneas.

#### 7.3 Reorganizar carpetas (si no se hizo antes)

- `scripts/kive.gd` → `player/kive.gd`
- `scenes/Kive.tscn` → `player/kive.tscn`
- Actualizar referencias en `Vagon1.tscn` y otras escenas que instancien Kive.

#### 7.4 Rework de debug_hud.gd

Actualizar para leer del nuevo sistema:

```gdscript
# Antes
info += "  jump=%s dive=%s\n" % [kive.jump_state, str(kive.is_diving)]
info += "  charging=%s atk=%s\n" % [str(kive.is_punch_charging), str(kive.is_attacking)]
if kive.is_punch_charging:
    info += "  charge_t=%.2fs\n" % kive.punch_charge_timer

# Después
var sm: StateMachine = kive.state_machine
info += "  state=%s\n" % str(sm.current_state_name)
info += "  crouch=%s hide=%s\n" % [str(kive.is_crouched), str(kive.is_hidden)]
if sm.current_state_name == &"PunchCharging":
    var charging_state: PunchCharging = sm.current_state as PunchCharging
    info += "  charge_t=%.2fs (charged=%s)\n" % [
        charging_state.charge_timer,
        str(charging_state.charge_timer >= kive.stats.attack_charge_time)
    ]
```

Esto requiere exponer en `kive.gd`:
```gdscript
@onready var state_machine: StateMachine = $StateMachine
```

#### 7.5 Verificación FINAL completa

- Pasar checklist manual completa, dos veces, en sesiones distintas.
- Si hay tiempo, jugar 10 minutos al Vagón 1 normalmente y ver si algo se siente raro.
- Verificar que `agent.gd` detecta exactamente igual que antes (mismas distancias, mismas reacciones).
- Verificar que `occluder_sync` actualiza la silueta correctamente al esconderse.
- Verificar que `GameManager.player_caught()` respawnea correctamente.

**Commit:** `refactor(kive): finalize state machine, cleanup, update debug_hud`

(Opcional: `git tag state-machine-complete`)

---

## 📁 Resumen final de archivos

### Nuevos (~21):
- `player/stats/kive_stats.gd`, `kive_stats_default.tres`
- `player/state_machine/state.gd`, `state_machine.gd`
- `player/components/kive_animator.gd`
- `player/states/movement/`: idle, walk, crouch_idle, crouch_walk, jump_anticipation, jump_rise, jump_fall, jump_landing, air_jump, dive_ground, dive_air, dive_landing
- `player/states/combat/`: punch, punch_charging, punch_charged, kick, execution, damaged
- `player/states/stealth/hidden.gd`

### Modificados (3):
- `player/kive.gd` (de ~817 → ~200 líneas)
- `player/kive.tscn` (estructura nueva con StateMachine)
- `scripts/debug_hud.gd` (rework completo en FASE 7)

### Eliminados (1):
- `scripts/guardia.gd` (legacy, FASE 0)

### NO tocados:
- `agent.gd`, `occluder_sync.gd`, `game_manager.gd`, `kive_music.gd`, `pause_menu.gd`, `alarm_light.gd`, `flashlight_system.gd`, `train_*`, `front_parallax.gd`, `debug_overlay.gd`, `vagon1.gd`

---

## 🔮 Lo que viene después (NO en este refactor)

Cuando esto esté completado y estable:

1. **Sistema de combos / input queue** sobre la nueva arquitectura.
2. **Wall slide / Wall jump / Climb** — añadir estados nuevos sin tocar los existentes.
3. **Refactor de `agent.gd`** a state machine reutilizando `State` y `StateMachine`.
4. **Sistema de poderes Sensible** — probablemente hot-swap del Resource `KiveStats` cuando se desbloqueen poderes.
