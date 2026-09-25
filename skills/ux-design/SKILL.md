---
name: ux-design
description: "Experiencia de usuario: heurísticas de usabilidad, flujos, formularios, feedback, jerarquía."
---

# Experiencia de Usuario (UX)

> **Cuándo usar:** al diseñar o revisar un flujo, formulario, pantalla, onboarding o interacción; cuando un producto "funciona" pero se siente confuso, lento o frustrante; cuando hay que decidir jerarquía, copy de botones, manejo de errores o estados de carga; antes de construir cualquier pantalla nueva. Si el trabajo es visual (color, tipografía, tokens) usa **ui-design**; si es de acceso (teclado, ARIA, contraste) usa **accessibility**; si es de velocidad real usa **performance**. Este skill es sobre el COMPORTAMIENTO y la EXPERIENCIA.

La UX no es cómo se ve, es cómo FUNCIONA y cómo se SIENTE. Un producto bonito con un flujo malo es un producto malo. La regla que gobierna todo lo demás: **el usuario no es tú, no leyó tu documentación, no le importa tu arquitectura y quiere terminar su tarea e irse.** Diseña para eso.

---

## 1. Principios fundamentales

1. **No me hagas pensar** (Steve Krug). Cada pregunta que la interfaz obliga a resolver ("¿esto es clickeable?", "¿dónde estoy?", "¿qué hago ahora?") es fricción. Lo obvio no se explica: se ve.
2. **El diseñador NO es el usuario.** Tu fluidez con el producto es un sesgo. Lo que para ti es evidente, para el usuario nuevo es un muro. Valida, no asumas.
3. **Reducir la carga cognitiva es el trabajo.** Cada decisión, cada campo, cada opción consume energía mental finita. Menos es más rápido, más claro y menos propenso a error.
4. **El sistema siempre comunica su estado.** El usuario nunca debe preguntarse si algo pasó. Cada acción tiene una reacción visible.
5. **Prevenir el error vale más que manejarlo.** El mejor mensaje de error es el que nunca aparece porque el diseño impidió el error.
6. **Consistencia sobre creatividad.** Reinventar patrones establecidos (menús, formularios, carritos) es hacer trabajar al usuario. La familiaridad es usabilidad.
7. **El camino feliz debe ser obvio y corto.** El 80% de los usuarios hace lo mismo. Ese camino debe ser el más directo, sin callejones sin salida.
8. **Diseña para el contexto real de uso.** Móvil en la calle, con una mano, con prisa, con mala conexión. No para tu monitor de 27" con fibra.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Mostrar siempre el estado del sistema (carga, éxito, error) | Dejar al usuario adivinando si algo pasó |
| Usar patrones que el usuario ya conoce | Reinventar navegación o controles por "originalidad" |
| Minimizar campos, pasos y opciones | Formularios largos y menús con 20 opciones |
| Botones que dicen la acción ("Guardar cambios") | Botones genéricos ("Enviar", "OK", "Aceptar") |
| Validación inline con mensajes específicos | Validar todo al final con "Error en el formulario" |
| Ofrecer deshacer (undo) | Confirmaciones molestas en cada acción trivial |
| Confirmar solo acciones destructivas e irreversibles | Confirmar acciones reversibles o triviales |
| Etiquetas visibles siempre | Placeholder como única etiqueta (desaparece al escribir) |
| Estados vacíos que guían y enseñan | Pantallas vacías sin contexto ni siguiente paso |
| Targets táctiles grandes (mín. 44×44 px) | Enlaces diminutos pegados uno al otro |
| Feedback inmediato (optimistic UI, skeletons) | Spinner congelado sin señal de progreso |
| Diseñar el camino feliz primero | Optimizar casos raros antes que el flujo principal |
| Probar con usuarios reales | Asumir que "se entiende solo" |

---

## 3. Las 10 heurísticas de usabilidad de Nielsen

El estándar de facto para evaluar cualquier interfaz. Memorízalas: son un checklist mental permanente.

