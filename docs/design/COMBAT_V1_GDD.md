# COMBAT V1 — Game Design Document

> Sistema de combate post-refactor, primera versión jugable.
> Sucesor del sistema legacy auditado en `COMBAT_AUDIT.md`.
> Status: diseño cerrado, pendiente de implementación.

---

## 1. Pilares de diseño

1. **Combate y stealth son rutas paralelas** del encuentro. Cada vagón se puede resolver "demoledor" o "fantasma", excepto los que fuercen una u otra.
2. **Encuentros adaptativos al número de enemigos** (típico 1-4 por vagón). Los combos deben funcionar tanto contra 1 como contra 4.
3. **Verticalidad como herramienta de control de espacio** — el vagón es estrecho y largo, las alturas (asientos, escenarios, barandillas) crean ventaja táctica.
4. **Identidad de Kive: golpes con peso narrativo**, no técnica fría. El vocabulario es boxeo y artes marciales con sabor expresivo (`golpe_bueno`, `maestro`, `stunt`). Cada hit cuenta una historia.
5. **V1 con animaciones existentes**; V2 con animaciones nuevas. Si no se puede hacer con lo que hay, va a V2.
6. **Diseño self-limiting** sobre cooldowns numéricos. Las restricciones deben sentirse diegéticas (recovery, contexto, posición), no impuestas por la UI.

---

## 2. Inputs

| Tecla | Acción | Notas |
|---|---|---|
| W | Punch (cadena de combo) | Tap = jab, hold = parte de combo |
| Q | Kick (cadena de combo) | |
| E | Dash | Doble modo: neutro / Sensible contextual |
| Space | Salto | (ya existente) |
| Shift | Dive | (ya existente) |
| Ctrl / C | Crouch | (ya existente) |
| **R** *(propuesta)* | Parry | Input dedicado, separado de Punch |

> **Decisión pendiente:** la tecla del Parry (`R`, `F`, click derecho del ratón…). Sugerencia: `R` por accesibilidad.

---

## 3. Combos terrestres

### 3.1 Punch chain — W → W → W

Cadena de tres puñetazos con cancel windows entre cada hit.

| Hit | Nombre interno | Sprite (V1) | Daño / efecto | Notas |
|---|---|---|---|---|
| 1 | `Punch1` | `punch_contact` | Hit ligero | Apertura rápida, abre paso al hit 2 |
| 2 | `Punch2` | `punch_contact` | Golpe bueno (KO a vulnerables) | Cross, conecta con peso |
| 3 | `Punch3` | `punch_contact` | Uppercut (lanza al enemigo arriba) | Termina cadena terrestre, abre vía aérea |
| 3+ (hold) | `Finisher` | `attack_charged_airtime` + `attack_charged_contact` | Charged punch como remate | Reutiliza animación de lunge actual |

**Cancel window:** durante los últimos ~150ms del recovery de cada hit, otro `W` encadena al siguiente. Si pulsas más tarde, el combo se reinicia.

**V1 nota:** todos los hits usan `punch_contact` con variaciones de timing y posición. Visualmente serán similares; en V2 cada hit tendrá animación única.

### 3.2 Kick chain — Q → Q

| Hit | Nombre interno | Sprite (V1) | Daño / efecto | Notas |
|---|---|---|---|---|
| 1 | `Kick1` | `kick_contact` | Knockback corto | Apertura |
| 2 | `Kick2` | `kick_contact` | **AOE alrededor de Kive** (multi-hit) | Roundhouse / 360° — golpea a todos los enemigos en rango |

**Cancel window:** igual que Punch chain.

### 3.3 Cross-cancels (Punch ↔ Kick)

Durante el recovery de cualquier hit del combo, **cancelable a la otra cadena**. Esto da combinaciones útiles:

| Combo | Uso |
|---|---|
| `W → Q → Q` | Apertura + AOE para limpiar grupo |
| `W → W → Q` | Set-up + AOE |
| `Q → W → W → W` | Apertura + chain completo contra un solo enemigo |
| `W → W → Q → Q` | 4 hits máximos sin finisher |

**Restricción V1:** los cancels solo van Punch → Kick o Kick → Punch. No `Q → Q → Q` (la cadena de kick es de 2 hits) ni `W → W → W → W` (el Punch3 es uppercut, no encadena horizontal).

---

## 4. Combate aéreo

### 4.1 Ataques aéreos básicos

| Input | Acción | Sprite (V1) |
|---|---|---|
| W en aire | Air Punch | `punch_contact` (en aire) |
| Q en aire | Air Kick | `kick_contact` (en aire) |
| Shift en aire | Dive (existe) | `dive_slide` |

