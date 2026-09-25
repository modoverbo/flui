---
name: error-handling-observability
description: "Manejo de errores, logging estructurado, métricas, trazas, alertas y resiliencia."
---

# Manejo de Errores y Observabilidad

> **Cuándo usar:** cuando diseñes o revises cómo un sistema falla y cómo lo observás. Dispara con: capturar/propagar excepciones, decidir entre excepción y `Result`, agregar reintentos/timeouts/circuit breakers, definir qué y cómo loggear, instrumentar métricas o trazas, diseñar health checks, configurar alertas/SLOs, o depurar un incidente donde "no sabemos qué pasó". Si estás escribiendo un `try/catch`, un log o un dashboard, esta skill aplica.

El error handling y la observabilidad son la MISMA disciplina vista desde dos ángulos: uno decide qué pasa cuando algo se rompe, el otro te permite enterarte. Un sistema que maneja errores pero no es observable falla en silencio; uno observable que no maneja errores te avisa mientras se cae. Necesitás los dos.

---

## 1. Principios fundamentales

Estos cuatro principios no se negocian. Todo lo demás son tácticas para cumplirlos.

1. **Fail fast en los bordes.** Validá y rechazá lo inválido lo antes posible, en la frontera del sistema (entrada de API, borde del dominio, deserialización). Un dato malo que entra profundo es un bug que explota lejos de su causa. Fallar temprano acorta la distancia entre el síntoma y el origen.

2. **Falla de forma segura (fail-safe / fail-secure).** Cuando algo se rompe, el estado por defecto debe proteger al usuario, a los datos y al sistema. Ante la duda, denegá el acceso, no cobres dos veces, no borres. Un fallo nunca debe dejar el sistema en un estado peor que apagado.

3. **Un error nunca se traga en silencio.** Cada error se maneja, se propaga con contexto, o se registra deliberadamente. El `catch {}` vacío es el pecado capital: convierte un fallo en un fantasma que vas a perseguir semanas después sin ninguna pista.

4. **Todo lo que corre en producción debe ser observable.** Si no podés responder "¿qué está pasando ahora?" y "¿por qué falló esto?" con los datos que ya emitís, no está listo para producción. La observabilidad no es un extra que se agrega después del incidente; es un requisito de diseño.

**El PORQUÉ:** los sistemas distribuidos no fallan de forma limpia. Fallan parcialmente, intermitentemente, bajo carga, a las 3 AM. No podés predecir el fallo exacto, pero SÍ podés diseñar para que cuando ocurra sea (a) contenido, (b) seguro y (c) visible. Eso es lo que separa un incidente de 5 minutos de uno de 5 horas.

---

## 2. Reglas de oro

| Haz | Evita |
|-----|-------|
| Validar en la frontera y fallar rápido | Dejar que datos inválidos penetren el dominio |
| Distinguir errores esperados de inesperados | Tratar un `email inválido` igual que un `NullPointerException` |
| Propagar el error con contexto adicional | Re-lanzar el error pelado o tragarlo |
| Loggear una vez, en el nivel donde se decide | Loggear-y-relanzar en cada capa (log duplicado) |
| Timeout en TODA llamada de red | Esperar infinito a un servicio caído |
| Reintentar solo operaciones idempotentes | Reintentar un `POST /pago` y cobrar tres veces |
| Backoff exponencial + jitter | Reintentar en bucle inmediato (thundering herd) |
| Logging estructurado (JSON, clave-valor) | `print("error: " + e)` sin contexto ni estructura |
| Correlacionar logs, métricas y trazas por `trace_id` | Tres silos que no se pueden cruzar |
| Mensaje útil al usuario, detalle al log | Volcar el stack trace en la pantalla del usuario |
| Alertar sobre síntomas (SLO violado) | Alertar sobre cada pico de CPU o cada excepción |
| Postmortems sin culpa | Buscar al culpable en vez de al fallo del sistema |
| Limpiar recursos en `finally`/`using`/`defer` | Fugar conexiones/handles cuando algo lanza |

