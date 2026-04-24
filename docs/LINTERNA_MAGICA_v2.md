# Linterna Mágica + Iluminación Cinematográfica v2

> Plan definitivo. Reemplaza el v1 anterior y el refactor previo de agent_flashlight.gd. Empezamos limpio. Objetivo: linterna blanca fría que esculpe el nivel, con sombras reales, polvo flotante, parpadeo sutil constante + alerta, y vagón en penumbra violácea.

---

## ANTES DE EMPEZAR

```
git add .
git commit -m "pre-flashlight-magic-v2"
```

---

## CONTEXTO Y VISIÓN

**La linterna es el elemento protagonista de iluminación del Vagón 1.** El vagón vive en penumbra violácea. La linterna del Agent es blanca fría y esculpe el espacio con su haz. Donde no llega, no ves. Donde llega, se proyectan sombras nítidas de Kive, Agent, butacas y columnas.

**Paleta narrativa reforzada:**
- Kive = rojo saturado
- Flai = cyan digital
- Agent = **blanco frío** (tecnología humana práctica, fría pero no digital)
- Vagón = violáceo apagado

Cuando Kive entra en el cono, el rojo choca con el blanco frío. Lectura instantánea de peligro.

---

## ARQUITECTURA LIMPIA

Olvidamos el refactor previo (agent_flashlight.gd con 4 nodos + Polygon2D ConeVisual). Empezamos de cero.

**Un solo sistema**: `FlashlightSystem.tscn`, escena reutilizable. Se instancia como hijo de `FlashlightHand` en Agent.tscn.

**Composición interna:**
```
FlashlightSystem (Node2D)
├── ConeLight (PointLight2D)          # el haz principal, proyecta sombras
├── BulbGlow (PointLight2D)           # resplandor en la lente
├── GroundSpot (PointLight2D)         # mancha de luz en el suelo
├── DustParticles (GPUParticles2D)    # polvo flotante en el haz
└── FlickerController (Node)           # script de parpadeo
```

**API pública:**
```gdscript
flashlight.set_active(bool)      # encender / apagar (visibility + enabled)
flashlight.set_alert_mode(bool)  # modo alerta (más parpadeo)
```

Eso es todo lo que el Agent llama. Todo lo demás es interno.

---

## ROADMAP DE FASES

- **FASE 0** — Eliminar código previo (refactor de tu hermano + cualquier resto)
- **FASE 1** — CanvasModulate global (vagón oscuro)
- **FASE 2** — Generador de textura de cono (blanco frío)
- **FASE 3** — Escena FlashlightSystem.tscn
- **FASE 4** — Script flashlight_system.gd con flicker integrado
- **FASE 5** — Integración en Agent.tscn + agent.gd
- **FASE 6** — DustParticles (el polvo)
- **FASE 7** — LightOccluder2D en Kive
- **FASE 8** — LightOccluder2D en Agent
- **FASE 9** — LightOccluder2D en butacas MID (4 grupos)
- **FASE 10** — Afinado visual

---

## FASE 0 — Limpiar lo previo

### 0.1 Eliminar archivos y nodos

- **Borrar** `scripts/agent_flashlight.gd` (el refactor previo).
- **Borrar** el nodo FlashlightHand completo en Agent.tscn (se recrea en Fase 5).
- **Borrar** cualquier otra referencia a `SourceGlow`, `GroundSpot` antiguo, `BounceLight`, `ConeVisual` (Polygon2D) en Agent.tscn o agent.gd.
- En `agent.gd`: buscar y quitar `flashlight_system.set_active(...)` y `flashlight_system.set_enabled(...)` temporalmente (se reintroducen en Fase 5 con otra API).

### 0.2 Mantener el cono de detección

**IMPORTANTE:** el Area2D `FlashlightConeDetector` que usa el Agent para detectar a Kive NO se toca. Es independiente del sistema visual de luz. El sistema de detección del juego sigue funcionando exactamente igual.

### Verificación Fase 0
- El juego arranca sin crashes (sin luz visible del Agent de momento)
- La detección sigue funcionando: Kive entra al trapecio Area2D → Agent lo detecta

---

## FASE 1 — CanvasModulate global

