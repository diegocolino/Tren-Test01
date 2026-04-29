# COMBAT V1.3 — Roadmap para Claude Code

> **Dash, aéreo y combate de grupo.**
> Construido encima de V1.2 (W chain + Q en contexto + cross-cancels + kill selectiva).
> Status: listo para implementar tras `combat-v1.2`.

## Filosofía de V1.3

Tres ideas que se construyen una sobre otra:

**1. Combate aéreo == combate suelo.** Mismo W chain, mismo Q, mismas cancels, misma kill selectiva. Solo cambia animación. Lo que es nuevo del aire es la **interacción aire↔suelo**.

**2. Dash (E) es la herramienta de movilidad de combate.** No es solo "moverse rápido" — es **dirigir el combo entre targets** sin perder el ritmo. Tipo Jett en Valorant: input simultáneo, casi insta, contextual.

**3. El combo vive en el jugador, no en el target.** Multi-target combate: Jab a agente 1, E+D + Cross a agente 2, E+A + Hook a agente 3. El chain se preserva. Cada agente recibe el estado que toca según su situación. Es **combate cinemático tipo DMC/Bayonetta/Sifu**.

**Coherencia con GDD:**
- Pilar 4: encuentros adaptativos (1-4 enemigos por vagón). El combate es de grupo de verdad.
- Pilar 5: verticalidad como herramienta de control de espacio.
- §7 Dash: doble modo neutro/Sensible. V1.3 implementa ambos + extensión a "Sensible ofensivo" para combate de grupo.

---

## Contexto

V1.2 cerrado en tag `combat-v1.2`. AgentDummy operativo en `test_combat.tscn`.

**Lo que existe hoy:**
- W chain Jab→Cross→Hook→Uppercut con cancel windows.
- Q standalone + Q en contexto (stunt_pie, ko_suelo, air_launch).
- Cross-cancels W↔Q tight + late.
- Chain preservation a través de FrontalKick.
- Kill selectiva (W tras STUNT/KO/AIRTIME mata).
- Q-air-launch aterriza en KO (Q=KO siempre).
- Cuerpos empujables solo por Q (W=violencia recreacional postmortem, V2 gore).
- Estados de movimiento: Jump, Fall, Land, AirJump, DiveAir, DiveLanding, DiveGround.
- Estado `Damaged` y respawn.

**Lo que queremos en V1.3:**
- Detección `is_in_air` en estados de combate. Mismo combo, distinto plano.
- Dive-attack: derribo non-lethal con RNG de esquive.
- Dash (E) en sus tres modos: neutro, defensivo (Sensible), ofensivo (Sensible).
- Dash dirigido al target más cercano en dirección.
- Chain preservation a través de Dash (multi-target combos).
- Q direccionales en aire con agente adyacente (slam, juggling, lateral).
- Ventana de reposicionamiento aérea (AirJump/AirDive entre dashes).
- Parry como input dedicado (R).
- W-execution sigilosa (Hidden + W = mata sigiloso).

**Lo que NO va en V1.3:**
- Finisher cinemático cargado del Uppercut (V1.5).
- Lógica activa de alarma (V1.5).
- UI combo counter, Sensible glow visual (V1.5).
- Animaciones aéreas únicas (V2 con sprites alpha).
- Animación de marcha atrás (depende de decisión narrativa "Kive nunca mira atrás" — aplazada).
- Q direccional combo extenso tipo aerial juggling 4+ hits (V2).
- Vault contextual (V2).

---

## Decisiones de diseño cerradas

### a) Combate aéreo idéntico a suelo

W chain, Q, cancels, kill selectiva: **idénticos**. NO crear estados nuevos `AirJab`, `AirCross`, etc. Solo añadir flag `is_in_air` que ajusta animación y aplica gravedad.

### b) Chain compartido entre planos

`_w_chain_timer` y `w_chain_step` se preservan al saltar/caer. Si chain estaba activo en suelo, primer W aéreo continúa. Idéntico a la "chain preservation a través de FrontalKick" de V1.2.