---

## Manejo de errores

### Errores esperados vs inesperados: tratalos distinto

Esta es la distinción más importante y la que más se ignora.

- **Errores esperados** (de negocio o validación): forman parte del funcionamiento normal. `EmailInvalido`, `SaldoInsuficiente`, `RecursoNoEncontrado`, `ConflictoDeVersion`. No son bugs; son respuestas legítimas del dominio. El usuario puede corregirlos. Se manejan como flujo de control explícito, se devuelven con un código/estado claro y **no** generan un log de nivel ERROR ni una alerta.

- **Errores inesperados** (bugs o infraestructura): violaciones de invariantes, `null` donde no debía haberlo, disco lleno, base de datos caída. Indican que algo está roto en el sistema, no en la entrada del usuario. Se loggean como ERROR con stack completo, disparan métricas y potencialmente alertas.

**El PORQUÉ:** si mezclás ambos, tu tasa de "errores" se contamina con validaciones normales y pierde toda señal. No podés alertar sobre errores si el 90% son "el usuario tipeó mal el email". Separalos desde el tipo de dato.

### Excepciones vs valores de resultado (Result / Either)

- Usá **valores de resultado** (`Result<T, E>`, `Either`, tuplas `(valor, error)`) para errores **esperados** del dominio. Hacen el fallo parte de la firma: el que llama está OBLIGADO a manejarlo por el compilador/tipo. Ideal para validación y reglas de negocio.

- Usá **excepciones** para lo **inesperado** y verdaderamente excepcional: fallos de infraestructura, violaciones de invariantes, condiciones de las que una capa individual no puede recuperarse.

- **Nunca uses excepciones para flujo de control normal.** `throw` para salir de un bucle o para "no encontrado" cuando "no encontrado" es esperado es abuso: es costoso, oscurece el flujo y confunde el análisis de errores. Si vas a atrapar la excepción tres líneas después, era un valor de resultado.

**El PORQUÉ:** las excepciones son saltos invisibles en el tipo. El `Result` hace el error visible en la firma y fuerza la decisión. Reservá el salto invisible para lo que realmente rompe la ejecución normal.

### Fail fast y validación en la frontera; guard clauses

Validá las entradas apenas cruzan el borde y salí temprano con guard clauses en vez de anidar.

```
// Evita: anidamiento profundo, la lógica feliz enterrada
func procesar(p *Pedido) error {
    if p != nil {
        if p.Items != nil {
            if len(p.Items) > 0 {
                // ...lógica real, 3 niveles adentro
            }
        }
    }
}

// Haz: guard clauses, falla rápido, lógica feliz al ras
func procesar(p *Pedido) error {
    if p == nil { return ErrPedidoNulo }
    if len(p.Items) == 0 { return ErrPedidoVacio }
    // ...lógica real, sin anidar
}
```

Una vez que un dato pasó la frontera y fue validado, el núcleo del dominio puede confiar en él. Eso es lo que hace la validación de borde: crea una zona de confianza. (Enlaza con **security**: la validación de borde es también la primera línea contra inyección y datos maliciosos.)

### No tragar errores: catch vacío es pecado

Un `catch` que no hace nada convierte un fallo en un misterio. Si atrapás un error, tenés que hacer **algo** con él: manejarlo, transformarlo, o registrarlo antes de propagar. "Lo ignoro y sigo" solo es válido cuando es una decisión explícita y documentada (y hasta ahí, dejá un comentario que diga POR QUÉ es seguro ignorarlo).

### Propagar con contexto: enriquecer, no ocultar

Cuando un error sube por las capas, cada capa que lo toca debería **agregar** contexto, no reemplazarlo:

```
// Evita: pierde la causa raíz
if err != nil { return errors.New("falló la operación") }

// Haz: envuelve preservando la cadena
if err != nil {
    return fmt.Errorf("cargando usuario %s desde db: %w", userID, err)
}
```

El `%w` (o el `cause`/`InnerException` de tu lenguaje) preserva la cadena original para inspección, mientras el mensaje agrega el "dónde y con qué datos". El resultado es un rastro que te lleva del síntoma a la causa sin adivinar.

### El nivel correcto para manejar

Regla: **manejá el error donde puedas tomar una decisión con él; propagalo si no.**

Una función de bajo nivel que lee un archivo no sabe si debería reintentar, mostrar un mensaje o abortar la request; solo el llamador que tiene contexto de negocio lo sabe. Entonces esa función propaga, y la capa de aplicación (o el error boundary/middleware) decide. Manejar demasiado abajo produce decisiones ciegas; manejar solo arriba, con contexto, produce decisiones correctas.

### No filtrar internals al usuario ni al atacante

El usuario recibe un mensaje **accionable y genérico**; el log recibe el **detalle técnico**. Nunca expongas stack traces, queries SQL, rutas de archivo, versiones de framework o mensajes de la base de datos al cliente.

```
// Al usuario:  "No pudimos procesar tu pago. Intentá de nuevo en unos minutos."
// Al log:      { level: ERROR, msg: "gateway timeout", provider: "stripe",
//                trace_id: "abc123", err: "context deadline exceeded", ... }
```

**El PORQUÉ:** un stack trace filtrado es un mapa para un atacante (enlaza con **security**) y es inútil para el usuario. Correlacioná ambos mundos con un `trace_id` o `error_id` que sí podés mostrar: "referencia del error: abc123" permite al soporte encontrar el log exacto sin filtrar nada.

### Limpieza de recursos e idempotencia en reintentos

- Todo recurso que se abre debe cerrarse aunque haya excepción: `finally`, `try-with-resources`/`using`, `defer`, context managers. No dependas del happy path para liberar conexiones, locks, file handles o transacciones.
- Si una operación se puede reintentar, hacela **idempotente**: usá claves de idempotencia, upserts, o verificá el estado antes de actuar. "Reintentar" y "efecto colateral no idempotente" juntos es cómo se cobra tres veces una tarjeta.

### Errores en la UI

- **Error boundaries** para que un fallo en un componente no tumbe toda la aplicación; aislá y mostrá un fallback local (enlaza con **frontend-architecture**).
- Diseñá **estados de error explícitos** en la UX: qué pasó, qué puede hacer el usuario, cómo reintentar. Un spinner infinito o una pantalla en blanco es peor que un mensaje de error claro (enlaza con **ux-design**).

---

## Resiliencia

La resiliencia es asumir que las dependencias VAN a fallar y diseñar para que su fallo no se convierta en el tuyo.

### Reintentos con backoff exponencial y jitter

- Reintentá **solo operaciones idempotentes** y solo ante errores **transitorios** (timeout, 503, connection reset), nunca ante errores de negocio (400, 404, "saldo insuficiente" no mejora reintentando).
- Usá **backoff exponencial** (100ms, 200ms, 400ms…) para no golpear un servicio ya caído, y agregá **jitter** (aleatoriedad) para que mil clientes no reintenten sincronizados y provoquen un *thundering herd*.
- Poné un **límite duro** de reintentos y un presupuesto de tiempo total. Reintentar para siempre es una caída disfrazada.

### Circuit breaker

Si una dependencia falla repetidamente, un circuit breaker **abre el circuito** y falla rápido durante un tiempo, en vez de que cada request espere el timeout completo. Estados: cerrado (normal) → abierto (falla rápido) → semiabierto (prueba con tráfico limitado). Esto protege tanto al que llama (libera hilos/conexiones) como al servicio caído (le da aire para recuperarse).

### Timeouts en TODA llamada de red

