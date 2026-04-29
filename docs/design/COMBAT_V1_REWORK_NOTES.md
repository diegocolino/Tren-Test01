# Combat V1.x — Notas del Rework

> Decisiones tomadas durante el rework V1.1 → V1.5 sobre comportamientos del sistema legacy
> (V0.5 / pre-refactor) que **NO** se mantienen idénticos en el rework, más decisiones de
> infraestructura tomadas durante el proceso, más bugs cazados y dónde viven, más
> decisiones filosóficas que emergen del playtest.
>
> Propósito: registro vivo. Se actualiza durante cada sub-paso. Cuando el rework cierre
> (V1.5 tag), este MD queda como auditoría histórica.

---

## V1.1 — W chain básico

### Quitado
- **`PunchCharging` y `PunchCharged` como ataques sueltos.**
  El sistema legacy tenía carga directa con W (mantener pulsado → ataque cargado independiente).
  En el rework, la carga vuelve **solo como hold de Uppercut (W4)** en V1.5 — finisher cinemático.

### Mantenido como stub
- **`is_punch_charging` e `is_punch_charged`** computed properties.
  Devuelven `false`. Existen solo por compatibilidad con `agent.gd` y `debug_hud.gd` hasta refactor de agent.gd post-V1.5.
- **`_parry_window_timer`** se mantiene en kive.gd. Se reutilizará en V1.3 sub-paso 10 con sistema Parry separado.

---

## V1.2 — Q standalone + Q-en-contexto + cross-cancels

### Quitado (sub-paso 2)
- **PARRY frontal contra GUARD_STANCE en `_resolve_q_hit`.**
  El legacy ejecutaba `AgentState.PARRY` cuando Q frontal impactaba a un agente en guardia.
  **Razón:** el Parry pasa a ser **input dedicado de Kive (R) en V1.3 sub-paso 10**, no respuesta del agente al Q.
  **Estado actual:** Q standalone contra agente en GUARD_STANCE → push only.

- **KO por detrás en `_resolve_q_hit`.**
  El legacy ejecutaba `AgentState.KO` automático cuando Q golpeaba al agente por la espalda.
  **Razón:** rompe el balance del sistema de combos. El "remate por la espalda" pertenece al **modo sigilo** (Hidden+Q ya cubre el remate K.O. silencioso, GDD §9.2).
  **Estado actual:** Q standalone por detrás → push only.
  **Reabrir si:** al jugar V1.5 se echa de menos vía de neutralización en combate abierto.

- **RNG 4% guard break.**
  El GDD V0.5 mencionaba "Guard break: RNG bajo (~4%)" para Q standalone. Nunca se implementó.
  **Razón para no implementar:** fantasma del GDD V0.5. Si en V1.5 al jugar se siente que falta, se reconsidera.

### Recolocado
- **Variable `last_w_executed` (kive.gd) — añadida en V1.2 sub-paso 1.**
  Originalmente el roadmap pedía `q_context = "after_uppercut"` separado de `"standalone"`. En playtest se descubrió que `uppercut.exit()` llama a `reset_w_chain()`, por lo que el `q_context` post-Uppercut siempre llega como `"standalone"`.
  **Solución:** separar **estado actual** (`q_context`) de **historial** (`last_w_executed`). Cada W setea su propio nombre en `enter()` (autoidentificación, lección 2 de V1.1). Se limpia en `reset_state()` y `set_control_enabled(false)`.

- **`stunt_duration` 1.5s → 2.0s en agent.gd.**
  Para que la "kill selectiva" se sienta como decisión moral y no apresurada. Tunable en V1.5.

### Decisiones filosóficas cerradas en sub-paso 3

#### 1. Q-air-launch aterriza en KO, no en DEAD

El roadmap V1.2 originalmente decía "muere al aterrizar igual que Uppercut". Reinterpretado durante playtest: **viola la filosofía W=DEATH/Q=KO**. Q nunca mata.

**Implementación:** flag `_airtime_kill_on_land`. Uppercut → `true`. Q-air-launch → `false`. `_process_airtime` bifurca al aterrizar.

#### 2. Cuerpos: Q los mueve, W no

**Filosofía cerrada:** W es violencia letal incluyendo postmortem. **W contra cadáver no busca utilidad mecánica en V1.2** — es violencia recreacional sin output. Q es control de posición — **mueve cuerpos** vivos o muertos.

**Implementación:** check al inicio de `receive_hit_from`:
```gdscript
if state == DEAD:
    if hit_type es de la familia Q: _apply_kick_push
    # W silencioso
    return
```

**Nota técnica:** `_enter_state(DEAD)` desactiva `collision_layer` del cuerpo, por lo que la hitbox de Kive no detecta cadáveres en práctica. Nuestro filtro queda como **red de seguridad** para V2 cuando se reactive la layer (gore mechanic).

**Gameplay emergente desbloqueado:** mover cuerpos a hide_zones, ocultar K.O. donde no los encuentre Flai, empujar cadáveres a obstáculos. Base mecánica para futuras vagones-thesis.

#### 3. Kill selectiva (sub-paso 3 core)

W sobre agente en STUNT, KO o AIRTIME → DEAD inmediato. Implementa el patrón "abrir con Q, cerrar con W" del GDD §4.4.

### Convive con legacy (no se rediseña hasta V2)

- **`last_hit_quality`** con dos familias de valores. Legacy V1: `none / hit / golpe_bueno / maestro / block / ko / push / execution`. Nuevos V1.2: `stunt_pie / ko_suelo / air_launch / push`.
  **Por qué:** los lectores son interpolación pura de string, sin match. Cero regresión. Unificar en V2.