1. **Visibilidad del estado del sistema.** El sistema informa qué está pasando mediante feedback apropiado y a tiempo. (Carga, guardado, posición actual, progreso.)
2. **Correspondencia entre el sistema y el mundo real.** Habla el lenguaje del usuario, con conceptos y palabras que conoce; no jerga técnica interna. Orden lógico y natural.
3. **Control y libertad del usuario.** Salidas de emergencia claras: deshacer, rehacer, cancelar, volver. El usuario cometió un error y quiere salir sin drama.
4. **Consistencia y estándares.** Las mismas palabras y acciones significan lo mismo en todo el producto. Sigue convenciones de la plataforma (Ley de Jakob).
5. **Prevención de errores.** Mejor que un buen mensaje de error es un diseño que evita el error: restricciones, valores por defecto sensatos, confirmación en acciones peligrosas.
6. **Reconocer antes que recordar.** Haz visibles objetos, acciones y opciones. No obligues a memorizar información entre pantallas. Muestra, no escondas.
7. **Flexibilidad y eficiencia de uso.** Aceleradores para expertos (atajos, plantillas) que no estorban al novato. Permite personalizar acciones frecuentes.
8. **Diseño estético y minimalista.** Sin información irrelevante o rara vez necesaria. Cada elemento extra compite por atención y diluye lo importante.
9. **Ayudar a reconocer, diagnosticar y recuperarse de errores.** Mensajes en lenguaje claro (sin códigos), que indican el problema Y sugieren una solución.
10. **Ayuda y documentación.** Idealmente el sistema se usa sin ayuda, pero cuando se necesita: fácil de buscar, enfocada en la tarea, concreta y con pasos.

---

## 4. Leyes de UX clave

Principios de psicología cognitiva aplicados al diseño. Explican el PORQUÉ del comportamiento del usuario.

- **Ley de Fitts** — El tiempo para alcanzar un objetivo depende de su tamaño y distancia. **Objetivos importantes = grandes y cercanos.** Botones primarios amplios; acciones frecuentes al alcance del pulgar; destinos pequeños y lejanos son fricción. Los bordes y esquinas de pantalla son "infinitamente grandes" (el cursor se detiene ahí).
- **Ley de Hick** — El tiempo de decisión crece con el número y complejidad de opciones. **Menos opciones = decisión más rápida.** Reduce, agrupa, prioriza, usa progressive disclosure. Un menú de 5 vence a uno de 20.
- **Ley de Miller (7±2)** — La memoria de trabajo maneja ~7 elementos a la vez. **Agrupa (chunking):** teléfonos, pasos, categorías en bloques de 3-5. No es límite rígido de ítems en pantalla, es guía para no sobrecargar la memoria activa.
- **Ley de Jakob** — Los usuarios pasan la mayor parte del tiempo en OTROS sitios. **Esperan que el tuyo funcione igual que los que ya conocen.** Innovar en patrones básicos (dónde está el carrito, el login, el buscador) los cuesta. Innova en valor, no en convenciones.
- **Ley de proximidad (Gestalt)** — Los elementos cercanos se perciben como relacionados. **Usa el espacio para agrupar:** label pegada a su campo, acciones relacionadas juntas, separación entre grupos distintos. El espacio en blanco es una herramienta de estructura.
- **Efecto Von Restorff (aislamiento)** — El elemento que destaca es el que se recuerda y se clickea. **Un solo botón primario destacado por pantalla.** Si todo grita, nada resalta. Usa el énfasis con avaricia.
- **Efecto Zeigarnik** — Recordamos mejor las tareas incompletas. **Aprovéchalo:** barras de progreso, checklists de onboarding, "te falta 1 paso" motivan a completar. El cerebro odia lo inconcluso.
- **Ley de Tesler (conservación de la complejidad)** — Todo sistema tiene una complejidad irreducible. **La pregunta es quién la absorbe:** el sistema o el usuario. Buen diseño se traga la complejidad (defaults inteligentes, autocompletado) para que el usuario no la sufra.
- **Ley de Postel (robustez)** — Sé tolerante en lo que aceptas, estricto en lo que produces. **Acepta el teléfono con espacios, guiones o paréntesis; la fecha en varios formatos.** Normaliza tú, no exijas al usuario.
- **Ley de Doherty** — Bajo ~400 ms de respuesta, la productividad y la satisfacción se disparan. **La velocidad percibida es parte de la UX** (ver performance).

---

## 5. Carga cognitiva

La energía mental del usuario es un recurso finito y agotable. Gástala en la tarea, no en descifrar la interfaz.