**Nunca esperes infinito.** Cada llamada saliente —HTTP, base de datos, cola, RPC, cache— lleva un timeout explícito y sensato. Un timeout ausente es una bomba de tiempo: bajo carga, los hilos se acumulan esperando respuestas que nunca llegan y agotan el pool, cayendo todo el servicio por un solo dependiente lento. El timeout convierte "colgado para siempre" en "error rápido y manejable". (Enlaza con **performance**: los timeouts y pools son parte del presupuesto de latencia.)

### Bulkheads

Aislá recursos por dependencia o por tipo de trabajo (pools de conexiones/hilos separados), como los compartimentos estancos de un barco. Así, un dependiente lento que agota su bulkhead no arrastra al resto del sistema. El fallo queda contenido en su compartimento.

### Degradación elegante y fallbacks

Cuando una dependencia no crítica cae, degradá en vez de caer: servir datos cacheados aunque estén algo viejos, ocultar una sección opcional, mostrar valores por defecto, encolar para procesar después. Definí explícitamente el **modo degradado**: qué features se apagan primero y qué sigue funcionando. Un sistema que ofrece el 80% cuando su recomendador cae es infinitamente mejor que uno que muestra error 500.

### Dead letter queues

En arquitecturas de mensajería, los mensajes que fallan tras N reintentos van a una **dead letter queue** en vez de perderse o bloquear la cola. Ahí se inspeccionan, corrigen y reprocesan. Requisito: los **consumidores deben ser idempotentes**, porque en entrega *at-least-once* el mismo mensaje puede llegar más de una vez.

### Health checks: liveness vs readiness

- **Liveness:** ¿el proceso está vivo o colgado? Si falla, el orquestador lo reinicia.
- **Readiness:** ¿está listo para recibir tráfico (dependencias conectadas, cache caliente, migraciones aplicadas)? Si falla, se lo saca del balanceador **sin** reiniciarlo.

Confundirlos causa reinicios en bucle (reiniciar algo que solo está esperando a que la base de datos vuelva no ayuda a nadie). Mantenelos separados y baratos.

---

## Observabilidad — los 3 pilares

Logs, métricas y trazas responden preguntas distintas. Los tres, correlacionados, te dan el panorama completo.

### Logs — el evento con detalle

- **Logging estructurado siempre.** Emití JSON o clave-valor, no strings interpolados. Un log estructurado se filtra, agrega y consulta; un string libre solo se lee a ojo. `{"level":"error","event":"pago_fallido","user_id":"u1","provider":"stripe","trace_id":"abc"}` vale mil `"error en el pago del user u1"`.
- **Niveles y cuándo usarlos:**
  - `DEBUG`: detalle fino para diagnóstico local; apagado en producción por defecto.
  - `INFO`: eventos de negocio normales y significativos ("pedido creado", "usuario autenticado").
  - `WARN`: algo anómalo pero recuperable, que quizás mires después (reintento exitoso, uso de fallback, deprecación).
  - `ERROR`: fallo real que requiere atención; algo no funcionó y alguien debería enterarse.
- **Contexto útil siempre:** `trace_id`, `user_id`, `request_id`, nombre del evento, duración. Sin contexto, un log es ruido.
- **NUNCA loggees secretos ni PII:** contraseñas, tokens, tarjetas, datos personales. Los logs se replican, indexan y comparten; un secreto en un log es una filtración permanente (enlaza con **security**). Redactá o hasheá.
- **No loggees en bucles calientes.** Un log por iteración en un loop de millones te tapa el disco, dispara costos y degrada la performance (enlaza con **performance**). Agregá o muestreá.

### Métricas — la agregación numérica en el tiempo

- **Qué medir — método RED** (para servicios de request):
  - **R**ate: requests por segundo.
  - **E**rrors: tasa de errores.
  - **D**uration: distribución de latencia (p50, p95, p99).
