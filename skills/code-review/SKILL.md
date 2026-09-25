---
name: code-review
description: "Revisión de código: qué mirar, tamaño de PR, feedback con criterio, checklist de revisor."
---

# Revisión de Código

> **Cuándo usar:** al abrir un Pull Request como autor, al recibir uno para revisar, al definir la política de revisión de un equipo, o cuando una revisión se estanca (feedback interminable, PRs que no avanzan, discusiones de estilo). Aplica tanto si revisás código humano como generado por IA.

La revisión de código NO es un trámite ni una aduana. Es el punto donde el código mejora y donde el conocimiento se difunde por el equipo. Si la tratás como una formalidad, perdés las dos cosas.

---

## 1. Principios fundamentales

Tres ideas gobiernan todo lo demás. Si internalizás esto, el resto son detalles.

1. **La revisión mejora el código Y difunde conocimiento.** Un buen review deja el código mejor de lo que estaba Y hace que dos personas (autor y revisor) entiendan mejor el sistema. Si solo buscás "cazar bugs", estás usando la mitad de la herramienta. La revisión es el mecanismo más barato que tiene un equipo para propagar contexto, patrones y estándares.

2. **Se revisa el CÓDIGO, no a la persona.** "Esta función hace demasiadas cosas" es feedback sobre código. "Siempre escribís funciones enormes" es un ataque a la persona. La diferencia no es cosmética: define si el equipo se atreve a abrir PRs o los esconde. La seguridad psicológica es un requisito técnico, no un lujo.

3. **El objetivo es correctitud y mantenibilidad, NO perfección.** El listón es: *¿este cambio mejora la salud del código a largo plazo?* No: *¿es exactamente como yo lo habría escrito?* Un PR que mejora el sistema debe aprobarse aunque no sea perfecto. La perfección es enemiga del flujo y del equipo. Aprobás lo "suficientemente bueno" y dejás las mejoras opcionales como sugerencias.

---

## 2. Reglas de oro

| Haz ✅ | Evita ❌ |
|--------|----------|
| Revisar rápido (en horas, no días) | Dejar PRs esperando y bloquear al equipo |
| Entender el PORQUÉ antes de criticar | Opinar sin leer la descripción ni el contexto |
| Distinguir bloqueadores de nits | Tratar todo con la misma urgencia |
| Proponer una alternativa concreta | Solo señalar el problema y desaparecer |
| Marcar lo menor como `nit:` | Bloquear un merge por una preferencia de estilo |
| Elogiar lo que está bien resuelto | Comentar solo lo negativo |
| Aprobar cuando está "suficientemente bueno" | Exigir que el código sea idéntico al tuyo |
| Automatizar lint/formato/tests en CI | Discutir a mano cosas que una máquina resuelve |
| Hacer preguntas cuando no entendés | Asumir mala intención o incompetencia |
| PRs pequeños y enfocados | PRs gigantes de "todo junto" |

---

## 3. Qué revisar, por prioridad

Revisá en este orden. El tiempo y la energía son finitos: gastalos primero donde más importa. Un nit de nombres no vale nada si hay un bug de lógica sin detectar.

1. **Correctitud y lógica.** ¿El código hace lo que dice? ¿Casos borde (nulos, vacíos, límites, concurrencia)? ¿Errores manejados o tragados? ¿Condiciones de carrera? Esto es lo primero SIEMPRE.
2. **Diseño / arquitectura y encaje con el sistema.** ¿Este cambio pertenece acá? ¿Respeta las capas y los límites (ver `refactoring`)? ¿Introduce acoplamiento innecesario o duplica algo que ya existe? ¿La abstracción es la correcta o está sobre/infra-diseñada?
3. **Seguridad.** Entrada validada, secretos fuera del código, autorización correcta, inyección/SSRF/XSS según el dominio. Ante cambios sensibles, aplicá `security` como checklist dedicado.
4. **Tests.** ¿Existen? ¿Prueban COMPORTAMIENTO y no implementación? ¿Cubren los casos borde del punto 1? Un PR sin tests para lógica nueva es, por defecto, un bloqueador. Ver `testing`.
5. **Legibilidad y nombres.** ¿Se entiende sin que el autor lo explique? ¿Los nombres dicen la intención? El código se lee muchas más veces de las que se escribe.
6. **Rendimiento donde importe.** N+1, loops anidados sobre datos grandes, allocaciones en caliente. Solo donde el perfil real lo justifique; no optimices por superstición.
7. **Estilo.** Que lo haga el LINTER, no el humano. Si estás comentando indentación o comillas a mano, tu equipo tiene un problema de tooling, no de revisión.