- **Reduce las decisiones.** Cada opción, campo o pantalla es una micro-decisión. Elimina lo prescindible, ofrece defaults sensatos.
- **Progressive disclosure (revelación por etapas).** Muestra solo lo necesario para el paso actual; revela lo avanzado bajo demanda ("Opciones avanzadas", acordeones, wizard por pasos). No abrumes con todo de golpe.
- **No me hagas pensar (Krug).** Lo clickeable parece clickeable. Los títulos describen el contenido. La navegación dice dónde estoy. Si el usuario duda, ya perdiste.
- **Reconocer > recordar.** Muestra las opciones en vez de exigir que las recuerde. Autocompletado, historial reciente, valores previos.
- **Chunking.** Divide procesos largos en pasos digeribles con progreso visible. Un formulario de 30 campos en 4 pasos se siente mucho más ligero que uno solo.

---

## 6. Arquitectura de información (AI)

Cómo se organiza y etiqueta el contenido para que la gente lo encuentre.

- **Jerarquía visual clara.** Lo importante primero, más grande, arriba. El ojo debe saber por dónde empezar sin esfuerzo (enlaza ui-design).
- **Navegación consistente y predecible.** Misma ubicación, mismas etiquetas en todo el producto. El usuario aprende una vez.
- **Agrupación lógica.** Categorías que reflejan el modelo mental del USUARIO, no el organigrama de la empresa.
- **Wayfinding (orientación).** El usuario siempre sabe: dónde está (título, breadcrumb, estado activo), de dónde vino y a dónde puede ir. Nunca perdido.
- **Etiquetas honestas y descriptivas.** "Productos" no "Soluciones sinérgicas". Que la palabra diga exactamente qué hay detrás.
- **Regla práctica:** si el usuario no encuentra algo, para él NO EXISTE. La mejor función escondida es una función muerta.

---

## 7. Flujos de usuario

- **Minimiza pasos.** Cada pantalla y click extra pierde usuarios. Elimina, combina, precompleta. Pregúntate en cada paso: "¿es realmente necesario?".
- **Camino feliz claro y directo.** El recorrido más común debe ser el más obvio y sin obstáculos. Optimízalo primero.
- **Permite deshacer y volver.** Nunca atrapes al usuario. Botón atrás funcional, cancelar visible, deshacer disponible.
- **Evita callejones sin salida.** Toda pantalla final ofrece un siguiente paso ("Volver al inicio", "Crear otro", "Ver resultado"). Un resultado vacío o un error también debe ofrecer salida.
- **Reduce el time-to-value.** Cuanto antes el usuario logre algo útil, mejor. Difiere registros, configuraciones y fricciones hasta que aporten valor claro.
- **Confirma el progreso en flujos largos.** Wizard con pasos numerados y estado ("Paso 2 de 4").

---

## 8. Formularios

El formulario es donde más UX se gana o se pierde. Es fricción pura: minimízala.

- **Una sola columna.** El ojo baja en línea recta. Multi-columna rompe el flujo y confunde el orden de llenado (excepto pares lógicos como Ciudad/CP).
- **Etiquetas visibles y arriba del campo.** Nunca uses el placeholder como única etiqueta: desaparece al escribir, mata la accesibilidad y obliga a recordar qué se pedía.
- **Validación inline y a tiempo.** Valida al salir del campo (blur), no al enviar. Confirma en verde lo correcto; señala el error donde ocurre, no en un resumen lejano.
- **Mensajes de error útiles y específicos.** "La contraseña necesita al menos 8 caracteres" no "Entrada inválida". Di QUÉ pasó y CÓMO arreglarlo.
- **Agrupación lógica.** Campos relacionados juntos (datos personales / dirección / pago), separados por espacio (Ley de proximidad).
- **Minimiza campos.** Cada campo cuesta conversión. Pide solo lo imprescindible ahora; lo demás, después. ¿Necesitas de verdad el teléfono?
- **Autocompletado y `autocomplete` correcto.** Aprovecha datos del navegador (nombre, email, dirección, tarjeta). Ahorra tecleo y errores.
- **Indica los OPCIONALES, no los obligatorios.** Si la mayoría son requeridos, marca solo los opcionales ("Teléfono (opcional)"). Menos ruido de asteriscos.
- **Formato de entrada tolerante (Ley de Postel).** Acepta teléfono/tarjeta/fecha con o sin espacios y guiones; normaliza tú. No rechaces por un espacio.
- **Input types y teclados adecuados.** `type="email"`, `type="tel"`, `inputmode` numérico: el teclado móvil correcto es UX invisible.
- **Botón de envío claro y con la acción.** "Crear cuenta", "Pagar $49" — no "Enviar". Deshabilítalo/muestra loading al procesar para evitar doble envío.
- **Preserva lo escrito ante un error.** Nunca borres el formulario por un fallo de validación o de red. Eso es imperdonable.

