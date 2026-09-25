---
name: api-design
description: "Diseño de APIs y endpoints: REST, versionado, errores, paginación, idempotencia, contratos."
---

# Diseño de APIs y Endpoints

> **Cuándo usar:** al crear o modificar endpoints, diseñar el contrato de un servicio, definir el formato de errores, decidir versionado, paginación o idempotencia, revisar una API antes de exponerla, o al elegir entre REST/GraphQL/gRPC/webhooks. Si estás escribiendo una ruta, un DTO o un código de estado, esta guía aplica.

Una API es un **contrato público**: una vez que un cliente depende de ella, cambiarla cuesta caro. Diseña pensando en que vas a vivir con esa decisión durante años. La consistencia vale más que la perfección: es mejor una convención "buena" aplicada en todos lados que una convención "perfecta" aplicada a medias.

---

## 1. Principios fundamentales

1. **El contrato es lo primero (contract-first).** Diseña el request/response y los errores antes de escribir lógica. El contrato es la única parte que no puedes romper sin avisar.
2. **Orientación a recursos, no a acciones.** La URL identifica *cosas* (recursos); el verbo HTTP identifica la *acción*. `POST /users` en vez de `POST /createUser`.
3. **Predecible y consistente.** Si `GET /users` devuelve una lista paginada, `GET /orders` debe hacerlo igual. Un desarrollador debe poder *adivinar* tu API tras ver tres endpoints.
4. **Explícito sobre implícito.** Estados, errores y formatos declarados. Nada de "si el campo viene vacío significa X".
5. **Robusto en lo que aceptas, estricto en lo que prometes.** Valida entrada con firmeza; mantén tu salida estable y documentada.
6. **Diseña para el fallo.** Reintentos, timeouts, idempotencia y rate limiting no son extras: son parte del contrato.
7. **Seguridad y privacidad por defecto.** No expongas internals, IDs autoincrementales sensibles ni detalles de stack. Ver skill **security**.
8. **La documentación es parte del entregable.** Una API sin OpenAPI actualizado es una API rota a medias.

---

## 2. Reglas de oro (Haz / Evita)

| Haz ✅ | Evita ❌ |
|--------|----------|
| `GET /users/123/orders` | `GET /getUserOrders?id=123` |
| Sustantivos en plural: `/products` | Verbos en la ruta: `/createProduct` |
| Códigos de estado semánticos (201, 404, 422) | Devolver `200 OK` con `{"error": true}` |
| Errores en formato `application/problem+json` | Errores con forma distinta en cada endpoint |
| Paginación por cursor en listas grandes | Devolver 50k registros sin límite |
| `Idempotency-Key` en POST de pagos | POST no idempotente que cobra dos veces al reintentar |
| Fechas en ISO 8601 UTC | `12/06/2026` (ambiguo día/mes) |
| Versionar desde el día 1 (`/v1`) | Romper el contrato sin versión |
| Validar y devolver 422 con detalle de campos | 500 genérico ante entrada inválida |
| Naming y casing consistente en todo | `userName` aquí y `user_name` allá |

---

## 3. Diseño orientado a recursos y nomenclatura de URLs

Un **recurso** es un sustantivo del dominio: `user`, `order`, `invoice`. La URL es su dirección.

Reglas de nomenclatura:

- **Sustantivos, no verbos.** El verbo lo pone HTTP.
- **Plural para colecciones:** `/users` (colección), `/users/123` (elemento). Mantén el plural incluso para el elemento; no mezcles `/user/123`.
- **Jerarquía para relaciones de pertenencia:** `/users/123/orders/456`. Evita anidar más de 2 niveles; a partir de ahí usa filtros: `/orders?userId=123`.
- **minúsculas** siempre en el path.
- **kebab-case** para segmentos de varias palabras: `/purchase-orders`, no `/purchaseOrders` ni `/purchase_orders`.
- **Sin extensiones** (`.json`) ni sufijos de tecnología. La negociación de formato va en `Accept`.
- **IDs opacos si es posible** (UUID o ULID) para no filtrar volumen ni permitir enumeración. Ver **security**.
- **Sub-recursos para acciones que no encajan en CRUD**, modeladas como recurso: `POST /orders/456/cancellations` en lugar de `POST /orders/456/cancel`. Cuando es imposible, un endpoint de "acción" acotado es tolerable: `POST /orders/456/actions/cancel`.

