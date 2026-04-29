# Kive en el Tren

Acción-stealth 2D ambientado en El Tren del universo Kilima. Kive, músico
en duelo, debe sobrevivir vagón a vagón sin ser arrestado ni asesinado.

Proyecto en desarrollo. Primer prototipo del Vagón 1.

## Estado actual

- **Movimiento V1** ✅ (Idle, Walk, Run, Jump, AirJump, Dive)
- **Sigilo V1** ✅ (Crouch, Hidden, Takedown)
- **Combate V1.3** ✅ (W chain + Q + cross-cancels + kill selectiva + aéreo + Dive-attack + Dash cinematico + finishers E+W/E+Q + multi-target)
- **Len-Flai V0.2** ✅ (Len-flai con triggers por alarm + transición animada + diálogo contextual)
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
- E — dash
- W — punch (mantener para cargar)
- Q — kick
- F1–F4 — debug overlay

## Tags de referencia

- `refactor-complete` — punto en el que el refactor de Kive a state machine
  quedó cerrado. Volver aquí si algo se rompe en commits futuros.
- `combat-v1.3` — combate cinemático cerrado (cap. V1.3 del roadmap).
- `lenflai-v0.1` — HUD funcional de Flai con datos reales. Sin Len todavía.
- `lenflai-v0.2` — Len-flai con state machine, transición animada, triggers por alarm, diálogo contextual.
- Sistema Flai: vive en `scripts/flai/`. Singleton de alarma: `FlaiAlarm`.