> Regla mental: cuanto más arriba en esta lista, más justificado está bloquear. Cuanto más abajo, más debería ser un `nit:` o una sugerencia opcional.

---

## 4. Tamaño del PR

El tamaño del PR es el factor más subestimado de una buena revisión. **Los PRs pequeños se revisan mejor.** No es opinión: la efectividad de la detección de defectos cae de forma pronunciada a medida que crece el diff. Pasadas unas ~400 líneas, la atención del revisor se degrada y empieza el "scroll y LGTM".

- **Apuntá a menos de ~400 líneas** de cambio real (sin contar generados/lockfiles).
- Un PR debe hacer **una cosa**. "Refactor + feature + fix" en un solo PR es tres revisiones fingiendo ser una.
- Si el PR es enorme, **es legítimo pedir que se divida** antes de revisarlo. No es pereza: es proteger la calidad de la revisión. Ver `chained-pr` para partir un cambio grande en una cadena de PRs revisables.
- Diez PRs de 40 líneas se revisan mejor y más rápido que uno de 400. Además, cada uno entra a `main` antes y reduce el riesgo de merge.

> Si como autor no podés explicar tu PR en dos o tres frases, probablemente hace demasiadas cosas.

---

## 5. Responsabilidades del AUTOR

La calidad de una revisión empieza antes de que el revisor la toque. Un buen autor le ahorra trabajo al revisor.

- **Auto-revisá PRIMERO.** Leé tu propio diff completo antes de pedir revisión, como si fuera de otra persona. Vas a encontrar la mitad de los problemas vos mismo: prints olvidados, código muerto, nombres pobres, un TODO que no debería estar.
- **PR pequeño y enfocado.** Una intención por PR (ver sección 4). Si mientras trabajabas encontraste otra cosa para arreglar, abrí un PR aparte.
- **Descripción con contexto.** Respondé tres cosas: *qué* cambia, *por qué* (el problema que resuelve, enlazá el issue), y *cómo probarlo*. El "por qué" es lo que el diff NO puede contar por sí solo. Ver `git-workflow` para convenciones de commits y PRs.
- **CI en verde ANTES de pedir revisión.** No hagas que un humano descubra lo que la máquina ya sabía. Pedir revisión con tests rojos quema el tiempo del revisor.
- **Respondé a TODOS los comentarios.** Aunque sea con un "hecho" o un "prefiero dejarlo así porque…". Un comentario sin respuesta deja la revisión en un limbo. No cierres hilos ajenos: eso lo hace quien comentó.
- **Asumí la mejor intención del revisor.** Un comentario duro casi nunca es un ataque; es alguien que quiere que el código salga mejor.

---

## 6. Responsabilidades del REVISOR

- **Revisá rápido.** La latencia de revisión es un impuesto sobre TODO el equipo. Un PR bloqueado detiene a una persona y, en cadena, a más. Objetivo: primer pase en horas, no días. Si no podés hacerlo completo ya, dejá al menos una señal ("lo miro esta tarde").
- **Entendé el PORQUÉ antes de criticar.** Leé la descripción y el issue. Muchas "objeciones" se disuelven cuando entendés la restricción que el autor ya consideró.
- **Distinguí bloqueadores de nits** (ver sección 8). No trates una preferencia de nombres con la misma urgencia que un bug de seguridad.
- **Proponé, no solo señales.** "Esto está mal" es ruido. "Esto falla con lista vacía; ¿un guard clause al inicio?" es ayuda. Si señalás un problema, ofrecé una dirección.
- **Aprobá cuando esté "suficientemente bueno".** No retengas una aprobación por mejoras opcionales. Aprobá y marcá lo demás como `nit:` o sugerencia. Bloquear es un acto serio; reservalo para problemas reales de correctitud, diseño, seguridad o tests faltantes.
- **No secuestres el PR.** No conviertas el cambio de otro en tu visión personal del código. Tu trabajo es evaluar si mejora el sistema, no reescribirlo mentalmente.

---

## 7. Cómo dar feedback

El feedback es donde la revisión se vuelve cultura. El mismo problema técnico, comunicado de dos formas, produce dos equipos distintos. Ver `comment-writer` para el tono; acá va el criterio.

