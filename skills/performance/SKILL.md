---
name: performance
description: "Rendimiento: medir antes de optimizar, caché, Big-O, concurrencia, lazy loading, presupuestos."
---

# Rendimiento

> **Cuándo usar:** antes de optimizar cualquier código; cuando aparecen reportes de lentitud, alto uso de CPU/memoria, tiempos de respuesta elevados, timeouts o mala experiencia percibida; al diseñar sistemas con requisitos de latencia/throughput; al revisar consultas lentas, bundles grandes, Core Web Vitals pobres o costos de infraestructura que crecen sin control. Si no hay una MÉTRICA que mejorar, no estás optimizando: estás adivinando.

El rendimiento no es una fase final ni un adorno. Es una consecuencia de decisiones de diseño (algoritmos, estructuras de datos, límites de red, modelo de datos) tomadas mucho antes de que exista el primer perfilado. Este skill enseña el PORQUÉ para que optimices con evidencia, no con superstición.

---

## 1. Principios fundamentales

1. **Medir antes de optimizar.** No puedes mejorar lo que no mides. Toda optimización empieza con un número (línea base) y termina con otro número (después). Si no hay antes/después medibles, no hubo optimización: hubo fe.
2. **"La optimización prematura es la raíz de todos los males" (Knuth).** La cita completa importa: *"deberíamos olvidarnos de las pequeñas eficiencias, digamos el 97% del tiempo. Sin embargo, no debemos dejar pasar nuestras oportunidades en ese 3% crítico."* No es "nunca optimices"; es "optimiza el 3% que importa, con datos que te digan cuál es".
3. **Make it work → make it right → make it fast.** En ese orden. Código rápido pero incorrecto no sirve. Código correcto pero enredado no se puede optimizar con seguridad. Primero funciona, luego es limpio y correcto, y SOLO ENTONCES, si una métrica lo exige, se hace rápido.
4. **El cuello de botella casi nunca está donde crees.** La intuición humana sobre rendimiento es notoriamente mala. Por eso perfilamos: para que los datos, no el ego, señalen el punto caliente.
5. **La mejor optimización es no hacer el trabajo.** Eliminar una llamada, cachear un resultado, evitar un round-trip o no renderizar lo invisible vence a cualquier micro-truco de bajo nivel.
6. **Optimizar tiene un costo.** Complejidad, legibilidad, mantenibilidad y bugs. Cada optimización debe pagar ese costo con una mejora real y medida sobre una ruta que de verdad importa.

---

## 2. Reglas de oro

| Haz | Evita |
|-----|-------|
| Perfilar y medir antes de tocar código | Optimizar por intuición o "porque se siente lento" |
| Definir una línea base y un objetivo numérico | Optimizar sin criterio de "terminado" |
| Atacar primero el cuello de botella dominante (80/20) | Micro-optimizar código que se ejecuta rara vez (código frío) |
| Elegir el algoritmo/estructura correcta (Big-O) | Ganar 5% con trucos cuando un O(n²)→O(n) da 100x |
| Cachear con TTL e invalidación pensada | Cachear todo "por si acaso" y servir datos obsoletos |
| Medir en entorno representativo (datos reales) | Concluir a partir de un benchmark de juguete |
| Establecer presupuestos de rendimiento y vigilarlos en CI | Descubrir la regresión en producción por quejas de usuarios |
| Optimizar la ruta caliente (hot path) real | Reescribir en un lenguaje "más rápido" sin perfilar |
| Documentar el porqué de cada optimización no obvia | Dejar código críptico "por rendimiento" sin evidencia |

---

## 3. Metodología: perfilar y medir primero

El ciclo de optimización es un lazo disciplinado, no un impulso:

1. **Define la métrica objetivo.** Latencia p50/p95/p99, throughput (req/s), tiempo de CPU, memoria pico, tamaño de bundle, LCP. Sin métrica no hay meta.
2. **Establece la línea base.** Mide el estado actual en condiciones representativas (datos y volumen reales, red realista). Guarda el número.
3. **Perfila para hallar el cuello de botella real.** Usa un profiler; no adivines. Busca el punto caliente que domina el tiempo total.
4. **Aplica la regla 80/20 (Pareto).** El ~80% del tiempo suele vivir en el ~20% del código. Optimiza ESE 20%. Ignora el resto hasta que un perfil te diga lo contrario.
5. **Cambia una cosa.** Optimiza el cuello de botella dominante y solo ese. Cambiar varias cosas a la vez impide saber qué funcionó.
6. **Vuelve a medir.** Compara contra la línea base. ¿Mejoró la métrica objetivo en la ruta que importa? Si no, revierte.
7. **Repite** hasta cumplir el objetivo o alcanzar rendimientos decrecientes.