**Air Punch y Air Kick:** ataques de un solo hit, sin cadena. Recovery permite caer normalmente. **Sin cancels en V1.**

### 4.2 Aerial chain (post-uppercut)

Si terminas el Punch chain con `Punch3` (uppercut), el enemigo sale lanzado al aire. **Kive puede saltar tras él** (Space) y encadenar:

```
Tierra: W → W → W (uppercut)
Aire:   Space → W (Air Punch) → Shift (Dive-attack al descender)
```

**V1 limitaciones:**
- Solo 1 hit aéreo (Air Punch o Air Kick) entre uppercut y caída.
- Dive-attack al descender hace daño si pasa por enemigo.
- **V2:** combos aéreos largos con cadenas y juggling.

### 4.3 Dive-attack (mejora del Dive existente)

Comportamiento nuevo: durante un `DiveAir`, **si Kive pasa por encima de un enemigo**, le hace daño automáticamente. No es un input nuevo, es un comportamiento del Dive.

**Daño:** equivalente a un Punch normal (golpe bueno si vulnerable).

---

## 5. Dash (E)

Sistema de **doble modo**. El mismo botón se comporta distinto según el contexto.

### 5.1 Dash neutro (modo por defecto)

| Campo | Valor |
|---|---|
| Trigger | `E` en cualquier momento que no haya contexto Sensible activo |
| Distancia | ~150 px |
| Duración | ~0.2s |
| Daño | Ninguno |
| I-frames | Ninguno |
| Recovery | ~0.25s animado al final (Kive aterriza con leve desequilibrio) |
| Cancelable por | Salto, ataque, crouch — interrumpen el recovery |
| Spam | Posible pero limitado por el recovery natural |
| Sprite (V1) | Reutiliza animación del lunge actual, **sin frame de impacto** (puño no extendido completo) |

**Filosofía:** movimiento puro. Sirve para reposicionarte, abrir distancia, llegar antes a un sitio.

### 5.2 Dash Sensible (modo contextual)

Cuando Kive detecta un **trigger Sensible activo**, el mismo input `E` hace algo MÁS.

**Triggers V1 — solo defensivos:**
- Un agente está en `WINDUP` o `ATTACK_RELEASE` apuntando a Kive (ataque entrante).
- Un proyectil está aproximándose a Kive.
  *(En V1 puede que no haya proyectiles; si los hay, contemplarlo. Si no, queda como hook para V2.)*

| Campo | Valor |
|---|---|
| Distancia | ~300 px (doble que neutro) |
| Duración | ~0.25s |
| Daño | Ninguno (sigue sin daño) |
| **I-frames** | Sí — durante todo el dash |
| Recovery | ~0.2s |
| Sprite (V1) | Animación lunge + **tinte blanco breve** indicando activación Sensible |
| Hit-stop | Pequeño hit-stop visual (~50ms) al activarse para enfatizar el momento |

**Filosofía:** **Len protegiéndote desde La Red.** El dash Sensible NO es entrenamiento técnico, es reflejo del Sensible activándose. Es **reactivo, no proactivo**, y por eso siente "ganado".

### 5.3 Indicador visual

Cuando el contexto Sensible está disponible, aplicar un **glow/tinte blanco brevísimo** (~150ms) sobre Kive. Eso le dice al jugador "ahora, pulsa E ahora".

**V1 mínimo:** un flash de modulate sobre el sprite cuando el Sensible se activa.
**V2:** efecto de partícula, sonido distintivo.

### 5.4 Hidden + E

**Pendiente decisión.** Opciones:
- (a) `E` deshabilitado durante Hidden.
- (b) `E` hace dash neutro (sales de Hidden).
- (c) `E` con trigger Sensible te permite dashear sin romper Hidden (alpha 0.35 se mantiene).

**Por defecto en V1:** opción (a) — `E` deshabilitado durante Hidden, para mantener simple.

---

## 6. Parry

Sistema dedicado, **separado del Punch**.

| Campo | Valor |
|---|---|
| Input | `R` (a confirmar tecla) |
| Ventana | 0.667s (40 frames a 60fps — igual que ahora) |
| Apertura | Al pulsar `R` |
| Cierre | Por timeout o tras parry exitoso |
| Sprite | Postura de bloqueo (V1: usar `idle` con flash visual; V2: animación dedicada) |
| Movimiento | Bloqueado durante la ventana |
| Si recibes hit dentro de ventana | Parry exitoso → agente → `AIRTIME` → `DEAD` |
| Si recibes hit fuera de ventana | Damaged → respawn |
| Cooldown | **No hay cooldown numérico**, pero tras un parry exitoso hay ~0.3s de "cierre" donde no puedes volver a abrir ventana |

**Filosofía:** parry como herramienta defensiva activa, no como subproducto de cargar ataque. El jugador decide cuándo defenderse.

