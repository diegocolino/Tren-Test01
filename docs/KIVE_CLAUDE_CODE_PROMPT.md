# KIVE EN EL TREN — Setup del Prototipo Vagón 1

> Instrucciones ejecutables para Claude Code con MCP de Godot activo.
> Objetivo: proyecto Godot 4 funcional donde Kive se mueve por el Vagón 1.
> Sin enemigos, sin combate, sin audio. Solo movimiento básico.

---

## CONTEXTO DEL PROYECTO

Juego 2D side-scroller en desarrollo llamado **Kive en el Tren**. Universo distópico, protagonista músico en duelo que huye vagón a vagón en un tren que lleva a Kilima. Este es el **primer prototipo jugable** — solo demuestra movimiento del personaje en el primer escenario. Mecánicas complejas (combate, sigilo, IA enemiga) vienen después en iteraciones separadas.

El estilo visual es 2D vectorial con contorno negro grueso sobre fondos de color plano. Los fondos están ya diseñados en tres capas para paralaje.

---

## STACK TÉCNICO

- **Godot 4.x** (última estable)
- **GDScript** (no C#)
- **Resolución**: 1920x1080 nativo, sin escalado
- **Stretch mode**: `canvas_items`
- **Stretch aspect**: `keep`
- **Default texture filter**: `Linear` (arte vectorial, no pixel art)
- **Orientación**: landscape

---

## ASSETS DISPONIBLES

En la carpeta `/assets/` del proyecto encontrarás (o los pongo yo ahí antes de que empieces):

| Archivo | Tipo | Dimensiones | Notas |
|---|---|---|---|
| `VAGON1_BACK.png` | Fondo | 7680x1080 | Capa fondo con paisaje falso |
| `VAGON1_MID.png` | Fondo | 7680x1080 | Capa media — paredes, butacas, escenario |
| `VAGON1_TOP.png` | Fondo | 7680x1080 | Capa frente con transparencia — columnas |
| `kive_idle.png` | Sprite | 256x256 | Kive parado, 1 frame |
| `kive_walk.png` | Spritesheet | 1280x256 | 5 frames horizontales de 256x256 |
| `kive_jump.png` | Spritesheet | 1280x256 | 5 frames horizontales de 256x256 |

**Importante**: los spritesheets son horizontales, frames alineados de izquierda a derecha, mismo tamaño cada uno, sin padding.

---

## TAREA 1 — Configurar el proyecto

1. Crear proyecto Godot 4 nuevo en la carpeta del workspace
2. Configurar `project.godot`:
   - `display/window/size/viewport_width = 1920`
   - `display/window/size/viewport_height = 1080`
   - `display/window/stretch/mode = "canvas_items"`
   - `display/window/stretch/aspect = "keep"`
   - `rendering/textures/canvas_textures/default_texture_filter = 1` (Linear)
3. Configurar Input Map:
   - `move_left` → KEY_LEFT, KEY_A
   - `move_right` → KEY_RIGHT, KEY_D
   - `run` → KEY_SHIFT (hold)
   - `jump` → KEY_SPACE, KEY_W, KEY_UP

---

## TAREA 2 — Importar assets

Al importar las PNG, configurar en el panel Import:
- **Filter**: ON (Linear filtering es correcto para este arte)
- **Mipmaps**: OFF
- **Repeat**: OFF
- **Fix alpha border**: ON (evita halos oscuros en transparencias)

---

## TAREA 3 — Crear SpriteFrames de Kive

Crear recurso `SpriteFrames` llamado `kive_frames.tres` en `/resources/`.

Animaciones a configurar:

| Nombre | Origen | Frames | Loop | FPS |
|---|---|---|---|---|
| `idle` | `kive_idle.png` | 1 (imagen completa) | Sí | 1 |
| `walk` | `kive_walk.png` | 5 (slice horizontal, 256x256 cada uno) | Sí | 10 |
| `jump_anticipation` | `kive_jump.png` frame 0 | 1 | No | 1 |
| `jump_rise` | `kive_jump.png` frame 1 | 1 | No | 1 |
| `jump_peak` | `kive_jump.png` frame 2 | 1 | No | 1 |
| `jump_fall` | `kive_jump.png` frame 3 | 1 | No | 1 |
| `jump_land` | `kive_jump.png` frame 4 | 1 | No | 1 |

---

## TAREA 4 — Crear la escena Vagon1.tscn

Estructura de nodos exacta:

```
Vagon1 (Node2D)
│
├── ParallaxBackground
│   ├── BackLayer (ParallaxLayer)
│   │   motion_scale = Vector2(0.3, 1)
│   │   └── BackSprite (Sprite2D)
│   │       texture = VAGON1_BACK.png
│   │       centered = false
│   │       position = Vector2(0, 0)
│   │
│   ├── MidLayer (ParallaxLayer)
│   │   motion_scale = Vector2(1.0, 1)
│   │   └── MidSprite (Sprite2D)
│   │       texture = VAGON1_MID.png
│   │       centered = false
│   │       position = Vector2(0, 0)
│   │
│   └── FrontLayer (ParallaxLayer)
│       motion_scale = Vector2(1.15, 1)
│       z_index = 10
│       └── FrontSprite (Sprite2D)
│           texture = VAGON1_TOP.png
│           centered = false
│           position = Vector2(0, 0)
│
├── Suelo (StaticBody2D)
│   z_index = 0
│   └── CollisionShape2D
│       shape = RectangleShape2D
│       shape size = Vector2(7680, 50)
│       position = Vector2(3840, 1000)
│       (esto es aproximación — se ajustará visualmente después)
│
└── Kive (CharacterBody2D)
    z_index = 5
    position = Vector2(200, 900)
    │
    ├── AnimatedSprite2D
    │   sprite_frames = kive_frames.tres
    │   animation = "idle"
    │   autoplay = "idle"
    │   centered = true
    │
    ├── CollisionShape2D
    │   shape = RectangleShape2D
    │   shape size = Vector2(80, 200)
    │   position = Vector2(0, 0)
    │
    └── Camera2D
        enabled = true
        position_smoothing_enabled = true
        position_smoothing_speed = 5.0
        drag_horizontal_enabled = true
        drag_left_margin = 0.2
        drag_right_margin = 0.2
        limit_left = 0
        limit_right = 7680
        limit_top = 0
        limit_bottom = 1080
```

**CRÍTICO sobre z_index**: Kive (z=5) debe renderizarse ENTRE MidLayer (z=0) y FrontLayer (z=10). Esto permite que las columnas del frente cubran a Kive cuando pase por detrás. Verifica que el z_index funciona correctamente después de crear la escena — es la mecánica de cobertura visual del juego.

---

## TAREA 5 — Script `kive.gd`

Adjuntar al nodo `Kive (CharacterBody2D)`. Código completo:

```gdscript
extends CharacterBody2D

# --- Parámetros ajustables desde el editor ---
@export var walk_speed: float = 300.0
@export var run_speed: float = 550.0
@export var jump_velocity: float = -900.0
@export var gravity: float = 2400.0
@export var air_control_factor: float = 0.7

# --- Timing del salto ---
const ANTICIPATION_DURATION: float = 0.08
const LANDING_DURATION: float = 0.1

# --- Estado interno ---
var jump_state: String = "none"  # none, anticipation, rising, peak, falling, landing
var jump_timer: float = 0.0

# --- Referencias ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	match jump_state:
		"anticipation":
			_process_anticipation(delta)
		"landing":
			_process_landing(delta)
		_:
			_process_normal_movement(delta)
	
	move_and_slide()
	_update_sprite_direction()


func _process_anticipation(delta: float) -> void:
	jump_timer += delta
	velocity.x = 0  # no se mueve horizontalmente durante el wind-up
	velocity.y = 0
	sprite.play("jump_anticipation")
	
	if jump_timer >= ANTICIPATION_DURATION:
		velocity.y = jump_velocity
		jump_state = "rising"


func _process_landing(delta: float) -> void:
	jump_timer += delta
	_apply_horizontal_input(false)
	sprite.play("jump_land")
	
	if jump_timer >= LANDING_DURATION:
		jump_state = "none"


func _process_normal_movement(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Input horizontal
	var in_air: bool = not is_on_floor()
	_apply_horizontal_input(in_air)
	
	# Jump input
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_state == "none":
		jump_state = "anticipation"
		jump_timer = 0.0
		return
	
	# Aterrizaje
	if is_on_floor() and (jump_state == "rising" or jump_state == "peak" or jump_state == "falling"):
		jump_state = "landing"
		jump_timer = 0.0
		return
	
	# Actualizar estado aéreo
	if not is_on_floor() and jump_state == "none":
		# Caída sin salto (se cayó de una plataforma)
		jump_state = "falling"
	
	if not is_on_floor() and jump_state in ["rising", "peak", "falling"]:
		if velocity.y < -50:
			jump_state = "rising"
			sprite.play("jump_rise")
		elif velocity.y > 50:
			jump_state = "falling"
			sprite.play("jump_fall")
		else:
			jump_state = "peak"
			sprite.play("jump_peak")
		return
	
	# Animación en suelo
	if is_on_floor() and jump_state == "none":
		if abs(velocity.x) > 10:
			sprite.play("walk")
			var is_running: bool = Input.is_action_pressed("run")
			sprite.speed_scale = 1.4 if is_running else 1.0
		else:
			sprite.play("idle")
			sprite.speed_scale = 1.0


func _apply_horizontal_input(in_air: bool) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var is_running: bool = Input.is_action_pressed("run")
	var speed: float = run_speed if is_running else walk_speed
	
	if in_air:
		speed *= air_control_factor
	
	if direction != 0:
		velocity.x = direction * speed
	else:
		# Deceleración suave cuando no hay input
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)


func _update_sprite_direction() -> void:
	if velocity.x > 1:
		sprite.flip_h = false
	elif velocity.x < -1:
		sprite.flip_h = true
```

---

## TAREA 6 — Verificaciones finales

Después de crear todo, verifica en el editor:

1. **La escena Vagon1.tscn se abre sin errores.**
2. **El z_index funciona**: arrastra a Kive en el editor hasta una columna de la capa frente — debe quedar visualmente oculto detrás de la columna.
3. **La cámara sigue a Kive**: ejecuta la escena (F6), mueve con flechas — la cámara debe desplazarse suavemente con él, con dead zone.
4. **Las tres capas hacen paralaje**: al moverse, la capa fondo se mueve más lento (sensación de lejanía) y la capa frente se mueve ligeramente más rápido (sensación de cercanía).
5. **Las animaciones funcionan**:
   - Kive parado → idle
   - Flecha derecha → walk hacia la derecha
   - Flecha izquierda → walk hacia la izquierda (sprite flipped)
   - Shift + dirección → walk más rápido
   - Espacio → jump cycle completo: anticipation → rise → peak → fall → land → idle

---

## LO QUE NO HAY QUE HACER EN ESTA ITERACIÓN

- Enemigos, guardias, IA, pathfinding
- Sistema de combate, ataque del puño
- Sistema de sigilo, conos de visión, cámaras de Flai funcionales
- Audio, música, SFX
- UI, menús, pantalla de título, HUD
- Shaders, efectos visuales, partículas, post-processing
- Puertas, interacciones, objetos recogibles
- Civiles evacuando, animaciones de NPC
- Guardar/cargar, checkpoints
- Cualquier sistema narrativo o de diálogo

---

## AMBIGÜEDADES Y TODOs

Si encuentras algo ambiguo durante la implementación:
1. **Tomá la decisión más razonable** siguiendo las convenciones estándar de Godot 4
2. **Dejá un comentario `# TODO: ...`** en el código indicando qué asumiste
3. **No pares a preguntar** — quiero un proyecto funcional con TODOs visibles, no un proyecto bloqueado por decisiones pendientes

Ejemplos de cosas que probablemente tengas que ajustar visualmente después y no debes bloquear por ellas:
- Altura exacta del suelo en el Vagón 1
- Tamaño exacto del CollisionShape2D de Kive
- Posición exacta de spawn de Kive
- Velocidades de movimiento (los números de arriba son punto de partida)

---

## ENTREGA ESPERADA

Al terminar:

1. **Proyecto Godot funcional** en el workspace, ejecutable con F5
2. **`README.md` en la raíz del proyecto** explicando:
   - Estructura de carpetas del proyecto
   - Controles del juego
   - Qué parámetros se pueden ajustar desde el editor
   - Lista de TODOs encontrados durante la implementación
3. **Todos los comentarios del código en español**, claros pero breves

Empezá por configurar `project.godot`, seguí con la importación de assets, después creá los recursos (SpriteFrames), después la escena, y por último el script. Verificá al final corriendo la escena.

---

*Prompt preparado tras sesión de diseño arte + mecánicas. Todas las decisiones de arte, paleta, y animación están ya tomadas — este prompt solo ejecuta la implementación técnica.*