**Caso post-Uppercut:** Uppercut llama a `reset_w_chain()` en exit, así que post-Uppercut → AirW = Jab fresh. Coherente con "Uppercut cierra dramáticamente".

### c) Chain compartido entre targets (multi-target)

El chain también se preserva al cambiar de target via Dash. Combo:
- Jab a agente 1 → E+D → Cross a agente 2 → E+A → Hook a agente 3 → Q a agente 3.
- Es un solo chain de 5 inputs distribuido. Chain preserva `w_chain_step`.
- Cada agente recibe el estado que toca según su situación (el agente 1 quizá queda en HIT, el 2 en KO, el 3 en AIRTIME).

### d) Dash modelo Jett

- **E + A o D** simultáneo (ambos pulsados a la vez).
- **E solo** = dash en dirección de facing.
- **E+S y E+Space descartados** (vertical lo cubren Dive y AirJump).
- Duración inicial: **8 frames (~0.133s)**, tunable. Casi insta.
- **Direccionalidad:** decisión sobre cambio de facing **aplazada** (depende de narrativa "Kive nunca mira atrás"). V1.3 arranca con comportamiento actual (volteo horizontal). Migración cuando aterrice la narrativa.

### e) Dash con tres modos contextuales

| Contexto | Comportamiento |
|---|---|
| **Neutro** (sin trigger) | Dash en dirección, sin daño, sin i-frames. Movimiento puro. |
| **Sensible defensivo** (agente en WINDUP/ATTACK_RELEASE apuntando a Kive) | Dash con i-frames, sin daño. Tinte blanco breve. |
| **Sensible ofensivo** (agente lanzado al aire por Kive) | Dash hacia agente. Velocity calculada para aterrizar al lado. Chain se preserva. |
| **Dirigido a target** (agente vulnerable en dirección de A/D) | Dash hacia ese agente. Posicionamiento de combate. |

**Prioridad de contextos** (si varios aplican): Sensible ofensivo > Sensible defensivo > Dirigido a target > Neutro.

### f) Q direccionales en aire

Solo activos si Kive en aire **+ agente adyacente en AIRTIME** (`_magnetic_target` válido).

- **Q + S** (down): ambos slam al suelo. Agente KO al aterrizar.
- **Q + Space** (up): ambos suben. Aerial chain (juggling).
- **Q + A/D** (lateral): ambos lateral. Agente sigue en AIRTIME, KO al aterrizar.

Sin agente adyacente: Q en aire es FrontalKick standalone.

### g) Dive-attack non-lethal con RNG de esquive

DiveAir + colisión con agente:
- **88% RNG** (`dive_connect_chance`) → knockdown (`AgentState.KO` con `_ko_type = "knockdown"`).
- **12% RNG** → esquiva con anim de salto pequeño.

Filosofía: Dive es **invasión de espacio**, no ataque letal. El RNG da agencia al agente. Tunable.

### h) Ventana de reposicionamiento aérea

Tras conectar un golpe en aire (W o Q), abrir ventana de **0.4s** (`air_repositioning_window`). Durante la ventana:
- AirJump disponible (sin gastar el `_air_jumps_left` de V1.2 si no estaba disponible).
- AirDive disponible.
- E (Dash) puede dirigirse a otro target.

Fuera de la ventana: comportamiento normal de aire (caer).

Esto permite combos cinemáticos tipo Dragon Ball: Dash → AirJab → AirJump (reposiciona) → Dash a otro target → AirJab → caer.

### i) Parry como input dedicado

Tecla **R** (mantener configurable en pause menu). Ventana de **0.667s (40 frames)**. Reusa `_parry_window_timer` del legacy.

- Apertura: pulsar R.
- Cierre: timeout o tras parry exitoso.
- Movimiento bloqueado durante la ventana.
- Si recibes hit dentro de la ventana → agente a AIRTIME → DEAD.
- Si recibes hit fuera → Damaged.
- Cooldown: ~0.3s tras parry exitoso.

### j) W-execution sigilosa

