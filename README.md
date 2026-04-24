# Kive en el Tren — Prototipo Vagón 1

Primer prototipo jugable del juego "Kive en el Tren". Movimiento del personaje (salto cargado, doble salto, dive, step climbing), enemigo Agent con IA de 11 estados y sistema de combate (punch/kick/parry), mecanica de sigilo (crouch + auto-hide + oido) y sistema de respawn.

## Estructura de carpetas

```
├── assets/              # Sprites y fondos PNG
│   ├── VAGON1_OUT.png   # Paisaje exterior proyectado — scroll rápido (7680x1080)
│   ├── VAGON1_BACK.png  # Fondo interior del vagón — paralaje (7680x1080)
│   ├── VAGON1_MID.png   # Capa media — paredes, butacas (7680x1080)
│   ├── VAGON1_TOP.png   # Capa frente — columnas que ocultan a Kive (7680x1080)
│   ├── VAGON1_ATMO.png  # Capa atmosférica encima de todo (7680x1080)
│   ├── Kive_Sprite.png           # Idle (256x256)
│   └── Kive_Walk-Run-Jump-AirJump-Crouch-Dive_Sprite.png  # Spritesheet principal
├── resources/
│   ├── kive_frames.tres  # SpriteFrames Kive (movimiento + combate)
│   ├── agent_frames.tres # SpriteFrames Agent (13 animaciones)
│   └── shaders/
│       ├── gaussian_blur.gdshader          # Depth of field (FrontLayer)
│       ├── horizontal_motion_blur.gdshader # Estrías de velocidad (OutLayer)
│       ├── vignette.gdshader               # Viñeta global (PostProcess)
│       ├── color_grading.gdshader          # Tinte atmosférico (AtmosphereGrade)
│       └── alarm_pulse.gdshader           # Alarma roja pulsante periférica (PostProcess)
├── scenes/
│   ├── Vagon1.tscn       # Escena principal del vagón
│   ├── Agent.tscn         # Escena del enemigo Agent (sprites reales + linterna)
│   ├── Guardia.tscn      # Escena del guardia legacy (referencia)
│   └── DebugHUD.tscn     # HUD de debug (CanvasLayer 12)
├── scripts/
│   ├── kive.gd            # Script de movimiento de Kive (salto cargado, dive, crouch)
│   ├── agent.gd            # IA del Agent (FSM 11 estados + combate)
│   ├── guardia.gd         # IA del guardia legacy (referencia)
│   ├── game_manager.gd    # Autoload — respawn y registro de entidades
│   ├── debug_overlay.gd   # Autoload — debug flags (F1-F4)
│   ├── debug_hud.gd       # HUD de debug (FPS, estados, distancia)
│   ├── pause_menu.gd      # Autoload — menú de controles + remapping (ESC)
│   ├── vagon1.gd          # Script de escena — registra Kive y fade en GameManager
│   ├── train_scroll.gd    # Scroll continuo del paisaje (OutLayer)
│   └── train_shake.gd     # Bamboleo de cámara (Camera2D)
└── project.godot
```

## Physics Layers

| Layer | Bit | Nombre | Uso |
|---|---|---|---|
| 1 | 1 | Player | Kive |
| 2 | 2 | Cover | Columnas que bloquean raycast de detección |
| 3 | 4 | Enemy | Guardias |
| 4 | 8 | World | Suelo, paredes, escaleras |
| 5 | 16 | Detection | Cono de visión, radio de oído |

## Sistema de movimiento

### Velocidades

| Estado | Velocidad (px/s) | Notas |
|---|---|---|
| Correr (default) | 800 | Movimiento base, sin mantener teclas extra |
| Andar (Left Shift) | 400 | Mantener Shift para caminar |
| Agachado | 200.0 | Cualquier modo crouch |
| Control aéreo | ×0.8 | Multiplicador sobre la velocidad actual |

### Salto cargado

El salto pasa por una fase de anticipation antes de despegar. Si Kive está corriendo, salta directamente (instajump) sin anticipation.