---

## 9. Prevención de errores y acciones destructivas

- **Prevenir > mensaje de error.** Restringe entradas imposibles, deshabilita lo no disponible, usa defaults seguros, formatea mientras se escribe.
- **Confirmación SOLO para acciones destructivas e irreversibles** (borrar cuenta, eliminar datos). Confirmar todo entrena a ignorar los diálogos.
- **Undo mejor que confirm.** Para acciones reversibles, ejecuta de inmediato y ofrece "Deshacer" (toast de unos segundos). Es más ágil y menos molesto que un "¿Estás seguro?".
- **Diálogos destructivos honestos.** El botón dice la acción real ("Eliminar 3 archivos"), la acción peligrosa NO es la de default, y el color comunica el riesgo.
- **Escribe para confirmar lo grave.** Para lo irreversible de verdad (borrar un repositorio), pedir teclear el nombre evita el click accidental.

---

## 10. Feedback y affordances

- **Affordance = el elemento parece lo que hace.** Un botón parece presionable, un link parece clickeable, un campo parece editable. Si algo es interactivo, debe verse interactivo; si no lo es, no debe parecerlo (falsa affordance = frustración).
- **Feedback inmediato.** Todo click, hover, focus y toque tiene respuesta visible al instante. Estados: normal, hover, activo, focus, deshabilitado, cargando.
- **Estados de carga.** Prefiere **skeletons** (esqueleto del contenido) a spinners: comunican estructura y se sienten más rápidos. Para esperas largas, muestra progreso real, no un giro infinito.
- **Estados de éxito y error visibles.** Confirma que la acción funcionó (toast, check, cambio de estado). Si falló, dilo claro y ofrece reintentar.
- **Feedback proporcional.** Acción pequeña, feedback discreto (micro-animación); acción importante, confirmación clara.

---

## 11. Estados vacíos (empty states)

Una pantalla vacía no es un error: es una **oportunidad de onboarding**. El primer momento con una función suele ser un estado vacío.

- **Explica qué va aquí** y por qué está vacío ("Aún no tienes proyectos").
- **Da el siguiente paso obvio.** Un CTA claro ("Crear tu primer proyecto").
- **Enseña el valor.** Un ejemplo, una ilustración o una plantilla que muestre cómo se verá lleno.
- **Distingue vacío de error y de "sin resultados".** "No tienes pedidos" ≠ "Falló la carga" ≠ "Sin resultados para tu búsqueda" (ofrece limpiar filtros).

---

## 12. Onboarding y primera experiencia

- **Time-to-value primero.** Que el usuario logre el "momento ajá" cuanto antes. Difiere lo que estorbe a ese primer éxito.
- **Muestra, no cuentes.** Onboarding contextual (tooltips en el momento justo) vence a un tour de 8 modales que nadie lee.
- **Reduce fricción de arranque.** Login social, plantillas, datos de ejemplo precargados, "empezar sin registro". El registro puede esperar hasta que haya valor que proteger.
- **Progreso visible (Zeigarnik).** Checklist de configuración ("2 de 4 pasos") impulsa a completar.
- **No pidas permisos ni pagos antes de dar valor.** Ganarte el sí primero.

---

## 13. Microcopy

Las palabras SON interfaz. El copy guía, tranquiliza y convierte.

- **Claridad sobre ingenio.** Que se entienda gana a que suene listo. En la duda, sé literal.
- **Botones que dicen la acción concreta.** "Guardar cambios", "Enviar invitación", "Pagar $49" — no "Enviar", "OK", "Continuar" a secas. El botón describe lo que va a pasar.
- **Tono humano y consistente.** Ni robótico ni excesivamente gracioso. Adecuado al contexto: sobrio al reportar un error, cálido al felicitar.
- **Errores empáticos y accionables.** Sin culpar ("Ingresaste mal el dato" → "No encontramos esa cuenta, revisa el email"). Explica y ofrece salida.
- **Etiquetas y placeholders con propósito.** El placeholder da un EJEMPLO de formato ("juan@correo.com"), no reemplaza la etiqueta.
- **Escribe para escanear.** La gente no lee, barre. Frases cortas, verbos al frente, negritas con criterio.

---

## 14. Accesibilidad como parte de la UX

La accesibilidad no es un añadido: es UX para todos. Lo accesible suele ser más usable para cualquiera. **Ver el skill `accessibility` para el detalle técnico.** En clave UX:

- **Todo operable con teclado**, con foco visible y orden lógico. No solo por mouse/touch.
- **Contraste suficiente.** Texto legible es usabilidad, no estética.
- **Targets grandes** (Fitts + motricidad): benefician al que tiembla, al que va en el metro y a todos.
- **No dependas solo del color** para comunicar estado (error en rojo + ícono + texto).
- **Jerarquía semántica correcta** (headings, labels, roles): estructura para lectores de pantalla Y para el resto.
- **Respeta `prefers-reduced-motion`** y evita animaciones que mareen o distraigan.

---

## 15. UX móvil

El móvil tiene su propio contexto: una mano, en movimiento, con prisa, con interrupciones, con conexión variable.

- **Zona del pulgar.** Las acciones frecuentes van en la mitad inferior, alcanzables con el pulgar. Lo importante NO va arriba a la izquierda en pantallas grandes.
- **Targets táctiles ≥ 44×44 px** con separación suficiente. Nada de enlaces microscópicos pegados.
- **Gestos con descubribilidad.** Los gestos ocultos (swipe, long-press) son atajos, no la única vía; deben tener alternativa visible.
- **Minimiza el tecleo.** Teclados correctos por tipo de campo, autocompletado, selección sobre escritura, cámara/escáner cuando aplique.
- **Contexto de uso interrumpible.** El usuario se distrae: guarda el progreso, permite retomar, no castigues salir de la app.
- **Prioriza despiadadamente.** La pantalla pequeña obliga a jerarquizar. Un CTA primario claro por vista.

---

## 16. Rendimiento percibido

Lo que el usuario SIENTE de velocidad pesa tanto como el tiempo real (Ley de Doherty). **Ver el skill `performance` para optimización real.** Trucos de percepción:

- **Optimistic UI.** Refleja el resultado esperado de inmediato (el "like" se pinta ya) y reconcilia con el servidor detrás; revierte si falla.
- **Skeletons > spinners.** Muestran estructura y arrancan la lectura; se perciben más rápidos.
- **Feedback inmediato al toque.** La UI reacciona en el mismo frame aunque el dato tarde. La respuesta instantánea mata la sensación de lentitud.
- **Carga progresiva.** Muestra primero lo above-the-fold y lo crítico; difiere lo secundario. Contenido parcial vence a pantalla en blanco.
- **Ocupa la espera.** Barra de progreso, mensajes de estado o pasos ("Verificando pago…") hacen la espera más corta.

---

## 17. Consistencia y patrones establecidos

- **No reinventes lo básico.** Login, buscador, carrito, paginación, tablas: hay patrones probados. Úsalos (Ley de Jakob).
- **Sistema de patrones interno.** Los mismos componentes se comportan igual en todo el producto (enlaza ui-design y su design system).
- **Consistencia externa e interna.** Externa: parecerse a lo que el usuario ya conoce. Interna: coherencia dentro de tu propio producto.
- **Innova donde aportas valor, no en las convenciones.** La creatividad va en resolver el problema del usuario, no en dónde escondes el botón de guardar.

---

## 18. Métricas y research básico

**No asumas: valida.** El diseñador no es el usuario, y la opinión no es dato.

- **Pruebas de usabilidad.** 5 usuarios detectan ~el 85% de los problemas graves. Dales una tarea real y OBSERVA en silencio; no expliques ni guíes.
- **Pregunta comportamiento, no opinión.** "¿Qué harías aquí?" y mirar qué hacen vale más que "¿te gusta?".
- **Métricas de UX.** Tasa de éxito de tarea, tiempo hasta completar, tasa de error, abandono por paso (funnel), SUS, NPS, CSAT. Combina cuantitativo (qué pasa) con cualitativo (por qué).
- **Instrumenta los funnels.** Descubre dónde se caen los usuarios y ataca ese paso concreto.
- **Itera.** La UX no se "termina": se prueba, se mide y se mejora en ciclos.
- **A/B testing para decidir entre opciones**, no para reemplazar el entender POR QUÉ.

---

## Anti-patrones

Evítalos siempre. Muchos son **dark patterns**: engañan al usuario. Además de dañinos éticamente, destruyen la confianza y hoy muchos son ilegales.

