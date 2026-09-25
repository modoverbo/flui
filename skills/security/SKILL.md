---
name: security
description: "Seguridad aplicada: OWASP, autenticación/autorización, secretos, validación, defensa en profundidad."
---

# Seguridad Aplicada

> **Cuándo usar:** léela ANTES de tocar cualquier cosa sensible: flujos de autenticación o autorización, manejo de datos de usuario o PII, endpoints públicos o expuestos a internet, formularios y parámetros que reciben entrada externa, consultas a base de datos con datos del usuario, manejo de secretos/credenciales/tokens, cookies y sesiones, subida de archivos, integraciones con terceros, o cualquier código que decida "¿este usuario puede hacer esto?". Si dudas de si aplica, aplica.

La seguridad no es una feature que se agrega al final: es una propiedad transversal del diseño. Un sistema seguro no depende de que "nadie encuentre el fallo", sino de que el fallo, aunque exista, no comprometa todo. Este skill tiene enfoque **defensivo**: proteger el sistema, no atacarlo. El objetivo es que entiendas el PORQUÉ de cada regla, porque una regla memorizada sin entender se rompe en el primer caso que no la contempla.

---

## 1. Principios fundamentales

Estos cinco principios son la base. Cada regla concreta más abajo es una consecuencia de alguno de ellos.

- **Defensa en profundidad (defense in depth):** nunca dependas de una sola barrera. Si el WAF falla, la validación de entrada debe atrapar el ataque; si esa falla, la consulta parametrizada; si esa falla, los permisos mínimos de la BD limitan el daño. Capas independientes. Un atacante debe romper TODAS, no una.
- **Mínimo privilegio (least privilege):** cada componente, usuario, token o proceso recibe solo los permisos que necesita para su tarea, ni uno más. El servicio que lee reportes no necesita `DROP TABLE`. El token de un widget de frontend no necesita scope de admin. Menos privilegio = menos superficie de daño cuando algo se compromete.
- **Secure by default:** el estado por defecto debe ser el seguro. Un endpoint nuevo debe estar cerrado hasta que explícitamente lo abras, no abierto hasta que recuerdes cerrarlo. Un permiso ausente se interpreta como "denegar", no como "permitir". La configuración de fábrica no debe requerir "endurecerla" para ser segura.
- **No confiar en la entrada (never trust input):** TODO dato que cruza una frontera de confianza es hostil hasta que se demuestre lo contrario: parámetros HTTP, headers, cookies, cuerpos JSON, archivos subidos, respuestas de APIs de terceros, incluso datos que vienen de tu propia BD si originalmente los puso un usuario. La validación ocurre en el **servidor**, siempre. El cliente valida por UX, no por seguridad.
- **Fail securely (fallar de forma segura):** cuando algo sale mal, el sistema debe caer hacia el estado seguro, no hacia el abierto. Si la verificación de permisos lanza una excepción, el resultado es DENEGAR, no PERMITIR. Un error nunca debe convertirse accidentalmente en un bypass. Compara: `if (tienePermiso()) permitir()` deja pasar si `tienePermiso()` explota y alguien lo captura mal; el diseño correcto deniega por defecto y solo permite en el camino explícitamente autorizado.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Validar y autorizar SIEMPRE en el servidor | Confiar en validaciones o checks del cliente |
| Consultas parametrizadas / ORM con bindings | Concatenar entrada del usuario en SQL/comandos |
| Hashear contraseñas con bcrypt / argon2 / scrypt | MD5, SHA-1, SHA-256 "a secas" o texto plano |
| Codificar la salida según el contexto (HTML, JS, URL) | Insertar datos del usuario crudos en el DOM |
| Secretos en gestor de secretos / variables de entorno | Secretos hardcodeados o commiteados al repo |
| Allowlist (lista de lo permitido) | Denylist (lista de lo prohibido) |
| HTTPS/TLS en todo, HSTS activo | HTTP plano, TLS opcional o downgradeable |
| Verificar autorización por objeto en cada acceso | Asumir que "solo la UI muestra sus datos" |
| Mensajes de error genéricos al cliente | Devolver stack traces, versiones o SQL al cliente |
| Rate limiting en auth y endpoints costosos | Login/reset sin límite de intentos |
| Rotar y revocar credenciales y tokens | Tokens eternos sin expiración ni revocación |
| Dependencias actualizadas y escaneadas | Librerías con CVEs conocidos "porque funciona" |