### 1.1 Añadir nodo en Vagon1.tscn

Como hijo directo del nodo raíz de la escena, antes que las capas BACK/MID/TOP:

```
CanvasModulate
  color = Color(0.18, 0.18, 0.24, 1.0)
```

Este nodo multiplica toda la escena. Todo lo que no esté iluminado por un Light2D queda en penumbra violácea.

### 1.2 Revisar luces decorativas existentes

Si en el vagón hay PointLight2D decorativos (luces de techo, pantallas cyan, lo que sea), ahora destacarán mucho más. Bajar su `energy` si es necesario:
- Pantallas cyan: `energy = 0.3-0.5`
- Luces de techo: `energy = 0.2-0.4` (si existen)

### Verificación Fase 1
- Vagón se ve muy oscuro, casi negro violáceo
- Kive y Agent son siluetas tenues
- Cualquier pantalla cyan brilla con presencia propia
- Esto es lo esperado. La linterna vuelve a iluminar en fases siguientes

---

## FASE 2 — Generador de textura de cono

### 2.1 Script generador

Crear `scripts/cone_texture_generator.gd`:

```gdscript
@tool
class_name ConeTextureGenerator
extends Node


# Genera una textura de cono blanco-frío para usar como PointLight2D.texture
# El cono apunta hacia la derecha (+X), se flipea con scale.x negativo del padre

static func generate(size: Vector2i = Vector2i(512, 280)) -> ImageTexture:
    var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    
    var center_y: float = size.y / 2.0
    
    # Parámetros del cono
    var origin_width_pct: float = 0.12  # cómo de "abierto" es el origen (0 = puntito)
    var max_width_pct: float = 0.95      # cómo de abierto está el extremo
    var falloff_curve: float = 1.8       # curva de caída (2.0 = cuadrático, 1.0 = lineal)
    
    for x in range(size.x):
        for y in range(size.y):
            var dist_x: float = float(x) / float(size.x)  # 0 en origen, 1 en extremo
            
            # Ancho del cono en esta X
            var cone_width: float = lerp(origin_width_pct, max_width_pct, dist_x)
            
            # Distancia vertical normalizada del eje central
            var dist_y: float = abs(float(y) - center_y) / center_y
            
            var alpha: float = 0.0
            
            if dist_y <= cone_width:
                # Dentro del cono
                var horizontal_falloff: float = pow(1.0 - dist_x, falloff_curve)
                var edge_softness: float = 1.0 - pow(dist_y / cone_width, 2.0)
                alpha = horizontal_falloff * edge_softness
            
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
    
    return ImageTexture.create_from_image(img)
```

### 2.2 Uso

La textura se genera una vez en `_ready()` del flashlight_system.gd (Fase 4). No necesitas guardarla como `.tres` — es ligera y se regenera en 20ms al arrancar.

### Verificación Fase 2
- El script compila sin errores
- La función es callable como `ConeTextureGenerator.generate()`

---

## FASE 3 — Escena FlashlightSystem.tscn

### 3.1 Crear escena

Archivo: `scenes/FlashlightSystem.tscn`

Estructura de nodos:

```
FlashlightSystem (Node2D)
│ - script: flashlight_system.gd (se crea en Fase 4)
│
├── ConeLight (PointLight2D)
│     energy = 1.5
│     color = Color(0.85, 0.92, 1.0, 1.0)     # blanco frío con tinte azulado muy leve
│     blend_mode = BLEND_MODE_ADD
│     shadow_enabled = true
│     shadow_filter = Light2D.SHADOW_FILTER_PCF13
│     shadow_filter_smooth = 2.0
│     shadow_color = Color(0.0, 0.0, 0.05, 0.92)
│     range_item_cull_mask = 1
│     texture_scale = 1.0
│     offset = Vector2(256, 0)                  # centro del cono 256px adelante
│     (texture se asigna en runtime desde el script)
│
├── BulbGlow (PointLight2D)
│     energy = 2.5
│     color = Color(1.0, 1.0, 1.0, 1.0)        # blanco puro en la lente
│     blend_mode = BLEND_MODE_ADD
│     shadow_enabled = false
│     texture_scale = 0.15                      # muy pequeñito
│     offset = Vector2(0, 0)                    # justo en la posición de la mano
│     (texture: usar un radial gradient estándar; Godot incluye uno por defecto)
│
├── GroundSpot (PointLight2D)
│     energy = 0.6
│     color = Color(0.85, 0.92, 1.0, 1.0)      # blanco frío tenue
│     blend_mode = BLEND_MODE_ADD
│     shadow_enabled = false                    # el suelo no ocluye
│     texture_scale = 0.4
│     offset = Vector2(280, 120)                # adelante y abajo
│     (texture: radial gradient estándar aplastado con scale.y = 0.4)
│
└── DustParticles (GPUParticles2D)
      (se configura en Fase 6)
```