`Hidden + W` → mata al agente con cinemática propia (placeholder usando `attack_charged_contact` con tint).
- Escala alarm (cuando V1.5 conecte la lógica).
- Permanente.
- Sigiloso (no rompe la condición Hidden mientras dura).

`Hidden + Q` ya existe (Execution actual, K.O. silencioso). No tocar.

---

## Plan en sub-pasos

Cada sub-paso es un commit. Cada commit deja el juego **jugable y testeable**.

### Sub-paso 1 — `is_in_air` detection en estados de combate

**Objetivo:** los estados de combate detectan si Kive está en aire y aplican gravedad. Sin cambios de comportamiento.

1.1. **En `kive.gd`** verificar/añadir computed property:
```gdscript
var is_in_air: bool:
    get: return not is_on_floor()
```

1.2. **En cada estado de combate** (`Jab`, `Cross`, `Hook`, `Uppercut`, `FrontalKick`):
- En `enter()`, leer `kive.is_in_air`. Guardar en variable local del estado si necesario.
- En `physics_update()`, si `is_in_air`, aplicar gravedad (`kive.velocity.y += stats.gravity * delta`).
- Mantener animación actual (placeholder).

1.3. **Print actualizado en `enter()` de los 5 estados:**
```gdscript
if DebugOverlay.show_debug_text:
    print("[%s] enter | chain_step=%d | in_air=%s" % [
        name, kive.w_chain_step, kive.is_in_air
    ])
```

(En FrontalKick, mantener lo que ya hay y añadir `in_air`.)

**Test (con dummy):**
- En suelo: W chain V1.2 intacto.
- Saltar → W → Jab en aire, Kive cae con gravedad mientras pega. No flota.
- Saltar → Q → FrontalKick aéreo, similar.
- Cancels W↔Q en aire funcionan.
- Combo W→W→W→W aéreo posible (saltar y mantener pulsando W). Mata si conecta.

**Commit:**
```
feat(combat): air detection in combat states (V1.3 substep 1)

Combat states detect is_in_air and apply gravity during execution.
Animations remain placeholders. No behavioral changes — same combos work
in air as ground.

Foundation for V1.3 air↔ground interactions.
```

---

### Sub-paso 2 — Dive-attack

**Objetivo:** DiveAir + colisión con agente → knockdown con RNG de esquive.

2.1. **Investigación previa SIN código:**
- Léeme el estado `DiveAir`. ¿Tiene hitbox? ¿Cómo detecta colisión?
- Si no tiene hitbox, propones cómo añadirla (Area2D hijo, layer/mask correctos).

2.2. **Variable nueva en `KiveStats`:**
```gdscript
@export_group("Dive-attack")
@export var dive_connect_chance: float = 0.88
```

2.3. **Hitbox del Dive:**
- Si no existe, añadir `DiveHitbox` (Area2D) en `kive.tscn`. Layer/mask coherentes con la PunchHitbox/KickHitbox actuales.
- Activar solo durante DiveAir (`enter()`), desactivar en `exit()`.

2.4. **Callback `_on_dive_hitbox_body_entered` en kive.gd:**
```gdscript
func _on_dive_hitbox_body_entered(body: Node2D) -> void:
    if not body.is_in_group("agent"):
        return
    if not body.has_method("receive_dive_from"):
        return
    body.receive_dive_from(self)
```

2.5. **Función `receive_dive_from` en agent.gd y agent_dummy.gd:**
```gdscript
func receive_dive_from(attacker: Node2D) -> void:
    if state == AgentState.DEAD:
        return
    if state == AgentState.KO:
        return  # ya está tirado
    
    if randf() < kive_stats.dive_connect_chance:
        last_hit_quality = "dive_knockdown"
        _ko_type = "knockdown"
        _apply_dive_knockback(attacker)
        _enter_state(AgentState.KO)
        # Llamar play_ko_sequence o equivalente
        if DebugOverlay.show_debug_text:
            print("[Agent] DIVE knockdown | _ko_type=knockdown")
    else:
        if DebugOverlay.show_debug_text:
            print("[Agent] DIVE dodged (RNG)")
        # Anim de salto pequeño placeholder
        sprite.play("idle")  # o lo que quede mejor
```