- **Escalada legacy V1.1: Cross/Hook contra HIT/STUNT → KO + golpe_bueno.**
  Detectada en sub-paso 3. Está en código pero **enmascarada por la kill selectiva** (que toma precedencia para STUNT/KO/AIRTIME). Solo emerge contra HIT.
  **Por qué se mantiene:** quitarla rompe el "feel" del W chain con cancels rápidos (juego rápido se siente como escalada de boxing). Si emerge en juego rápido, es **mecánica emergente, no bug**.
  **Pendiente para V1.5 polish:** decidir si se mantiene tal cual, se redefine con sistema RNG del V0.5, o se elimina.

### Aparcado para V1.3 (cerrado, en implementación)
- **AIRTIME rematable.** En V1.2, Q-air-launch ya lleva a KO al aterrizar. V1.3 mantiene esa base y añade:
  - W aéreo (no estado nuevo, mismo Jab/Cross/etc en aire) → mata al agente lanzado.
  - Q aéreo → aterriza en KO de manera limpia.
  - Si Kive no remata aéreamente, el agente ya cae bien (KO desde V1.2).

### Aparcado para V2 (post-V1.5)

- **Despertar del KO.** En V1.2, `ko_suelo` deja al agente en KO permanente del run. V2 añadirá timer de despertar y posible reacción (avisar a Flai si nadie remata).

- **Mecánica gore — W sobre cadáver.**
  W contra cuerpo DEAD puede convertirse en mecánica con utilidades: arrancar brazo para huella dactilar, sangre como pista, partes corporales como objetos. Casa con vagones-thesis (forzar profanación) y con la pregunta moral del personaje.
  **Implementación V2:** reactivar `collision_layer` del cadáver en `_enter_state(DEAD)` para que la hitbox de Kive lo detecte de nuevo. El filtro actual de `receive_hit_from` (que ya intercepta W sobre DEAD como "ignorado") cambia a "ejecuta gore mechanic".
  **Filosofía cerrada:** W siempre es violencia letal, incluyendo postmortem. El gore convierte esa violencia en agencia mecánica del jugador.

- **Esconder K.O. en safe zones.**
  Mecánica emergente nacida del playtest de sub-paso 3. Mover cuerpos K.O. con Q a zonas donde Flai no los detecte. Base ya existente (Q empuja cuerpos). Falta: definir hide_zones para cuerpos, lógica de "Flai no detecta K.O. en hide_zone".

- **Q encadenable post-W (Q chain).** Q tras Q en contexto W escalando el efecto (W → Q → STUNT, W → Q → Q → KO, etc). Multiplica combos y carga cognitiva — se diseña con calma cuando el sistema base esté jugado.

- **Reabrir KO por detrás si playtest lo pide.**
- **Reabrir RNG guard break si playtest lo pide.**
- **Unificar `last_hit_quality` (familias legacy + V1.2).**
- **Decidir escalada legacy** (mantener / redefinir / eliminar). Ver "Convive con legacy".

---

## V1.3 — Dash, aéreo y combate de grupo (en implementación)

> V1.3 expandido durante diseño post-V1.2. Originalmente "solo aéreo + Dive-attack" (3 sub-pasos). Reescrito a 12 sub-pasos al cazar que **el modelo de input para interacciones aire-suelo debe vivir en Dash (V1.4 original), no en Space**. Restructurado: V1.3 absorbe Dash, Parry, W-execution sigilosa. V1.4 queda libre para detección centralizada y stealth integration completa.

### Estado del roadmap (V1.3 cerrado con scope reducido)

```
✅ Sub-paso 1 — Aéreo (40e3716)
✅ Sub-paso 2 — Dive-attack FALLEN (6b0df47)
✅ Sub-paso 3 — Dash neutro (769cb7f)
✅ Sub-paso 4 — Dash dirigido (44c5082) — refactorizado en 5a
✅ Sub-paso 5a — DashOffensive + sensible system + memoria targets (5a04bf0)
✅ Rename Execution → Takedown (42970a8)
✅ Sub-paso 5b — Modificadores E+W/E+Q + cinematic teleport (836bd56)
✅ Sub-paso 6 — Parche timer W chain en DashOffensive (timeout 0.6→0.4, reset en enter+snap)
✅ Sub-paso 7 — Chain preservation multi-target (verificación)
✅ Sub-paso 8 — Tests integrados + tag combat-v1.3

Reasignado a V1.4: Parry (R), W-execution sigilosa (Hidden+W), fix detección Hidden
Reasignado a V1.5: Q direccionales aéreos, ventana repo aérea, polish
Descartado: Input buffer (sub-paso 6 original — sin dolor observado en playtest)
```

### Decisiones de diseño cerradas en pre-implementación

#### Combate aéreo == combate suelo
W chain, Q standalone, Q en contexto, cross-cancels, kill selectiva: **todo idéntico**. NO crear estados nuevos `AirJab/AirCross/etc`. Solo flag `is_in_air` ajusta animación y aplica gravedad.

#### Chain compartido entre planos y entre targets
El `_w_chain_timer` y `w_chain_step` se preservan al saltar/caer **y al cambiar de target via Dash**. El combo vive en el jugador, no en el target. Multi-target: Jab a agente 1 → E+D + Cross a agente 2 → E+A + Hook a agente 3 = un solo chain de 3 inputs, cada agente recibe el estado que toca.

Coherente con la "chain preservation a través de FrontalKick" de V1.2 — misma filosofía: Q intercepta, Dash redirige, ninguno resetea.

#### Combat physics aéreo (sub-paso 1)
**`combat_friction` y `velocity.x = 0` no se aplican en aire.** En aire, la gravedad ya frena verticalmente y horizontalmente no hay rozamiento real. Aplicar fricción horizontal en aire es doble freno artificial — Kive se atasca al pegar.

Implementación: `if not kive.is_in_air:` antes de aplicar fricción en los 4 W states y antes de `velocity.x = 0` en FrontalKick.