> **Percentiles > promedios.** El promedio esconde el dolor. Un p99 alto significa que 1 de cada 100 peticiones es horrible, y suelen ser tus usuarios más activos o tus cargas más grandes. Optimiza colas (tail latency), no medias.
>
> **Mide dónde ocurre.** Un profiler de laptop no representa producción. Reproduce volúmenes, latencias de red y concurrencia realistas, o usa APM sobre tráfico real.

---

## 4. Complejidad algorítmica (Big-O)

Antes que cualquier truco, la **elección del algoritmo y la estructura de datos** define el techo de rendimiento. Un cambio de O(n²) a O(n log n) hace irrelevante cualquier micro-optimización.

| Notación | Nombre | Ejemplo típico | Sensación al escalar |
|----------|--------|----------------|----------------------|
| O(1) | Constante | Acceso a hash/array por índice | Ideal: no crece |
| O(log n) | Logarítmica | Búsqueda binaria, índice B-tree | Excelente |
| O(n) | Lineal | Recorrer una lista una vez | Aceptable |
| O(n log n) | Linealítmica | Ordenamientos eficientes (merge/quick) | Buen límite para ordenar |
| O(n²) | Cuadrática | Bucles anidados, comparar todos con todos | Peligro con n grande |
| O(2ⁿ) | Exponencial | Fuerza bruta, recursión sin memoización | Inviable salvo n diminuto |
| O(n!) | Factorial | Permutaciones exhaustivas | Casi siempre inaceptable |

**Elegir la estructura correcta es media optimización:**

- **Hash map / diccionario** → búsqueda, inserción y borrado O(1) promedio. Convierte un `O(n)` de "buscar en lista" en `O(1)`.
- **Set** → pertenencia O(1) y deduplicación. Si haces `if x in lista` dentro de un bucle, tienes un O(n²) escondido: usa un set.
- **Árbol balanceado / índice ordenado** → rango y orden en O(log n).
- **Cola / pila / heap** → prioridades y procesamiento en orden sin re-ordenar todo.

> **Anti-patrón clásico:** buscar en una lista dentro de un bucle (`for x: if x in big_list`). Es O(n·m). Precarga un `set`/`dict` una vez y baja a O(n). Esto suele dar más ganancia que semanas de micro-tuning.

Cuidado con la asintótica engañosa: para `n` pequeño, un O(n²) con constante baja puede ganarle a un O(n log n) con overhead alto. Big-O describe crecimiento, no valores absolutos. Por eso: **mide**.

---

## 5. Caché

El caché es la optimización más poderosa y la más peligrosa: cambia trabajo por memoria y por el riesgo de servir datos obsoletos. *"Solo hay dos cosas difíciles en informática: la invalidación de caché y nombrar cosas."*

**Niveles (de más cerca del usuario a más cerca del dato):**

1. **Cliente / navegador** — memoria local, `Cache-Control`, `ETag`, service workers. El round-trip más barato es el que no ocurre.
2. **CDN / edge** — activos estáticos y respuestas cacheables servidas geográficamente cerca del usuario.
3. **Aplicación** — memoria del proceso o caché distribuida (Redis, Memcached) para resultados costosos: cómputos, respuestas de APIs, fragmentos renderizados.
4. **Base de datos** — caché de plan de consulta, buffer pool, vistas materializadas, `result cache`.

**Estrategias de escritura/lectura:**

- **Cache-aside (lazy loading):** la app consulta el caché; si falla (miss), lee la fuente, la guarda y la devuelve. Simple y común. Riesgo: primera petición lenta y posible *thundering herd* en expiración.
- **Write-through:** cada escritura va al caché y a la fuente sincrónicamente. Datos siempre consistentes en caché; escrituras algo más lentas.
- **Write-behind (write-back):** se escribe al caché y se persiste a la fuente de forma asíncrona. Escrituras rápidas; riesgo de pérdida si el caché cae antes de persistir.