2.6. **`_apply_dive_knockback`:** knockback lateral fuerte + caer. Reusa `_apply_kick_push` con valores propios o variable nueva (`dive_knockback_distance`).

2.7. **Print gateado en cada conexión y esquive.**

**Test (con dummy en `test_combat.tscn`):**
- Salto → Dive sobre dummy IDLE → 88% conecta knockdown, 12% esquiva.
- Dummy en KO suelo + Dive → ignorado.
- Dummy en GUARD_STANCE + Dive → conecta (igual que Q en contexto rompe guardia).
- Dummy knockdown + W → mata por kill selectiva (V1.2 intacto).

**Commit:**
```
feat(combat): dive-attack with RNG dodge (V1.3 substep 2)

DiveAir now connects via DiveHitbox. On collision:
- 88% RNG: knockdown (KO with _ko_type="knockdown")
- 12% RNG: dodge with small jump anim

Non-lethal. Coherent with Dive as space invasion (GDD §0).

New: KiveStats.dive_connect_chance (0.88, tunable).
Killing combo: Jump → Dive → connect → W = kill selectiva from KO.
```

---

### Sub-paso 3 — Dash neutro (E sin contexto)

**Objetivo:** estado `Dash` nuevo. E pulsado solo (sin contexto especial) hace dash horizontal.

3.1. **Variable en `KiveStats`:**
```gdscript
@export_group("Dash")
@export var dash_duration: float = 0.133  # 8 frames
@export var dash_distance_neutral: float = 280.0  # px
@export var dash_distance_sensible: float = 480.0  # px (V1.3 substep 5)
@export var dash_recovery: float = 0.083  # 5 frames
```

3.2. **Estado nuevo `Dash` en `player/states/movement/dash.gd`:**
- `class_name Dash extends State`
- Variables: `phase ("active" | "recovery")`, `phase_timer`, `_dash_direction` (1 o -1).
- En `enter()`: leer dirección de input (A/D pulsado o, si ninguno, facing). Setear `_dash_direction`. Aplicar velocity inicial.
- En `physics_update()`:
  - "active": velocity constante en `_dash_direction`. Cuando `phase_timer >= dash_duration` → "recovery".
  - "recovery": velocity decae rápido. Cuando `phase_timer >= dash_recovery` → `_decide_next_state()`.

3.3. **Nodo en `kive.tscn`:** `Dash` bajo StateMachine.

3.4. **Transiciones a Dash:** desde estados base (Idle, Walk, Run) detectar `Input.is_action_just_pressed("dash")` (input action nuevo) y transicionar.

3.5. **Input action `dash` en InputMap mapeado a E.**

3.6. **Cancel del Dash:** durante "recovery" del Dash, accept Jump, attack_punch, attack_kick, crouch como ya hacen otros estados.

3.7. **Print gateado:**
```gdscript
func enter(_msg = {}) -> void:
    _dash_direction = ...
    if DebugOverlay.show_debug_text:
        print("[Dash] enter | direction=%d | facing=%s | input=%s" % [
            _dash_direction, kive.facing_right, "..."
        ])
```

**Test:**
- E sin A/D → dash en facing.
- E+A → dash izquierda (con/sin cambio de facing según comportamiento actual).
- E+D → dash derecha.
- Dash → cancel a Jump funciona.
- Dash → cancel a Jab funciona.
- Suelo: Kive sigue en suelo durante el dash (no flota).
- Sin regresiones en Idle/Walk/Run.

**Commit:**
```
feat(movement): Dash state — neutral mode (V1.3 substep 3)

New Dash state in player/states/movement/dash.gd.
- Input action "dash" mapped to E in InputMap.
- E (alone) = dash in facing direction.
- E+A or E+D = dash in input direction.
- ~8 frames active + 5 frames recovery (tunable in KiveStats).
- Cancellable to jump, attack, crouch during recovery.

Sensible modes (defensive, offensive, target-directed) come in next substeps.
```

