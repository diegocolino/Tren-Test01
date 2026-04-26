# KIVE EN EL TREN — Game Design Document
> Versión 0.2 — documento vivo, actualizar libremente

---

## 1. CONCEPTO

Un nivel/minijuego de acción y sigilo ambientado en El Tren, la única forma de transporte lujosa y autónoma que atraviesa La Carretera hacia Kilima.

**Logline jugable:**
Kive acaba de enterarse de la muerte de su hermana Len. Alterado y en duelo, se monta en El Tren junto a Yeri. Un altercado en el andén hace saltar las alarmas. Objetivo: sobrevivir vagón a vagón hasta la próxima parada y salir sin ser arrestado ni asesinado.

**Escala del proyecto:**
- Puede ser un nivel standalone (minijuego del universo Kilima)
- O el primer nivel jugable del arco completo de *Kive el Rebelde*

---

## 2. LORE RELEVANTE PARA EL JUEGO

### El mundo
- **Kilima** es una estructura distópica y jerarquizada. El Tren es el acceso privilegiado a ella.
- **La Carretera** es el territorio hostil que El Tren atraviesa. Apocalíptica: campos de refugiados, bases de saqueadores. Pero desde el tren se ve un paisaje falso — naturaleza, cascadas, animales. Flai proyecta una mentira en las ventanas.
- **Flai** es la IA omnipresente que controla El Tren: seguridad, monitoreo, puertas, sistemas. Cyan. Lo sabe casi todo. Enemigo invisible del nivel.
- **La Agencia SL** controla las carreras artísticas en Kilima. Kive está bajo su contrato. Su hermana Len era la nueva cara de la Agencia. Ahora está muerta.
- **Len (La Huérfana)** — hermana de Kive, recién muerta. Su conciencia está en La Red. Desde ahí interfiere con Flai para proteger a Kive. No se muestra explícitamente, pero su presencia se siente: cuando Flai falla, es ella. Ángel guardián.

### Los personajes en el tren
- **Kive (El Rebelde)** — protagonista. Músico, ex-estrella de La Montaña, bajo contrato con La Agencia. En duelo por Len. Alterado, impulsivo. Todavía no es el líder de la Resistencia — es un hombre roto. Nota: **D#**. Color: **Rojo**.
- **Yeri (El Explorador)** — el único de los 12 que ha viajado a pie por La Carretera. Conoce el mundo exterior, los sistemas del tren, los peligros. Luchador habilidoso. Nota: **A**. En el vagón 1 no está — se dividen al colarse. Se reencuentran en el vagón 2. Cinemática de Yeri saltando al tren en marcha.

### Tono emocional
Kive no es un héroe todavía. El altercado no nace de rebeldía política — nace del dolor. Un músico famoso al que alguien reconoce en el peor momento de su vida.

---

## 3. SISTEMA ARMÓNICO GIGAGEN

| Entidad | Nota | Color |
|---------|------|-------|
| Kive | D# | Rojo |
| Yeri | A | — |
| El Tren | F | Oro rosa |
| Flai | — | Cyan |

**D# — F — A** = tríada aumentada. Inestable. Tres entidades en tensión dentro de un espacio que no le pertenece a ninguna.

**F como nota del Tren:** la subdominante. Tensión sin resolución. El lugar de tránsito entre lo que eras y lo que vas a ser.

> ⚠️ Notas de los vagones individuales: por definir.

---

## 4. PALETA DE COLOR

| Elemento | Color | Uso |
|----------|-------|-----|
| El Tren | Oro rosa | Estructura, materiales, lujo distópico |
| Flai | Cyan | Tecnología, cámaras, puertas, alertas |
| Kive | Rojo | El personaje, sus momentos de control, sus poderes |
| Verde orgánico | puntual | Solo en ventanas y plantas biotec interiores |
| Negro | FX único | Apagón, fuerzas del mal, peligro absoluto |
| Blanco | FX único | Len interfiere, Kive conecta, poderes Sensible |

