# Parche de limpieza y optimización — Cubo 1 + Cubo 2

> Tras auditoría completa del código del proyecto, este parche aplica fixes técnicos antes de seguir añadiendo features. NO añade mecánicas nuevas, NO cambia comportamiento observable del juego (salvo los bugs que arregla). Es puro trabajo de limpieza.

---

## ORDEN OBLIGATORIO

**CUBO 1 primero, completo, con verificación. Después CUBO 2.** No mezclar.

Esto es crítico: si algo se rompe, tenemos que saber en qué cubo fue. Terminar Cubo 1, probar que el juego arranca y funciona, luego abordar Cubo 2.

Antes de empezar: hacer commit git de estado actual con mensaje `"pre-cleanup v1"`.

---

## CUBO 1 — Fixes críticos (bugs reales + trampas evitables)

### 1.1 Fix bug: typo en crouch_walk_speed
**Archivo:** `scripts/kive.gd` línea 14
```gdscript
# Antes:
@export var crouch_walk_speed: float = 200.4
# Después:
@export var crouch_walk_speed: float = 200.0
```

### 1.2 Fix bug: guardia ignora pause
**Archivo:** `scripts/guardia.gd` línea 52
Eliminar completamente:
```gdscript
process_mode = Node.PROCESS_MODE_ALWAYS
```
Con esto, el guardia se congela correctamente cuando el menú de pausa está abierto.

### 1.3 Fix bug: race condition en respawn
**Archivo:** `scripts/game_manager.gd`

Añadir variable privada al principio del script:
```gdscript
var _respawning: bool = false
```

Modificar `player_caught()`:
```gdscript
func player_caught() -> void:
    if _respawning or kive_ref == null:
        return
    _respawning = true
    player_respawn_started.emit()
    _do_respawn()
```

Modificar `_do_respawn()` para resetear la flag al final (justo antes del `player_respawn_completed.emit()`):
```gdscript
    _respawning = false
    player_respawn_completed.emit()
```

### 1.4 Fix naming que miente: is_running_currently
**Archivo:** `scripts/kive.gd` línea 430-431

Renombrar el método:
```gdscript
# Antes:
func is_running_currently() -> bool:
    return not Input.is_action_pressed("run") and abs(velocity.x) > 10

# Después:
func is_sprinting() -> bool:
    return not Input.is_action_pressed("run") and abs(velocity.x) > 10
```

Actualizar llamada en `scripts/guardia.gd` línea 108:
```gdscript
# Antes:
if kive_ref.is_running_currently():
# Después:
if kive_ref.is_sprinting():
```

**Verificar con grep/búsqueda que no hay más llamadas a `is_running_currently`** antes de dar por cerrado este punto.

### 1.5 Fix magic number en _can_hide
**Archivo:** `scripts/kive.gd` líneas 447-451

```gdscript
# Antes:
func _can_hide() -> bool:
    for guard in GameManager.guards:
        if is_instance_valid(guard) and guard.state == 2:  # State.ALERT
            return false
    return true

# Después:
func _can_hide() -> bool:
    for guard in GameManager.guards:
        if is_instance_valid(guard) and guard.state == guard.State.ALERT:
            return false
    return true
```

### 1.6 Fix: queue_redraw() solo cuando debug activo
**Archivo:** `scripts/kive.gd` línea 132

```gdscript
# Antes:
queue_redraw()
# Después:
if DebugOverlay.debug_enabled:
    queue_redraw()
```

**Archivo:** `scripts/guardia.gd` línea 96

```gdscript
# Antes:
queue_redraw()
# Después:
if DebugOverlay.debug_enabled:
    queue_redraw()
```

**Verificar también si `_update_collision_shape()` de kive.gd (línea 406) llama a queue_redraw()** — si es así, aplicar el mismo fix.

### 1.7 Reset _was_moving_at_jump en estados de reset
**Archivo:** `scripts/kive.gd`

En `reset_state()`, añadir la línea para resetear:
```gdscript
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
    _was_moving_at_jump = false  # <-- AÑADIR
    _update_collision_shape()
    if is_hidden:
        _unhide()
```

En `_cancel_charged_jump()`, añadir:
```gdscript
func _cancel_charged_jump() -> void:
    sprite.play()
    _is_charging_jump = false
    _jump_charge_timer = 0.0
    _was_moving_at_jump = false  # <-- AÑADIR
    jump_state = "recovery"
    sprite.play("jump_recovery")
```