### 3.2 Texturas base necesarias

**Radial gradient estándar para BulbGlow y GroundSpot**: Godot no siempre incluye una por defecto. Si tu hermano no la encuentra:
- Crear `resources/radial_gradient.tres` = GradientTexture2D
  - fill = GradientTexture2D.FILL_RADIAL
  - gradient: blanco sólido a transparente, con curve suave
  - width, height = 256

**Cone texture para ConeLight**: se genera en runtime, no requiere `.tres`.

### Verificación Fase 3
- La escena se abre sin errores
- Los 3 PointLight2D son visibles en el editor (los nodos, aún sin texture asignada en ConeLight)

---

## FASE 4 — Script flashlight_system.gd

### 4.1 Archivo

Crear `scripts/flashlight_system.gd`:

```gdscript
extends Node2D
## Sistema de linterna cinematográfica del Agent.
## Composición de ConeLight (proyecta sombras), BulbGlow (lente), GroundSpot (suelo),
## DustParticles (polvo) y control de parpadeo (flicker).
##
## API pública:
##   set_active(bool)      — enciende / apaga todo el sistema
##   set_alert_mode(bool)  — aumenta la frecuencia e intensidad del parpadeo


const ConeTextureGenerator = preload("res://scripts/cone_texture_generator.gd")

@onready var cone_light: PointLight2D = $ConeLight
@onready var bulb_glow: PointLight2D = $BulbGlow
@onready var ground_spot: PointLight2D = $GroundSpot
@onready var dust_particles: GPUParticles2D = $DustParticles

# === Flicker ===
@export_group("Flicker sutil (idle)")
@export var flicker_idle_min_interval: float = 3.0
@export var flicker_idle_max_interval: float = 8.0
@export var flicker_idle_dip_energy: float = 0.75   # multiplicador de energy durante el dip
@export var flicker_idle_dip_duration: float = 0.08

@export_group("Flicker alerta")
@export var flicker_alert_min_interval: float = 0.4
@export var flicker_alert_max_interval: float = 1.2
@export var flicker_alert_dip_energy: float = 0.4
@export var flicker_alert_dip_duration: float = 0.05

var _is_active: bool = true
var _is_alert: bool = false
var _next_flicker_time: float = 0.0
var _time_accumulator: float = 0.0

# Guardar energías base para restaurar después del flicker
var _base_cone_energy: float = 0.0
var _base_bulb_energy: float = 0.0
var _base_ground_energy: float = 0.0


func _ready() -> void:
    # Generar y asignar textura de cono
    cone_light.texture = ConeTextureGenerator.generate(Vector2i(512, 280))
    
    # Guardar energías base
    _base_cone_energy = cone_light.energy
    _base_bulb_energy = bulb_glow.energy
    _base_ground_energy = ground_spot.energy
    
    _schedule_next_flicker()


func _process(delta: float) -> void:
    if not _is_active:
        return
    
    _time_accumulator += delta
    
    if _time_accumulator >= _next_flicker_time:
        _do_flicker()
        _schedule_next_flicker()


func set_active(active: bool) -> void:
    _is_active = active
    visible = active
    cone_light.enabled = active
    bulb_glow.enabled = active
    ground_spot.enabled = active
    dust_particles.emitting = active


func set_alert_mode(alert: bool) -> void:
    _is_alert = alert
    # Opcional: cambio de color/intensidad en alerta
    if alert:
        cone_light.energy = _base_cone_energy * 1.15
    else:
        cone_light.energy = _base_cone_energy


func _schedule_next_flicker() -> void:
    var min_i: float = flicker_alert_min_interval if _is_alert else flicker_idle_min_interval
    var max_i: float = flicker_alert_max_interval if _is_alert else flicker_idle_max_interval
    _next_flicker_time = _time_accumulator + randf_range(min_i, max_i)


func _do_flicker() -> void:
    var dip_mult: float = flicker_alert_dip_energy if _is_alert else flicker_idle_dip_energy
    var dip_dur: float = flicker_alert_dip_duration if _is_alert else flicker_idle_dip_duration
    
    # A veces doble blip (20% de las veces)
    var do_double: bool = randf() < 0.2
    
    var tween: Tween = create_tween()
    tween.tween_property(cone_light, "energy", _base_cone_energy * dip_mult, dip_dur * 0.4)
    tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy * dip_mult, dip_dur * 0.4)
    tween.parallel().tween_property(ground_spot, "energy", _base_ground_energy * dip_mult, dip_dur * 0.4)
    
    tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.6)
    tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy, dip_dur * 0.6)
    tween.parallel().tween_property(ground_spot, "energy", _base_ground_energy, dip_dur * 0.6)
    
    if do_double:
        tween.tween_interval(0.05)
        tween.tween_property(cone_light, "energy", _base_cone_energy * dip_mult, dip_dur * 0.3)
        tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy * dip_mult, dip_dur * 0.3)
        tween.tween_property(cone_light, "energy", _base_cone_energy, dip_dur * 0.4)
        tween.parallel().tween_property(bulb_glow, "energy", _base_bulb_energy, dip_dur * 0.4)
```