---

## 3. OWASP Top 10 (referencia 2021, vigente)

El estándar de facto para priorizar riesgos en aplicaciones web. Conócelo de memoria a nivel de qué es y cómo se mitiga.

1. **A01 – Broken Access Control (control de acceso roto):** el usuario accede a datos o acciones que no le corresponden (ver el pedido de otro, escalar a admin). *Mitigar:* denegar por defecto, verificar autorización por objeto en el servidor en CADA request, no exponer IDs adivinables sin check de propiedad. Ver §8.
2. **A02 – Cryptographic Failures (fallos criptográficos):** datos sensibles sin cifrar o con cripto débil (contraseñas en SHA plano, TLS opcional, PII en claro). *Mitigar:* TLS obligatorio, cifrado en reposo, algoritmos actuales, hashing lento para contraseñas. Ver §7 y §14.
3. **A03 – Injection (inyección):** SQL, NoSQL, comandos de SO, LDAP donde entrada del usuario se interpreta como código. *Mitigar:* consultas parametrizadas, ORM, validación por allowlist, nunca concatenar. Ver §4.
4. **A04 – Insecure Design (diseño inseguro):** el fallo está en la arquitectura, no en un bug puntual (flujo de recuperación de cuenta sin verificación, ausencia de límites de negocio). *Mitigar:* threat modeling, patrones seguros desde el diseño, historias de abuso además de historias de usuario.
5. **A05 – Security Misconfiguration (configuración insegura):** defaults inseguros, features de debug en producción, permisos abiertos, cabeceras faltantes. *Mitigar:* hardening por defecto, deshabilitar lo no usado, cabeceras de seguridad, revisar config por entorno. Ver §13.
6. **A06 – Vulnerable and Outdated Components (componentes vulnerables):** dependencias con CVEs conocidos. *Mitigar:* inventario de dependencias, escaneo continuo, actualizar, lockfiles. Ver §15.
7. **A07 – Identification and Authentication Failures (fallos de autenticación):** login débil, sesiones mal gestionadas, credenciales por defecto, sin MFA. *Mitigar:* hashing fuerte, MFA, gestión de sesión robusta, rate limiting. Ver §6 y §9.
8. **A08 – Software and Data Integrity Failures (fallos de integridad):** deserialización insegura, actualizaciones o dependencias sin verificar firma, CI/CD comprometido. *Mitigar:* verificar integridad/firmas, no deserializar datos no confiables, proteger el pipeline (supply chain). Ver §15.
9. **A09 – Security Logging and Monitoring Failures (fallos de logging y monitoreo):** ataques que pasan inadvertidos por falta de registro o alertas. *Mitigar:* logging de eventos de seguridad, monitoreo y alertas, sin loggear secretos. Ver §16.
10. **A10 – Server-Side Request Forgery (SSRF):** el servidor hace peticiones a URLs controladas por el atacante (acceso a metadata interna, red interna). *Mitigar:* allowlist de destinos, bloquear rangos internos/loopback, no reenviar URLs crudas del usuario.

---

## 4. Inyección (SQL / NoSQL / comandos)

La inyección ocurre cuando datos se interpretan como código. La causa raíz es **mezclar datos y código en la misma cadena**. La solución no es "escapar mejor": es **separar estructuralmente** datos de instrucciones.

**Regla absoluta: nunca concatenes entrada del usuario en una consulta o comando.**

```sql
-- ❌ VULNERABLE: la entrada se convierte en código
query = "SELECT * FROM users WHERE email = '" + email + "'"
-- entrada: ' OR '1'='1  → devuelve todos los usuarios

-- ✅ SEGURO: consulta parametrizada, el driver separa datos de código
query = "SELECT * FROM users WHERE email = ?"
db.execute(query, [email])
```