| Fase | Duración | Descripción |
|---|---|---|
| Anticipation | 0.04s | Kive se agacha (frame de preparación). Solo parado o andando |
| Carga (hold) | 0 – 0.4s | Mantener Space para cargar. Se confirma tras 0.14s de hold |
| Release | — | Soltar Space para saltar |
| Cancel | 4.0s | Si se mantiene >4s, el salto se cancela |

| Parámetro | Valor |
|---|---|
| Velocidad mínima (sin cargar) | -800 |
| Velocidad máxima (carga completa) | -1200 |
| Umbral de carga (charge threshold) | 0.14s |
| Tiempo de carga completa | 0.4s |
| Cancel timeout | 4.0s |

**Visual**: durante la carga, el sprite pausa en el frame 1 de jump_anticipation.
**Corriendo**: instajump directo a jump_air, sin pasar por anticipation.

### Doble salto (air jump)

- 1 salto extra en el aire (`max_air_jumps = 1`)
- Velocidad: -800
- Transiciones de animación: `air_jump_rise` → `air_jump_fall` → `jump_precontact`
- Se resetea al tocar el suelo

### Dive

#### Ground dive

Se activa con Right Shift mientras Kive corre (no funciona andando ni parado).

- Slide horizontal a 1200 px/s en la dirección actual
- Fricción de 800 px/s² — se frena progresivamente
- Duración máxima: 1.2s
- Reduce hitbox (misma que crouch, ×0.7)
- Mantener Right Shift para extender el slide, soltar para terminar
- **Combo**: Jump durante dive → cancela dive + salta (con air jumps reseteados)

#### Air dive

Se activa con Right Shift en el aire.

- Impulso horizontal: velocidad de dive × 0.8
- Boost vertical: min(-400, velocity.y) — garantiza impulso hacia arriba
- **Combo**: Jump durante air dive → cancela dive + air jump

### Step climbing

Kive (y el guardia) suben escalones automáticamente al caminar contra ellos.
- `STEP_HEIGHT = 80.0`
- Lógica: choque con pared en suelo → test espacio libre arriba → test avance a altura elevada → subir

### Máquina de estados del salto

```
none → anticipation → jump_air → precontact → contact → recovery → none
                                                 ↑
air jump:  air_jump_rise → air_jump_fall ─────────┘
                                                 ↑
caída libre:  none → jump_air → precontact ──────┘
```

Estados: `none`, `anticipation`, `jump_air`, `air_jump_rise`, `air_jump_fall`, `precontact`, `contact`, `recovery`

## Sistema de sigilo

### Crouch (agacharse)

Dos modos configurables desde el menú de pausa (ESC):
- **Toggle** (default): pulsar S o C para alternar agachado/de pie
- **Hold**: mantener S o C para agacharse, soltar para levantarse

Solo funciona en el suelo, sin saltar y sin dive activo.

- Reduce la altura de la collision shape (×0.7)
- Velocidad agachado: 200.0 px/s
- Silencia completamente a Kive para el oído del guardia (radio de detección = 1px)
- Saltar desde agachado levanta automáticamente a Kive antes del salto

### Esconderse (Auto-hide)

Kive se esconde automáticamente cuando se cumplen **todas** estas condiciones:
- Está agachado (`is_crouched`)
- Dentro de una HideZone (Area2D, grupo `hide_zone`)
- En el suelo
- Sin salto activo (`jump_state == "none"`)
- Sin input direccional
- Velocidad horizontal < 10 px/s
- Ningún guardia en estado ALERT

**Salir**: cualquier input de movimiento (A/D) o salto (Space).

- **Efecto visual**: Sprite semitransparente (alpha 0.35)
- **Detección**: El guardia ignora completamente a Kive escondido (visión + oído)
- **Física**: `collision_layer=0` y `collision_mask=0` → Kive es invisible para la física
- Respawn resetea el estado de escondite

### Deteccion dual del Agent

El Agent detecta a Kive por **vista** y **oido** simultaneamente:

**Vista**: Cono trapezoidal (350px, linterna) + raycast para linea de vision. Si una columna (Cover layer) esta entre el Agent y Kive, la vision se bloquea.

**Oido**: Area2D circular con radio dinamico segun el estado de Kive:

| Estado de Kive | Radio de oído |
|---|---|
| Quieto | 80px |
| Caminando | 250px |
| Corriendo | 450px |
| Agachado | 1px (sordo) |

La deteccion combina ambos sentidos: `detected = (en_cono AND visible) OR oido`

**Nota**: Si Kive esta escondido (`is_hidden = true`), la deteccion ignora a Kive completamente.

Ver seccion "Estados del Agent (FSM)" arriba para la tabla completa de estados.

## Enemigos — Agent

### Estructura de la escena (Agent.tscn)

```
Agent (CharacterBody2D, z=4, layer=Enemy, mask=World)
├── AnimatedSprite2D (agent_frames.tres, 13 animaciones)
├── CollisionShape2D (80x200)
├── Hurtbox (Area2D)
├── FlashlightHand (Node2D)
│   ├── Flashlight (PointLight2D)
│   └── FlashlightConeDetector (Area2D, trapecio 350px)
├── HearingRange (Area2D, radio dinamico)
├── AttackHitbox (Area2D, 120x60)
├── StateIndicator (Label)
└── DebugLabel (Label, debug_visual)
```

### Estados del Agent (FSM)

| Estado | Comportamiento | Transicion a... |
|---|---|---|
| PATROL | Camina entre markers a 80px/s con linterna | GUARD_STANCE si detecta |
| GUARD_STANCE | Persigue a 240px/s, espera en rango | WINDUP tras 1.5s en rango / PATROL tras 2s sin detectar |
| GUARD_BROKEN | Aturdido 0.8s (guard roto por kick) | GUARD_STANCE |
| WINDUP | Prepara ataque 0.5s | ATTACK_RELEASE |
| ATTACK_RELEASE | Golpea (hitbox activa 0.12s) | GUARD_STANCE |
| PARRY | Reaccion al ser parriado | GUARD_STANCE |
| HIT | Retroceso 0.3s | GUARD_STANCE / STUNT / AIRTIME segun calidad |
| STUNT | Aturdido de pie 0.8s | FLOORSTUNT |
| AIRTIME | Volando por golpe maestro | DEAD al aterrizar |
| FLOORSTUNT | Tumbado 3s | GUARD_STANCE |
| DEAD | Muerto permanente | - |

## Sistema de combate

### Ataques de Kive

| Ataque | Tecla | Tipo | Bloqueo |
|---|---|---|---|
| Punch rapido | W (tap) | Golpe frontal | Total (sin movimiento/salto/dive/crouch) |
| Punch cargado | W (hold >0.4s) | Golpe potente (+1 calidad) | Total |
| Kick | Q | Empujon + 30% guard break | Total |

### Calidad de golpe

La calidad depende del estado del Agent y la posicion relativa de Kive:

| Estado Agent | Frente | Lateral | Detras |
|---|---|---|---|
| Desprevenido (PATROL) | maestro | maestro | maestro |
| Guard | mal | mal | normal |
| Guard broken | bueno | bueno | maestro |
| Windup | normal | normal | bueno |
| Release | bueno | bueno | maestro |
| Stunt | bueno | maestro | maestro |

Punch cargado sube un nivel (mal->normal->bueno->maestro).

### Resoluciones de golpe

| Calidad | Resultado |
|---|---|
| mal | Agent vuelve a GUARD_STANCE |
| normal | Agent vuelve a GUARD_STANCE |
| bueno | HIT -> STUNT -> FLOORSTUNT -> GUARD_STANCE |
| maestro | HIT -> AIRTIME (flash blanco) -> DEAD |

### Extras del kick

- **Push**: empuja al Agent ~120px en la direccion del kick
- **Guard break**: 30% de probabilidad de romper guardia -> GUARD_BROKEN 0.8s
- **Kick por detras**: FLOORSTUNT directo (bypass stunt)

### Parry

- Ventana: 8 frames (~133ms) desde que se pulsa W
- Si el Agent ataca durante la ventana: Agent -> STUNT, Kive flash verde
- Si no hay parry: Kive flash rojo -> respawn

### Como anadir mas Agents