**TTL (time to live):** toda entrada debe expirar. El TTL es el equilibrio entre frescura y tasa de aciertos. Datos volátiles → TTL corto; datos casi inmutables → TTL largo. Añade *jitter* al TTL para evitar que miles de claves expiren a la vez (estampida).

**Invalidación — el problema difícil:**

- **Por expiración (TTL):** simple, pero acepta ventanas de datos obsoletos.
- **Por evento:** invalida/actualiza la clave cuando el dato de origen cambia. Preciso, pero exige acoplar escrituras con el caché y es fácil olvidar una ruta de mutación.
- **Por versión / clave con hash de contenido:** cambia la clave cuando cambia el contenido (ideal para activos: `app.abc123.js`). Nunca sirves algo viejo porque la clave nueva no existía antes.

> **Regla:** define la estrategia de invalidación ANTES de añadir el caché. Un caché sin plan de invalidación es un generador de bugs de datos obsoletos que aparecerán en el peor momento. Y mide la **tasa de aciertos (hit ratio)**: un caché con 20% de aciertos añade complejidad sin ganancia.

---

## 6. Rendimiento de base de datos

La base de datos es el cuello de botella #1 en la mayoría de aplicaciones de backend. Ver también **database-design** para el modelado que evita estos problemas de raíz.

- **Problema N+1:** cargar N registros y luego lanzar una consulta por cada uno (1 + N consultas). Es el asesino silencioso de rendimiento en ORMs. Solución: *eager loading* / `JOIN` / carga por lotes (`WHERE id IN (...)`). Detéctalo revisando los logs de consultas bajo carga realista.
- **Índices:** un índice convierte un *full table scan* O(n) en una búsqueda O(log n). Indexa columnas usadas en `WHERE`, `JOIN` y `ORDER BY`. Pero los índices no son gratis: ralentizan escrituras y ocupan espacio. No indexes todo; indexa lo que las consultas lentas piden.
- **Consultas lentas:** usa `EXPLAIN`/`EXPLAIN ANALYZE` para ver el plan. Busca *full scans*, índices no usados, `SELECT *` innecesarios y funciones sobre columnas indexadas (anulan el índice).
- **Paginación:** nunca traigas todo. Paginación por *offset* (`LIMIT/OFFSET`) es simple pero degrada en páginas profundas (el motor descarta N filas). Para conjuntos grandes usa **keyset/cursor pagination** (`WHERE id > last_id LIMIT k`): rendimiento constante sin importar la profundidad.
- **Selecciona solo lo necesario:** `SELECT` de columnas concretas reduce I/O y memoria frente a `SELECT *`.
- **Connection pooling:** abrir conexiones es caro; reutilízalas con un pool dimensionado.

---

## 7. Concurrencia y asincronía

La primera pregunta ante una tarea lenta: **¿es I/O bound o CPU bound?** La respuesta determina la herramienta.

- **I/O bound** (red, disco, BD, APIs): el hilo espera, no calcula. La solución es **asincronía/concurrencia**: no bloquear mientras esperas. `async/await`, event loops, hilos que ceden el control. Ejecutar N llamadas de red en paralelo en vez de en serie puede dar una mejora de N×.
- **CPU bound** (cálculo, cifrado, compresión, procesamiento de imágenes): el hilo está ocupado calculando. La asincronía NO ayuda; necesitas **paralelismo real** en múltiples núcleos (procesos, worker threads, colas de trabajo, SIMD/GPU si aplica).

**Reglas prácticas:**

- **No bloquees el hilo principal / event loop.** En entornos de un solo hilo (Node.js, UI del navegador), una operación síncrona pesada congela TODO. Muévela a un worker o hazla asíncrona.
- **Batching (procesamiento por lotes):** agrupa muchas operaciones pequeñas en una grande. Una inserción de 1000 filas vence a 1000 inserciones. Una llamada que pide 100 IDs vence a 100 llamadas. Reduce overhead por operación y round-trips.
- **Paraleliza I/O independiente.** Si tres consultas no dependen entre sí, lánzalas juntas (`Promise.all`, `gather`, goroutines) en vez de secuencialmente.
- **Cuidado con la concurrencia:** condiciones de carrera, deadlocks y acceso a estado compartido. La velocidad no vale un bug de corrupción de datos. Prefiere inmutabilidad y aislamiento de estado.
- **Limita el paralelismo.** Concurrencia ilimitada satura conexiones, memoria y servicios aguas abajo. Usa pools/semáforos con límite.