### 4.2 Asignar script a la escena

En FlashlightSystem.tscn, seleccionar el nodo raíz → asignar `flashlight_system.gd`.

### Verificación Fase 4
- La escena FlashlightSystem.tscn abre sin errores
- Al arrancar la escena aislada (play scene solo), se ve el cono blanco frío + bulb + ground spot
- Cada 3-8 segundos hay un mini parpadeo
- 20% de parpadeos son dobles

---

## FASE 5 — Integración en Agent.tscn + agent.gd

### 5.1 Estructura de Agent.tscn

Bajo el nodo raíz Agent, recrear la FlashlightHand:

```
Agent (CharacterBody2D)
├── (todos los nodos existentes: Sprite, CollisionShape, Hurtbox, etc.)
├── FlashlightHand (Node2D)
│     position = Vector2(65, -40)        # ajustar visualmente a la mano del sprite
│     (scale.x se flipea al cambiar facing_right; lo gestiona agent.gd)
│     │
│     └── FlashlightSystem (instancia de FlashlightSystem.tscn)
│
├── FlashlightConeDetector (Area2D)
│     (SIN CAMBIOS — sigue como estaba para detección)
│     ...
```

**Nota:** `FlashlightSystem` es una instancia, no un nodo creado a mano. Arrastrar `scenes/FlashlightSystem.tscn` al árbol de Agent como hijo de FlashlightHand.

### 5.2 Cambios en agent.gd

Reemplazar las viejas referencias al sistema de linterna.

Añadir referencia:
```gdscript
@onready var flashlight_system: Node2D = $FlashlightHand/FlashlightSystem
```

Eliminar las viejas (`source_glow`, `ground_spot`, `bounce_light`, `cone_visual`).

En `_ready()`:
```gdscript
func _ready() -> void:
    # ... código existente ...
    flashlight_system.set_active(true)
    flashlight_system.set_alert_mode(false)
```

En `_update_visuals()` o donde se actualiza el facing:
```gdscript
# Flipear la mano completa (y con ella, el FlashlightSystem)
flashlight_hand.scale.x = -1.0 if not facing_right else 1.0
```

En transiciones de estado, activar el alert mode cuando corresponda:
```gdscript
func _enter_state(new_state: State) -> void:
    state = new_state
    state_timer = 0.0
    # ... código existente ...
    
    # Alert mode activado en estados de combate
    match new_state:
        State.GUARD_STANCE, State.WINDUP, State.ATTACK_RELEASE, State.GUARD_BROKEN:
            flashlight_system.set_alert_mode(true)
        State.PATROL:
            flashlight_system.set_alert_mode(false)
        State.DEAD:
            flashlight_system.set_active(false)
```