- **Método USE** (para recursos: colas, pools, CPU): **U**tilization, **S**aturation, **E**rrors.
- **Tipos de instrumento:**
  - **Contador:** solo sube (requests totales, errores totales).
  - **Histograma:** distribución de valores (latencias, tamaños); permite percentiles.
  - **Gauge:** valor puntual que sube y baja (conexiones activas, profundidad de cola).
- **Cuidado con la cardinalidad.** Cada combinación única de labels crea una serie temporal. Poner `user_id` o `trace_id` como label de una métrica **explota** la cardinalidad y tumba tu sistema de métricas. Los identificadores de alta cardinalidad van en logs y trazas, NO en labels de métricas.

### Trazas distribuidas — el camino de una request entre servicios

- Un **trace_id** único se genera en el borde y se propaga por todos los servicios y llamadas que atiende una request. Es el hilo que cose el recorrido completo.
- Cada operación es un **span** con inicio, fin, y atributos; los spans se anidan para formar el árbol de la request. Así ves exactamente qué servicio y qué operación consumió los 800ms.
- **Propagación de contexto:** el `trace_id` (y el `span_id` padre) viajan en headers (`traceparent` de W3C Trace Context) o en el contexto del mensaje. Si un servicio no propaga, la traza se corta ahí y perdés visibilidad. Usá **OpenTelemetry** para instrumentar de forma estándar y agnóstica al backend.

### Correlación entre los 3 pilares

El `trace_id` es el pegamento. Con él: una alerta de métrica ("p99 de latencia disparado") → te lleva a las trazas de esas requests lentas → cada span linkea a sus logs estructurados con el mismo `trace_id`. Métrica te dice **que** algo pasa, la traza **dónde**, el log **por qué**. Sin el id común, tenés tres silos y un incidente a ciegas. Poné `trace_id` en cada log y en cada span, siempre.

---

## Alertas y SLOs

### Alertar sobre síntomas, no sobre causas

- Definí **SLIs** (indicadores: disponibilidad, latencia, tasa de error) y **SLOs** (objetivos: "99.9% de las requests bajo 300ms al mes"). Alertá cuando el SLO está en riesgo, es decir, cuando el **usuario** está sufriendo.
- Usá el **error budget:** el margen entre el 100% y tu SLO. Mientras haya presupuesto, no despiertes a nadie por un pico aislado; cuando el presupuesto se quema rápido, alertá.
- **No alertes sobre causas ruidosas** (CPU al 80%, un pod reiniciado, una excepción suelta). Esos son datos para el dashboard, no motivos para un page. La CPU alta solo importa si degrada un SLI.

### Evitar la fatiga de alertas

Cada alerta debe ser **accionable**: si suena, alguien tiene que hacer algo AHORA. Una alerta que se ignora, se silencia o "siempre está en rojo" es peor que ninguna, porque entrena al equipo a ignorar el ruido y así se pierde la alerta real. Menos alertas, mejores. Toda alerta lleva un runbook: qué significa y qué hacer.

### Postmortems sin culpa (blameless)

Después de un incidente, el postmortem busca **qué falló en el sistema y los procesos**, no quién apretó el botón. El error humano es un síntoma de un sistema que permitió el error; la pregunta correcta es "¿por qué era posible cometerlo y por qué no lo detectamos antes?". La cultura sin culpa es lo que hace que la gente reporte incidentes en vez de esconderlos, y es la única forma de que el sistema aprenda. Documentá causa raíz, línea de tiempo, impacto y acciones concretas de mejora.

---

## Anti-patrones comunes