Filosofía: en suelo, plantar pies para pegar con peso (correcto). En aire, no hay suelo donde plantar — mantener inercia es coherente con combate cinemático.

#### Dive-attack: V1.3 sin RNG, V1.5 reactiva esquiva (sub-paso 2)
Roadmap original proponía 88% conecta + 12% esquiva. **Aplazado a V1.5.** Razones:
1. Ni Agent ni Dummy tienen lógica de salto en V1.3. Esquivar visualmente sin animación = bug.
2. RNG sin animación → 12% del tiempo el target se queda quieto inexplicablemente. Peor UX que no tener RNG.
3. RNG es polish (feel), no mecánica core. El core es "Dive derriba".
4. V1.5 con animaciones alpha permite esquive cinemático real.

**V1.3 sub-paso 2:** Dive-attack siempre conecta (100% knockdown). Sin `dive_connect_chance` en KiveStats. Sin rama de esquiva.

**V1.5 reactiva con:**
- `dive_connect_chance` en KiveStats (88% inicial).
- Animación de esquiva (anim alpha de salto pequeño).
- Decisión arquitectónica: ¿RNG decidido por Kive o por agente? (Coherencia: Kive decide para que sea simple. Coherencia con "agente experto esquiva más": agente decide. **Pendiente para V1.5 según necesidad.**)

#### Dive-attack: estado FALLEN, no KO (sub-paso 2)
Drift filosófico cazado durante implementación. El roadmap inicial proponía Dive → KO con `_ko_type="knockdown"`. **Incorrecto.** Decisión correcta:

- **Estado nuevo `FALLEN`** (renombrado de `KNOCKED_DOWN` por feo). Tirado pero levantándose.
- Dive-attack → FALLEN (NO KO).
- Duración 1.5s (`fallen_duration`), luego vuelve a IDLE/PATROL automáticamente.
- Durante FALLEN: vulnerable a hits normales, **pero la kill selectiva NO aplica** (W sobre FALLEN = HIT, no mata).
- Dive contra DEAD/KO/AIRTIME/STUNT/FALLEN → ignorado.

**Filosofía:** Q neutraliza → abre kill selectiva. Dive solo derriba → **NO** abre kill selectiva. Patrón "abrir con Q, cerrar con W" se mantiene exclusivo del Q. Si quieres matar tras Dive, esperas a que se levante y aplicas combo W normal o Q→W.

Distinto de KO: KO es permanente del run (Q→KO suelo), FALLEN es transitorio (Dive).

#### DiveGround vs DiveAir: física diferenciada del impacto (sub-paso 2)
Cazado durante implementación. Roadmap inicial trataba ambos Dives como "mismo Dive-attack". **Físicamente son distintos** y la mecánica debe reflejarlo.

**DiveGround (slide en suelo):**
- Kive impacta los **pies/tobillos** del agente.
- Agente sale **disparado hacia arriba** (voltereta hacia adelante).
- Kive **casi atraviesa** al agente — apenas pierde momentum.
- Físicamente: barrido bajo, poca masa que pare a Kive.

**DiveAir (caída en aire):**
- Kive impacta **cuerpo entero** (cara/pecho).
- Agente sale **disparado en la dirección del dive** (no hacia arriba — hacia donde va Kive).
- Kive **siente fricción**: frena horizontal y acelera caída vertical (efecto rebote).
- Físicamente: choque cuerpo a cuerpo, ambas masas chocan.

**Filosofía:** captura el gesto de cada Dive.
- DiveGround = movimiento de **avance** (quitarte enemigos del paso sin parar).
- DiveAir = movimiento de **interceptación** (plantar un golpe contundente).

**Implementación:** `receive_dive_from(attacker, dive_type)` con parámetro `"ground"` o `"air"`. Kive aplica fricción propia según tipo en `_on_dive_hitbox_body_entered`.

V1.3 reusa anim placeholder igual para ambos. V1.5 con sprites alpha cada uno tendrá animación propia (voltereta vs choque frontal).

#### Dash modelo Jett
- **E + A/D simultáneo** (no secuencial). Tipo Valorant Jett.
- **E solo** = dash en facing.
- **E+S y E+Space descartados.** Vertical lo cubren Dive (Shift) y AirJump (Space).
- Duración inicial: **8 frames (~0.133s)**, tunable.

#### Tres modos contextuales de Dash + dirigido a target

| Contexto | Comportamiento |
|---|---|
| Neutro | Dash sin daño, sin i-frames |
| Sensible defensivo (agente WINDUP/RELEASE pointing Kive) | Dash + i-frames + tinte blanco |
| Sensible ofensivo (target en AIRTIME tras Kive lo lanzó) | Dash hacia target. Velocity calculada |
| Dirigido a target (E+A/D con agente vulnerable en dirección) | Dash al lado del agente |

Prioridad: ofensivo > defensivo > dirigido > neutro.

#### Q direccionales en aire
Solo activos si `_magnetic_target` válido (agente adyacente en AIRTIME mientras Kive en aire).
- Q+S: ambos slam suelo.
- Q+Space: ambos suben (juggling).
- Q+A/D: ambos lateral.

Sin target: Q en aire es FrontalKick standalone normal.

#### Dive-attack non-lethal con RNG
- 88% conecta knockdown (KO con `_ko_type="knockdown"`).
- 12% esquiva.

Filosofía: Dive es invasión de espacio (gesto inspirado en RedFist), no ataque letal. RNG da agencia al agente.

#### Ventana de reposicionamiento aérea
Tras conectar golpe en aire, 0.4s donde AirJump y AirDive están disponibles aunque normalmente no. Permite combos cinemáticos: Dash → AirJab → AirJump (repo) → Dash a otro target → AirJab.

#### Parry input dedicado
Tecla R. Ventana 0.667s (40 frames). Reusa `_parry_window_timer` mantenido desde V1.1. Hidden + R desactivado.