### Verificación Fase 5
- Al arrancar Vagon1, el Agent tiene cono blanco frío visible
- Cono se flipea al cambiar dirección de patrulla
- Cuando el Agent detecta a Kive y entra en GUARD_STANCE, el parpadeo se intensifica
- Cuando vuelve a PATROL, el parpadeo se relaja
- Cuando muere, la linterna se apaga

---

## FASE 6 — DustParticles (el polvo)

### 6.1 Configurar GPUParticles2D dentro de FlashlightSystem.tscn

Seleccionar el nodo DustParticles (ya existe vacío desde Fase 3):

```
DustParticles (GPUParticles2D)
  emitting = true
  amount = 40
  lifetime = 3.5
  preprocess = 2.0                       # pre-llena el cono al arrancar
  speed_scale = 1.0
  explosiveness = 0.0
  randomness = 0.8
  local_coords = false                   # IMPORTANTE: coords globales para que el polvo no se arrastre con el agent
  
  process_material = [ParticleProcessMaterial nuevo]
  texture = [imagen pequeña de mota: 4x4 blanco con alpha, o CanvasItem blanco puro]
```

### 6.2 ParticleProcessMaterial

```
ParticleProcessMaterial
  direction = Vector3(1, 0, 0)           # polvo "viaja" hacia adelante del cono
  spread = 35.0                          # en grados; abre el polvo en cono
  initial_velocity_min = 2.0
  initial_velocity_max = 8.0             # MUY lento
  
  gravity = Vector3(0, -3.0, 0)          # flota HACIA ARRIBA levemente
  
  angular_velocity_min = -5.0
  angular_velocity_max = 5.0
  
  scale_min = 0.3
  scale_max = 1.2
  scale_curve = [curve que sube y baja: nace pequeño, crece, muere pequeño]
  
  color = Color(1.0, 1.0, 1.0, 0.25)    # blanco semitransparente
  color_ramp = [opcional: blanco → blanco-azulado muy leve]
  
  emission_shape = EMISSION_SHAPE_BOX
  emission_box_extents = Vector3(256, 100, 0)   # caja que cubre el cono
  (position del nodo DustParticles ajustada para que la caja empiece desde la lente)
```

### 6.3 Material de textura aditiva

El nodo DustParticles debe tener:
```
CanvasItemMaterial
  blend_mode = BLEND_MODE_ADD            # CLAVE: solo brilla cuando está en luz
```

**Efecto resultante:** las partículas son blanco semitransparente con blend ADD. Fuera del cono de luz: casi invisibles (fondo oscuro + ADD = casi nada). Dentro del cono: brillan porque el cono las ilumina y el ADD las suma. Polvo solo visible en la luz. Exactamente lo que quieres.

### 6.4 Textura de mota

Si no tienes una textura de partícula a mano, generar una mini PNG en Krita:
- 8x8 píxeles
- Círculo blanco difuminado con alpha (bordes suaves)

O usar un `GradientTexture2D` radial en el GPUParticles2D.texture directamente.

### Verificación Fase 6
- Al arrancar, se ven motas de polvo flotando dentro del cono
- El polvo es sutil, no dominante
- Fuera del cono no se ve (o apenas)
- El polvo tiene movimiento suave, no turbulento
- Si el Agent patrulla, el polvo viejo se queda atrás (local_coords=false) mientras el nuevo se emite delante

---

## FASE 7 — LightOccluder2D en Kive

### 7.1 Nodo a añadir en Kive.tscn

Como hijo del nodo raíz de Kive:

```
LightOccluder (LightOccluder2D)
  light_mask = 1
  occluder = [OccluderPolygon2D nuevo]
```

### 7.2 Polígono (silueta aproximada)