**V1 limitación:** el parry sigue siendo binario (todo o nada). Sin variantes (perfect parry, late parry, etc.).

---

## 7. Charged Punch / Finisher

**Cambio fundamental respecto al sistema legacy:** ya no es un ataque suelto. Solo se activa como **finisher de combo**.

### 7.1 Activación

`W → W → W (mantenido)` — al llegar al tercer Punch, si mantienes el botón, se carga.

| Tiempo de mantenimiento | Resultado |
|---|---|
| < 0.4s | Punch3 normal (uppercut) |
| 0.4s – 2.4s | Charged Punch (lunge interpolado 40%-100%) |
| 2.4s+ | Auto-release con charge máximo |

### 7.2 Comportamiento del lunge

Idéntico al sistema actual:
- `velocity.x = facing × 2400 × impulse_factor`
- `velocity.y = -1200 × impulse_factor`
- `impulse_factor = lerp(0.4, 1.0, charge_ratio)`

### 7.3 V1 — hit-stop básico

Cuando el charged punch impacta:
- **Hit-stop:** `Engine.time_scale = 0.0` durante ~0.1s.
- **Frame freeze** del sprite en `attack_charged_contact`.
- **Camera shake** breve.
- **Restaurar** time_scale tras el freeze.

Esto es la versión "minimalista" que da impacto sin necesitar arte nuevo.

### 7.4 V1.5 — Finisher cinemático completo

**Tras tener V1 funcionando**, ampliar el hit-stop a una cinemática completa:

- Time-freeze más largo (~0.3s).
- Cámara cambia de ángulo o se acerca.
- Slow-mo en el momento de impacto.
- Frame-hold extendido del golpe.
- El enemigo sale volando con efecto exagerado (overshoot).
- Posible: viñetado o flash blanco al final.

**Reutilizable** para otros momentos especiales:
- Parrys exitosos contra enemigos clave (jefes, etc.).
- Executions desde Hidden.
- Maestros (cuando el sistema actual los detecta).

---

## 8. Reacciones del agente

**No cambian respecto al sistema actual.** Lo que migrad es lo que dispara cada reacción:

| Trigger nuevo | Reacción del agente | Cómo se llama |
|---|---|---|
| Punch1 (cualquier estado) | Hit ligero | `receive_hit_from(self, false, "punch")` |
| Punch2 (vulnerable) | Golpe bueno (KO) | `receive_hit_from(self, false, "punch")` con detección de combo en kive |
| Punch3 / uppercut | Lanza al aire | Nueva función: `receive_uppercut(self)` o flag adicional |
| Charged Punch finisher (vulnerable) | Maestro (DEAD) | `receive_hit_from(self, true, "punch")` con `charge_ratio >= 0.95` |
| Charged Punch finisher (guard) | Stunt (1.5s) | igual que ahora |
| Kick1 | Knockback / push | `receive_hit_from(self, false, "kick")` |
| Kick2 (AOE) | Múltiples enemigos en radio reciben hit | Iteración sobre enemigos en rango |
| Air Punch / Air Kick | Hit normal | `receive_hit_from(self, false, "punch"/"kick")` |
| Dive-attack | Hit normal | igual que arriba |
| Execution (desde Hidden) | KO inmediato | `receive_execution(self)` (no cambia) |
| Parry | AIRTIME → DEAD | `receive_parry()` (no cambia) |

**Nota:** la lógica de "vulnerable / guard / detrás" del agente sigue igual. Solo añadimos el trigger de "uppercut" y el "AOE" del Kick2.

---

## 9. UI / Indicadores visuales (mínimo V1)

### 9.1 Combo counter

- Esquina superior derecha o flotante sobre Kive.
- Texto simple: `x1`, `x2`, `x3`, `FINISHER READY`.
- Aparece al iniciar combo, se mantiene durante cancel windows, desaparece al fallar el timing o reset.

### 9.2 Sensible glow (Dash contextual)

- Tinte blanco breve sobre el sprite de Kive cuando el contexto Sensible se activa.
- Duración del flash: ~150ms.
- Se desvanece si no se pulsa E en la ventana.

### 9.3 Parry telegraph (visual del agente)

- Cuando el agente está en `WINDUP` apuntando a Kive, **cambiar el color del cono de visión** o añadir un **flash rojo** breve.
- Esto le indica al jugador "ahora vale la pena pulsar parry".
- **No es un nuevo sistema**, solo un cambio visual sobre lo que ya existe.

### 9.4 Hit feedback

- Hit-stop breve en cada conexión de combo (~30-50ms).
- Camera shake escalado por daño (más fuerte en finisher, AOE, parry).
- Flash blanco breve sobre el agente impactado.