---

### Sub-paso 4 — Dash dirigido a target

**Objetivo:** E+A/D con agente vulnerable en dirección → dash hacia ese agente. Posicionamiento de combate.

4.1. **En `kive.gd`** función helper:
```gdscript
func find_closest_agent_in_direction(direction: int) -> Node2D:
    # direction: 1 (derecha) o -1 (izquierda)
    var closest: Node2D = null
    var closest_dist: float = INF
    for agent in get_tree().get_nodes_in_group("agent"):
        if not is_instance_valid(agent):
            continue
        if agent.has_method("is_vulnerable_to_dash") and not agent.is_vulnerable_to_dash():
            continue
        var dx = agent.global_position.x - global_position.x
        if sign(dx) != direction:
            continue
        var dist = abs(dx)
        if dist < closest_dist:
            closest_dist = dist
            closest = agent
    return closest
```

4.2. **En `agent.gd` y `agent_dummy.gd`** función `is_vulnerable_to_dash`:
```gdscript
func is_vulnerable_to_dash() -> bool:
    return state in [AgentState.PATROL, AgentState.ALERT, AgentState.GUARD_STANCE,
                     AgentState.WINDUP, AgentState.ATTACK_RELEASE, AgentState.ATTACK_RECOVERY,
                     AgentState.HIT, AgentState.STUNT]
```
(NO incluye KO/AIRTIME/DEAD/KNOCKED_DOWN — esos no son target válido para reposicionarse.)

4.3. **En `Dash.enter()`:** tras determinar `_dash_direction`, llamar a `find_closest_agent_in_direction`. Si hay target dentro de un rango (`dash_target_range`, ej. 600px):
- Calcular velocity para llegar al lado del agente (~80px de offset).
- Setear flag `_dash_target_mode = true`.

4.4. **Variable nueva en `KiveStats`:**
```gdscript
@export var dash_target_range: float = 600.0
@export var dash_target_offset: float = 80.0  # px de Kive al agente al aterrizar
```

4.5. **Print gateado:**
```gdscript
if DebugOverlay.show_debug_text:
    if _dash_target_mode:
        print("[Dash] enter | TARGET MODE | target=%s | dist=%.1f" % [target.name, dist])
    else:
        print("[Dash] enter | NEUTRAL | direction=%d" % _dash_direction)
```

**Test:**
- 1 dummy a la derecha + E+D → Kive dasha hasta el lado del dummy.
- 1 dummy a la izquierda + E+A → Kive dasha hasta el lado del dummy.
- Sin dummy en dirección → dash neutro normal.
- Dummy en KO + E+D → dash neutro (no es target válido).
- Dummy lejos (>600px) + E+D → dash neutro.

**Commit:**
```
feat(combat): Dash directed to closest agent in direction (V1.3 substep 4)

E+A or E+D with vulnerable agent in input direction → dash lands beside agent.
Without target (no agent, KO/DEAD agent, agent too far): neutral dash.

New helpers:
- kive.find_closest_agent_in_direction(direction)
- agent/dummy.is_vulnerable_to_dash()

New stats: dash_target_range (600px), dash_target_offset (80px).
```

---

### Sub-paso 5 — Dash Sensible defensivo

**Objetivo:** E mientras un agente apunta a Kive en WINDUP/ATTACK_RELEASE → dash con i-frames + tinte blanco.

5.1. **Variable en `KiveStats`:**
```gdscript
@export var dash_sensible_iframes_duration: float = 0.25
```

5.2. **Función `is_under_threat` en kive.gd:**
```gdscript
func is_under_threat() -> bool:
    for agent in get_tree().get_nodes_in_group("agent"):
        if not is_instance_valid(agent):
            continue
        if agent.has_method("is_threatening") and agent.is_threatening(self):
            return true
    return false
```