1. Crear dos `Marker2D` para los puntos de patrulla
2. Instanciar `Agent.tscn` como hijo de la escena
3. Asignar `patrol_marker_a` y `patrol_marker_b` en el inspector
4. El Agent se registra automaticamente en GameManager

### Legacy (Guardia.tscn)

`Guardia.tscn` y `guardia.gd` se mantienen como referencia. `GameManager.register_guard()` funciona como alias de `register_enemy()`.

## Sistema de respawn

### GameManager (Autoload)

Gestiona el ciclo de captura y respawn:

1. Agent ataca Kive sin parry -> `GameManager.player_caught()`
2. Se desactiva el control de Kive
3. Fade out (0.3s, pantalla negra)
4. Kive se reposiciona en spawn (200, 700)
5. Todos los enemigos vuelven a PATROL en su marker A
6. Fade in (0.3s)
7. Se reactiva el control

El `RespawnFade` es un `CanvasLayer` (layer=11) con un `ColorRect` negro que cubre toda la pantalla, alpha inicial 0.

## Debug avanzado

### Teclas de debug

| Tecla | Funcion |
|---|---|
| F1 | Toggle general debug (grupo `debug_visual`) |
| F2 | Toggle hitboxes (punch rojo, kick naranja, hurtbox azul) |
| F3 | Toggle timeline (animacion + frame actual) |
| F4 | Toggle cono de linterna |

### DebugHUD (CanvasLayer 12)

Panel en esquina superior izquierda con:
- FPS
- Estado de Kive (crouch, hide, cast, attack, parry window, anim+frame)
- Estado del Agent (state, timer, hit quality, detection flags, anim+frame)
- Distancia Kive-Agent en px

### Colores de hitboxes

| Hitbox | Color |
|---|---|
| Hurtbox | Azul `(0.2, 0.5, 1.0, 0.3)` |
| Punch | Rojo `(1.0, 0.2, 0.2, 0.5)` |
| Kick | Naranja `(1.0, 0.5, 0.0, 0.5)` |
| Agent attack | Rojo `(1.0, 0.2, 0.2, 0.5)` |

Para desactivar permanentemente en release, cambiar `debug_enabled = false` en `debug_overlay.gd`.

## Controles

| Acción | Tecla default | Notas |
|---|---|---|
| Mover izquierda | A | |
| Mover derecha | D | |
| Saltar | Space | Mantener para cargar salto |
| Andar (lento) | Left Shift (mantener) | Por defecto Kive corre |
| Agacharse | S, C | Toggle o hold (configurable en menú ESC) |
| Dive | Right Shift | En suelo (corriendo) o en aire |
| Punch | W | Tap=rapido, hold>0.4s=cargado |
| Kick | Q | Empuja + 30% guard break |
| Debug overlay | F1 | Toggle global |
| Debug hitboxes | F2 | Toggle hitboxes |
| Debug timeline | F3 | Toggle anim info |
| Debug linterna | F4 | Toggle cono linterna |

Todas las teclas de movimiento (excepto F1-F4) son remapeables desde el menú de pausa.

## Menú de pausa

Se abre/cierra con **ESC**. Pausa el juego completamente.

### Funciones

- **Remapping de teclas**: las 6 acciones de juego (Move Left, Move Right, Jump, Crouch, Walk, Dive) se pueden reasignar a cualquier tecla. Click en el botón de la acción → pulsar nueva tecla. ESC cancela el remapping.
- **Crouch Mode**: alterna entre Toggle (default) y Hold.
- **Persistencia**: los controles y el modo crouch se guardan en `user://settings.cfg` y se cargan automáticamente al iniciar.

## Parámetros ajustables desde el editor

### Kive