**Dark patterns (prohibidos por ética):**
- **Confirmshaming.** Culpar al usuario por rechazar ("No, no quiero ahorrar dinero").
- **Roach motel.** Fácil entrar (suscribirse en 1 click), dificilísimo salir (cancelar por teléfono en horario hábil).
- **Costos ocultos / drip pricing.** Revelar cargos recién al final del checkout.
- **Preguntas con truco / doble negación** para confundir el opt-out.
- **Sneak into basket.** Agregar cosas al carrito sin que el usuario las pida.
- **Casillas premarcadas** para consentimiento o suscripciones.
- **Urgencia/escasez falsa.** Contadores y "solo quedan 2" inventados.
- **Nagging.** Pedir lo mismo (permisos, reseña) una y otra vez hasta rendir al usuario.

**Anti-patrones de usabilidad:**
- **Formularios larguísimos** que piden todo de golpe, sin dividir ni justificar campos.
- **Errores crípticos** ("Error 0x8007", "Entrada inválida") sin decir qué ni cómo arreglar.
- **Placeholder como etiqueta**: la instrucción desaparece al escribir.
- **Callejones sin salida:** pantallas de éxito/error/vacío sin siguiente paso.
- **Borrar lo escrito** por un error de validación o de red.
- **Confirmar todo:** entrena a ignorar diálogos y hace lento el uso.
- **Menús gigantes** que violan Hick sin agrupar ni priorizar.
- **Spinners infinitos** sin progreso ni contexto.
- **Botones genéricos** ("Enviar", "OK") que no dicen qué pasará.
- **Mystery meat navigation:** íconos sin etiqueta cuyo significado hay que adivinar.
- **Layout shift:** contenido que salta al cargar y provoca clicks erróneos.
- **Autoplay con sonido**, popups inmediatos y modales que tapan la tarea.
- **Reinventar patrones básicos** por "diferenciarse".

---

## Checklist de UX

Antes de dar por terminada una pantalla o flujo:

- [ ] El estado del sistema es siempre visible (carga, éxito, error, vacío)
- [ ] El camino feliz es obvio y toma los mínimos pasos posibles
- [ ] Cada acción tiene feedback inmediato y visible
- [ ] Hay salida en cada pantalla: volver, cancelar, deshacer (sin callejones sin salida)
- [ ] Las acciones destructivas se confirman; las reversibles ofrecen undo
- [ ] Los formularios: una columna, etiquetas visibles, mínimos campos, opcionales marcados
- [ ] La validación es inline, a tiempo, con mensajes específicos y accionables
- [ ] Lo escrito se preserva ante errores; input tolerante a formatos
- [ ] Los botones dicen la acción concreta ("Guardar cambios", no "Enviar")
- [ ] Los estados vacíos guían y enseñan el siguiente paso
- [ ] Un solo CTA primario destacado por vista (Von Restorff)
- [ ] La jerarquía visual dirige el ojo a lo importante primero
- [ ] La navegación es consistente y el usuario siempre sabe dónde está
- [ ] Se usan patrones conocidos; no se reinventa lo básico (Jakob)
- [ ] Targets táctiles ≥ 44×44 px, acciones clave en zona del pulgar (móvil)
- [ ] Operable con teclado, foco visible, contraste y semántica correctos (accessibility)
- [ ] Rendimiento percibido cuidado: skeletons, optimistic UI, carga progresiva (performance)
- [ ] Microcopy claro, humano y consistente; errores empáticos
- [ ] Sin dark patterns ni anti-patrones
- [ ] Validado con usuarios reales, no solo con la intuición del equipo

---

## Referencias

- **Nielsen Norman Group** (nngroup.com) — 10 Usability Heuristics; artículos de research y patrones.
- **Laws of UX** (lawsofux.com), Jon Yablonski — leyes de UX aplicadas al diseño.
- **Don't Make Me Think**, Steve Krug — usabilidad y sentido común.
- **The Design of Everyday Things**, Don Norman — affordances, señales, modelos mentales.
- **Refactoring UI**, Wathan & Schoger — decisiones prácticas de jerarquía y forma.
- **Form Design Patterns**, Adam Silver — formularios accesibles y usables.
- **WCAG / WAI** (w3.org/WAI) — accesibilidad (ver skill `accessibility`).
- **Deceptive Patterns** (deceptive.design), Harry Brignull — catálogo de dark patterns a evitar.

**Skills relacionados:** `ui-design` (jerarquía visual, tipografía, color, design system), `accessibility` (teclado, ARIA, contraste, semántica), `performance` (velocidad real que sostiene la percibida).