OccluderPolygon2D.polygon:
```
PackedVector2Array([
  Vector2(-25, -110),   # esquina superior izquierda cabeza
  Vector2(25, -110),    # esquina superior derecha cabeza
  Vector2(35, -70),
  Vector2(45, -40),
  Vector2(45, 40),
  Vector2(30, 90),
  Vector2(30, 110),     # pie derecho
  Vector2(-30, 110),    # pie izquierdo
  Vector2(-30, 90),
  Vector2(-45, 40),
  Vector2(-45, -40),
  Vector2(-35, -70),
])
```

closed = true

### 7.3 Ajuste

Los vértices son aproximados. En el editor, seleccionar el OccluderPolygon2D y ajustar visualmente hasta que encaje con la silueta de Kive idle.

### Verificación Fase 7
- Cuando Kive está en el cono del Agent, proyecta sombra hacia atrás (opuesta a la luz)
- La sombra se mueve con Kive
- Si Kive sale del cono, no hay sombra

---

## FASE 8 — LightOccluder2D en Agent

### 8.1 Nodo en Agent.tscn

Bajo el nodo raíz Agent:

```
LightOccluder (LightOccluder2D)
  light_mask = 2                         # CLAVE: distinto de 1
  occluder = [OccluderPolygon2D]
```

### 8.2 Por qué light_mask = 2

El ConeLight tiene `range_item_cull_mask = 1`, que significa "solo ocluye cosas con light_mask = 1". El Agent tiene light_mask = 2, así que **su propia linterna no lo ve como occluder** (no se auto-ocluye).

Kive tiene light_mask = 1, así que SÍ es ocluido por la linterna del Agent.

Las butacas tendrán light_mask = 1 (ver Fase 9).

### 8.3 Polígono del Agent

OccluderPolygon2D.polygon:
```
PackedVector2Array([
  Vector2(-22, -105),
  Vector2(22, -105),
  Vector2(35, -65),
  Vector2(42, -30),
  Vector2(42, 45),
  Vector2(32, 95),
  Vector2(32, 108),
  Vector2(-32, 108),
  Vector2(-32, 95),
  Vector2(-42, 45),
  Vector2(-42, -30),
  Vector2(-35, -65),
])
```

closed = true

### Verificación Fase 8
- El Agent NO proyecta sombra sobre su propio cono
- Kive SIGUE proyectando sombra cuando entra al cono

---

## FASE 9 — LightOccluder2D en butacas MID (4 grupos)

### 9.1 Concepto

Las butacas están dibujadas dentro de VAGON1_MID.png. Añadimos 4 LightOccluder2D como hijos de la capa MID, posicionados encima de cada grupo de butacas.

### 9.2 Script de setup (recomendado para hacerlo rápido)

Crear `scripts/butaca_occluders_setup.gd`:

```gdscript
@tool
extends Node2D
## Placeholder para los 4 occluders de butacas del Vagón 1.
## Hijo de la capa MID en Vagon1.tscn.

const BUTACA_POSITIONS: Array[Vector2] = [
    Vector2(2500, 750),
    Vector2(3300, 750),
    Vector2(4100, 750),
    Vector2(4900, 750),
]

const BUTACA_POLYGON: PackedVector2Array = PackedVector2Array([
    Vector2(-150, -80),
    Vector2(-130, -100),
    Vector2(-80, -80),
    Vector2(-40, -100),
    Vector2(0, -80),
    Vector2(40, -100),
    Vector2(80, -80),
    Vector2(130, -100),
    Vector2(150, -80),
    Vector2(150, 80),
    Vector2(-150, 80),
])


func _enter_tree() -> void:
    if not Engine.is_editor_hint():
        return
    
    # Crear occluders si no existen
    if get_child_count() == 0:
        _create_occluders()


func _create_occluders() -> void:
    for i in range(BUTACA_POSITIONS.size()):
        var occluder := LightOccluder2D.new()
        occluder.name = "ButacaOccluder%d" % (i + 1)
        occluder.position = BUTACA_POSITIONS[i]
        occluder.light_mask = 1
        
        var poly := OccluderPolygon2D.new()
        poly.polygon = BUTACA_POLYGON
        poly.closed = true
        occluder.occluder = poly
        
        add_child(occluder)
        occluder.owner = get_tree().edited_scene_root
```

### 9.3 Uso