| Parámetro | Valor default | Descripción |
|---|---|---|
| `walk_speed` | 400.0 | Velocidad al andar (Shift) |
| `run_speed` | 800.0 | Velocidad al correr (default) |
| `gravity` | 2400.0 | Fuerza de gravedad |
| `air_control_factor` | 0.8 | Multiplicador de control en el aire |
| `max_air_jumps` | 1 | Saltos adicionales en el aire (doble salto) |
| `air_jump_velocity` | -800.0 | Impulso vertical del salto en el aire |
| `crouch_walk_speed` | 200.0 | Velocidad agachado |
| `crouch_height_multiplier` | 0.7 | Multiplicador de altura agachado |
| `jump_charge_time` | 0.4 | Tiempo para carga completa del salto |
| `jump_velocity_min` | -800.0 | Impulso mínimo (salto sin cargar) |
| `jump_velocity_max` | -1200.0 | Impulso máximo (salto cargado al 100%) |
| `dive_speed` | 1200.0 | Velocidad horizontal del dive |
| `dive_max_duration` | 1.2 | Duración máxima del slide en suelo |
| `dive_friction` | 800.0 | Fricción durante el slide |

### Guardia

| Parámetro | Valor default | Descripción |
|---|---|---|
| `patrol_speed` | 80.0 | Velocidad de patrulla |
| `alert_speed` | 280.0 | Velocidad de persecución |
| `suspicion_to_alert_time` | 1.2 | Segundos de detección continua para pasar a ALERT |
| `alert_to_suspicious_time` | 3.0 | Segundos sin detección para bajar de ALERT |
| `suspicious_to_patrol_time` | 5.0 | Segundos sin detección para volver a PATROL |
| `hearing_radius_walking` | 250.0 | Radio de oído cuando Kive camina |
| `hearing_radius_running` | 450.0 | Radio de oído cuando Kive corre |
| `hearing_radius_idle` | 80.0 | Radio de oído cuando Kive está quieto |
| `hearing_radius_crouched` | 1.0 | Radio de oído cuando Kive está agachado |

## Animaciones (kive_frames.tres)

Spritesheet unificado con 15 animaciones en `Kive_Walk-Run-Jump-AirJump-Crouch-Dive_Sprite.png` (+ idle desde `Kive_Sprite.png`):

| Animación | Frames | FPS | Loop | Uso |
|---|---|---|---|---|
| `idle` | 1 | — | si | De pie, sin moverse |
| `walk` | 4 | 8 | si | Andando (Shift) |
| `run` | 4 | 10 | si | Corriendo (default) |
| `crouch_idle` | 1 | — | si | Agachado quieto |
| `crouch_walk` | 7 | 8 | si | Agachado caminando |
| `jump_anticipation` | 2 | 8 | no | Preparación del salto (solo parado/andando) |
| `jump_air` | 1 | — | no | En el aire (salto normal) |
| `jump_precontact` | 1 | — | no | Cayendo, cerca del suelo |
| `jump_contact` | 1 | 8 | no | Aterrizaje |
| `jump_recovery` | 1 | 6 | no | Recuperación post-aterrizaje |
| `air_jump_rise` | 1 | — | no | Doble salto — subiendo |
| `air_jump_fall` | 1 | — | no | Doble salto — bajando |
| `dive_start` | 3 | 12 | no | Inicio del dive |
| `dive_slide` | 1 | — | si | Slide en suelo / air dive |
| `dive_end` | 1 | 8 | no | Final del dive |

## Capas de renderizado

El vagón usa 5 capas visuales con z_index para controlar profundidad:

| Capa | Nodo | z_index | Notas |
|---|---|---|---|
| OUT | ParallaxBackground > OutLayer | 0 | Paisaje exterior, motion_scale=1.0, scroll continuo + motion blur |
| BACK | ParallaxBackground > BackLayer | 0 | Fondo interior del vagón, motion_scale=0.88 (paralaje sutil) |
| MID | ParallaxBackground > MidLayer | 0 | Paredes, butacas, motion_scale=1.0 |
| Agent | CharacterBody2D | 4 | Enemigo Agent (sprites reales + linterna) |
| Kive | CharacterBody2D | 5 | Personaje jugable |
| TOP | Node2D (FrontLayer) | 10 | Columnas que ocultan a Kive |
| ATMO | Node2D (AtmoLayer) | 20 | Capa atmosférica sobre todo |

**Nota sobre el paisaje**: El fondo exterior (OUT) es una proyección plana de Flai en pantallas LED integradas en el vagón. Usa `motion_scale=(1, 1)` para que se mueva solidario al vagón. El desplazamiento visible lo genera el scroll continuo via `motion_offset` en `train_scroll.gd`.