```
GET    /articles                 # lista de artículos
POST   /articles                 # crea un artículo
GET    /articles/{id}            # un artículo
PATCH  /articles/{id}            # modifica parcialmente
DELETE /articles/{id}            # elimina
GET    /articles/{id}/comments   # comentarios de ese artículo
```

---

## 4. Verbos HTTP: semántica, seguridad e idempotencia

| Verbo | Uso | ¿Seguro? | ¿Idempotente? | Body request |
|-------|-----|:--------:|:-------------:|--------------|
| `GET` | Leer un recurso o colección | Sí | Sí | No |
| `POST` | Crear recurso / operación no idempotente | No | **No** | Sí |
| `PUT` | Reemplazo completo (o crear con ID conocido) | No | Sí | Sí (completo) |
| `PATCH` | Modificación parcial | No | No garantizado* | Sí (parcial) |
| `DELETE` | Eliminar | No | Sí | Opcional |

- **Seguro** = no altera estado del servidor (solo lectura). Nunca uses `GET` para mutar; los proxies y prefetchers pueden repetirlo.
- **Idempotente** = repetir la misma petición N veces deja el mismo estado final que hacerla 1 vez. Clave para reintentos seguros ante timeouts de red.
- **PUT vs PATCH:** `PUT` reemplaza el recurso entero (los campos omitidos se borran/resetean); `PATCH` toca solo lo enviado. No uses `PUT` para updates parciales.
- \* **PATCH** puede ser idempotente según cómo lo diseñes. Un `PATCH` que fija valores absolutos (`{"status": "paid"}`) es idempotente; uno que hace deltas (`{"balance": "+10"}`) no lo es. Prefiere el primero.
- **POST** es el verbo por defecto para acciones no idempotentes; protégelo con `Idempotency-Key` (sección 8).

---

## 5. Códigos de estado HTTP

Usa el código que comunica el resultado real. El status es la primera señal que lee el cliente y su lógica de reintento depende de él.

| Código | Significado | Cuándo usarlo |
|--------|-------------|---------------|
| `200 OK` | Éxito con cuerpo | GET, PATCH/PUT con respuesta |
| `201 Created` | Recurso creado | POST que crea; incluye header `Location` |
| `202 Accepted` | Aceptado, procesamiento async | Jobs, colas; devuelve URL de seguimiento |
| `204 No Content` | Éxito sin cuerpo | DELETE, o PUT/PATCH sin retorno |
| `301/308` | Movido permanente | Cambio de URL estable |
| `304 Not Modified` | Caché válido | Respuesta a `If-None-Match`/`If-Modified-Since` |
| `400 Bad Request` | Petición malformada | JSON inválido, sintaxis rota |
| `401 Unauthorized` | Falta o falla autenticación | Token ausente/inválido |
| `403 Forbidden` | Autenticado pero sin permiso | Autorización denegada |
| `404 Not Found` | Recurso inexistente | ID no encontrado (o para ocultar existencia) |
| `405 Method Not Allowed` | Verbo no soportado en esa ruta | Incluye header `Allow` |
| `409 Conflict` | Conflicto de estado | Duplicado, versión desactualizada |
| `410 Gone` | Recurso eliminado permanentemente | Recursos retirados |
| `412 Precondition Failed` | Falló condicional | `If-Match` con ETag viejo |
| `422 Unprocessable Entity` | Sintaxis OK, semántica inválida | Validación de negocio (email inválido, campo requerido) |
| `429 Too Many Requests` | Rate limit excedido | Incluye `Retry-After` |
| `500 Internal Server Error` | Fallo del servidor no controlado | Bug; nunca filtres stack trace |
| `502/503/504` | Upstream/indisponible/timeout | Degradación; el cliente puede reintentar |