#### W-execution sigilosa
Hidden + W → mata silencioso. Mirror de Hidden + Q (Takedown legacy, renombrado del antiguo Execution). Escalará alarm en V1.5. Reusará `is_execution` (variable reservada en el rename de sub-paso 5).

---

### Sub-paso 5a cerrado — DashOffensive + sensible system + memoria de targets

#### Decisión arquitectónica: Dash separado en estados distintos
Pre-5a, el `dash.gd` neutral tenía la lógica de target dirigido (sub-paso 4). Cazado durante diseño: mezclar todos los modos del Dash en un solo estado iba a hacer `dash.gd` inmanejable cuando llegasen Sensible defensivo (V1.5), magnetic, remates W/Q, etc.

**Decisión:** separar en estados:
- `Dash` — neutral puro (sub-paso 3, sin target).
- `DashOffensive` — modos ofensivos (target dirigido + magnetic, futuros remates).
- `DashDefensive` — V1.5, no se toca aún.

`decide_dash_state()` en kive.gd decide a qué estado transicionar al pulsar E según contexto.

#### Filosofía: solo W marca al objetivo
**Decisión filosófica clave del sistema de combate de grupo cinemático.**

El RedFist es el objeto que conecta con los enemigos — la marca, el sello. Cuando un W de Kive (suelo o aire) impacta a un agente, ese agente queda registrado en `_chain_hit_agents`.

**Q (FrontalKick) y Dive-attack NO marcan.** Las piernas controlan espacio y derriban, pero no establecen identificación del target.

**Coherencia con GDD §0:**
- W = matar a sangre fría + **marca al objetivo**.
- Q = pacificar / neutralizar (sin marca).
- Dive = invasión de espacio (sin marca).

**Implicación mecánica importante:** un combate puramente Q/Dive nunca activa el target dirigido del Dash. El **combate cinemático tipo Yasuo/Akali emerge solo del modo letal**. Diferenciación mecánica de las dos filosofías W=DEATH/Q=KO en términos de **movilidad, no solo daño**.

**Implementación:**
- Variable `_chain_hit_agents: Array[Node2D]` en kive.gd.
- `register_w_hit(agent)` llamado desde callback de hitbox en kive.gd cuando `current_attack_type == "punch"`. Q ignorado.
- Se limpia con `reset_w_chain()` y `reset_state()`.
- `find_chained_agent_in_direction(direction)` filtra el array por dirección + `is_dash_target()` + más cercano.
- `DashOffensive` busca target dentro de este array.

#### Sistema Sensible unificado (terminología)
Un sistema con tres triggers (no tres sistemas):

| Trigger | Cuándo | Estado |
|---|---|---|
| Sensible target | `is_in_combat()` true + agente W-marcado en dirección | DashOffensive (5a) |
| Sensible offensive | `_sensible_target` válido (Kive lanzó al aire) | DashOffensive (5a) |
| Sensible defensive | Amenaza entrante (proyectil, agente WINDUP) | DashDefensive (V1.5) |

**Variables en kive.gd:**
- `_sensible_target: Node2D` — agente lanzado a AIRTIME, magnético durante `sensible_window` (0.4s).
- `_sensible_window_timer` — limpia `_sensible_target` al expirar.
- `is_in_combat()` — helper público: `is_chain_active() or _sensible_target != null`.
- `open_sensible_window(target)` — llamado por agent/dummy desde ramas uppercut y air_launch al entrar a AIRTIME.

**`KiveStats`:**
- `sensible_window: float = 0.4`
- `magnetic_speed_multiplier: float = 4.0` (subido de 3.0 tras playtest — Kive no alcanzaba al lanzado).

#### Polish físico magnetic — vertical impulse fijo, no escalado
Decisión cerrada al implementar 5a. La fórmula inicial `velocity.y = dy * 2.0` escalaba linealmente: si target muy alto, Kive salía disparado vertical raro.

**Decisión:** vertical impulse **fijo** (`-400` arriba, `+200` abajo) multiplicado por `magnetic_speed_multiplier`. Tunable. Predecible. Solo en modo magnetic — modo target es horizontal puro.

---

### Rename Execution → Takedown (commit aparte, prep V1.3 sub-paso 11)

Cazado al diseñar sub-paso 5b. La variable legacy `is_finisher` (Hidden + Q) y el estado `Execution` estaban **semánticamente mal**.

**Razón:** Hidden + Q es **K.O. silencioso, no letal**. "Execution" implica letal — contradice filosofía W=DEATH/Q=KO.

**Decisión cerrada:**
- `is_finisher` → `is_takedown`.
- `receive_execution()` → `receive_takedown()`.
- Estado `Execution` (archivo, class_name, nodo, StringName) → `Takedown`.
- Strings literales (`last_hit_quality`, `_ko_type`, prints) → `"takedown"`.

**Vocabulario reservado para V1.3 sub-paso 11 (Hidden + W silent kill):**
- Future state: `Execution` (versión letal real).
- Future flag: `is_execution`.
- Future function: `receive_execution`.

Sin esto, sub-paso 11 hubiera tenido que renombrar igualmente al crear el estado Execution real. Hacer rename ahora = trabajo adelantado, evita doble trabajo + bugs intermedios.

Término "takedown" es estándar de género (Splinter Cell, MGS, Far Cry) para K.O. sigilosos no letales.

**Bug post-rename:** Hidden + Q dejó de entrar tras aplicar el rename. Cache stale del editor de Godot con la entrada vieja `execution.gd::Execution<>State`. **Solución:** cerrar y reabrir el proyecto para reindexar filesystem cache. No era bug de código.

**Lección operativa aprendida:** tras renombrar archivos `.gd` con `git mv`, **siempre cerrar y reabrir el proyecto en Godot** antes de testear. Si no se reabre, los nodos del rename pueden no registrarse como `State` (el `if child is State` falla por cache stale) y todo el flow del estado se rompe silenciosamente.