**Nota sobre BACK**: La capa BACK es el fondo interior del vagón (columnas lejanas, estructura). Tiene `motion_scale=(0.88, 1)` para un paralaje sutil respecto a MID, dando sensación de profundidad dentro del vagón.

**Nota técnica**: La capa TOP no usa ParallaxBackground porque Godot 4 no respeta z_index entre ParallaxBackground y nodos regulares. Se usa un Node2D con z_index=10 que se mueve 1:1 con la cámara (equivalente a motion_scale=1.0).

## Geometría del nivel

### Suelo principal
`StaticBody2D` con `CollisionShape2D` horizontal que cubre todo el vagón (7680x50, centrado en y=800).

### Paredes invisibles
Dos `StaticBody2D` con colisión vertical (50x1080) en los bordes del nivel:
- **ParedIzquierda** — x=0, impide salir por la izquierda
- **ParedDerecha** — x=7680, impide salir por la derecha

### Escaleras y suelo elevado
Al final del vagón (derecha) hay una escalera de 2 escalones (`Escalon1`, `Escalon2`) que conecta el suelo principal con un `SueloElevado` más alto. Los escalones son `CollisionShape2D` dentro de un `StaticBody2D` llamado `Escaleras`.

**Step climbing** (Kive y Guardia): Ambos suben escalones automáticamente al caminar contra ellos. `STEP_HEIGHT = 80.0`. Lógica: si chocas con pared en el suelo → test espacio arriba → test avance a altura elevada → subir. La gravedad aterriza suavemente en el siguiente frame.

### Columnas de cobertura (ColumnCollisions)
3 `StaticBody2D` (layer=Cover, mask=0) que bloquean el raycast de detección del guardia. Posiciones provisionales: X=1500, 3500, 5500. Ajustar visualmente para alinear con las columnas de VAGON1_TOP.png.

### HideZones en columnas
Cada columna (Column1, Column2, Column3) tiene un `Area2D` hijo que define la zona donde Kive puede esconderse:
- `collision_layer=0`, `collision_mask=1` (Player), grupo `hide_zone`
- `CollisionShape2D`: 160x300, centrado en la columna
- `monitoring=true`, `monitorable=false`

## Efectos del tren

Dos efectos permanentes simulan el movimiento del tren:

### Paisaje en movimiento (train_scroll.gd)

Adjunto al nodo `ParallaxBackground > OutLayer`. Desplaza el paisaje exterior continuamente usando `motion_offset` del ParallaxLayer (forma idiomática en Godot 4). El loop se consigue con `motion_mirroring` configurado al ancho de la textura (7680px).

| Parámetro | Nodo | Valor default | Descripción |
|---|---|---|---|
| `scroll_speed` | OutLayer | 1920.0 | Velocidad del scroll en px/seg |

Para invertir la dirección del scroll (cambiar el sentido del tren), poner un valor negativo en `scroll_speed`.

### Bamboleo de cámara (train_shake.gd)

Adjunto al nodo `Kive > Camera2D`. Aplica un offset sinusoidal sutil que simula el traqueteo del tren. La frecuencia X está multiplicada por 0.7 respecto a Y para evitar sincronía perfecta y dar sensación más orgánica.

| Parámetro | Nodo | Valor default | Descripción |
|---|---|---|---|
| `shake_amplitude_y` | Camera2D | 3.0 | Amplitud vertical en px |
| `shake_amplitude_x` | Camera2D | 1.0 | Amplitud horizontal en px |
| `shake_frequency` | Camera2D | 0.8 | Frecuencia en Hz |
| `shake_enabled` | Camera2D | true | Activar/desactivar bamboleo |

## Efectos de cámara

Tres shaders en `resources/shaders/` añaden profundidad visual:

### Blur gaussiano — depth of field (gaussian_blur.gdshader)

Aplicado a `FrontLayer > FrontSprite`. Las columnas del primer plano aparecen desenfocadas, simulando que la cámara enfoca a Kive. Usa premultiplied alpha para evitar halos oscuros en bordes transparentes.

