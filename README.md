# Kive en el Tren — Prototipo Vagón 1

Primer prototipo jugable del juego "Kive en el Tren". Solo movimiento del personaje en el escenario del Vagón 1, sin enemigos, combate ni audio.

## Estructura de carpetas

```
├── assets/              # Sprites y fondos PNG
│   ├── VAGON1_OUT.png   # Paisaje exterior proyectado — scroll rápido (7680x1080)
│   ├── VAGON1_BACK.png  # Fondo interior del vagón — paralaje (7680x1080)
│   ├── VAGON1_MID.png   # Capa media — paredes, butacas (7680x1080)
│   ├── VAGON1_TOP.png   # Capa frente — columnas que ocultan a Kive (7680x1080)
│   ├── VAGON1_ATMO.png  # Capa atmosférica encima de todo (7680x1080)
│   ├── Kive_Sprite.png           # Idle (256x256)
│   ├── Kive_WalkingCycle_Sprite.png  # Walk spritesheet (1280x256, 5 frames)
│   └── Kive_Jump_Sprite.png         # Jump spritesheet (1280x256, 5 frames)
├── resources/
│   ├── kive_frames.tres  # SpriteFrames con todas las animaciones
│   └── shaders/
│       ├── gaussian_blur.gdshader          # Depth of field (FrontLayer)
│       ├── horizontal_motion_blur.gdshader # Estrías de velocidad (OutLayer)
│       ├── vignette.gdshader               # Viñeta global (PostProcess)
│       ├── color_grading.gdshader          # Tinte atmosférico (AtmosphereGrade)
│       └── alarm_pulse.gdshader           # Alarma roja pulsante periférica (PostProcess)
├── scenes/
│   └── Vagon1.tscn       # Escena principal del vagón
├── scripts/
│   ├── kive.gd            # Script de movimiento de Kive
│   ├── train_scroll.gd    # Scroll continuo del paisaje (OutLayer)
│   └── train_shake.gd     # Bamboleo de cámara (Camera2D)
└── project.godot
```

## Capas de renderizado

El vagón usa 5 capas visuales con z_index para controlar profundidad:

| Capa | Nodo | z_index | Notas |
|---|---|---|---|
| OUT | ParallaxBackground > OutLayer | 0 | Paisaje exterior, motion_scale=1.0, scroll continuo + motion blur |
| BACK | ParallaxBackground > BackLayer | 0 | Fondo interior del vagón, motion_scale=0.88 (paralaje sutil) |
| MID | ParallaxBackground > MidLayer | 0 | Paredes, butacas, motion_scale=1.0 |
| Kive | CharacterBody2D | 5 | Personaje jugable |
| TOP | Node2D (FrontLayer) | 10 | Columnas que ocultan a Kive |
| ATMO | Node2D (AtmoLayer) | 20 | Capa atmosférica sobre todo |

**Nota sobre el paisaje**: El fondo exterior (OUT) es una proyección plana de Flai en pantallas LED integradas en el vagón. Usa `motion_scale=(1, 1)` para que se mueva solidario al vagón. El desplazamiento visible lo genera el scroll continuo via `motion_offset` en `train_scroll.gd`.

**Nota sobre BACK**: La capa BACK es el fondo interior del vagón (columnas lejanas, estructura). Tiene `motion_scale=(0.88, 1)` para un paralaje sutil respecto a MID, dando sensación de profundidad dentro del vagón.

**Nota técnica**: La capa TOP no usa ParallaxBackground porque Godot 4 no respeta z_index entre ParallaxBackground y nodos regulares. Se usa un Node2D con z_index=10 que se mueve 1:1 con la cámara (equivalente a motion_scale=1.0).

## Controles

| Acción | Teclas |
|---|---|
| Mover izquierda | Flecha izquierda, A |
| Mover derecha | Flecha derecha, D |
| Saltar | Espacio, W, Flecha arriba |
| Correr | Shift (mantener) |

## Parámetros ajustables desde el editor

Selecciona el nodo `Kive` en el inspector para modificar:

| Parámetro | Valor default | Descripción |
|---|---|---|
| `walk_speed` | 300.0 | Velocidad al caminar |
| `run_speed` | 850.0 | Velocidad al correr (Shift) |
| `jump_velocity` | -900.0 | Impulso vertical del salto |
| `gravity` | 2400.0 | Fuerza de gravedad |
| `air_control_factor` | 0.7 | Multiplicador de control en el aire |

## Geometría del nivel

### Suelo principal
`StaticBody2D` con `CollisionShape2D` horizontal que cubre todo el vagón (7680x50, centrado en y=800).

### Paredes invisibles
Dos `StaticBody2D` con colisión vertical (50x1080) en los bordes del nivel:
- **ParedIzquierda** — x=0, impide salir por la izquierda
- **ParedDerecha** — x=7680, impide salir por la derecha

### Escaleras y suelo elevado
Al final del vagón (derecha) hay una escalera de 2 escalones (`Escalon1`, `Escalon2`) que conecta el suelo principal con un `SueloElevado` más alto. Los escalones son `CollisionShape2D` dentro de un `StaticBody2D` llamado `Escaleras`. Kive sube saltando escalón a escalón.

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
4. **Kive** — CharacterBody2D (z=5)
   - DustParticles — partículas de polvo (local_coords=false)
5. **TOP** — Node2D FrontLayer (z=10, blur gaussiano)
6. **ATMO** — Node2D AtmoLayer (z=20)
7. **AtmosphereGrade** — CanvasLayer 9 (color grading)
8. **PostProcess** — CanvasLayer 10 (viñeta + alarma roja pulsante)

## TODOs

- El tamaño del CollisionShape de Kive (80x200) puede necesitar ajuste fino
- La posición de spawn de Kive (200, 700) es provisional
- La capa ATMO está en blend normal — experimentar con opacidad/blend si se desea