- **SQL:** usa consultas parametrizadas / prepared statements SIEMPRE, o un ORM que use bindings por debajo. El placeholder (`?`, `$1`, `:email`) garantiza que el valor jamás se interprete como estructura.
- **NoSQL (p. ej. MongoDB):** también es inyectable. Un `{ "$gt": "" }` inyectado en un campo de contraseña puede saltarse el login. Valida tipos, rechaza operadores en entrada, usa el driver correctamente.
- **Comandos de SO:** evita invocar shell con entrada del usuario. Si es inevitable, usa APIs que reciban argumentos como array (no una cadena de shell) y valida contra allowlist. Nunca `exec("convert " + filename)`.
- **Cuando la parametrización no cubre** (nombres de tabla/columna dinámicos, `ORDER BY`): usa **allowlist** — compara la entrada contra un conjunto fijo de valores válidos, nunca la insertes directa.

Enlace: al diseñar el acceso a datos, coordina con **database-design** para modelos y permisos de BD con mínimo privilegio.

---

## 5. Cross-Site Scripting (XSS)

XSS ejecuta JavaScript del atacante en el navegador de la víctima. Causa raíz: **datos del usuario tratados como marcado/código en la salida.** La defensa central es **codificar la salida según el contexto**.

- **Reflejado:** la entrada vuelve inmediatamente en la respuesta (búsqueda que repite el término sin codificar).
- **Almacenado:** la carga se guarda (comentario, perfil) y ataca a todos los que lo ven. El más peligroso.
- **DOM-based:** JS del propio sitio escribe entrada no confiable en el DOM (`innerHTML`, `document.write`).

Mitigaciones, en capas:

- **Codificación de salida contextual:** codifica según DÓNDE se inserta el dato — HTML body, atributo, dentro de `<script>`, URL. No es lo mismo. Usa las utilidades del framework (React/Angular/Vue escapan por defecto; respétalas).
- **Nunca uses `innerHTML` / `dangerouslySetInnerHTML` / `v-html`** con datos del usuario. Usa `textContent` o binding seguro. Si DEBES renderizar HTML del usuario, **sanitiza** con una librería robusta (p. ej. DOMPurify) — nunca a mano con regex.
- **Content Security Policy (CSP):** cabecera que restringe de dónde se cargan scripts. Una CSP estricta (sin `unsafe-inline`) convierte muchos XSS en inofensivos aunque la carga llegue. Es tu red de seguridad, no tu primera línea.
- **Cookies con `HttpOnly`:** evita que JS lea la cookie de sesión, limitando el robo de sesión vía XSS.

```js
// ❌ VULNERABLE
el.innerHTML = "Hola " + userName;

// ✅ SEGURO
el.textContent = "Hola " + userName;
```

---

## 6. CSRF (Cross-Site Request Forgery)

Un sitio malicioso hace que el navegador de la víctima envíe una petición autenticada a TU sitio (aprovechando su cookie de sesión) sin que ella lo sepa (transferir dinero, cambiar email).

Mitigaciones:

- **Tokens anti-CSRF:** token impredecible por sesión/formulario que el servidor emite y verifica en cada petición que cambia estado. El sitio atacante no puede leerlo (same-origin), así que no puede falsificar la petición.
- **Cookies `SameSite`:** `SameSite=Lax` (buen default) o `Strict` impide que la cookie se envíe en peticiones cross-site, cortando el vector de raíz. Combínalo con tokens; no dependas de uno solo.
- **Verifica el método:** las operaciones que cambian estado nunca por `GET`. `GET` es seguro/idempotente por contrato; mutaciones van por `POST/PUT/PATCH/DELETE`.
- Para APIs con tokens en header (no cookies), CSRF clásico no aplica igual, pero valida `Origin`/`Referer` en flujos sensibles.

---

## 7. Autenticación (¿quién eres?)