---

## VERIFICACIÓN DEL CUBO 1 — ANTES DE PASAR AL CUBO 2

1. Godot compila sin errores
2. Vagon1 arranca normal
3. Kive se mueve como antes (walk, run, jump, dive, crouch)
4. Guardia patrulla, detecta, persigue como antes
5. ESC abre menú: el guardia se congela (antes seguía moviéndose)
6. Ser atrapado: fade funciona, respawn correcto
7. Segundo atrapamiento inmediato después del respawn: no debe haber comportamiento raro

Si algo falla, parar y reportar antes de tocar Cubo 2.

---

## CUBO 2 — Limpieza de deuda técnica

Solo ejecutar si el Cubo 1 se ha verificado. Nuevo commit git antes de empezar: `"pre-cleanup v2"`.

### 2.1 Eliminar código muerto: fade_layer en GameManager
**Archivo:** `scripts/game_manager.gd`

Eliminar líneas:
```gdscript
@onready var fade_layer: CanvasLayer = null
```

Cambiar:
```gdscript
# Antes:
@onready var fade_rect: ColorRect = null
# Después:
var fade_rect: ColorRect = null
```

(Eliminar `@onready` porque en un autoload sin árbol de nodos no aporta nada.)

Modificar firma de `register_fade`:
```gdscript
# Antes:
func register_fade(layer: CanvasLayer, rect: ColorRect) -> void:
    fade_layer = layer
    fade_rect = rect

# Después:
func register_fade(rect: ColorRect) -> void:
    fade_rect = rect
```

**Archivo:** `scripts/vagon1.gd`

Actualizar la llamada:
```gdscript
# Antes:
GameManager.register_fade($RespawnFade, $RespawnFade/FadeRect)
# Después:
GameManager.register_fade($RespawnFade/FadeRect)
```

### 2.2 Eliminar has_method guards innecesarios
**Archivo:** `scripts/game_manager.gd`

Nosotros controlamos Kive. Los checks defensive no aportan, solo confunden.

```gdscript
# Antes:
if kive_ref.has_method("set_control_enabled"):
    kive_ref.set_control_enabled(false)
# Después:
kive_ref.set_control_enabled(false)
```

Aplicar en las 3 llamadas (`set_control_enabled(false)`, `reset_state()`, `set_control_enabled(true)`).

### 2.3 Extraer helper _fade_to
**Archivo:** `scripts/game_manager.gd`

Añadir método helper:
```gdscript
func _fade_to(alpha: float) -> void:
    if fade_rect:
        var tween: Tween = create_tween()
        tween.tween_property(fade_rect, "color:a", alpha, 0.3)
        await tween.finished
```

Reemplazar los dos bloques de fade en `_do_respawn`:

```gdscript
# Antes (bloque 1):
if fade_rect:
    var tween: Tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
    await tween.finished

# Después:
await _fade_to(1.0)
```

```gdscript
# Antes (bloque 2):
if fade_rect:
    var tween: Tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, 0.3)
    await tween.finished

# Después:
await _fade_to(0.0)
```

### 2.4 Constantes nombradas en lugar de magic numbers
**Archivo:** `scripts/kive.gd`

Añadir al grupo de constantes (después de `const charge_cancel_time: float = 4.0`):

```gdscript
# --- Collision ---
const default_collision_height: float = 200.0
const player_layer_bit: int = 1 << 0  # Layer 1 "Player" en el inspector
const world_layer_bit: int = 1 << 3   # Layer 4 "World" en el inspector
```

Reemplazar los `200` hardcoded en `_update_collision_shape()` (líneas 401-404):
```gdscript
func _update_collision_shape() -> void:
    var shape: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
    if is_crouched or is_diving:
        shape.size.y = default_collision_height * crouch_height_multiplier
        $CollisionShape2D.position.y = (default_collision_height * (1.0 - crouch_height_multiplier)) / 2
    else:
        shape.size.y = default_collision_height
        $CollisionShape2D.position.y = 0
    if DebugOverlay.debug_enabled:
        queue_redraw()
```

Reemplazar los magic numbers en `_hide()` (líneas 457-459):
```gdscript
func _hide() -> void:
    is_hidden = true
    velocity = Vector2.ZERO
    sprite.modulate.a = 0.35
    collision_layer = 0
    collision_mask = 0
```
Este ya está bien con 0/0, pero en `_unhide()` (líneas 462-466):