---

### Sub-paso 5b cerrado — Modificadores E+W/E+Q + cinematic teleport

#### Filosofía cerrada: "W mantenida desde ANTES de E"

Cazada durante playtest del 5b. El issue inicial: el usuario humanamente no puede pulsar E + W exactamente a la vez. Pulsa E primero, luego W con delay de unos frames. Con `Input.is_action_just_pressed`, el finisher casi nunca entra.

Discutidos varios parches: late finisher detection durante active phase, auto-hit garantizado, tecla F dedicada al modificador. **Todos descartados.**

**Decisión final:** el finisher se EXPRESA ANTES del Dash, no después. Mantienes W o Q, **luego** pulsas E.

- `Input.is_action_pressed` lee estado actual de la tecla (sin importar cuándo se pulsó).
- Si W mantenida en el frame de E → `_pending_finisher = "w"`.
- Funciona sin código nuevo — convención de fighting games (Tekken, SF, MK): mantener modificador, pulsar acción.

**Coherencia narrativa:** Kive **decide** el tipo de remate antes de iniciar el Dash, no improvisa mid-dash. Más limpio. Más intencional.

**Sistema escalable:**
- W mantenida → finisher W chain (hoy).
- Q mantenida → finisher Q (hoy).
- W + Q mantenidas → execution combo especial (V2).
- Shift mantenida → finisher Dive (potencial V1.3+/V2).
- R mantenida → Parry-counter (V1.4).

Cada combinación de modificadores mantenidos = finisher distinto. Sin refactor del Dash.

#### Implementación
- Variable `_pending_finisher: String` en kive.gd (`""`, `"w"`, `"q"`).
- Detección en `decide_dash_state()` con `Input.is_action_pressed` (W tiene precedencia sobre Q).
- Tanto `Dash` neutral como `DashOffensive` honran el finisher al final de fase active.
- Si `_pending_finisher != ""`, transición directa a Jab (W chain según `get_w_chain_next()`) o FrontalKick. Skip recovery.
- Limpieza por refresco — siguiente `decide_dash_state` lo resetea.

**Sin agente W-marcado pero E+W/Q pulsado:** Dash neutral + W/Q al aire al final. Skill expression ("ir corriendo y meter una W").

#### Polish: cinematic teleport progresivo en DashOffensive

Cazado durante playtest: tras conectar magnetic, Kive pasaba por encima del target y el finisher (Uppercut) salía volando. Filosofía: el finisher debe **anclar al punto de impacto**.

**Decisión: teleport progresivo XY durante segunda mitad del active.**

| Fase | Comportamiento |
|---|---|
| Frame 0 → mid-active (`progress < dash_teleport_threshold` 0.5) | Dash puro con velocity, gravedad, `move_and_slide` |
| Mid-active → fin-active (`progress >= threshold`) | Lerp progresivo XY hacia `_target_position`. Sin gravedad. Sin `move_and_slide` (lerp gestiona posición). Velocity decae a 0 |
| Fin-active (snap) | Posición exacta = `_target_position`. Velocity zero. `move_and_slide()` sin movimiento (recalcula `is_on_floor()`). Transición a finisher |

**Variables tunables en KiveStats:**
- `dash_teleport_threshold: float = 0.5` — punto de active donde arranca el teleport.
- `dash_teleport_curve: float = 2.0` — exponente de aceleración (cuadrática por defecto).

**Tracking del target durante el dash:** `_target_position` cacheada en `enter()` y actualizada cada frame mientras `_dash_target` sea válido. Si el target muere mid-dash, congela última posición conocida.

**Bug `is_on_floor()` post-snap:** tras setear `kive.global_position.y` con teleport, `is_on_floor()` devolvía valor del frame anterior (cuando Kive estaba en suelo del dash puro). Resultado: `Uppercut.enter()` reportaba `in_air=false` aunque Kive estaba claramente en aire.

**Fix:** llamar `move_and_slide()` con velocity zero tras el snap. No mueve a Kive (no hay velocity para integrar) pero **sí** recalcula colisiones y `is_on_floor()`.

**Limitación conocida (V1.5):** el teleport por lerp ignora colisiones. Si Kive dasha hacia un target con pared en medio, atraviesa. No problema en V1.3 (test_combat sin paredes complejas), sí problema en vagones reales. Apuntar para V1.5: raycast pre-lerp.

#### Tres conceptos finales del vocabulario tras 5b

| Concepto | Variable | Trigger |
|---|---|---|
| **Takedown** | `is_takedown` | Hidden + Q (K.O. silencioso, no letal). Existe. |
| **Execution** | `is_execution` | Hidden + W (kill silencioso letal). Reservado V1.3 sub-paso 11. |
| **Finisher** | `_pending_finisher` | Remate al final del Dash (W/Q mantenido + E). Existe. |

Tres conceptos distintos, tres nombres claros. Sin spanglish. Sin ambigüedad. Sin doble uso de variables.

---

## Decisión: cerrar V1.3 con scope reducido

Post-5b playtest detectó bug: `_w_chain_timer` corre libre durante DashOffensive y a veces expira mid-dash, causando finishers inconsistentes (Jab en vez del chain step esperado). El sub-paso 6 original (input buffer) se descartó — sin dolor observado en playtest.

**Decisión:** cerrar V1.3 con scope reducido. Tres sub-pasos nuevos:
- Sub-paso 6: parche timer (reset en enter + snap, timeout 0.6→0.4)
- Sub-paso 7: verificación chain multi-target (probablemente 0 cambios)
- Sub-paso 8: tests integrados + tag combat-v1.3

Features descartadas de V1.3 y reasignadas:
- **V1.4:** Parry (R), W-execution sigilosa (Hidden+W), fix detección Hidden
- **V1.5:** Q direccionales aéreos, ventana repo aérea, polish