Claves:
- **Distingue 401 vs 403**: 401 = "no sé quién eres"; 403 = "sé quién eres y no puedes".
- **Distingue 400 vs 422**: 400 = no pude parsear; 422 = parseé pero los datos violan reglas. Muchos frameworks usan 400 para ambos; si eliges 422 para validación, sé consistente.
- **4xx = culpa del cliente** (no reintentar igual); **5xx = culpa del servidor** (reintentable con backoff). Esta división guía la lógica de reintentos del cliente.
- Nunca `200` con un error dentro. Rompe caches, monitoreo y clientes.

---

## 6. Formato de errores consistente (RFC 7807)

Todos los errores deben tener **la misma forma** en toda la API. Usa `application/problem+json` (RFC 9457, antes RFC 7807).

```http
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json
```
```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "La solicitud contiene campos inválidos",
  "status": 422,
  "detail": "El campo 'email' no tiene un formato válido.",
  "instance": "/users",
  "traceId": "b7d3f1a2-...",
  "errors": [
    { "field": "email", "code": "invalid_format", "message": "Debe ser un email válido." },
    { "field": "age",   "code": "out_of_range",  "message": "Debe ser mayor o igual a 18." }
  ]
}
```

Campos:
- `type` (URI): identificador estable y documentable del tipo de error. La clave que el cliente puede usar para ramificar lógica.
- `title`: resumen legible, constante por `type`.
- `status`: repite el código HTTP (útil cuando el status se pierde en logs).
- `detail`: mensaje específico de *esta* ocurrencia.
- `instance`: URI de la ocurrencia.
- `traceId` (extensión): correlaciona con logs/observabilidad. Ver skill **error-handling-observability**.
- `errors[]` (extensión): detalle por campo para validación. Usa `code` legible por máquina, no solo `message`.

Reglas:
- **Nunca** filtres stack traces, nombres de tablas, queries SQL ni rutas internas en `detail`. Ver **security**.
- Mensajes accionables para el cliente, genéricos para lo interno (loguea lo detallado del lado servidor con el mismo `traceId`).
- El `code` por campo permite i18n y ramificación programática sin parsear texto.

---

## 7. Versionado de API

Versiona **desde el primer release**. No versionar es apostar a que nunca cambiarás nada incompatible.

| Estrategia | Ejemplo | Pros | Contras |
|-----------|---------|------|---------|
| **URL path** | `GET /v1/users` | Visible, cacheable, fácil de rutear y probar en navegador | "No purista" REST; versiona toda la API a la vez |
| **Header custom** | `Api-Version: 2026-06-30` | URL limpia; granularidad fina | Menos visible; difícil de probar a mano; cache más complejo |
| **Media type** | `Accept: application/vnd.example.v2+json` | Purista; versiona por recurso | Complejo; poco intuitivo para consumidores |

**Recomendación:** **versionado en URL path (`/v1`)** para la mayoría de APIs públicas y de producto: es explícito, trivial de rutear, cachear y depurar. Reserva versionado por header/media-type para APIs muy grandes con ciclos de vida por recurso.

Reglas de evolución:
- **Cambios aditivos son compatibles**: agregar campos opcionales o endpoints no rompe. Los clientes deben ignorar campos desconocidos (diséñalos tolerantes).
- **Cambios incompatibles** (renombrar/eliminar campos, cambiar tipos, endurecer validación) exigen nueva versión mayor.
- Publica **política de deprecación**: header `Deprecation` + `Sunset` (RFC 8594), fecha de retiro y guía de migración. Da meses, no días.
- Fechas como versión (`2026-06-30`) funcionan bien para APIs con evolución continua (estilo Stripe).

---

## 8. Paginación, filtrado, ordenamiento y búsqueda

**Nunca** devuelvas una colección sin límite. Pagina siempre.

**Offset/limit** — simple, permite saltar a página N:
```
GET /users?limit=20&offset=40
```
- Pros: fácil, "página 5" directo.
- Contras: se degrada en datasets grandes (el motor cuenta y descarta filas); **inconsistente** si se insertan/borran filas mientras paginas (saltos o duplicados).