5.3. **Función `is_threatening` en agent/dummy.gd:**
```gdscript
func is_threatening(target: Node2D) -> bool:
    if state not in [AgentState.WINDUP, AgentState.ATTACK_RELEASE]:
        return false
    # Verificar que el target está delante (en el cono de ataque)
    var dx = target.global_position.x - global_position.x
    if facing_right and dx > 0:
        return true
    if not facing_right and dx < 0:
        return true
    return false
```

5.4. **En `Dash.enter()`:** verificar `kive.is_under_threat()` antes de mirar target. Si true:
- `_sensible_mode = "defensive"`
- Activar i-frames (flag `kive._iframes_active = true`).
- Distancia del dash = `dash_distance_sensible` (más larga).
- Tinte blanco: aplicar `sprite.modulate = Color(2.0, 2.0, 2.0)` durante el dash, restaurar en exit.
- Hit-stop opcional al inicio (~50ms).

5.5. **`_iframes_active` en kive.gd:** flag que `receive_hit_from` o equivalente debe leer para ignorar daño.

5.6. **En agent_dummy.gd añadir `is_threatening`** (aunque dummy no ataca, devuelve false siempre — pero la función debe existir para que kive.is_under_threat no falle).

5.7. **Print gateado:**
```gdscript
print("[Dash] SENSIBLE DEFENSIVE | distance=%.1f | iframes ON" % dash_distance_sensible)
```

**Test:**
- Agente real (no dummy) en WINDUP apuntando a Kive → E → Dash con i-frames + tinte blanco. Si el agente conecta su ataque durante el dash, no recibes daño.
- Dummy no ataca, así que no se puede probar fácil → fase 2 con Vagón 1.

**Nota:** este sub-paso es difícil de verificar con dummy. Lo testeamos con Agent real en sanity check de Vagón 1 al final del V1.3.

**Commit:**
```
feat(combat): Dash Sensible defensive — i-frames vs WINDUP/RELEASE (V1.3 substep 5)

When an agent is threatening Kive (WINDUP or ATTACK_RELEASE pointed at him),
E triggers Sensible defensive dash with:
- i-frames during entire dash
- longer distance (dash_distance_sensible)
- white tint on sprite

Helpers: kive.is_under_threat(), agent.is_threatening(target).

Hard to verify with dummy (no AI). Verify in Vagón 1 sanity check.
```

---

### Sub-paso 6 — Parche del timer W chain en DashOffensive

**Objetivo:** `_w_chain_timer` corre libre durante DashOffensive. A veces expira mid-dash, causando finishers inconsistentes (Jab en vez del chain step esperado). Fix: reset timer en enter() y en snap antes de get_w_chain_next(). Timeout reducido 0.6→0.4 para feel más snappy.

**Cambios:**
1. `kive_stats.gd:59` — `w_chain_reset_timeout: 0.6 → 0.4`
2. `dash_offensive.gd` enter() — reset `_w_chain_timer = 0.0` si chain activo (mirror de `frontal_kick.gd:15-16`)
3. `dash_offensive.gd` snap finisher — reset `_w_chain_timer = 0.0` antes de `get_w_chain_next()` para garantizar chain vivo en el momento del despacho

**Nota:** rama Q del finisher NO necesita reset. Hace `return &"FrontalKick"` directo sin consultar chain. Además, `frontal_kick.gd:15-16` ya resetea en su propio `enter()`.

**Test:**
1. Jab → Q → E+W mantenida x5. Esperado: siempre Hook
2. Jab → Cross → Q → E+W. Esperado: Uppercut
3. W→W→W→W natural sin dash. Esperado: encadenan cómodos a 0.4s
4. Jab → esperar 0.5s → W. Esperado: Jab fresco (chain expirado)
5. Si 0.4s se siente tight en test 3, subir a 0.5s

**Commit:** `fix(combat): preserve W chain through DashOffensive + tune timeout (V1.3 sub-paso 6)`

---

### Sub-paso 7 — Chain preservation multi-target (verificación)

**Objetivo:** verificar que `_chain_hit_agents` + `find_chained_agent_in_direction()` preservan el chain step al cambiar de target via dash.