- **Hashing de contraseñas:** usa un algoritmo **lento y con sal**: **argon2** (preferido), **bcrypt** o **scrypt**. Están diseñados para ser costosos y resistir fuerza bruta con GPU. **NUNCA** MD5, SHA-1, SHA-256/512 planos: son rápidos, y "rápido" es exactamente lo que un atacante quiere para probar millones de hashes.
- **Salting:** cada contraseña con una sal única y aleatoria (bcrypt/argon2 la manejan internamente). La sal impide precomputar (rainbow tables) y hace que dos usuarios con la misma contraseña tengan hashes distintos.
- **Nunca guardes la contraseña en claro ni cifrada de forma reversible.** El hashing es unidireccional a propósito: no necesitas recuperarla, solo verificarla.
- **Políticas sensatas:** longitud mínima razonable (favorece frases largas sobre reglas de complejidad crípticas), compara contra listas de contraseñas filtradas conocidas, no fuerces rotación periódica arbitraria (empeora la higiene).
- **MFA (autenticación multifactor):** ofrécela y exígela para cuentas privilegiadas. Algo que sabes + algo que tienes. Reduce drásticamente el impacto de credenciales robadas.
- **Comparación en tiempo constante** al verificar tokens/OTP para evitar timing attacks.
- **Enumeración de usuarios:** mensajes de login/registro/reset genéricos ("credenciales inválidas"), sin revelar si el email existe. Ver §17.

---

## 8. Autorización (¿qué puedes hacer?)

**Authn ≠ Authz.** Autenticación es *quién eres*; autorización es *qué se te permite*. Estar logueado (authn) no implica poder ver el recurso X (authz). Se verifican por separado, y ambas **en el servidor, siempre**.

- **Control de acceso a nivel de objeto (IDOR):** el fallo más común. Si `/api/orders/1234` devuelve un pedido, verifica que ese pedido **pertenece al usuario autenticado**, no solo que el usuario esté logueado. Nunca asumas que "como la UI solo le muestra sus IDs, no probará otros". Un atacante cambia el ID a mano en segundos.

```
❌ getOrder(id)                  // devuelve cualquier pedido a cualquiera logueado
✅ getOrder(id, currentUser)     // verifica ownership: order.userId == currentUser.id
```

- **RBAC (por roles):** permisos agrupados en roles (`admin`, `editor`, `viewer`). Simple y escalable para la mayoría de casos.
- **ABAC (por atributos):** decisiones según atributos del usuario, recurso y contexto (departamento, hora, ubicación). Más granular, más complejo. Úsalo cuando RBAC se queda corto.
- **Deny by default:** sin regla explícita que permita → denegar.
- **Verifica en cada capa relevante,** no solo en el gateway. Un endpoint interno también autoriza.

Enlace: al definir endpoints y su modelo de permisos, aplica esto junto con **api-design**.

---

## 9. Sesiones y tokens

**Sesiones (server-side):**

- ID de sesión aleatorio, largo, impredecible. Cookie con `HttpOnly`, `Secure`, `SameSite`.
- **Regenera el ID de sesión tras el login** (previene session fixation).
- Expiración por inactividad y absoluta. Invalida la sesión en el servidor al cerrar sesión (no basta borrar la cookie).

**JWT — úsalo entendiendo sus riesgos:**

- **`alg: none`:** rechaza SIEMPRE tokens sin firma. Fija el algoritmo esperado en el servidor; no dejes que el token dicte su propio algoritmo (ataque clásico de confusión de algoritmo, p. ej. RS256→HS256).
- **No guardes datos sensibles en el payload:** un JWT va firmado pero **no cifrado**; cualquiera lo decodifica en base64 y lee su contenido. Nada de PII, contraseñas ni secretos ahí.
- **Expiración corta (`exp`):** los JWT son difíciles de revocar porque son autocontenidos. Compénsalo con vida corta + **refresh tokens** rotables y revocables.
- **Revocación:** para logout real o cuentas comprometidas necesitas una estrategia (lista de revocación, versión de token en BD, o sesiones server-side). No confíes solo en "el token expira eventualmente".
- **Almacenamiento en el cliente:** preferible cookie `HttpOnly`+`Secure` sobre `localStorage` (este último es legible por cualquier XSS).

