# Kive en el Tren

Acción-stealth 2D ambientado en El Tren del universo Kilima. Kive, músico
en duelo, debe sobrevivir vagón a vagón sin ser arrestado ni asesinado.

Proyecto en desarrollo. Primer prototipo del Vagón 1.

## Estado actual

- **Movimiento V1** ✅ (Idle, Walk, Run, Jump, AirJump, Dive)
- **Sigilo V1** ✅ (Crouch, Hidden, Execution)
- **Combate V1.2** ✅ (W chain + Q standalone + Q-en-contexto + cross-cancels + kill selectiva + Q=KO landing + cuerpos empujables)
- **Detección centralizada** 📋 planeada
- **Vagón 2 (Yeri)** 📋 planeado

## Documentación

- [`docs/design/KIVE_TREN_GDD.md`](docs/design/KIVE_TREN_GDD.md) — diseño del juego completo
- [`docs/design/COMBAT_V1_GDD.md`](docs/design/COMBAT_V1_GDD.md) — diseño del combate V1
- [`docs/design/IDEAS_SUELTAS_BACKLOG.md`](docs/design/IDEAS_SUELTAS_BACKLOG.md) — backlog y cosas pendientes
- [`docs/systems/`](docs/systems/) — documentación técnica por sistema (en construcción)

## Cómo abrir el proyecto

Godot 4. Abrir `project.godot` desde el editor.

Escena principal: `scenes/Vagon1.tscn`.

## Controles

Configurables desde el menú de pausa (ESC). Defaults:
- A/D — movimiento horizontal
- Space — saltar (mantener para cargar)
- Shift izquierdo — andar (lento, sigilo)
- Shift derecho — dive
- S/C — agacharse
- W — punch (mantener para cargar)
- Q — kick
- F1–F4 — debug overlay

## Tag de referencia

`refactor-complete` — punto en el que el refactor de Kive a state machine
quedó cerrado. Volver aquí si algo se rompe en commits futuros.