- **Catch-log-rethrow duplicado:** atrapar, loggear y relanzar el mismo error en cada capa produce el mismo error loggeado cinco veces y cinco alertas por un solo fallo. Loggeá **una vez**, donde se toma la decisión final.
- **Tragar excepciones:** `catch {}` vacío. El fallo desaparece y dejás un fantasma sin rastro.
- **Loggear y seguir como si nada:** loggear un ERROR y continuar la ejecución con estado corrupto. O es manejable (entonces manejalo de verdad) o no lo es (entonces frená).
- **Sin timeouts:** llamadas de red que esperan infinito y agotan el pool de conexiones bajo carga.
- **Reintentar lo no idempotente:** reintentar un `POST` con efecto colateral y duplicar cobros, envíos o registros.
- **Logs sin estructura:** strings interpolados imposibles de filtrar o agregar; observabilidad de solo lectura a ojo.
- **Alertar por todo:** un page por cada excepción y cada pico → fatiga de alertas → se ignora la que importaba.
- **Excepciones como control de flujo:** `throw`/`catch` para lo que es un resultado esperado y normal.
- **PII/secretos en logs:** filtración permanente disfrazada de "debug".
- **`trace_id` ausente:** logs, métricas y trazas que no se pueden cruzar; cada incidente arranca de cero.

---

## Checklist de errores y observabilidad

**Manejo de errores**
- [ ] Los errores esperados (negocio) y los inesperados (bugs/infra) se distinguen por tipo y se tratan distinto.
- [ ] Se usan `Result`/valores para lo esperado y excepciones solo para lo excepcional; ninguna excepción como flujo normal.
- [ ] Validación en la frontera con guard clauses; el dominio confía en datos ya validados.
- [ ] No hay ningún `catch` vacío sin justificación explícita y comentada.
- [ ] Los errores se propagan enriquecidos con contexto (dónde, con qué datos, causa preservada).
- [ ] El usuario recibe mensajes accionables; los internals (stack, SQL, rutas) solo van al log.
- [ ] Los recursos se liberan siempre (`finally`/`using`/`defer`), aun con excepción.

**Resiliencia**
- [ ] Toda llamada de red tiene timeout explícito.
- [ ] Los reintentos usan backoff exponencial + jitter, con límite, solo en operaciones idempotentes y errores transitorios.
- [ ] Hay circuit breakers y/o bulkheads en las dependencias críticas.
- [ ] Existe un modo degradado definido con fallbacks para dependencias no críticas.
- [ ] Los mensajes fallidos van a una DLQ; los consumidores son idempotentes.
- [ ] Liveness y readiness están separados y son baratos.

**Observabilidad**
- [ ] Todos los logs son estructurados (JSON/clave-valor) con niveles correctos.
- [ ] Ningún secreto ni PII se loggea; no se loggea en bucles calientes.
- [ ] Se exponen métricas RED/USE con instrumentos y cardinalidad controlada.
- [ ] Hay trazas distribuidas con `trace_id` propagado entre servicios (OpenTelemetry).
- [ ] Logs, métricas y trazas se correlacionan por `trace_id`.

**Alertas**
- [ ] Las alertas se basan en SLOs/síntomas y error budget, no en causas ruidosas.
- [ ] Toda alerta es accionable y tiene runbook; no hay fatiga de alertas.
- [ ] Los incidentes generan postmortems sin culpa con acciones concretas.

---

## Referencias

- **Google SRE Book** y **SRE Workbook** — SLIs/SLOs, error budgets, alerting sobre síntomas, postmortems sin culpa (sre.google/books).
- **OpenTelemetry** — estándar de instrumentación para trazas, métricas y logs; propagación de contexto W3C Trace Context (opentelemetry.io).
- **The Twelve-Factor App, Factor XI (Logs)** — tratar los logs como flujos de eventos hacia stdout, no como archivos que la app gestiona (12factor.net).
- **Release It!** (Michael Nygard) — patrones de estabilidad: circuit breaker, bulkhead, timeouts.

**Skills relacionadas:** `security` (no filtrar internals, no loggear secretos/PII, validación de borde), `testing` (probar caminos de error, no solo el happy path), `performance` (timeouts, pools, costo de logging en caliente, presupuesto de latencia), `frontend-architecture` (error boundaries), `ux-design` (estados de error en la interfaz).