**Motivación:** V1.3 ya tiene masa crítica de features (aéreo + dive + dash cinematico + finishers + magnetic). Añadir Parry y W-execution en la misma versión infla el scope sin necesidad. Mejor cerrar, tagear, y atacar defensa activa como bloque coherente en V1.4.

---

## V1.4 — REASIGNADA (pendiente)

> Originalmente V1.4 era "Dash + Parry + W-execution sigilosa + fix detección Hidden". Esos elementos se absorbieron en V1.3 al cazar que el modelo de input es coherente integrado. V1.4 queda libre para foco diferente.

**Contenido actual V1.4 (planeado):**
- Lógica activa de detección centralizada / sistema A de alarma (Flai funcional).
- Fix detección durante Hidden (forzar a CrouchIdle si ALERT te ve).
- Stealth integration completa.
- Posible: persistencia de KO (timer de despertar V2 → traerlo a V1.4 si se siente necesario).

*Sin entradas detalladas todavía — se redefine al cerrar V1.3.*

---

## V1.5 — Polish, finisher, alarma activa (pendiente)

*Sin entradas todavía.*

Recordatorios para V1.5:
- Decidir qué hacer con la escalada legacy (Cross/Hook contra HIT → KO).
- Finisher cinemático cargado del Uppercut (W4 hold).
- Lógica activa de alarma (Sistema A funcional, kills suben alarm).
- UI combo counter visual.
- Telegraph del agente en WINDUP.
- Sensible glow visual.
- **Decisión de input model basada en playtest.** Tras V1.3 cerrado, jugar 15-20 min y evaluar si hace falta input buffer.
  - **Hipótesis:** con cancel tight (0.15s) + late chain (~0.6s) + Dash + ventana repo aéreo, la cobertura es suficiente sin buffer.
  - **Si la hipótesis falla:** implementar input buffer estándar (estilo Tekken / Street Fighter): guardar el último input durante ~150-300ms y consumirlo automáticamente cuando se abre la cancel window.
  - **Descartado:** macros mecanizados tipo LoL. No encaja con filosofía de decisiones momento-a-momento.

- **Tuning de timings a múltiplos de 4 frames (60fps).** Filosofía estándar de fighting games — da consistencia con animaciones futuras y predictibilidad de timings. Análisis pre-hecho durante sub-paso 5 de V1.2:

| Variable | Actual | Propuesta (múltiplo de 4) | Notas |
|---|---|---|---|
| punch_anticipation | 0.08 (5f) | 4f (0.067) | Más snappy |
| punch_release | 0.15 (9f) | 8f (0.133) | Ligeramente más corto |
| punch_recovery | 0.25 (15f) | 16f (0.267) | Un pelo más largo, más ventana |
| kick_anticipation | 0.05 (3f) | 4f (0.067) | Sube un frame |
| kick_release | 0.10 (6f) | 8f (0.133) | Más presencia visual |
| kick_recovery | 0.15 (9f) | 12f (0.2) | Q tiene más peso que W |
| w_chain_cancel_window | 0.15 (9f) | 8f (0.133) | Más estricto |
| q_cancel_window | 0.15 (9f) | 8f (0.133) | Simétrico con W |
| dash_duration | 0.133 (8f) | 8f ✓ | Ya es múltiplo |
| magnetic_window | 0.4 (24f) | 24f ✓ | Ya es múltiplo |
| air_repositioning_window | 0.4 (24f) | 24f ✓ | Ya es múltiplo |
| parry_window_duration | 0.667 (40f) | 40f ✓ | Ya es múltiplo |
| w_chain_reset_timeout | 0.6 (36f) | 36f ✓ | Ya es múltiplo |
| stunt_duration | 2.0 (120f) | 120f ✓ | Ya es múltiplo |

  **Decisión filosófica clave:** `kick_recovery` (12f) > `cancel_window`s (8f) → la patada tiene peso, no es spam. El W chain encadena más rápido (premia secuencias agresivas) que el Q (que es herramienta de control deliberada).
  **Cuándo aplicar:** tras playtest de V1.3 con timings actuales, si el "feel" pide consistencia. No antes — tunear sin datos es perder iteraciones.

---

## Infraestructura de testing — AgentDummy

> Decisión paralela al roadmap V1.2, tomada durante sub-paso 2 cuando se hizo evidente que
> el `Agent` real no es buen sujeto de pruebas: monolítico (~919 líneas), FSM compleja con
> match gigante, detección/patrulla/combate propios. Cazó al menos 4 bugs propios en
> sub-pasos 2-4 de V1.2.

### Decisiones de arquitectura

- **Clase nueva `AgentDummy` (extends CharacterBody2D)**, no herencia de Agent ni flag `is_dummy` interno.
- **El dummy es un saco de boxeo.** Sin patrulla, sin detección, sin ataque, sin GUARD_STANCE/WINDUP/etc.
- **Sí tiene** los estados de reacción: IDLE, HIT, STUNT, KO, AIRTIME, DEAD.
- **Sí tiene** las funciones de dispatch copiadas de Agent (`receive_hit_from`, `_resolve_q_hit`, `_resolve_w_hit`, `_apply_kick_push`, `_get_position_tier`).
- **Control:** F7 → reset dummy a IDLE en posición inicial.
- **Escena dedicada:** `scenes/test_combat.tscn`. Sin Flai, sin GameManager.
- **Debug forzado en escena:** `scripts/test_combat.gd` setea `DebugOverlay` flags en `_ready`.

### Bugs encontrados durante bringup del dummy

- **Push perdido por orden de ejecución en `_physics_process`.** El bloque de aplicar `_pending_kick_push_velocity` se ejecutaba ANTES del `match state`, y `DummyState.IDLE` ponía `velocity.x = 0` incondicional. Fix: invertir orden — state dispatch primero, push aplicado DESPUÉS para tener prioridad explícita.
  **Bug solo del dummy**, no del Agent original.