---

## 10. Gestión de secretos

Un secreto en el repositorio es un secreto comprometido — asume que ya se filtró.

- **NUNCA** commitees claves, tokens, contraseñas, cadenas de conexión ni certificados privados. Ni en código, ni en config, ni en tests, ni en el historial.
- Usa **variables de entorno** o, mejor, un **gestor de secretos** (Vault, AWS Secrets Manager, GCP Secret Manager, etc.) con acceso auditado y mínimo privilegio.
- **`.gitignore`** para `.env` y archivos de credenciales; provee un `.env.example` sin valores reales.
- **Rota** los secretos periódicamente y **de inmediato** ante cualquier sospecha de exposición.
- **Si un secreto llegó al repo:** rotarlo es lo primero (invalidar el viejo). Borrarlo del historial es secundario y no sustituye la rotación — el valor ya pudo ser clonado. Coordina esto con **git-workflow** para limpieza de historial y prevención (hooks/escáneres de secretos en pre-commit).
- Escaneo automático de secretos en CI y pre-commit para atraparlos antes del push.

---

## 11. Validación de entrada y saneamiento de salida

Dos operaciones distintas, ambas necesarias:

- **Validación de entrada (al recibir):** ¿este dato tiene la forma esperada? Tipo, rango, longitud, formato, pertenencia a un conjunto. **Allowlist siempre que puedas:** define lo que ES válido y rechaza el resto. Una denylist ("bloquea `<script>`") siempre olvida un caso; una allowlist ("solo dígitos") no.
- **Saneamiento/codificación de salida (al emitir):** transforma el dato para que sea seguro en su destino (HTML, SQL, shell, log, JSON). El MISMO dato se codifica distinto según a dónde va.

**Clave: validas al entrar, codificas al salir.** No confundas: validar no hace segura la salida, y codificar no valida la lógica de negocio.

```
Entrada  → validar (¿es un email bien formado? ¿el monto es > 0?)
Proceso  → tratar como dato, nunca como código
Salida   → codificar según contexto (HTML-encode al render, param al SQL)
```

- Valida en el servidor aunque el cliente ya valide (el cliente es cosmético).
- Rechaza temprano y explícito; no "arregles" silenciosamente entrada malformada.

---

## 12. Transporte y datos

- **HTTPS/TLS obligatorio** en todo el tráfico, sin excepciones ni "solo en login". El tráfico en claro es interceptable y modificable.
- **HSTS (`Strict-Transport-Security`):** obliga al navegador a usar HTTPS y previene downgrade a HTTP. Actívalo con `max-age` largo.
- **Cifrado en reposo:** datos sensibles y PII cifrados en disco/BD/backups. Gestiona las claves aparte de los datos.
- **PII y minimización de datos:** recolecta solo lo que necesitas, guárdalo el mínimo tiempo, restringe quién accede. El dato que no tienes no se puede filtrar. Considera anonimización/seudonimización cuando el caso de uso lo permita.
- **Datos sensibles fuera de URLs** (quedan en logs, historial, referrers). Van en el cuerpo, no en query strings.

---

## 13. Cabeceras de seguridad

Configúralas por defecto en todas las respuestas:

- **`Content-Security-Policy`:** controla orígenes de scripts/estilos/recursos. La defensa más potente contra XSS. Empieza restrictiva y afloja lo justo; evita `unsafe-inline`.
- **`Strict-Transport-Security` (HSTS):** fuerza HTTPS (ver §12).
- **`X-Content-Type-Options: nosniff`:** impide que el navegador adivine el MIME type y ejecute algo como script por error.
- **`X-Frame-Options: DENY`** (o CSP `frame-ancestors`): previene clickjacking al no permitir embeber tu sitio en iframes.
- **`Referrer-Policy`** (p. ej. `strict-origin-when-cross-origin`): limita qué URL se filtra en el header `Referer` hacia terceros.
- **`Permissions-Policy`:** restringe APIs del navegador (cámara, geolocalización) que tu app no usa.