- **Amable Y directo.** No son opuestos. Sé claro sobre el problema y cálido con la persona. Suavizar tanto que el problema se pierde no ayuda a nadie.
- **Siempre el PORQUÉ técnico.** "Cambiá esto" enseña obediencia. "Cambiá esto porque este `map` reasigna en cada render y rompe la memoización" enseña un concepto. El PORQUÉ es lo que hace crecer al equipo.
- **Ejemplos y sugerencias concretas.** Un bloque de código o una sugerencia aplicable vale más que tres párrafos abstractos.
- **Preguntas en vez de órdenes** cuando corresponda. "¿Consideraste extraer esto a una función?" invita a pensar. "Extraé esto" cierra la conversación. Usá la orden solo cuando de verdad no hay alternativa.
- **Marcá los nitpicks como `nit:`.** Esa etiqueta le dice al autor "esto es menor, decidís vos". Sin ella, todo comentario parece un bloqueador. Adoptá convenciones tipo Conventional Comments (`nit:`, `question:`, `suggestion:`, `issue:`, `praise:`).
- **Elogiá lo bueno.** "Buena solución para el caso concurrente" no es adulación: refuerza el patrón que querés ver más seguido y equilibra la conversación. Un review que solo señala lo malo desgasta.

---

## 8. Distinguir el peso de cada comentario

La causa número uno de revisiones tóxicas o eternas es tratar todo con la misma gravedad. Etiquetá explícitamente:

| Tipo | Significado | ¿Bloquea el merge? |
|------|-------------|--------------------|
| **Bloqueador** (`issue:`) | Bug, fallo de diseño, hueco de seguridad, test faltante para lógica nueva | **Sí** — debe arreglarse |
| **Sugerencia** (`suggestion:`) | Una mejora real pero opcional; el código funciona sin ella | No — decide el autor |
| **Nit** (`nit:`) | Detalle menor: nombre, orden, comentario | No — casi siempre lo decide el autor |
| **Pregunta** (`question:`) | No entendés algo o querés confirmar una decisión | No por sí sola — puede revelar un bloqueador |

Si el 90% de tus comentarios son nits, el problema está en el tooling (configurá el linter) o en la altitud de tu revisión (estás mirando el árbol y perdiendo el bosque).

---

## 9. Automatizá lo automatizable

La revisión humana es cara y valiosa. NO la gastes en lo que una máquina hace mejor.

- **Lint y formato** → linter + formateador en CI (y en pre-commit).
- **Tests** → suite en CI, obligatoria para mergear.
- **Análisis estático / tipos / seguridad básica** → en el pipeline.

Todo lo que un check automatizado puede atrapar, NO debería aparecer nunca en un comentario humano. Cuando la máquina cubre estilo, formato y regresiones, el humano queda libre para lo que solo el humano ve: diseño, intención, correctitud sutil, encaje con el sistema. Ver `git-workflow` para integrar estos gates.

---

## 10. Velocidad y flujo

- **Revisá en horas, no en días.** La revisión rápida no es un favor: mantiene al equipo en movimiento y reduce el costo de cambio de contexto del autor.
- **Revisiones pequeñas y frecuentes** superan a las grandes y esporádicas. Un flujo constante de PRs chicos mantiene la deuda de revisión baja.
- Un primer pase rápido con "voy a mirarlo en detalle a la tarde, pero a primera vista bien" desbloquea psicológicamente al autor aunque la revisión completa venga después.
- Si vas a estar ausente, redirigí tus revisiones. Un PR no debería esperar a una sola persona.

---

## 11. Seguridad y tests en el checklist

No son "otra revisión": son parte de ESTA.

- **Seguridad:** validación de entrada, manejo de secretos, autorización, dependencias con CVEs, superficies de inyección. Ante código de auth, pagos, datos sensibles o límites de confianza, aplicá `security` como paso dedicado y no lo trates como opcional.
- **Tests:** ¿el PR incluye tests para el comportamiento nuevo o cambiado? ¿Prueban comportamiento observable y no detalles internos? ¿Fallan si rompés la lógica a propósito? Ver `testing`. Lógica nueva sin tests es, por defecto, bloqueador.

---

## 12. Cultura de revisión

La técnica sin cultura produce equipos que temen abrir PRs. Cuidá esto tan deliberadamente como cuidás el código.

- **Seguridad psicológica.** La gente tiene que poder abrir código imperfecto sin miedo a la humillación. Un equipo que esconde su trabajo del review es un equipo que dejó de aprender.
- **Asumí buena intención** en ambas direcciones. El autor no fue vago; el revisor no te ataca. Casi siempre es cierto, y actuar como si lo fuera baja el conflicto a la mitad.
- **La revisión es aprendizaje MUTUO.** El revisor senior también aprende del PR que revisa. Nadie tiene el monopolio del contexto. Un junior puede detectar algo que un senior pasó por alto.
- Rotá quién revisa. Concentrar toda la revisión en una persona crea un cuello de botella y un único punto de conocimiento.

---

## 13. Self-merge: cuándo sí, cuándo NO