**Cursor (keyset)** — recomendado para listas grandes o en tiempo real:
```
GET /users?limit=20&cursor=eyJpZCI6MTIzfQ==
```
```json
{
  "data": [ /* ... */ ],
  "pagination": {
    "nextCursor": "eyJpZCI6MTQzfQ==",
    "hasMore": true
  }
}
```
- Pros: rendimiento estable (usa índice `WHERE id > ?`), consistente ante inserciones. Ver **database-design** y **performance**.
- Contras: no permite "ir a la página 7"; solo siguiente/anterior. El cursor debe ser **opaco** (codifica el keyset, no lo expongas crudo).

**Filtrado, orden y búsqueda** por query params, con convención estable:
```
GET /orders?status=paid&createdAfter=2026-01-01&sort=-createdAt,total&q=laptop&fields=id,total
```
- Filtros: `campo=valor`. Para rangos, prefijos claros: `createdAfter`, `minPrice`.
- Orden: `sort=-createdAt` (`-` = descendente); múltiples separados por coma.
- Búsqueda de texto libre: `q=`.
- Selección de campos (sparse fieldsets): `fields=id,name` para reducir payload.
- **Documenta y valida** los campos permitidos: no permitas ordenar/filtrar por columnas arbitrarias (riesgo de rendimiento e inyección). Ver **security**.

---

## 9. Idempotencia y reintentos seguros

Las redes fallan **después** de que el servidor procesó pero **antes** de que la respuesta llegue. El cliente reintenta y —sin protección— duplica la operación (doble cobro, doble pedido).

- `GET`, `PUT`, `DELETE` son idempotentes por naturaleza: reintentar es seguro.
- `POST` **no** lo es. Protégelo con **`Idempotency-Key`**:

```http
POST /payments
Idempotency-Key: 8f14e45f-...
Content-Type: application/json
```

Mecánica del lado servidor:
1. El cliente genera una clave única (UUID) por *intento lógico* de operación y la reutiliza en cada reintento.
2. El servidor almacena `(idempotency-key → resultado)` con TTL (p. ej. 24h).
3. Si llega una clave ya vista: devuelve el **resultado guardado** sin re-ejecutar.
4. Si la clave está en proceso: responde `409 Conflict` o espera.
5. Valida que el body coincida con el de la primera vez; si difiere, `422`.

Reglas:
- El cliente reintenta con **backoff exponencial + jitter**, solo ante `5xx`, `429` y timeouts de red. Nunca reintenta `4xx` (salvo `429`).
- Operaciones intrínsecamente no idempotentes (crear pago, enviar email) **requieren** `Idempotency-Key`.
- Persiste las claves en almacenamiento durable (no solo memoria) para sobrevivir reinicios. Ver **database-design**.

---

## 10. Validación de entrada y contratos (schema-first)

- **Schema-first / OpenAPI-first:** define el contrato en OpenAPI y genera validadores, tipos y stubs desde ahí. El schema es la fuente de verdad, no el código.
- **Valida todo lo que entra** en el borde: tipos, formatos, rangos, longitudes, enums, campos requeridos. Rechaza lo desconocido según política (estricto para writes sensibles).
- **DTOs separados de entidades de dominio.** No serialices tu modelo de base de datos directo: filtras internals y acoplas el contrato al esquema de datos. Define `CreateUserRequest`, `UserResponse` explícitos.
- **No confíes en el cliente** para nada de seguridad: precios, roles, `ownerId` se derivan del servidor/token, nunca del body.
- Devuelve **422** con la lista de campos inválidos (sección 6), no un 500.

```jsonc
// CreateUserRequest (lo que aceptas)
{ "email": "a@b.com", "password": "secret", "name": "Ada" }

// UserResponse (lo que devuelves — sin password, sin campos internos)
{ "id": "usr_01H...", "email": "a@b.com", "name": "Ada", "createdAt": "2026-06-30T10:00:00Z" }
```

---

## 11. Autenticación y autorización

- **Autenticación** = quién eres. **Autorización** = qué puedes hacer. Son distintas; implementa ambas.

| Mecanismo | Cuándo | Notas |
|-----------|--------|-------|
| **API Keys** | Server-to-server, integraciones simples | Fácil; sin identidad de usuario ni granularidad. Rotables, revocables. |
| **OAuth2** | Acceso delegado de terceros, apps de usuario | Estándar para "inicia sesión con"; scopes por permiso. |
| **JWT (Bearer)** | Sesiones stateless, microservicios | Autocontenido, verificable sin DB; **no revocable** fácilmente → usa expiración corta + refresh tokens. |