---

## 10. Stealth integration

### 10.1 Sin cambios respecto al sistema actual

- `Hidden + Q` → Execution
- `Hidden + W` → unhide → PunchCharging
- Hidden auto-activa con crouch + hide_zone + safe enemies (igual que ahora)

### 10.2 Cambios menores

- `Hidden + E` → desactivado (decisión por defecto, simple).
- `Hidden + Space (jump)` → JumpAnticipation (sale de Hidden), igual que ahora.
- `Hidden + R (parry)` → desactivado (no tiene sentido un parry desde sigilo).

### 10.3 Detección durante Hidden

**Bug actual:** si te detectan estando Hidden, sigues en Hidden hasta que tú decidas salir. Esto es incorrecto.

**Fix V1:** si un agente en estado `ALERT` o superior tiene a Kive en su cono de visión, **forzar transición de Hidden a CrouchIdle**. Ya no estás oculto si te ven.

---

## 11. Excluido de V1 (queda para V2)

| Feature | Razón |
|---|---|
| Animaciones únicas por hit del combo | Requiere arte nuevo |
| Cinemática completa del finisher (V1.5) | Tras tener V1 funcional |
| Combos aéreos largos | Requiere balanceo y arte |
| Más variedad de Kicks (low-kick, axe-kick) | Requiere arte |
| Daño numérico (HP del agente) | V1 es binario "vulnerable / no vulnerable" |
| Vault contextual (Dash sobre objetos) | Requiere props mapeados |
| Perfect parry / late parry | Refinamiento de feel |
| Combos de 4+ hits | Decisión de feel tras playtest |
| Nuevas teclas dedicadas a combos especiales | Mantener inputs simples en V1 |
| Cinemática de Execution desde Hidden | V2 |
| Direccionalidad del ataque (arriba, abajo, atrás) | V2 |

---

## 12. Plan de implementación V1

### Fase 1 — Fundamentos (sin cambios visuales)
1. Crear estado `Punch1`, `Punch2`, `Punch3` (rename del actual `Punch` y duplicación).
2. Implementar transiciones de cancel window entre ellos.
3. Lo mismo con `Kick1`, `Kick2`.
4. Cross-cancels Punch ↔ Kick.
5. Air Punch y Air Kick como estados aéreos básicos.
6. Combo counter visual (label simple).

### Fase 2 — Mecánicas nuevas
7. Estado `Parry` separado, input dedicado.
8. Estado `Dash` con doble modo (neutro / Sensible).
9. Sistema de detección de "trigger Sensible" (escanea agentes en `WINDUP/ATTACK_RELEASE`).
10. Sensible glow visual.
11. Uppercut: Punch3 lanza al enemigo al aire.

### Fase 3 — Charged como finisher
12. Charged Punch solo activable como Hit3 mantenido.
13. Hit-stop básico al impacto.
14. Camera shake y feedback.
15. Eliminar el viejo flujo del PunchCharging como input directo (pasa a ser fase de Punch3).

### Fase 4 — Stealth integration
16. Fix de detección durante Hidden (forzar a CrouchIdle si te ven).
17. Reactions a Air-attacks, Dive-attack, AOE Kick2.

### Fase 5 — Polish V1
18. Telegraph del Parry (visual del agente en WINDUP).
19. UI de combo counter pulida.
20. Playtest extensivo.

### Fase 6 — V1.5
21. Cinemática completa del finisher (cuando V1 esté estable).

---

## 13. Métricas de éxito V1

V1 está "completa" cuando:
- ✅ Puedes hacer un combo de 3 puñetazos terrestre y se siente que conecta.
- ✅ Puedes cancelar Punch → Kick y viceversa con timing.
- ✅ Air Punch y Air Kick son utilizables tras un salto.
- ✅ El uppercut lanza al enemigo arriba y puedes seguirlo con Air Punch.
- ✅ El Dash neutro funciona como reposicionamiento sin sentirse spam.
- ✅ El Dash Sensible se activa de forma reactiva con feedback claro.
- ✅ El Parry es un input dedicado y funciona contra ataques telegrafiados.
- ✅ El Charged Punch como finisher se siente como un cierre épico.
- ✅ Sin regresiones en stealth y movimiento.

---

## 14. Métricas de éxito V1.5

V1.5 está "completa" cuando:
- ✅ El finisher tiene cinemática que para el tiempo y rompe la pantalla.
- ✅ Los maestros (parrys, executions) tienen feedback cinemático equivalente.
- ✅ El feel del combate transmite "Kive como rebelde con poderes Sensible".

---

*v0.1 — diseño cerrado tras conversación de auditoría y propuesta.*
*Próximo paso: implementación Fase 1.*