- **Regla por defecto: al menos una aprobación de otra persona** antes de mergear. El valor de la revisión está justamente en el otro par de ojos; auto-aprobarte lo anula.
- **Quién debe aprobar:** alguien con contexto del área tocada. Para código sensible (auth, pagos, infra, migraciones), sumá a quien tenga ownership de esa zona.
- **Self-merge aceptable solo** para casos triviales y de bajo riesgo con política explícita del equipo: revertir un cambio propio recién roto, un typo en un doc, un bump mecánico. Fuera de eso, esperá la aprobación aunque duela la latencia. La prisa no justifica saltarse el control.

---

## 14. Anti-patrones comunes

- **PRs gigantes.** El pecado original. Garantiza revisiones superficiales. → PRs pequeños; ver `chained-pr`.
- **Feedback destructivo.** Sarcasmo, condescendencia, atacar a la persona. Rompe el equipo y no arregla el código. → Amable y directo, sobre el código.
- **Bikeshedding.** Discutir infinitamente el color del cobertizo (nombres triviales, comillas) mientras el reactor nuclear pasa sin revisar. → Prioridad (sección 3) y `nit:`.
- **Bloquear por estilo.** Retener un merge por una preferencia personal que el linter ni siquiera marca. → Automatizá o marcá como `nit:`.
- **"LGTM" sin leer.** Aprobar para sacarse el PR de encima. Es peor que no revisar: da una falsa sensación de control. → Si no tenés tiempo de leerlo, no lo apruebes.
- **Nitpicking infinito.** Ronda tras ronda de detalles minúsculos que impiden mergear algo ya correcto. → Aprobá con nits; el autor decide.
- **Revisor fantasma.** Comentar un problema y desaparecer, dejando el PR colgado sin resolución. → Respondé y cerrá tus hilos.
- **Reescribir mentalmente el PR ajeno.** Exigir que el código sea idéntico al que vos habrías escrito. → El listón es "mejora el sistema", no "es mi versión".

---

## 15. Checklist del revisor

- [ ] Leí la descripción y entiendo el PORQUÉ del cambio
- [ ] **Correctitud:** la lógica es correcta y maneja los casos borde (nulos, vacíos, límites, concurrencia)
- [ ] **Diseño:** el cambio encaja en el sistema, respeta capas y no duplica lo existente
- [ ] **Seguridad:** entrada validada, sin secretos, autorización correcta (`security` si aplica)
- [ ] **Tests:** existen para el comportamiento nuevo/cambiado y prueban comportamiento, no implementación
- [ ] **Legibilidad:** los nombres dicen la intención y el código se entiende sin explicación oral
- [ ] **Rendimiento:** sin problemas evidentes donde el volumen lo justifica (N+1, loops calientes)
- [ ] El tamaño del PR es razonable (< ~400 líneas); si no, pedí dividirlo
- [ ] Etiqueté cada comentario por peso (bloqueador / sugerencia / `nit:` / pregunta)
- [ ] Di el PORQUÉ técnico y propuse alternativas, no solo señalé
- [ ] Elogié al menos lo que está bien resuelto
- [ ] Aprobé si está "suficientemente bueno"; no retuve por mejoras opcionales

## 16. Checklist del autor antes de pedir revisión

- [ ] Me auto-revisé el diff completo como si fuera de otra persona
- [ ] El PR hace UNA sola cosa y está enfocado
- [ ] El tamaño es pequeño (< ~400 líneas de cambio real); si no, lo partí (`chained-pr`)
- [ ] La descripción responde qué, por qué (con issue enlazado) y cómo probar
- [ ] CI está en verde (lint, tests, tipos)
- [ ] Agregué/actualicé tests para el comportamiento nuevo o cambiado
- [ ] No quedó código muerto, prints de debug ni TODOs sin sentido
- [ ] Los commits siguen la convención del equipo (`git-workflow`)
- [ ] Elegí revisor(es) con contexto del área tocada

---

## 17. Referencias

- **Google Engineering Practices — Code Review** (`google.github.io/eng-practices`): el estándar de referencia. Clave: aprobar cuando el cambio mejora la salud del código, no cuando es perfecto; y priorizar la velocidad de revisión.
- **Conventional Comments** (`conventionalcomments.org`): etiquetas (`nit:`, `suggestion:`, `issue:`, `question:`, `praise:`) para comunicar el peso de cada comentario sin ambigüedad.

**Skills relacionadas:** `git-workflow` (commits, PRs, gates de CI) · `testing` (tests que prueban comportamiento) · `security` (revisión de seguridad dedicada) · `refactoring` (diseño, capas y acoplamiento) · `chained-pr` (partir PRs grandes) · `comment-writer` (tono del feedback).