Reglas:
- Credenciales **siempre** por header `Authorization: Bearer <token>`, **nunca** en query string (se filtran en logs y caches).
- **Solo HTTPS.** Sin TLS, cualquier token viaja en claro.
- **Nunca** devuelvas datos sensibles (password hash, tokens internos, PII innecesaria) en respuestas. Usa DTOs.
- Autorización **por recurso**: verifica que el usuario es dueño de `/orders/456`, no solo que está autenticado. El fallo aquí es una de las vulnerabilidades más comunes (BOLA/IDOR).
- `401` para auth ausente/inválida; `403` para permiso denegado. Para no revelar existencia de recursos ajenos, `404` puede ser preferible a `403`.
- Detalle profundo en la skill **security**.

---

## 12. Rate limiting

Protege la API de abuso y garantiza equidad. Comunica los límites por headers:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
RateLimit-Limit: 100
RateLimit-Remaining: 0
RateLimit-Reset: 30
```

- `429` cuando se excede la cuota.
- `Retry-After`: segundos (o fecha HTTP) que el cliente debe esperar. El cliente **debe** respetarlo.
- Expón el estado de cuota en cada respuesta (`RateLimit-*`) para que el cliente se autorregule antes de chocar.
- Define límites por clave/usuario/IP y por endpoint (los caros más estrictos). Ver **performance** y **security**.

---

## 13. Caché HTTP

Reduce latencia y carga sin lógica extra en el cliente. Ver **performance**.

- **`Cache-Control`** controla la cacheabilidad:
  - `public, max-age=3600` — cacheable por proxies y navegador 1h.
  - `private, max-age=0, no-cache` — solo cliente, revalida siempre.
  - `no-store` — datos sensibles, nunca se guardan.
- **`ETag`** (validador de versión) + petición condicional:

```http
# Respuesta
ETag: "a1b2c3"

