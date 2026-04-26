# Manual Testing Checklist — Kive Refactor

> **Documento vivo.** Pasar esta checklist al final de **CADA fase** del refactor.
> Si algo falla o se siente distinto al estado pre-refactor, **parar y debuguear**. No avanzar.

---

## 🎮 Cómo usar esta checklist

1. Antes de empezar el refactor, jugar el Vagón 1 con la versión actual y memorizar el feel de cada mecánica.
2. Después de cada fase, lanzar el juego y recorrer esta lista entera.
3. Marcar cada punto con ✅ (funciona idéntico) o ❌ (algo cambió).
4. Si hay un ❌ → parar, debuguear, no commitear hasta que esté arreglado.
5. Para fases que tocan combate (FASE 6) o jump (FASE 4), recorrer la lista DOS VECES.

---

## ✅ Checklist completa

### Movimiento horizontal
- [ ] Idle: Kive parado en suelo plano, sprite "idle" reproduciendo
- [ ] Walk (run lento): mantener `run` y moverse → velocidad walk_speed (400)
- [ ] Run (default): mover sin presionar `run` → velocidad run_speed (800)
- [ ] Cambio walk↔run mid-movimiento: instantáneo, sin glitches
- [ ] Detenerse: Kive frena suavemente, no para de golpe
- [ ] Cambio de dirección: sprite voltea correctamente (flip_h)

### Crouch
- [ ] Modo TOGGLE (PauseMenu hold_to_crouch=false): pulsar crouch → agachado, pulsar de nuevo → levantado
- [ ] Modo HOLD (PauseMenu hold_to_crouch=true): mantener crouch → agachado, soltar → levantado
- [ ] Crouch walk: agachado + mover → velocidad crouch_walk_speed (200)
- [ ] Sprite correcto: `crouch_idle` parado, `crouch_walk` moviéndose
- [ ] Collision shape se reduce al agacharse (probar bajo cornisa baja)
- [ ] No se puede saltar agachado (jump no hace nada hasta levantarse)
- [ ] No se puede atacar agachado salvo desde Hidden

### Salto estándar
- [ ] Salto estático (parado + space tap rápido): salto bajo
- [ ] Salto con carga corta (parado + space mantenido ~0.2s): salto medio
- [ ] Salto con carga larga (parado + space mantenido 0.4s+): salto máximo
- [ ] Anticipación visible: sprite `jump_anticipation`, Kive se queda quieto durante carga
- [ ] Cancelación: mantener space >4s → cancela el salto, sprite `jump_recovery`
- [ ] Running jump: moviéndose + space → salto inmediato sin anticipación, sprite `jump_air`
- [ ] Air control: durante salto, mover horizontal aplica con factor 0.8
- [ ] Aterrizaje: contact (`jump_contact`) → recovery (`jump_recovery`) → idle/walk

### Double jump (air jump)
- [ ] Saltar + space en aire → segundo salto, sprite `air_jump_rise`
- [ ] Solo se permite 1 air jump por ciclo (max_air_jumps = 1)
- [ ] Después del air jump, no se puede saltar más hasta tocar suelo
- [ ] Aterrizaje desde air jump funciona normal

### Caída sin salto
- [ ] Saltar de un borde sin pulsar space → estado falling correcto
- [ ] Sprite `jump_precontact` cuando velocity.y > 200
- [ ] Aterrizaje correcto al tocar suelo

### Dive
- [ ] Ground dive: moviéndose (no walking lento) + dive → desliza a velocidad alta
- [ ] Ground dive frena gradualmente (dive_friction)
- [ ] Ground dive timeout: máximo 1.2s
- [ ] Air dive: en el aire + dive → impulso horizontal + caída acelerada
- [ ] Air dive landing: al aterrizar, mantener dive → sigue como dive_slide
- [ ] Air dive landing: al aterrizar, sin dive → `dive_end` y vuelve a normal
- [ ] Dive cancel con jump: durante dive + space en suelo → salto normal
- [ ] Dive cancel con jump: durante dive + space en aire (con air jump dispo) → air jump
- [ ] Collision shape se reduce durante dive (mismo que crouch)

### Hide system
- [ ] Crouch en HideZone → automáticamente hidden (`is_hidden=true`, alpha=0.35)
- [ ] Levantarse mientras hidden → unhide automático
- [ ] Salir de la zona crouched → unhide automático
- [ ] Hidden bloquea detección por agent.gd (vision + light)
- [ ] No se puede hide si hay agente en estado de combate cerca
- [ ] Hidden + W (punch) → unhide, luego empieza charge normal
- [ ] Hidden + Q (kick) → ejecución (finisher), no unhide previo