```gdscript
# Antes:
func _unhide() -> void:
    is_hidden = false
    sprite.modulate.a = 1.0
    collision_layer = 1
    collision_mask = 8  # World

# Después:
func _unhide() -> void:
    is_hidden = false
    sprite.modulate.a = 1.0
    collision_layer = player_layer_bit
    collision_mask = world_layer_bit
```

### 2.5 Renombrar _on_dive_landed a _handle_dive_landing
**Archivo:** `scripts/kive.gd`

**Primero verificar con grep** que `_on_dive_landed` solo aparece en las líneas 128 y 360 (definición y llamada). Si hay más llamadas, actualizar todas.

```gdscript
# Línea 360:
func _on_dive_landed() -> void:
# Cambiar a:
func _handle_dive_landing() -> void:

# Línea 128:
_on_dive_landed()
# Cambiar a:
_handle_dive_landing()
```

### 2.6 Añadir separadores de sección a kive.gd
**Archivo:** `scripts/kive.gd`

Reorganizar con separadores para navegación. Estructura sugerida:

```gdscript
extends CharacterBody2D

# ========== EXPORTS ==========
# (variables @export actuales)

# ========== CONSTANTS ==========
# (const actuales)

# ========== STATE ==========
# (var actuales de estado interno)

# ========== REFERENCES ==========
# (@onready)

# ========== LIFECYCLE ==========
# _ready, _physics_process

# ========== JUMP / AIR STATES ==========
# _process_anticipation, _release_jump, _cancel_charged_jump, _process_landing

# ========== MOVEMENT ==========
# _process_normal_movement, _apply_horizontal_input, _update_sprite_direction, _try_step_up

# ========== DIVE ==========
# _start_ground_dive, _start_air_dive, _process_dive, _handle_dive_landing

# ========== CROUCH / HIDE ==========
# _update_collision_shape, _can_hide, _hide, _unhide

# ========== SIGNALS ==========
# _on_animation_finished, _on_hide_zone_entered, _on_hide_zone_exited

# ========== PUBLIC API ==========
# set_control_enabled, reset_state, is_sprinting

# ========== DEBUG ==========
# _draw
```

**NO reorganizar el orden de funciones si no es necesario.** El objetivo es solo añadir los separadores donde correspondan según dónde ya están las funciones. Si una función está en mitad de otra sección por legacy, déjala y aplica el separador más cercano.

---

## VERIFICACIÓN DEL CUBO 2

1. Godot compila sin errores
2. Todos los tests del Cubo 1 siguen pasando
3. Kive se puede esconder en hide zones cuando guardias no están en ALERT
4. Kive NO se puede esconder cuando hay guardia en ALERT
5. Collision layer de Kive al salir de hide: sigue chocando con suelo (World)
6. Dive funciona tanto en suelo como en aire
7. Dive aterrizaje desde aire: transiciona correctamente

---

## LO QUE NO HAY QUE TOCAR

(Y si Claude Code propone tocarlo, desactivar la propuesta — son cambios fuera de alcance)

- `jump_state` como string (refactor a enum queda pendiente — demasiado riesgo vs beneficio en este parche)
- `kive_spawn_position` hardcoded en GameManager (cambio arquitectural para futuro, cuando haya Vagón 2)
- Acoplamiento Kive ↔ Guardia con métodos públicos en lugar de variables (refactor de diseño para futuro)
- Convención de underscore (ya es coherente: público sin `_`, privado con `_`)
- Input action name "run" (renombrar rompería user://settings.cfg persistido)
- `has_node()` checks en guardia.gd para DebugLabel/RayLine (los nodos existen, el código es correcto)
- `is_running_currently()` (aunque el nombre confunda) NO se elimina — se renombra. La funcionalidad se mantiene idéntica.

---

## ENTREGA

Al terminar ambos cubos:

1. Proyecto compila sin warnings nuevos
2. Todos los tests de verificación pasan
3. Commit final con mensaje `"cleanup v1: cubo 1 + cubo 2"`
4. Actualizar README.md si alguno de los cambios afecta a documentación existente (por ejemplo, los parámetros del GameManager han cambiado)

Estimación razonable: entre 45 minutos y 2 horas según velocidad de ejecución y verificación. No apresurarse con la verificación entre cubos.