---

## 14. Criptografía (usar, no inventar)

- **No implementes cripto propia.** Usa librerías establecidas y revisadas. La cripto casera falla en formas sutiles e invisibles hasta que es tarde.
- Algoritmos actuales y modos correctos (AES-GCM para cifrado autenticado; evita ECB y modos sin autenticación).
- Aleatoriedad **criptográficamente segura** (CSPRNG) para tokens, sales, IDs de sesión — nunca `Math.random()` ni PRNGs de propósito general.
- Gestiona el ciclo de vida de las claves: generación, almacenamiento seguro, rotación, revocación.
- Para contraseñas: hashing lento (§7). Para datos que necesitas recuperar: cifrado simétrico autenticado. Son problemas distintos con herramientas distintas.

---

## 15. Dependencias y supply chain

Tu código es tan seguro como la librería más débil que importas.

- **Escaneo continuo de vulnerabilidades** (Dependabot, `npm audit`, `pip-audit`, Snyk, etc.) en CI. Trata los CVEs como bugs bloqueantes según severidad.
- **Actualiza** con regularidad; no dejes que las dependencias envejezcan hasta acumular deuda de seguridad.
- **Lockfiles** (`package-lock.json`, `poetry.lock`, `go.sum`) commiteados: builds reproducibles y protección contra sustitución de versiones.
- **Minimiza dependencias:** cada paquete es superficie de ataque y riesgo de código malicioso. ¿Realmente necesitas esa librería para tres líneas?
- **Verifica integridad** (hashes/firmas) de artefactos y del pipeline de build. Protege credenciales de CI/CD: un pipeline comprometido inyecta en todo lo que despliega.

---

## 16. Logging seguro

El logging es doble filo: esencial para auditoría, peligroso si registra lo que no debe.

- **NUNCA loggees:** contraseñas, tokens, claves de API, cookies de sesión, PII sensible, números completos de tarjeta, contenido de secretos. Ni siquiera "temporalmente para debug" — esos logs persisten y se filtran.
- **SÍ registra para auditoría:** intentos de login (éxito y fallo), cambios de permisos, accesos a datos sensibles, operaciones administrativas, errores de seguridad. Con quién, qué, cuándo y desde dónde — sin el contenido secreto.
- **Enmascara/redacta** datos sensibles antes de escribir (p. ej. `****1234`).
- Protege los logs mismos: acceso restringido, retención definida, sin exponerlos públicamente.

Enlace: para el diseño de logging estructurado, correlación, niveles y qué es auditable, apóyate en **error-handling-observability**.

---

## 17. Manejo de errores y menor exposición

- **No filtres internals al cliente:** stack traces, mensajes de la BD, rutas de archivos, nombres de frameworks o versiones. Ayudan al atacante a mapear el sistema. Al cliente: mensaje genérico + un ID de correlación. El detalle va al log interno.
- **Mensajes uniformes** en flujos sensibles (login, reset, registro): no reveles si el email existe, si la contraseña era casi correcta, etc. Evita la enumeración.
- **Menor exposición en respuestas de API:** devuelve solo los campos necesarios. Nada de `SELECT *` serializado crudo que arrastre `password_hash`, flags internos o campos de otros usuarios. Define DTOs de salida explícitos (allowlist de campos), no listas de exclusión.
- **Fail securely (§1):** un error en la verificación de permisos deniega, no permite.

---

## 18. Rate limiting y anti-abuso

- **Rate limiting** en autenticación, reset de contraseña, verificación de OTP y endpoints costosos. Frena fuerza bruta y credential stuffing.
- **Backoff / bloqueo temporal** tras varios intentos fallidos, con cuidado de no habilitar un DoS por bloqueo (prefiere throttling progresivo + CAPTCHA sobre lockout permanente).
- **Anti-enumeración:** respuestas y tiempos uniformes para no revelar existencia de recursos/usuarios (§17).
- **Límites de negocio:** además de límites técnicos, pon topes lógicos (máximo de transferencias, de creación de recursos) para contener abuso automatizado.