### Combate básico — Punch
- [ ] Punch tap (W rápido) → animación normal, hitbox PunchHitbox activa brevemente
- [ ] Daño normal a Agent en estado vulnerable
- [ ] Recovery correcto: ~0.25s sin poder hacer otra cosa
- [ ] Durante punch: no se puede mover, velocity.x = 0

### Combate cargado — Punch Charged
- [ ] Mantener W → sprite `attack_charged_casting`, timer visible en debug
- [ ] Soltar W antes de attack_charge_time (0.4s) → punch normal
- [ ] Soltar W después de 0.4s → CHARGED PUNCH con lunge
- [ ] Lunge: impulso interpolado (40% en charge mínimo, 100% en charge máximo)
- [ ] Auto-release: mantener W >2.4s → release automático con charge máxima
- [ ] Sprite durante vuelo: `attack_charged_airtime`
- [ ] Sprite en contacto: `attack_charged_contact`
- [ ] Aterrizaje del charged punch: termina ataque, transiciona a landing
- [ ] Charged punch a Agent vulnerable → maestro (airtime hit)
- [ ] Charged punch a Agent en GUARD_STANCE → stunt

### Combate — Kick
- [ ] Kick (Q) → animación, hitbox KickHitbox activa
- [ ] Kick NO es cargable (Q tap = Q hold)
- [ ] Kick a Agent de frente en GUARD_STANCE → block (PARRY del agente)
- [ ] Kick a Agent por detrás → KO inmediato
- [ ] Kick a Agent vulnerable (HIT/STUNT) → KO

### Combate — Ejecución (Finisher)
- [ ] Hidden + Q → ejecución con sprite kick
- [ ] No hace unhide previo
- [ ] `is_finisher = true` durante el ataque
- [ ] Ejecución llama `agent.receive_execution(self)` (no `receive_hit_from`)
- [ ] Después de ejecución, vuelve a unhide normal

### Combate — Parry
- [ ] Parry window: ventana de ~40 frames (0.66s) durante PunchCharging
- [ ] Recibir hit del Agent durante parry window → flash verde, agent queda en airtime/maestro
- [ ] Recibir hit fuera de parry window → flash rojo, GameManager.player_caught()
- [ ] Después de parry exitoso, ventana se cierra

### Step climbing
- [ ] Caminar contra escalón (≤80px de alto) → sube automáticamente
- [ ] Escalón demasiado alto (>80px) → bloquea como pared normal
- [ ] Step up funciona durante run y walk
- [ ] Step up NO funciona durante dive ni en el aire

### Otros
- [ ] Respawn (al ser cazado por agente): fade out → reposicionar → fade in → control restaurado
- [ ] PauseMenu (ESC): pausa correctamente, no desincroniza estados al reanudar
- [ ] God mode: F1 activa, cámara libre, no rompe estados de Kive
- [ ] Debug HUD: toggle correcto, info actualizada en tiempo real

---

## 🐛 Si algo falla

### Cómo reportar el bug
Si encuentras un ❌, anota:
- **Fase del refactor:** (ej: "FASE 4 — Jump")
- **Mecánica afectada:** (ej: "Charged jump cancela mal")
- **Cómo reproducir:** pasos exactos
- **Comportamiento esperado:** (cómo era antes)
- **Comportamiento actual:** (cómo es ahora)
- **Estado de la state machine** en el momento del bug (visible en debug HUD)

### Antes de avanzar a la siguiente fase
- TODOS los puntos relevantes a la fase actual deben estar ✅
- Los puntos de fases anteriores también deben seguir ✅ (regresión)
- Si hay ❌ pendientes, NO commitear "completed" — arreglar primero

---

## 📊 Cobertura por fase

Aproximadamente qué partes de la checklist se ven afectadas por cada fase:

| Fase | Áreas a revisar con extra atención |
|---|---|
| FASE 0 | Todo (verificar que infraestructura no rompe nada) |
| FASE 1 | Todo (shim debe ser idéntico al pre-refactor) |
| FASE 2 | Idle, Walk, transiciones a/desde otros estados |
| FASE 3 | Crouch, Hide, transiciones entre crouch/walk/idle |
| FASE 4 | Salto completo, double jump, caídas, aterrizajes |
| FASE 5 | Dive completo, dive cancels, dive landings |
| FASE 6 | Combate completo: punch, charged, kick, execution, parry, damage |
| FASE 7 | Regresión completa + verificar debug_hud + agent.gd siguen OK |