### Extensiones planeadas en V1.3

- **2 dummies en test_combat.tscn** (sub-paso 7) para verificar multi-target.
- **F7 reset itera sobre TODOS los nodos del grupo "agent"** (sub-paso 7).
- **Hide_zone en test_combat** (sub-paso 11) para verificar W-execution.

### Deuda técnica reconocida

`receive_hit_from`, `_resolve_q_hit`, `_resolve_w_hit` se duplican entre `Agent` y `AgentDummy`. Cambios deben propagarse manualmente.

**Cuándo unificar:** cuando se haga el refactor de `agent.gd` a state machine (post-V1.5). Ese refactor extraerá la resolución de hits a un componente reutilizable.

---

## Apéndice: lecciones del rework

### Lección A — Legacy contiene decisiones no documentadas

El código legacy contiene decisiones de diseño que el GDD no explicita. Algunas son buenas (PARRY como feedback). Otras contradictorias (KO por detrás). Otras fantasmas (RNG 4%).

**Regla:** cuando un sub-paso pide reescribir una función legacy, **leer el código actual antes de redefinir** y registrar aquí cualquier comportamiento descartado.

### Lección B — Filosofía de la state machine

Cuando una variable empieza a tener dos significados según contexto, separarlos con función dedicada o variable separada **antes** de que el bug emerja. Aplicado en V1.1 (`is_chain_active()`) y V1.2 (`q_context` vs `last_w_executed`).

### Lección C — Buen sujeto de pruebas

Cuando el sujeto de pruebas tiene comportamiento propio complejo, distinguir bugs propios del nuevo sistema vs comportamientos del sujeto se vuelve difícil. Crear infraestructura de testing aislada ahorra tiempo de debug. El AgentDummy cazó 4+ bugs en V1.2 que en Agent real habrían sido invisibles.

### Lección D — Verificar antes de copiar

Cuando se copia código de un sistema A a un sistema B simplificado, las simplificaciones revelan dependencias implícitas no obvias.

**Regla operativa:** cuando copies código a un contexto simplificado, hacer un repaso explícito de "qué hace este código que el contexto original ignoraba pero el simplificado no puede".

### Lección E — El GDD como brújula filosófica

Durante V1.2 sub-paso 3 emergieron tres decisiones filosóficas no anticipadas por el roadmap: Q=KO en aterrizaje, cuerpos empujables solo por Q, kill selectiva como mecánica explícita. Las tres se cerraron consultando el GDD V1.

**Regla operativa:** cuando una decisión emerge en playtest y no está en el roadmap, consultar GDD primero. Si el GDD contesta, esa es la decisión. Si el GDD no contesta, conversación de diseño separada con tiempo.

### Lección F — Pensar el modelo de input antes de codificar

Durante el diseño de V1.3, el roadmap original proponía Space como input mágico para "magnetic jump". Al pensar V1.4 (Dash con E), el usuario detectó que **Space estaría sobrecargado** (jump + AirJump + magnetic).

**Decisión:** restructurar. Mover magnetic + Q direccionales + ventana repo aéreo a Dash (E). V1.3 absorbe Dash, Parry, W-execution. V1.4 reasignada a detección centralizada.

**Regla operativa:** cuando un sub-paso depende de un input que va a tener otro uso en versiones futuras, **decidir el modelo de input a versión completa antes de codificar**. 30 minutos de planning ahorran sesiones de re-trabajo.

### Lección G — Reconocer cuándo parar a hacer infraestructura vs parchar

Durante sub-paso 5b emergió un patrón peligroso: cada feature nuevo del Dash hacía el timing de input MÁS exigente, y la respuesta natural era **añadir parches específicos al feature** (late detection, auto-hit, fallbacks). Casi metimos ~30 líneas de parches para cubrir el caso "E+W simultáneo difícil humanamente".

El usuario cazó: *"oye no crees que nos estamos como complicando mucho?"*

**Decisión cazada:** parches abordaban síntomas, no causa raíz. La causa raíz era ausencia de input buffer. **Parar V1.3 lineal, hacer buffer (sub-paso 6 reordenado), retomar.**

**Patrón filosófico cazado:** durante sub-paso 5b también surgió la solución no-parche más elegante: el modificador "W mantenida desde antes" **eliminó el problema** sin necesidad de buffer ni parches. `Input.is_action_pressed` ya hacía el trabajo.

**Regla operativa:** cuando notes que estás añadiendo parches específicos para resolver problemas que afectan a múltiples features (input lag, race conditions, polish físico), **parar y preguntar:**
1. ¿Hay un cambio filosófico de diseño que elimine el problema sin código? (Ej: modificador mantenido vs simultáneo).
2. ¿Hay infraestructura compartida que resuelva todos los casos a la vez? (Ej: input buffer general).
3. Si las dos son no, parche aceptado. Si alguna es sí, **infraestructura primero, parche evitado**.

### Lección H — Vocabulario filosóficamente correcto desde el origen

Durante diseño de sub-paso 5b emergió que `is_finisher` y `Execution` (legacy) estaban **semánticamente mal**: ambos se usaban para Hidden + Q, que es K.O. silencioso, **no letal**. "Execution" implica letal.

Detectado pre-implementación del sub-paso 11 (W-execution sigilosa, kill letal real). Si hubiéramos seguido con `is_execution` apuntando al K.O., al crear el estado Execution real en sub-paso 11 hubiera habido **conflicto de nombres + doble trabajo de rename**.

**Decisión:** rename completo a `Takedown` (commit aparte, prep V1.3). 21 sustituciones en 6 archivos. Pure rename, cero cambios funcionales.