# Petición posterior del cliente
GET /articles/1
If-None-Match: "a1b2c3"
# → 304 Not Modified si no cambió (ahorra ancho de banda)
```

- **`ETag` + `If-Match`** también sirve para **concurrencia optimista**: `PUT`/`PATCH` con `If-Match: "a1b2c3"` → `412 Precondition Failed` si otro modificó el recurso. Evita el "last write wins".
- `Last-Modified` + `If-Modified-Since` es la alternativa basada en fecha.

---

## 14. HATEOAS y madurez de Richardson (breve)

El **Modelo de Madurez de Richardson** clasifica cuán RESTful es una API:

- **Nivel 0** — un solo endpoint, todo por POST (RPC sobre HTTP). No REST.
- **Nivel 1 — Recursos:** múltiples URLs por recurso, pero un solo verbo.
- **Nivel 2 — Verbos HTTP:** verbos y códigos de estado correctos. **Aquí vive la mayoría de las APIs "REST" reales y es un objetivo perfectamente válido.**
- **Nivel 3 — HATEOAS:** las respuestas incluyen links que indican las acciones siguientes posibles.

```json
{
  "id": "ord_123",
  "status": "pending",
  "_links": {
    "self":   { "href": "/orders/ord_123" },
    "cancel": { "href": "/orders/ord_123/cancellations", "method": "POST" },
    "pay":    { "href": "/orders/ord_123/payments", "method": "POST" }
  }
}
```

**Pragmatismo:** apunta a **Nivel 2** como mínimo sólido. HATEOAS (Nivel 3) es elegante pero pocos clientes lo aprovechan; adóptalo solo si tu consumidor navegará dinámicamente. No te obsesiones con la pureza.

---

## 15. REST vs GraphQL vs gRPC vs Webhooks

| Estilo | Modelo | Mejor para | Evita cuando |
|--------|--------|-----------|--------------|
| **REST** | Recursos + HTTP | APIs públicas, CRUD, caché HTTP, amplia interoperabilidad | Necesitas agregación compleja de muchos recursos por vista |
| **GraphQL** | Grafo, query del cliente | Clientes que arman vistas variadas, evitar over/under-fetching, front-ends ricos | Caché HTTP simple; equipos sin apetito por su complejidad (N+1, rate limiting por costo) |
| **gRPC** | RPC + Protobuf/HTTP2 | Microservicios internos, baja latencia, streaming, contratos tipados | APIs de navegador (soporte limitado), consumidores públicos heterogéneos |
| **Webhooks** | Push del servidor por evento | Notificar al cliente de eventos async (pagos, cambios de estado) | Necesitas respuesta síncrona; el cliente no puede exponer endpoint |

Claves:
- **REST** es el default seguro para APIs de producto y públicas.
- **GraphQL** brilla con front-ends que consumen datos heterogéneos; su costo es caché, rate limiting por complejidad de query y evitar N+1 (ver **performance**, **database-design**).
- **gRPC** para el interior de tu sistema (service-to-service).
- **Webhooks** complementan REST para lo asíncrono; **firma el payload** (HMAC) y hazlos idempotentes del lado receptor (reintentos duplican). Ver **security**.

---

## 16. Consistencia: naming, fechas, casing, envelopes

- **Casing de campos:** elige **uno** y aplícalo en TODA la API. `snake_case` es común en REST; `camelCase` si tu ecosistema es JS/JSON. Nunca los mezcles.
- **Fechas y horas: siempre ISO 8601 en UTC** con offset: `2026-06-30T10:00:00Z`. Nunca formatos locales ambiguos ni timestamps epoch sin documentar. Incluye zona.
- **Booleanos** con nombres claros: `isActive`, `hasShipped` (no `flag`, no `status=1`).
- **Enums** como strings estables (`"pending"`, `"paid"`), no números mágicos. Documenta los valores posibles.
- **Dinero:** entero en la unidad mínima (centavos) + código de moneda ISO 4217 (`{ "amount": 1050, "currency": "USD" }`), o string decimal. **Nunca** float para dinero.
- **Envelope de respuesta:** decide si envuelves o no y sé consistente:
  ```json
  { "data": { ... }, "meta": { ... } }        // colección o recurso
  { "data": [ ... ], "pagination": { ... } }  // lista
  ```
  Un envelope da lugar para metadata/paginación/links sin romper el contrato. Alternativa válida: recurso "desnudo" + paginación en headers. Elige una.
- **Null vs ausente:** define la semántica. Omitir un campo ≠ enviarlo `null`. Documenta cuál usas (relevante para `PATCH`).

---

## 17. Seguridad de API (esenciales)

Complementa con la skill **security**; aquí lo mínimo innegociable:

- **HTTPS obligatorio.** Redirige HTTP→HTTPS; considera HSTS.
- **Valida y sanitiza toda entrada.** Trata cada input como hostil: previene inyección SQL/NoSQL/comando (ver **database-design**).
- **No filtres internals en errores:** ni stack traces, ni nombres de tabla, ni versiones de software. Mensaje genérico al cliente, detalle en logs con `traceId`.
- **CORS restrictivo:** whitelist explícita de orígenes; no uses `Access-Control-Allow-Origin: *` en endpoints autenticados.
- **Rate limiting** contra fuerza bruta y abuso (sección 12).
- **Autorización por objeto** (evita IDOR/BOLA): verifica ownership en cada acceso, no solo autenticación.
- **Mínima exposición de datos:** devuelve solo lo necesario; nada de PII o secretos de más.
- **Payloads con límite de tamaño** y timeouts, para frenar DoS.
- **Secretos fuera del código y de las URLs.** Tokens por header, nunca en query params.

---

## 18. Documentación como contrato (OpenAPI)

- **OpenAPI (Swagger)** es el contrato ejecutable: describe endpoints, schemas, ejemplos, errores y auth. Genera docs, SDKs, mocks y tests desde él.
- **Contract-first:** escribe/actualiza el OpenAPI *antes* de implementar. Que el código cumpla el spec, no al revés.
- **Versiona el contrato junto al código** (en el repo) y trátalo como parte de la definición de "hecho": un PR que cambia la API sin actualizar OpenAPI está incompleto.
- Valida en CI que la implementación cumple el spec (contract testing). Detecta breaking changes automáticamente comparando versiones del spec.
- Publica ejemplos reales de request/response por endpoint, incluidos los errores.

---

## Anti-patrones comunes

- **Verbos en la URL:** `/getUser`, `/createOrder`, `/user/delete`. Usa recursos + verbo HTTP.
- **Túnel POST:** todo por `POST` con un campo `action` (Richardson Nivel 0).
- **`200 OK` con error dentro** del body. Rompe clientes, caché y monitoreo.
- **Filtrar internals** en errores (stack trace, SQL, rutas). Fuga de seguridad.
- **No paginar** y devolver colecciones ilimitadas. Bomba de latencia/memoria.
- **Naming/casing inconsistente** entre endpoints (`user_id` vs `userId`).
- **No versionar** y luego romper a todos los clientes con un cambio incompatible.
- **Serializar la entidad de dominio/DB directo,** exponiendo campos internos y acoplando el contrato al esquema.
- **`POST` de cobro sin idempotencia:** el reintento por timeout cobra dos veces.
- **Confiar en el cliente** para precio, rol u ownership (viene en el body).
- **Ignorar códigos de estado:** todo `200` o todo `500`.
- **Anidamiento profundo de rutas** (`/a/1/b/2/c/3/d/4`): usa filtros.
- **Fechas locales/ambiguas** sin zona horaria.
- **Breaking changes silenciosos** en producción sin `Deprecation`/`Sunset`.

---

## Checklist antes de dar por buena una API

- [ ] URLs orientadas a recursos: sustantivos, plural, minúsculas, kebab-case.
- [ ] Verbos HTTP con semántica correcta; sin verbos en la ruta.
- [ ] Códigos de estado precisos por caso (201 al crear, 422 en validación, 404/403 diferenciados).
- [ ] Formato de error único (`problem+json`) con `type`, `title`, `status`, `detail`, `traceId`.
- [ ] Sin fugas de internals en errores; mensajes genéricos + logs correlacionados.
- [ ] Versionado definido y visible (`/v1`) con política de deprecación.
- [ ] Toda colección paginada (cursor para grandes); filtros/orden validados y documentados.
- [ ] `Idempotency-Key` en `POST` no idempotentes; reintentos con backoff definidos.
- [ ] Entrada validada en el borde; DTOs de request/response separados del dominio.
- [ ] AuthN y AuthZ implementadas; autorización por objeto (sin IDOR); solo HTTPS.
- [ ] Rate limiting con `429` + `Retry-After` y headers `RateLimit-*`.
- [ ] Caché donde aplique: `ETag`/`Cache-Control`; concurrencia optimista con `If-Match`.
- [ ] Naming, casing, fechas ISO 8601 UTC y formato de dinero consistentes en toda la API.
- [ ] Envelope de respuesta y semántica de `null`/ausencia definidas y uniformes.
- [ ] OpenAPI actualizado, versionado en el repo y validado en CI.
- [ ] Ejemplos de request/response y de errores documentados por endpoint.

---

## Referencias

- RFC 9457 — Problem Details for HTTP APIs (reemplaza RFC 7807): https://www.rfc-editor.org/rfc/rfc9457
- RFC 9110 — HTTP Semantics (métodos y códigos de estado): https://www.rfc-editor.org/rfc/rfc9110
- RFC 8594 — Sunset HTTP Header: https://www.rfc-editor.org/rfc/rfc8594
- MDN — HTTP: https://developer.mozilla.org/es/docs/Web/HTTP
- MDN — Códigos de estado HTTP: https://developer.mozilla.org/es/docs/Web/HTTP/Status
- OpenAPI Specification: https://spec.openapis.org/oas/latest.html
- Richardson Maturity Model (Martin Fowler): https://martinfowler.com/articles/richardsonMaturityModel.html
- Stripe API (referencia de diseño y idempotencia): https://docs.stripe.com/api
- Google API Design Guide: https://cloud.google.com/apis/design
- OWASP API Security Top 10: https://owasp.org/API-Security/

---

**Skills relacionadas:** **security** (auth, CORS, inyección, secretos), **database-design** (paginación por keyset, N+1, persistencia de idempotencia), **error-handling-observability** (traceId, logging, correlación) y **performance** (caché, rate limiting, payloads).