**Resultado:** verificación cubierta implícitamente en logs del sub-paso 6, sin código adicional necesario. Combo 2 del playtest muestra `[DashOffensive] enter | TARGET | target=AgentDummy` cuando el cancel anterior fue contra AgentDummy2, y el chain step (1) se preserva produciendo Hook correcto. Sin commit independiente.

---

### Sub-paso 8 — Tests integrados + tag combat-v1.3

**Batería completa de verificación:**

```
# V1.2 intacto (sanidad básica)
- W chain en suelo
- Q standalone, Q en contexto, cross-cancels
- Kill selectiva
- Q sobre cadáver = push, W sobre cadáver = silencio

# Aéreo (sp1)
- Saltar → W chain aéreo, saltar → Q, cancels W↔Q aire

# Dive-attack (sp2)
- Dive sobre dummy → FALLEN, FALLEN+W = HIT

# Dash neutro (sp3)
- E sin contexto = dash facing, E+A/E+D = dash dirección

# Dash dirigido/ofensivo (sp4/5a)
- E+D con dummy W-marcado, sin W-marked = neutro

# Magnetic (sp5a)
- Uppercut → E rápido → dash a AIRTIME

# Finisher (sp5b)
- E+W mantenida, E+Q mantenida

# Chain preservation (sp6-7)
- Jab → Q → E+W → Hook (chain preservado a través de dash)
- Jab dummy1 → E+D+W → Cross dummy2 (multi-target)

# Takedown
- Hidden+Q → KO silencioso
```

**Tag:**
```bash
git tag combat-v1.3
git push --tags
```

**Bug conocido (diferido a V1.5):** Uppercut post-magnetic no conecta hitbox; target muere en landing (KO→DEAD) en vez de mid-air. Agent's AIRTIME velocity outpaces hitbox window. Fix planificado con Smash + slam physics + auto-hit fallback.

**Commit:** `chore(combat): tag combat-v1.3 — cinematic combat closed`

---

## Reasignaciones post-cierre V1.3

**V1.4 — Defensa activa + stealth fixes:**
- Parry (R) — input dedicado, ventana 0.667s
- W-execution sigilosa (Hidden+W) — kill letal silencioso
- Fix detección durante Hidden (forzar CrouchIdle si ALERT te ve)

**V1.5 — Aéreo avanzado + repo + polish:**
- Q direccionales aéreos (slam/juggling/lateral con _magnetic_target)
- Ventana de reposicionamiento aérea (AirJump/AirDive tras hit conectado)
- Polish general, tuning, UI

---

## Verificación final V1.3

Cuando los 8 sub-pasos commiteados (1-5b cerrados + 6-8 nuevos):

1. **Sin errores en consola.**
2. **V1.2 intacto:** W chain, Q en contexto, cross-cancels, kill selectiva, cuerpos empujables.
3. **Aéreo:** combate idéntico a suelo + Dive-attack.
4. **Dash en sus modos:** neutro, dirigido, ofensivo (magnetic), finishers E+W/E+Q.
5. **Chain preservation:** timer no expira mid-dash, multi-target funciona.
6. **Sin regresiones** en stealth, movement, V1.2 entero.

---

## Si algo se rompe

- Tag de retorno: `combat-v1.2`.
- Cada sub-paso es commit independiente, revertible.
- Sub-paso 5 (Sensible defensivo) es el menos verificable con dummy — verificar en Vagón 1.

---

*v final — V1.3 cerrado con scope reducido. 8 sub-pasos (1-5b + 6-8). Decisiones cerradas:*
*- Combate aéreo == combate suelo*
*- Chain compartido entre planos y entre targets*
*- Dash modelo Jett (E + A/D simultáneo, casi insta)*
*- Modos de Dash (neutro, dirigido, ofensivo/magnetic) + finishers E+W/E+Q*
*- Dive-attack non-lethal con RNG*
*- Timer W chain preservado a través de DashOffensive*
*- Reasignado a V1.4: Parry, W-execution, Hidden fix*
*- Reasignado a V1.5: Q aéreos, repo aérea, polish*