| Parámetro | Dónde editarlo | Valor default | Descripción |
|---|---|---|---|
| `blur_radius` | FrontSprite > Material > Shader Params | 10.0 | Radio del blur en px |
| `samples` | FrontSprite > Material > Shader Params | 16 | Calidad (reducir si baja fps) |

### Motion blur horizontal (horizontal_motion_blur.gdshader)

Aplicado a `OutLayer > OutSprite`. Estrías horizontales de velocidad en el paisaje, reforzando la sensación de que el tren avanza rápido.

| Parámetro | Dónde editarlo | Valor default | Descripción |
|---|---|---|---|
| `blur_radius` | OutSprite > Material > Shader Params | 44.0 | Radio horizontal en px |
| `samples` | OutSprite > Material > Shader Params | 44 | Calidad |

### Viñeta (vignette.gdshader)

Aplicado a `PostProcess (CanvasLayer, layer=10) > Vignette (ColorRect)`. Oscurecimiento sutil de los bordes del frame.

| Parámetro | Dónde editarlo | Valor default | Descripción |
|---|---|---|---|
| `vignette_intensity` | Vignette > Material > Shader Params | 0.2 | Intensidad (0-1) |
| `vignette_softness` | Vignette > Material > Shader Params | 0.5 | Gradualidad (0-1) |
| `vignette_color` | Vignette > Material > Shader Params | Negro | Color de la viñeta |

### Alarma roja pulsante (alarm_pulse.gdshader)

Aplicado a `PostProcess (CanvasLayer, layer=10) > AlarmPulse (ColorRect)`, después de la viñeta. Simula luces de alarma reflejándose desde fuera del encuadre. El efecto es puramente periférico — nunca inunda el centro del frame, preservando la legibilidad de Kive y la atmósfera cyan/violácea de la escena. El pulso usa una curva asimétrica (subida rápida, caída lenta) para evitar una sinusoidal mecánica.

| Parámetro | Dónde editarlo | Valor default | Descripción |
|---|---|---|---|
| `alarm_color` | AlarmPulse > Material > Shader Params | (1, 0.25, 0.125) | Color de la alarma |
| `min_intensity` | AlarmPulse > Material > Shader Params | 0.08 | Intensidad mínima (siempre visible) |
| `max_intensity` | AlarmPulse > Material > Shader Params | 0.5 | Intensidad en el pico del pulso |
| `pulse_frequency` | AlarmPulse > Material > Shader Params | 0.4 | Frecuencia en Hz (~2.5s por ciclo) |
| `edge_softness` | AlarmPulse > Material > Shader Params | 0.35 | Qué tan adentro llega (0.1 = solo borde, 0.5 = invade más) |
| `asymmetry` | AlarmPulse > Material > Shader Params | 0.3 | Asimetría de la curva (0 = sinusoidal, 1 = muy asimétrica) |

## Efectos de ambiente

### Color grading (color_grading.gdshader)

Aplicado a `AtmosphereGrade (CanvasLayer, layer=9) > GradeRect (ColorRect)`. Tinte violáceo-cyan frío que unifica cromáticamente toda la escena. Usa SCREEN_TEXTURE para leer la pantalla y aplicar ajustes de saturación, contraste, lift y tinte.

| Parámetro | Dónde editarlo | Valor default | Descripción |
|---|---|---|---|
| `tint_color` | GradeRect > Material > Shader Params | (0.3, 0.4, 0.55) | Color del tinte |
| `tint_strength` | GradeRect > Material > Shader Params | 0.15 | Intensidad del tinte (0-1) |
| `contrast` | GradeRect > Material > Shader Params | 1.1 | Ajuste de contraste |
| `saturation` | GradeRect > Material > Shader Params | 0.9 | Ajuste de saturación |
| `lift` | GradeRect > Material > Shader Params | 0.02 | Elevación de sombras |

### Partículas de polvo (GPUParticles2D)

Nodo `Kive > DustParticles`. Motas de polvo flotando en el aire del vagón. El emisor sigue a Kive (`local_coords = false`) así que las partículas se generan alrededor de él y quedan flotando en el mundo mientras avanza.