En Vagon1.tscn, añadir un Node2D llamado `ButacaOccluders` como hijo de la capa MID, y asignarle este script. Al guardar la escena, se crearán los 4 occluders.

### 9.4 Ajuste visual

Las posiciones X (2500, 3300, 4100, 4900) y la Y (750) son **estimaciones**. Al ver el resultado en Godot, tu hermano arrastrará cada occluder hasta que coincida con su grupo de butacas correspondiente.

### Verificación Fase 9
- Los 4 occluders aparecen en la escena
- Cuando el Agent patrulla y el cono pasa por encima de las butacas, se proyectan 4 sombras alargadas hacia atrás
- Si Kive se esconde detrás de una butaca, queda en sombra (la butaca lo oculta físicamente de la luz)

---

## FASE 10 — Afinado visual

Ejecutar el juego y verificar el mood general. Ajustar estos parámetros hasta que quede como quieres:

### Panel de mandos para afinar

| Parámetro | Dónde | Efecto si subes |
|---|---|---|
| `CanvasModulate.color` | Vagon1.tscn | Vagón más claro / menos mood |
| `ConeLight.energy` | FlashlightSystem.tscn | Cono más intenso |
| `ConeLight.color` | FlashlightSystem.tscn | Tono del haz (más azul / más blanco) |
| `ConeLight.shadow_color.a` | FlashlightSystem.tscn | Sombras más opacas |
| `ConeLight.shadow_filter_smooth` | FlashlightSystem.tscn | Sombras más difuminadas |
| `ConeLight.texture_scale` | FlashlightSystem.tscn | Cono más grande |
| `BulbGlow.energy` | FlashlightSystem.tscn | Punto de la lente más brillante |
| `GroundSpot.energy` | FlashlightSystem.tscn | Mancha del suelo más visible |
| `DustParticles.amount` | FlashlightSystem.tscn | Más polvo |
| `flicker_idle_min/max_interval` | FlashlightSystem.tscn | Parpadeos más frecuentes |

### Valores de partida ya están en el plan

Son estimaciones razonables. El afinado fino puede requerir 20-30 minutos de prueba-error visual hasta que te enamore.

---

## ARCHIVOS INVOLUCRADOS

| Archivo | Acción |
|---|---|
| `scripts/agent_flashlight.gd` | **Borrar** (Fase 0) |
| `scripts/cone_texture_generator.gd` | Crear |
| `scripts/flashlight_system.gd` | Crear |
| `scripts/butaca_occluders_setup.gd` | Crear |
| `scenes/FlashlightSystem.tscn` | Crear |
| `scenes/Agent.tscn` | Modificar (recrear FlashlightHand + FlashlightSystem, añadir LightOccluder) |
| `scenes/Kive.tscn` (o inline en Vagon1) | Modificar (añadir LightOccluder) |
| `scenes/Vagon1.tscn` | Modificar (CanvasModulate, ButacaOccluders) |
| `scripts/agent.gd` | Modificar (nueva API de flashlight_system) |
| `resources/radial_gradient.tres` | Crear si no existe (opcional) |

---

## ESTIMACIÓN

- Ejecución inicial: 2-3 horas con Claude Code
- Afinado visual: 1-2 sesiones (30-60 min cada una)

Commit final: `flashlight magic v2`

---

## LO QUE NO HACE ESTE PLAN (explícito)

- NO toca combate, AI, animaciones, movimiento, stealth, crouch, hide zones
- NO toca FlashlightConeDetector (Area2D de detección)
- NO añade occluders a columnas del BACK ni marcos del TOP (iteración futura)
- NO añade luces cenitales decorativas al vagón (iteración futura, opcional)

---

## PREGUNTAS ABIERTAS PARA ITERACIONES FUTURAS

- Shader custom de "haz con volumen" en vez de textura plana (más avanzado)
- Parpadeo reactivo a eventos específicos (ej: Kive en el cono → parpadeo mayor)
- Segundo Agent con linterna de color distinto (más tarde en el juego)
- Luces cenitales del techo del vagón (reforzarían el mood de vagón abandonado)
- Reflejos del cono en el suelo pulido oro rosa (efecto especular)