**Negro y blanco no son colores del mundo — son interrupciones.**
**Ámbar = Éter únicamente.** No se usa en el tren.

---

## 5. SISTEMA DE CAPAS (GODOT)

Todos los vagones comparten el mismo stack:

- **Fondo** — paisaje falso de Flai. Paralaje lento. Cuando Len interfiere: glitch, se ve La Carretera real.
- **Mid** — estructura, mobiliario, decoración. Estático.
- **Frente** — columnas, barandillas, objetos delante del personaje. Profundidad.

### Vocabulario visual constante en todos los vagones
- Proporciones idénticas de techo, suelo y ventanas
- Materiales oro rosa con detalles steampunk (remaches, tuberías, engranajes orgánicos)
- Presencia de Flai en cyan (cámaras, paneles, indicadores)
- Al menos una planta biotec rara por vagón

### Lo que cambia por vagón
- Función del espacio y mobiliario
- Intensidad de Flai
- Uso de FX negro/blanco
- Nota armónica propia

---

## 6. ESTRUCTURA NARRATIVA DEL NIVEL

### Prólogo (cinemática)
Altercado en el andén — alguien reconoce a Kive en el peor momento. Alarmas. Yeri distrae a los guardias. Kive se cuela con el tren casi en marcha. Se dividen.

### Vagón 1 — El Teatro
**Solo. Alarma activa. Sin poderes.**

Vagón de actuaciones en vivo para la élite. Escenario, butacas, micrófonos. Vacío.
Kive entra desde las butacas. Enemigos en la sala. El escenario es zona de ventaja — altura, visibilidad. Salida al fondo, detrás del escenario.

**Simbolismo:** Kive lleva toda su vida subiendo a escenarios desde abajo. Lo hace una vez más, huyendo y roto. No para actuar — para escapar.
**Flai:** activo. Ventanas con paisaje falso. Luz cyan fría.

### Vagón 2 — (por definir)
Reencuentro con Yeri. Cinemática: Yeri saltando al tren en marcha como un héroe.

### Vagones 3-6 — (por definir)
- Un vagón: Flai falla. Len distrae a la IA. Sin vigilancia. Posible apagón (FX negro).
- Un vagón: Kive desbloquea poderes Sensible con ayuda de Len. FX blanco. Primer momento donde el rojo domina el espacio.
- Último vagón: primera vista real de Kilima por las ventanas.

---

## 7. MECÁNICAS (PENDIENTE)

- [ ] Combate de Kive — cuerpo a cuerpo improvisado, sin poderes en vagón 1
- [ ] Sistema de sigilo — detección por cono de visión o sonido
- [ ] Yeri como NPC pasivo — diálogos, abre rutas, no pathfinding complejo todavía
- [ ] Flai como amenaza — cámaras, puertas, niveles de alerta
- [ ] Condiciones de derrota — arresto vs muerte
- [ ] Mecánica de poderes Sensible — cómo se activan, qué hacen

---

## 8. PRIORIDADES ACTUALES

1. **Dibujar el Vagón 1 — El Teatro**
2. Definir notas armónicas de cada vagón
3. Definir qué vagón rompe el estilo completamente
4. Montar el primer escenario en Godot con Kive
5. Mecánicas básicas de movimiento y un enemigo simple

---

## 9. PREGUNTAS ABIERTAS

- ¿Qué vagón es el del apagón de Flai?
- ¿En qué vagón desbloquea Kive sus poderes Sensible?
- ¿Cuántos vagones en total?
- ¿Qué vagón rompe el estilo visual completamente?
- ¿Qué se ve por las ventanas cuando Len hace glitch en Flai?
- Notas armónicas de cada vagón

---

*v0.1 — iniciado en conversación con Claude, abril 2026*
*v0.2 — paleta definitiva, sistema armónico, vagón 1 definido, sistema de capas*