| Propiedad | Valor | Descripción |
|---|---|---|
| `amount` | 44 | Número de partículas |
| `lifetime` | 4.0s | Duración de vida |
| `preprocess` | 5.0s | Pre-simulación al cargar |
| `scale_min/max` | 0.04 / 0.4 | Tamaño muy pequeño |
| `initial_velocity` | 4-44 | Rango amplio: unas flotan, otras se mueven más |
| `spread` | 180° | Direcciones totalmente aleatorias |
| `damping` | 0.4-4.0 | Frenado variable — algunas se detienen, otras derivan |

## Orden de render

Stack completo de abajo a arriba:

1. **OUT** — ParallaxBackground > OutLayer (paisaje exterior + scroll + motion blur)
2. **BACK** — ParallaxBackground > BackLayer (fondo interior, parallax 0.88)
3. **MID** — ParallaxBackground > MidLayer (paredes, butacas)
4. **Guardia** — CharacterBody2D (z=4)
5. **Kive** — CharacterBody2D (z=5)
   - DustParticles — partículas de polvo (local_coords=false)
6. **TOP** — Node2D FrontLayer (z=10, blur gaussiano)
7. **ATMO** — Node2D AtmoLayer (z=20)
8. **AtmosphereGrade** — CanvasLayer 9 (color grading)
9. **PostProcess** — CanvasLayer 10 (viñeta + alarma roja pulsante)
10. **RespawnFade** — CanvasLayer 11 (fade negro para respawn)
11. **PauseMenu** — CanvasLayer 100 (menú de controles)

## Decisiones de implementación

- **Velocidad invertida**: correr es el default, Shift = andar. El tren se siente más dinámico si Kive corre por defecto — los momentos de sigilo requieren Shift consciente.
- **Auto-hide vs toggle manual**: se eliminó el toggle con Q. El hide es automático al agacharse en una HideZone sin movimiento, simplificando los controles y haciendo el sigilo más intuitivo.
- **Salto cargado con anticipation frame**: permite feedback visual antes del salto. Al correr se salta la anticipation para no romper el flujo de movimiento.
- **collision_mask del guardia = 9 (World + Player)**: El doc original especificaba mask=8 (solo World), pero eso impedía que `get_slide_collision()` detectara a Kive para la captura. Se corrigió a 9.
- **Posiciones de ColumnCollisions provisionales**: X=1500, 3500, 5500 son estimaciones. Ajustar visualmente para alinear con las columnas reales de VAGON1_TOP.png.
- **HearingRange radius mínimo = 1px**: En vez de 0, para evitar posibles warnings de Godot con shapes de radio 0.
- **Polygon2D vs ColorRect para el guardia**: Los nodos `ColorRect` (Control) bajo `CharacterBody2D` se desacoplan del viewport cuando la cámara topa con sus límites, causando que el guardia apareciera "pegado" al borde de la pantalla. Cambiados a `Polygon2D` (Node2D) que se comportan correctamente.
- **process_mode del guardia**: El guardia usa el `process_mode` heredado (INHERIT). Anteriormente se forzaba `PROCESS_MODE_ALWAYS` pero esto impedía que el guardia se congelara al pausar el juego.
- **Step climbing (STEP_HEIGHT = 80.0)**: Tanto Kive como el guardia suben escalones automáticamente. Se usa un test de espacio libre arriba + avance a la altura elevada para determinar si un choque con pared es un escalón franqueable.

## TODOs

- Ajustar posiciones de ColumnCollisions para alinear con VAGON1_TOP.png
- El tamaño del CollisionShape de Kive (80x200) puede necesitar ajuste fino
- La posición de spawn de Kive (200, 700) es provisional
- La capa ATMO está en blend normal — experimentar con opacidad/blend si se desea
- Reemplazar placeholders visuales del guardia (Polygon2D) con sprites reales

## Bugs conocidos

- **Guardia errático cerca de columnas en SUSPICIOUS/ALERT**: El guardia se comporta erráticamente cerca de columnas (Cover layer) cuando está en estado SUSPICIOUS o ALERT. Parece relacionado con la pérdida del raycast de línea de visión al cruzar columnas. En PATROL no ocurre.