---

## 8. Frontend

El rendimiento percibido por el usuario se juega en el navegador. Ver también **frontend-architecture**.

**Core Web Vitals** (métricas de experiencia real de Google):

- **LCP (Largest Contentful Paint):** tiempo hasta que el elemento principal es visible. Objetivo: **< 2.5 s**. Mejora con: servidor rápido, precarga del recurso crítico, imágenes optimizadas, menos JS bloqueante.
- **CLS (Cumulative Layout Shift):** cuánto "salta" el layout. Objetivo: **< 0.1**. Mejora reservando dimensiones para imágenes/anuncios/fuentes y evitando inserciones que empujen contenido.
- **INP (Interaction to Next Paint):** capacidad de respuesta a interacciones (reemplazó a FID). Objetivo: **< 200 ms**. Mejora reduciendo trabajo en el hilo principal y dividiendo tareas largas.

**Técnicas clave:**

- **Tamaño de bundle:** el JS es caro (descargar, parsear, ejecutar). Mídelo y ponle presupuesto. Cada KB de JS cuesta más que un KB de imagen.
- **Code splitting:** divide el bundle por ruta/componente; carga solo lo que la vista actual necesita.
- **Lazy loading:** difiere lo no crítico — componentes fuera de viewport, imágenes below-the-fold (`loading="lazy"`), rutas no visitadas.
- **Tree shaking:** elimina código muerto en el build. Importa solo lo que usas; evita `import * from`.
- **Imágenes optimizadas:** formatos modernos (WebP/AVIF), tamaño correcto (`srcset`), compresión, dimensiones explícitas (ayuda a CLS). Las imágenes suelen ser el mayor peso de la página.
- **Virtualización de listas:** renderiza solo las filas visibles de listas largas (windowing). Renderizar 10.000 filas en el DOM mata el rendimiento; renderiza ~20 y recicla.
- **Minimiza re-renders:** memoización, claves estables, evitar trabajo en cada frame.

---

## 9. Red

Cada round-trip cuesta latencia (a veces cientos de ms). La red es lenta y variable; trátala como recurso escaso.

- **Compresión:** activa **gzip** o mejor **brotli** en respuestas de texto (HTML, CSS, JS, JSON). Reduce el peso transferido drásticamente casi gratis.
- **CDN:** sirve activos y respuestas cacheables desde el edge, cerca del usuario. Menos distancia = menos latencia.
- **HTTP/2 y HTTP/3:** multiplexación (muchas peticiones sobre una conexión), compresión de headers y, en HTTP/3 (QUIC), menor impacto de pérdida de paquetes. Elimina la necesidad de trucos antiguos como *domain sharding*.
- **Minimiza round-trips:** agrupa peticiones, usa GraphQL/BFF para no hacer N llamadas, inlinea recursos críticos, aprovecha `preconnect`/`preload`.
- **Debounce y throttle:** controla eventos de alta frecuencia (scroll, resize, teclado, autocompletado).
  - **Debounce:** espera a que el usuario "pare" antes de actuar (ideal para búsqueda mientras escribe).
  - **Throttle:** ejecuta como máximo una vez cada X ms (ideal para scroll/resize).
- **Paginación y respuestas magras:** no transfieras datos que el cliente no usa.

---

## 10. Memoria

La memoria es un recurso finito, y su mal uso causa lentitud (GC agresivo, *paging*) y caídas (OOM).

**Fugas comunes (memory leaks):**

- **Listeners no removidos:** suscribirse a eventos/observables y no desuscribirse al destruir el componente.
- **Referencias no liberadas:** colecciones globales que crecen sin límite (cachés sin TTL/tamaño máximo, mapas que solo acumulan).
- **Closures que capturan objetos grandes** y viven más de lo esperado.
- **Timers/intervalos** (`setInterval`) que nunca se cancelan.
- **Referencias colgantes** en el DOM tras remover elementos.

**Trade-off espacio-tiempo:** con frecuencia cambias memoria por velocidad y viceversa. Cachear, memoizar y precalcular usan MÁS memoria para ganar tiempo. Streaming, paginación y procesamiento perezoso usan MENOS memoria a cambio de más cómputo o latencia. No hay respuesta universal: depende de si el recurso escaso es la RAM o el reloj.