**Regla operativa:** cuando una variable o estado tenga nombre **filosóficamente impreciso** según la decisión de diseño actual, renombrar **antes** de construir features encima. Hacer "trabajo adelantado" cuando el rename es claro evita doble trabajo después + bugs intermedios de "estado a medio renombrar".

**Bug operativo del rename:** Godot mantiene cache stale del filesystem tras `git mv`. Tras renombrar, **siempre cerrar y reabrir el proyecto** antes de testear. Si no, los nodos pueden no registrarse como su clase base por cache stale, y todo el flow del estado se rompe silenciosamente.

### Lección I — Cuando recortar scope de una versión

V1.3 nació con 12 sub-pasos mezclando 3 bloques temáticos (dash cinematico, defensa activa, stealth). Tras implementar 7 sub-pasos (1-5b + rename), el playtest reveló un bug de timer en DashOffensive — fix trivial, pero quedaban 5 sub-pasos pesados (Q direccionales, repo aéreo, Parry, W-execution, tests).

**Señales de que conviene recortar:**
1. La versión ya tiene masa crítica de features funcionales y testeables
2. Los sub-pasos restantes forman un bloque temático diferente al núcleo de la versión
3. Un bug en lo ya implementado indica que hay deuda técnica que resolver antes de apilar más
4. El sub-paso descartado (input buffer) no generó dolor en playtest — señal de que el scope original era inflado

**Regla operativa:** si una versión tiene >6 sub-pasos y los últimos son temáticamente distintos del núcleo, considerar cerrar y reasignar. Mejor una versión cerrada y tagueada que una versión eterna con features a medio integrar.

### Lección J — Reset incondicional del timer en helpers de chain

El chain timer se resetea SIEMPRE en helpers que se interponen entre W (FrontalKick, DashOffensive, futuros Parry/Dash sin finisher), sin guarda condicional.

Razón: ni `is_chain_active()` ni `w_chain_step > 0` son guardas correctas. La primera depende del timer (que es justo lo que intentamos preservar) y falla con cancels largos. La segunda falla después del primer Jab (step=0 indistinguible de "no combo"). El step solo avanza al entrar a Cross/Hook/Uppercut.

Reset incondicional es seguro porque si no había combo, `get_w_chain_next()` devuelve "" y `dash_offensive.gd` cae a Jab, que es el comportamiento correcto. Si había combo, el reset lo mantiene vivo.

Bug evidencia (V1.3 sub-paso 6): combo Jab→Q→E+W producía Jab repetido en vez de Cross. Tras reset incondicional, produce Cross.

Aplica en: FrontalKick.enter(), DashOffensive.enter(), DashOffensive snap. Patrón a seguir en futuros estados que se interpongan en chain.

### Regla operativa general

**No se reabre una decisión registrada aquí sin volver a discutirla.** Si en V1.5 el playtest dice "falta vía X", se reconsidera con datos en mano. No por "ah, antes lo había".

---

## Decisiones narrativas pendientes (afectan a implementación futura)

### "Kive nunca mira atrás"

Decisión narrativa surgida durante diseño de V1.3/V1.4: **Kive no gira hacia atrás, especialmente en suelo.** Va hacia adelante siempre. Si necesita moverse hacia atrás (esquivar, reposicionarse), lo hace con **animación de marcha atrás** sin cambiar facing.

**Razón filosófica:** Kive es El Rebelde del GDD, está en duelo, está roto. **No huye, no cede.** Mirar atrás = retroceso emocional. Encarar siempre adelante = decisión activa de seguir. Coherente con la guardia zurda boxística (GDD pilar 3): mantiene lado izquierdo hacia el objetivo, no gira a la ligera.

**Estado actual del código:** el sistema usa volteo horizontal con cambio de facing al pulsar A/D contrario al actual. Esa lógica **se mantendrá hasta que se decida la narrativa**, pero conviene saber que va a cambiar.

**Implicaciones cuando aterrice:**
- Cambio de facing solo si Kive **gira deliberadamente** (giro de combate, finisher, evento narrativo).
- Movimiento hacia atrás = animación de marcha atrás (a definir en sprites alpha).
- Dash A en facing derecha = dash izquierda **sin cambiar facing**.
- En aire, sí puede mirar atrás (decisión menos cerrada — el aire es momento "fuera de control").

**Cuándo decidir:** cuando llegue diseño de animaciones alpha o cuando emerja conflicto mecánico. No bloquea V1.3 ni V1.4.

**Aplica a:** cambio de facing en Dash (V1.3), Walljump (V2), Dive lateral, idle/walk/run lateral.

---

*v0.1 — abierto en V1.2 sub-paso 2 al detectar diferencias entre legacy y roadmap.*
*v0.2 — añadidos sub-paso 2 cerrado, AgentDummy infrastructure, lecciones B y C.*
*v0.3 — añadido cierre de sub-paso 2 + bug del push (dummy only) + lección D.*
*v0.4 — añadido cierre de sub-paso 3 con tres decisiones filosóficas + lección E.*
*v0.5 — añadido V1.3 expandido (12 sub-pasos), V1.4 reasignada, decisión narrativa "Kive nunca mira atrás", lección F. Tabla de tuning múltiplos de 4 ampliada con nuevas variables de V1.3.*
*v0.6 — cierre sub-paso 5a (DashOffensive arquitectura, sensible system unificado, memoria targets W-marcados, filosofía "solo W marca"), rename Execution → Takedown (vocabulario coherente con W=DEATH/Q=KO, reservado is_execution para sub-paso 11), cierre sub-paso 5b (modificadores mantenidos, _pending_finisher, cinematic teleport progresivo, fix is_on_floor post-snap), filosofía "W mantenida desde antes de E", sub-paso 6 reordenado a input buffer (era chain preservation multi-target), lecciones G (infraestructura vs parches) y H (vocabulario filosóficamente correcto + bug Godot cache post-git mv).*