---

## Anti-patrones comunes

- "Lo valido en el frontend, con eso basta." — El cliente es inspeccionable y modificable. Toda validación de seguridad es del lado servidor.
- Concatenar entrada en SQL/comandos "porque el ORM es lento aquí".
- `md5(password)` o `sha256(password)` para guardar contraseñas.
- Comprobar `if (user.isLoggedIn)` y asumir que eso autoriza el acceso al objeto (falta el check de ownership → IDOR).
- Guardar el JWT en `localStorage` y meter datos sensibles en su payload.
- Secretos hardcodeados "temporalmente" que terminan en el historial de git.
- Denylist de caracteres "peligrosos" en lugar de allowlist de lo válido.
- Devolver el stack trace al cliente en producción para "facilitar el debug".
- Desactivar la verificación de certificados TLS (`verify=False`) para que "funcione ya".
- `Math.random()` para generar tokens o IDs de sesión.
- Loggear el request completo (con Authorization header y body) "para debug".
- Confiar en `Referer`/`Origin` como ÚNICA defensa CSRF sin tokens ni `SameSite`.
- Endpoint nuevo abierto por defecto "porque todavía no configuré permisos".

---

## Checklist de seguridad antes de exponer

- [ ] Toda entrada del usuario se valida en el servidor (allowlist)
- [ ] Consultas parametrizadas / ORM; cero concatenación en SQL/NoSQL/shell
- [ ] Salida codificada según contexto; sin `innerHTML` con datos de usuario
- [ ] Autenticación con hashing fuerte (argon2/bcrypt/scrypt) + sal
- [ ] Autorización verificada en el servidor y por objeto (sin IDOR)
- [ ] Sesiones/tokens: expiración, revocación, cookies `HttpOnly`+`Secure`+`SameSite`
- [ ] JWT: algoritmo fijado, `alg:none` rechazado, sin datos sensibles en el payload
- [ ] Sin secretos en el repo; en gestor de secretos o variables de entorno
- [ ] HTTPS/TLS obligatorio y HSTS activo
- [ ] Cabeceras de seguridad configuradas (CSP, nosniff, X-Frame-Options, Referrer-Policy)
- [ ] CSRF cubierto (tokens + `SameSite`) en operaciones que cambian estado
- [ ] Rate limiting en login, reset y endpoints costosos
- [ ] Dependencias escaneadas, actualizadas y con lockfile commiteado
- [ ] Logs sin secretos/PII; eventos de seguridad auditados
- [ ] Errores genéricos al cliente; sin stack traces ni versiones expuestas
- [ ] Respuestas de API con solo los campos necesarios (DTO de salida)
- [ ] Cifrado en reposo para datos sensibles; PII minimizada
- [ ] Fail securely verificado: los errores deniegan, no permiten

---

## Skills relacionados

- **api-design** — modelado de endpoints, contratos y permisos por recurso.
- **error-handling-observability** — logging estructurado, correlación y manejo de errores sin fuga de internals.
- **database-design** — modelo de datos, permisos de BD con mínimo privilegio, cifrado en reposo.
- **git-workflow** — prevención y limpieza de secretos en el historial, hooks y escáneres en pre-commit.

---

## Referencias

- **OWASP Top 10** — https://owasp.org/www-project-top-ten/
- **OWASP Cheat Sheet Series** — https://cheatsheetseries.owasp.org/ (guías concretas por tema: Authentication, Authorization, SQL Injection Prevention, XSS Prevention, CSRF, Password Storage, JWT, Secrets Management, Logging)
- **OWASP ASVS** (Application Security Verification Standard) — requisitos verificables por nivel.
- **OWASP API Security Top 10** — riesgos específicos de APIs.
- **CWE Top 25** — debilidades de software más peligrosas.
- **NIST SP 800-63B** — guía moderna de contraseñas y autenticación.