> **Cuidado:** una tabla de memoización sin límite es una fuga con otro nombre. Toda estructura que crece con la entrada necesita un tope (LRU, tamaño máximo, TTL).

Instrumenta con métricas de memoria y observabilidad (ver **error-handling-observability**) para detectar crecimiento sostenido antes del OOM.

---

## 11. Presupuestos de rendimiento (performance budgets)

Un presupuesto es un límite numérico acordado que NO se debe superar. Convierte "rápido" (subjetivo) en un umbral verificable.

Ejemplos de presupuestos:

- Bundle JS inicial ≤ 170 KB comprimido.
- LCP ≤ 2.5 s en 4G / dispositivo de gama media.
- p95 de latencia de la API ≤ 300 ms.
- Consulta de BD en ruta caliente ≤ 50 ms.
- Máximo de N consultas por request.

**Seguimiento en CI:** el presupuesto solo sirve si se vigila automáticamente. Integra herramientas (Lighthouse CI, bundle analyzers, límites de tamaño, pruebas de carga) que **fallen el build** ante una regresión. Descubrir la lentitud en CI cuesta minutos; descubrirla en producción cuesta usuarios. Trata una regresión de rendimiento como un bug: bloquea el merge.

---

## 12. Escalado

Cuando la optimización de un nodo llega a su límite, se escala. Pero **primero optimiza**: escalar código ineficiente solo multiplica la factura del desperdicio.

- **Escalado vertical (scale up):** máquina más grande (más CPU/RAM). Simple, sin cambios de arquitectura, pero tiene techo físico y coste creciente, y suele implicar un punto único de fallo.
- **Escalado horizontal (scale out):** más máquinas en paralelo tras un balanceador. Sin techo práctico y con redundancia, pero exige diseño distribuido.
- **Statelessness:** el escalado horizontal REQUIERE servicios sin estado local. Guarda el estado (sesión, caché) en un almacén compartido (Redis, BD), no en la memoria del nodo. Un servidor con estado no se puede replicar ni reemplazar libremente.
- **Colas para desacoplar picos:** ante ráfagas de carga, encola el trabajo y procésalo a ritmo sostenible en vez de saturar el sistema. La cola absorbe el pico (buffering) y desacopla productor de consumidor, mejorando resiliencia y suavizando la demanda. Ideal para tareas no interactivas (emails, informes, procesamiento).
- **Aguas abajo (downstream):** escalar el frontend no ayuda si la BD es el cuello. Escala el recurso limitante real, identificado por perfilado.

---

## 13. Anti-patrones de optimización

- **Optimizar sin medir:** cambiar código "porque debería ser más rápido". Sin línea base es imposible saber si mejoró o empeoró.
- **Micro-optimización prematura:** pelear por nanosegundos (`++i` vs `i++`, elegir el bucle "más rápido") mientras un N+1 o un O(n²) domina el tiempo. Ganas 0.1% y pierdes legibilidad.
- **Optimizar código frío:** acelerar una función que se ejecuta una vez al día. Esfuerzo en la ruta equivocada; concéntrate en la caliente.
- **Cachear todo:** añadir caché en todas partes multiplica bugs de invalidación y datos obsoletos. Cachea lo costoso y repetido, con hit ratio medido.
- **Reescribir en un lenguaje "más rápido"** sin perfilar: casi siempre el problema es el algoritmo o el I/O, no el lenguaje. Un O(n²) es lento en cualquier lenguaje.
- **Benchmarks de juguete:** medir con 10 registros y concluir para 10 millones. La asintótica y los efectos de caché/BD solo aparecen con datos realistas.
- **Sacrificar corrección por velocidad:** un resultado rápido pero incorrecto no vale nada. `make it right` va antes que `make it fast`.
- **Complejidad opaca "por rendimiento":** dejar código críptico sin comentario ni evidencia de que ganó algo. Si no lo mediste, probablemente no ganaste nada y sí perdiste mantenibilidad.

---

## 14. Herramientas de profiling por stack

No memorices herramientas; conoce las CATEGORÍAS y busca la del stack:

- **Profilers de CPU/memoria:** muestran dónde se gasta el tiempo y la memoria (flame graphs, sampling). Cada lenguaje tiene el suyo (perfiladores de CPU/heap, `--prof`, samplers nativos).
- **APM (Application Performance Monitoring):** trazas distribuidas, latencias p50/p95/p99, mapas de dependencias en producción sobre tráfico real (Datadog, New Relic, OpenTelemetry, Sentry). Complementa la observabilidad de **error-handling-observability**.
- **Frontend / web:** Lighthouse y Chrome DevTools (Performance, Coverage), WebPageTest, y RUM (Real User Monitoring) para Core Web Vitals con usuarios reales.
- **Base de datos:** `EXPLAIN ANALYZE`, logs de consultas lentas, monitores de plan de ejecución.
- **Análisis de bundle:** analizadores de tamaño de bundle y límites de tamaño (size-limit) en el build.
- **Pruebas de carga:** generadores de carga (k6, JMeter, Locust) para medir throughput y latencia bajo estrés y validar presupuestos.

Regla: usa datos de producción o lo más cercano posible. Un profiler local es una hipótesis; el APM sobre tráfico real es la verdad.

---

## Anti-patrones comunes

- No definir una métrica objetivo antes de empezar ("optimizar" sin destino).
- Confundir promedio con experiencia real; ignorar p95/p99 y la *tail latency*.
- Buscar dentro de un bucle en listas en vez de usar `set`/`dict` (O(n²) oculto).
- Dejar N+1 en el ORM sin revisar los logs de consultas.
- Cachés sin TTL ni política de invalidación → datos obsoletos y fugas de memoria.
- Bloquear el event loop / hilo principal con trabajo pesado síncrono.
- Enviar bundles enormes sin code splitting ni tree shaking.
- Renderizar listas de miles de elementos sin virtualización.
- No comprimir respuestas de texto ni usar CDN para activos.
- Escalar horizontalmente un servicio con estado local.
- No tener presupuestos de rendimiento ni vigilancia en CI (la regresión llega a producción).

---

## Checklist de rendimiento

- [ ] Hay una métrica objetivo clara y numérica (latencia, throughput, LCP, memoria...).
- [ ] Se estableció una línea base en condiciones representativas.
- [ ] Se perfiló para identificar el cuello de botella REAL antes de tocar código.
- [ ] Se aplicó la regla 80/20: se atacó el punto caliente dominante.
- [ ] Se revisó la complejidad Big-O y las estructuras de datos elegidas.
- [ ] No hay búsquedas O(n²) evitables ni problemas N+1 en la BD.
- [ ] Las consultas lentas tienen índices adecuados (verificado con EXPLAIN).
- [ ] La paginación usa keyset/cursor para conjuntos grandes.
- [ ] El caché tiene TTL y una estrategia de invalidación definida; se mide el hit ratio.
- [ ] Las tareas I/O bound son asíncronas/paralelas; las CPU bound no bloquean el hilo principal.
- [ ] Se usa batching para operaciones repetidas.
- [ ] Frontend: Core Web Vitals dentro de objetivo (LCP < 2.5 s, CLS < 0.1, INP < 200 ms).
- [ ] Bundle con code splitting, lazy loading y tree shaking; imágenes optimizadas.
- [ ] Listas largas virtualizadas.
- [ ] Respuestas comprimidas (brotli/gzip); activos por CDN; HTTP/2-3 activo.
- [ ] Sin fugas de memoria (listeners, timers, cachés sin tope revisados).
- [ ] Presupuestos de rendimiento definidos y vigilados en CI.
- [ ] El escalado planificado es coherente (statelessness para horizontal; colas para picos).
- [ ] Cada optimización no obvia está medida (antes/después) y documentada.

---

## Referencias

- web.dev — Core Web Vitals (LCP, CLS, INP): https://web.dev/vitals/
- MDN — Performance y Web Performance: https://developer.mozilla.org/en-US/docs/Web/Performance
- Google Lighthouse / PageSpeed Insights: https://developer.chrome.com/docs/lighthouse
- Donald Knuth — *Structured Programming with go to Statements* (origen de la cita sobre optimización prematura).
- Brendan Gregg — *Systems Performance* y metodología USE (Utilization, Saturation, Errors) para análisis de recursos.
- Martin Fowler — patrones de caché y refactorización de rendimiento: https://martinfowler.com/
- OpenTelemetry — observabilidad y trazas: https://opentelemetry.io/

**Skills relacionados:** `database-design` (modelado, índices, N+1 desde el diseño), `frontend-architecture` (bundles, rendering, arquitectura de UI), `error-handling-observability` (métricas, trazas y detección de regresiones en producción).
