---
name: database-design
description: "Modelado de datos: normalización, índices, transacciones, migraciones, N+1, integridad."
---

# Diseño de Bases de Datos

> **Cuándo usar:** al crear o modificar un esquema; al elegir claves, tipos o índices; al escribir migraciones; al diagnosticar consultas lentas, bloqueos o N+1; al decidir SQL vs NoSQL; al modelar relaciones o auditoría. Léela ANTES de tocar DDL o el ORM.

El esquema es el contrato más duro del sistema: el código se refactoriza en una tarde, los datos migrados sobreviven años. Diseña pensando en cómo se **consulta** y cómo **evoluciona**, no solo en cómo se guarda.

## 1. Principios fundamentales

- **La verdad vive en la base de datos, no en la aplicación.** Las invariantes críticas (unicidad, referencias, rangos) se protegen con constraints, no solo con validación en código: hay múltiples clientes, procesos batch y consolas que escriben.
- **Modela el dominio primero, optimiza después.** Empieza normalizado y correcto; desnormaliza con medición y motivo, no por intuición.
- **Diseña para el patrón de acceso.** En SQL normalizas y luego indexas para tus queries; en NoSQL diseñas el modelo alrededor de las queries desde el día uno.
- **Toda escritura importante es transaccional.** Si dos filas deben cambiar juntas o ninguna, van en la misma transacción.
- **El esquema evoluciona; planifícalo.** Cada cambio es una migración versionada, reversible y sin downtime. No hay "editar la tabla a mano en producción".
- **Los datos superan en tamaño a la RAM y a tu paciencia.** Lo que funciona con 10 mil filas puede colapsar con 10 millones. Piensa en cardinalidad y en el plan de ejecución.

## 2. Reglas de oro (Haz / Evita)

| Haz | Evita |
| --- | --- |
| Declarar `NOT NULL` por defecto y relajar solo con motivo | Columnas nullable "por si acaso" |
| Claves foráneas con `ON DELETE` explícito | Integridad referencial solo en el código |
| Índices guiados por `EXPLAIN` y queries reales | Indexar todo "por las dudas" |
| Timestamps en UTC (`timestamptz`) | `timestamp` sin zona o hora local |
| Transacciones cortas y enfocadas | Transacciones que abarcan llamadas de red o input de usuario |
| Migraciones expand/contract en dos fases | `ALTER` destructivos en un solo despliegue |
| Tipos precisos (`numeric` para dinero, `uuid`, `enum`) | `varchar` o `float` para todo |
| Paginación por cursor en listas grandes | `OFFSET` alto en tablas grandes |
| `SELECT` de columnas explícitas | `SELECT *` en código de producción |
| Restricciones `CHECK` para estados válidos | Confiar en que "la app nunca insertará eso" |

## 3. Modelado: entidades y relaciones

Identifica **entidades** (sustantivos del dominio: `usuario`, `pedido`, `producto`) y las **relaciones** entre ellas. La cardinalidad decide la forma de las tablas.

- **1:1** — mismo ciclo de vida o separación por acceso/seguridad. FK con `UNIQUE` en la tabla dependiente, o comparten PK. Úsalo con moderación: a menudo es una sola tabla partida sin razón.
  ```sql
  CREATE TABLE perfil (
    usuario_id bigint PRIMARY KEY REFERENCES usuario(id) ON DELETE CASCADE,
    bio text
  );
  ```
- **1:N** — el caso más común. La FK vive en el lado "muchos".
  ```sql
  CREATE TABLE pedido (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id bigint NOT NULL REFERENCES usuario(id),
    creado_en timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);
  ```
- **N:M** — requiere **tabla puente** (join table). Su PK compuesta es el par de FKs; añade atributos de la relación aquí (cantidad, rol, fecha).
  ```sql
  CREATE TABLE pedido_producto (
    pedido_id   bigint NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    producto_id bigint NOT NULL REFERENCES producto(id),
    cantidad    int NOT NULL CHECK (cantidad > 0),
    precio_unit numeric(12,2) NOT NULL,
    PRIMARY KEY (pedido_id, producto_id)
  );
  ```

**Claves primarias:** toda tabla tiene una. Prefiere una clave sustituta (surrogate) estable frente a claves naturales que pueden cambiar (email, DNI). **Claves foráneas:** siempre declaradas; indexa la columna FK salvo que ya sea prefijo de otro índice.

## 4. Normalización

Normalizar = eliminar redundancia para que cada hecho viva en un solo lugar. Evita anomalías de inserción, actualización y borrado.

- **1NF — valores atómicos.** Nada de listas en una celda ni columnas repetidas (`tel1`, `tel2`, `tel3`). Cada fila es única.
  - Mal: `etiquetas = "rojo,grande,oferta"` → Bien: tabla `producto_etiqueta`.
- **2NF — sin dependencias parciales.** En 1NF y cada atributo no clave depende de **toda** la PK, no de parte de ella. Relevante con PK compuesta.
  - Mal: en `pedido_producto(pedido_id, producto_id, nombre_producto)`, `nombre_producto` depende solo de `producto_id` → muévelo a `producto`.
- **3NF — sin dependencias transitivas.** Ningún atributo no clave depende de otro atributo no clave.
  - Mal: `pedido(id, cp, ciudad)` donde `ciudad` depende de `cp` → separa a una tabla de códigos postales.

Regla mnemotécnica: *cada atributo depende de la clave, de toda la clave, y de nada más que la clave.* Para la mayoría de sistemas OLTP, **3NF es el objetivo**.

**Desnormaliza a propósito** cuando: (1) hay un cuello de botella medido en lecturas, (2) el dato de origen es inmutable o histórico (guardar `precio_unit` en la línea de pedido es correcto: es el precio *en ese momento*), (3) un contador/agregado se lee muchísimo más de lo que se actualiza. Documenta la redundancia y define cómo se mantiene coherente (trigger, job, columna calculada).

## 5. Elección de claves: autoincremental vs UUID/ULID

| Criterio | Autoincremental (`bigint identity`) | UUID v4 | ULID / UUIDv7 |
| --- | --- | --- | --- |
| Localidad de índice (B-tree) | Excelente (secuencial) | Mala (aleatorio → fragmentación) | Buena (ordenado por tiempo) |
| Generable en el cliente | No | Sí | Sí |
| Enumerable / filtrable por atacante | Sí (expone volumen) | No | Parcial (contiene tiempo) |
| Tamaño | 8 bytes | 16 bytes | 16 bytes |
| Merge entre bases / sharding | Difícil | Fácil | Fácil |

- **Autoincremental**: mejor rendimiento de inserción e índices compactos; ideal para monolito con una sola BD. Desventaja: filtrable y difícil de fusionar.
- **UUID v4**: aleatoriedad total; **penaliza** los B-tree porque cada insert cae en una página distinta (page splits, cache misses). Evítalo como PK en tablas grandes de escritura intensa.
- **ULID / UUIDv7**: lo mejor de ambos: globalmente único **y** ordenable en el tiempo → localidad de índice sana. Preferido cuando necesitas IDs generados por el cliente o sistemas distribuidos.

Truco: si usas UUID por requisitos externos pero quieres índices sanos, usa **UUIDv7/ULID** o mantén una PK `bigint` interna + una columna `uuid` pública indexada.

## 6. Índices

Un índice acelera lecturas a cambio de espacio y de coste en cada escritura. No son gratis.

- **Qué indexar:** columnas en `WHERE`, `JOIN`, `ORDER BY` y FKs. Prioriza alta selectividad (muchos valores distintos).
- **Índices compuestos y orden de columnas:** el orden importa. La regla es **igualdad → rango → orden**: columnas con predicados de igualdad primero, luego la de rango, luego las de ordenación. Un índice `(a, b)` sirve para filtrar por `a` y por `a AND b`, pero **no** para filtrar solo por `b` (regla del prefijo izquierdo).
  ```sql
  -- Query: WHERE tenant_id = ? AND estado = ? ORDER BY creado_en DESC
  CREATE INDEX idx_pedido_busqueda ON pedido (tenant_id, estado, creado_en DESC);
  ```
- **Índices cubrientes (covering):** si el índice contiene todas las columnas que la query necesita, se resuelve sin tocar la tabla (index-only scan). En PostgreSQL usa `INCLUDE`:
  ```sql
  CREATE INDEX idx_cover ON pedido (usuario_id) INCLUDE (estado, total);
  ```
- **Índices parciales:** indexa solo el subconjunto relevante; más pequeños y rápidos.
  ```sql
  CREATE INDEX idx_pedido_activos ON pedido (usuario_id) WHERE eliminado_en IS NULL;
  ```
- **Cuándo NO indexar:** columnas de baja cardinalidad (booleanos, un `estado` con 3 valores) salvo en índice parcial/compuesto; tablas pequeñas (el scan secuencial gana); columnas que casi no se consultan.
- **Coste en escrituras:** cada `INSERT`/`UPDATE`/`DELETE` mantiene **todos** los índices de la tabla. Diez índices = diez estructuras que actualizar por escritura. Índices sin uso son puro lastre: audítalos (`pg_stat_user_indexes`) y elimina los muertos.

## 7. Integridad de datos

Las constraints son documentación ejecutable y la última línea de defensa.

- **`NOT NULL`** — por defecto. `NULL` significa "desconocido", no "cero" ni "vacío", y contamina comparaciones (`NULL = NULL` es `NULL`).
- **`UNIQUE`** — unicidad de negocio (email, slug). Puede ser compuesta.
- **`CHECK`** — invariantes de dominio: `CHECK (total >= 0)`, `CHECK (estado IN ('nuevo','pagado','enviado'))`, `CHECK (fin > inicio)`.
- **`FOREIGN KEY`** — integridad referencial: impide referenciar filas inexistentes y borrados que dejarían huérfanos.
- **`ON DELETE` / `ON UPDATE`:**
  - `RESTRICT` / `NO ACTION` — bloquea el borrado del padre si hay hijos (por defecto y más seguro).
  - `CASCADE` — borra/actualiza los hijos. Potente y peligroso: úsalo solo cuando el hijo no tiene vida propia (líneas de un pedido, sí; pedidos de un usuario, probablemente no).
  - `SET NULL` — deja la FK en `NULL` (la columna debe ser nullable).

## 8. Transacciones y ACID

**ACID**: Atomicidad (todo o nada), Consistencia (respeta las reglas del esquema), Aislamiento (las transacciones concurrentes no se pisan), Durabilidad (lo confirmado persiste ante caídas).

**Niveles de aislamiento** (SQL estándar, de menos a más estricto) y anomalías que previenen:

| Nivel | Dirty read | Non-repeatable read | Phantom read |
| --- | --- | --- | --- |
| Read Uncommitted | Posible | Posible | Posible |
| Read Committed | No | Posible | Posible |
| Repeatable Read | No | No | Posible* |
| Serializable | No | No | No |

\* En PostgreSQL, Repeatable Read usa snapshot y **también** evita phantoms; Serializable añade detección de anomalías de serialización (puede abortar con error de serialización, hay que reintentar).

- **Dirty read:** leer datos que otra transacción aún no confirmó (y quizá revierta).
- **Non-repeatable read:** leer la misma fila dos veces y obtener valores distintos porque otra transacción la modificó y confirmó en medio.
- **Phantom read:** re-ejecutar la misma consulta de rango y aparecen/desaparecen filas.

**Default:** la mayoría de bases usan **Read Committed**, buen equilibrio. Sube a **Repeatable Read/Serializable** para lógica financiera o invariantes multi-fila, y **prepárate a reintentar** ante errores de serialización.

## 9. Bloqueos, deadlocks y transacciones cortas

- **Mantén las transacciones cortas.** Nunca abras una transacción y hagas dentro una llamada HTTP, esperes input del usuario o proceses un archivo. Prepara los datos fuera; abre, escribe, cierra.
- **Deadlock:** dos transacciones se esperan mutuamente por recursos en orden inverso. El motor mata a una (víctima) y devuelve error.
- **Evitarlos:** (1) accede a las tablas/filas **siempre en el mismo orden**; (2) transacciones cortas y con pocos locks; (3) usa `SELECT ... FOR UPDATE` para bloquear explícitamente en orden determinista; (4) reduce el nivel de aislamiento si no necesitas más; (5) **reintenta** con backoff: los deadlocks y errores de serialización son normales, no excepcionales.
- Evita long-running `UPDATE`s masivos que bloquean tablas enteras; procésalos por lotes.

## 10. El problema N+1

Ocurre cuando cargas una lista (1 query) y luego, por cada elemento, lanzas otra query. 100 pedidos → 1 + 100 = 101 queries.

```
-- Anti-patrón (pseudo-ORM)
pedidos = Pedido.all()               -- 1 query
for p in pedidos:
    print(p.usuario.nombre)          -- +1 query por pedido → N+1
```

**Soluciones:**
- **Eager loading** — indica al ORM que precargue la relación (`includes`, `with`, `joinedload`, `prefetch_related`). Genera 1–2 queries en lugar de N+1.
- **JOIN explícito** — trae todo en una sola consulta cuando quieres campos de ambas tablas.
  ```sql
  SELECT p.id, u.nombre
  FROM pedido p JOIN usuario u ON u.id = p.usuario_id;
  ```
- **Carga por lotes (batch / `IN`)** — recoge los IDs y haz una sola query: `WHERE usuario_id IN (...)`, luego mapea en memoria. Base del patrón DataLoader.

Detéctalo: cuenta las queries en desarrollo (logs del ORM, `bullet`, herramientas APM). Un endpoint cuyo número de queries crece con el tamaño de la lista es N+1.

## 11. Optimización de consultas

- **`EXPLAIN` / `EXPLAIN ANALYZE`:** `EXPLAIN` muestra el plan estimado; `ANALYZE` lo **ejecuta** y da tiempos y filas reales. Busca `Seq Scan` sobre tablas grandes, estimaciones muy distintas de las reales (estadísticas desactualizadas → `ANALYZE`), y nested loops con muchas iteraciones.
- **Evita `SELECT *`:** trae columnas de más (I/O, red), rompe índices cubrientes y hace frágil el código ante cambios de esquema. Lista las columnas.
- **Predicados sargables** (Search ARGument ABLE): permiten usar el índice. No apliques funciones sobre la columna indexada.
  ```sql
  -- No sargable (ignora el índice sobre creado_en):
  WHERE date(creado_en) = '2026-06-30'
  -- Sargable:
  WHERE creado_en >= '2026-06-30' AND creado_en < '2026-07-01'
  ```
  Igual con `WHERE lower(email) = ?` → usa un índice funcional o guarda el email normalizado.
- **Paginación por cursor (keyset)** en vez de `OFFSET`: `OFFSET 100000` obliga a leer y descartar 100 000 filas. El cursor salta directo con el índice:
  ```sql
  SELECT * FROM pedido
  WHERE (creado_en, id) < (:ultimo_creado, :ultimo_id)
  ORDER BY creado_en DESC, id DESC
  LIMIT 20;
  ```
- Evita `count(*)` exacto sobre tablas enormes en cada request; usa estimaciones o contadores materializados.

## 12. Migraciones

- **Versionadas:** cada cambio es un archivo ordenado, en control de versiones, aplicado por una herramienta (Flyway, Liquibase, Alembic, Prisma Migrate, Rails). Nunca cambios manuales en producción.
- **Reversibles:** define el `down` o un plan de rollback. Si no es reversible (borrar una columna con datos), documéntalo y protégelo.
- **Sin downtime — patrón expand/contract:**
  1. **Expand:** añade lo nuevo de forma compatible hacia atrás (nueva columna nullable, nueva tabla, nuevo índice `CONCURRENTLY`). El código viejo sigue funcionando.
  2. **Migrate/backfill + doble escritura:** el código nuevo escribe en ambos sitios; rellenas datos históricos.
  3. **Contract:** cuando nada usa lo viejo, elimínalo en un despliegue posterior.
- **Backfills seguros:** procesa por **lotes** (p. ej. 1 000–10 000 filas) con pausas; un `UPDATE` de toda la tabla bloquea y satura el WAL/replicación. Hazlo idempotente y reanudable.
- Cuidado con operaciones que **reescriben la tabla o toman lock fuerte** (añadir columna con default volátil en motores antiguos, cambiar tipo). En PostgreSQL crea índices con `CREATE INDEX CONCURRENTLY` y valida constraints en dos pasos (`NOT VALID` → `VALIDATE CONSTRAINT`).

## 13. SQL vs NoSQL

Elige por el patrón de acceso y las garantías, no por moda.

| Tipo | Modelo | Fuerte en | Débil en | Ejemplos |
| --- | --- | --- | --- | --- |
| **Relacional (SQL)** | Tablas + relaciones | Integridad, transacciones, queries ad-hoc, joins | Escala horizontal de escritura, esquema muy variable | PostgreSQL, MySQL |
| **Documental** | JSON anidado por documento | Esquema flexible, agregados que se leen juntos | Joins complejos, transacciones multi-documento | MongoDB, Couchbase |
| **Clave-valor** | `clave → valor` | Latencia mínima, caché, sesiones, rate limit | Consultas por valor, relaciones | Redis, DynamoDB |
| **Columnar / analítica** | Orientado a columnas | Agregaciones sobre miles de millones de filas (OLAP) | Escrituras/updates fila a fila (OLTP) | ClickHouse, BigQuery, Redshift |
| **Grafo** | Nodos + aristas | Recorridos de relaciones (redes, recomendaciones, fraude) | Cargas analíticas masivas, escritura simple | Neo4j, Neptune |

Regla práctica: **empieza en PostgreSQL.** Cubre relacional, JSONB (documental), clave-valor y búsqueda razonable. Cambia de motor cuando tengas un problema concreto y medido que Postgres no resuelve.

## 14. Modelado según patrón de acceso (query-first en NoSQL)

En SQL modelas las entidades y luego escribes queries. En NoSQL (sobre todo clave-valor/documental como DynamoDB) es al revés: **enumera primero los patrones de acceso** ("dame los pedidos de un usuario ordenados por fecha", "dame el último estado de un dispositivo") y diseña las claves (partition key + sort key), índices secundarios y la forma del documento para servir esas queries en O(1). Duplicar datos para servir cada patrón es normal aquí; consistencia se gestiona en la escritura. Si tus patrones de acceso son impredecibles o necesitas joins ad-hoc, ese es un fuerte indicio de que quieres SQL.

## 15. Borrado, auditoría y timestamps

- **Soft delete vs hard delete:** *soft delete* marca `eliminado_en timestamptz` en vez de borrar. Úsalo cuando necesitas historial, papelera, auditoría o referencias. Coste: **todas** las queries deben filtrar `WHERE eliminado_en IS NULL` (usa índice parcial o una vista) y las constraints `UNIQUE` deben contemplar los borrados. *Hard delete* cuando el dato es basura o lo exige la ley (derecho al olvido). A menudo: soft delete + purga programada.
- **Auditoría mínima:** `created_at` y `updated_at` en toda tabla; añade `created_by`/`updated_by` si importa quién. Para historial completo, tabla de auditoría append-only o triggers.
- **Timestamps en UTC siempre.** Guarda en `timestamptz`/UTC; convierte a la zona del usuario solo en presentación. Mezclar zonas en la base es fuente inagotable de bugs.

## 16. Connection pooling

Abrir una conexión a la base es caro (handshake, autenticación, memoria por conexión en el servidor). Sin pool, cada request paga ese coste y saturas el límite de conexiones (`max_connections`) bajo carga. Un **pool** reutiliza un conjunto acotado de conexiones. En entornos serverless o con muchas instancias, usa un pooler externo (PgBouncer, RDS Proxy) en modo transaction pooling para no multiplicar conexiones. Dimensiona el pool: más conexiones no es más rápido; suele haber un óptimo cercano a `núcleos * 2` a nivel de base. Ver skill **performance**.

## 17. Particionado y sharding

- **Particionado** (una sola base): divide una tabla grande en particiones por rango (fecha), lista o hash. Mejora mantenimiento (purgar un mes = soltar una partición) y permite podar particiones en las queries. Útil desde decenas de millones de filas o series temporales.
- **Sharding** (varias bases): reparte los datos entre servidores por una **shard key**. Escala escritura y almacenamiento más allá de una máquina, pero complica joins, transacciones y unicidad global. Es una decisión de última instancia: agota réplicas de lectura, índices, particionado y caché antes. Elige la shard key con cuidado (evita hotspots).

## 18. Datos sensibles

- **Nunca guardes secretos en claro.** Contraseñas → hash con `bcrypt`/`argon2` (nunca cifrado reversible ni MD5/SHA). Tokens/API keys → guarda solo el hash.
- **Cifrado en reposo** a nivel de disco/volumen (TDE, discos cifrados) y **cifrado a nivel de columna** para PII especialmente sensible.
- **Minimiza y separa:** no almacenes lo que no necesitas (números de tarjeta → usa un proveedor PCI). Restringe el acceso por rol; no uses el usuario superadmin desde la app.
- No metas PII ni secretos en logs, mensajes de error ni claves/índices. Ver skill **security**.

## 19. Concurrencia: optimistic vs pessimistic locking

Dos usuarios leen la misma fila y la actualizan; sin control, el segundo pisa al primero (**lost update**).

- **Optimistic locking:** asume que los conflictos son raros. Añade una columna `version` (o usa `updated_at`). Al actualizar, comprueba que no cambió; si cambió, la actualización afecta 0 filas → rechaza y reintenta.
  ```sql
  UPDATE cuenta SET saldo = :nuevo, version = version + 1
  WHERE id = :id AND version = :version_leida;
  -- 0 filas afectadas ⇒ alguien más escribió: recarga y reintenta
  ```
  Ideal para web (sin locks mantenidos entre requests), alta concurrencia con pocos choques.
- **Pessimistic locking:** asume conflictos frecuentes; bloquea la fila al leer con `SELECT ... FOR UPDATE` y la retiene hasta el commit. Garantiza exclusión pero reduce concurrencia y puede causar deadlocks. Úsalo para operaciones cortas y críticas (decrementar stock, mover saldo) dentro de una transacción breve.

## Anti-patrones comunes

- **EAV (Entity-Attribute-Value):** tabla genérica `(entidad, atributo, valor)` para "flexibilidad". Destruye tipado, constraints y rendimiento. Usa columnas reales o `JSONB` acotado.
- **Columnas multivalor:** CSV en una celda (`"1,4,9"`). Rompe 1NF; imposible indexar/joinear. Usa tabla puente.
- **Todo `varchar`/`text` y `NULL`:** pierdes validación e índices eficientes. Tipa fuerte (`numeric`, `boolean`, `enum`, `timestamptz`).
- **Sin claves foráneas "por rendimiento":** ahorras microsegundos y compras datos huérfanos y corrupción silenciosa.
- **`float` para dinero:** errores de redondeo. Usa `numeric`/`decimal` o enteros en la unidad mínima (céntimos).
- **Indexar todo / no indexar nada:** ambos extremos duelen. Mide con `EXPLAIN` y estadísticas de uso.
- **Lógica de negocio pesada en triggers ocultos:** difícil de depurar y testear. Úsalos para auditoría/integridad, no para orquestar procesos.
- **UUIDv4 como PK en tablas de escritura intensa:** fragmentación de índice. Usa ULID/UUIDv7 o `bigint`.
- **Transacciones que envuelven llamadas externas:** locks retenidos durante segundos → contención y deadlocks.
- **`OFFSET` grande para paginar:** degradación lineal. Usa keyset/cursor.
- **Estados como texto libre sin `CHECK`/enum:** aparecen `"Pagado"`, `"pagado"`, `"PAGADO"`.

## Checklist de diseño de esquema

- [ ] Cada tabla tiene PK estable (surrogate salvo motivo claro)
- [ ] Estrategia de clave elegida a conciencia (bigint / ULID / UUIDv7) según acceso y distribución
- [ ] Relaciones modeladas con la cardinalidad correcta; N:M con tabla puente
- [ ] Esquema en 3NF; toda desnormalización está justificada y documentada
- [ ] Columnas `NOT NULL` por defecto; nullables justificados
- [ ] FKs declaradas con `ON DELETE`/`ON UPDATE` explícitos
- [ ] Constraints `UNIQUE` y `CHECK` que codifican las reglas de negocio
- [ ] Tipos precisos (`numeric` para dinero, `timestamptz` en UTC, `enum`/`CHECK` para estados)
- [ ] Índices para `WHERE`/`JOIN`/`ORDER BY`/FKs; compuestos con orden correcto
- [ ] Sin `SELECT *`; predicados sargables; paginación por cursor en listas grandes
- [ ] Sin N+1 en los caminos de lectura calientes (eager/batch verificado)
- [ ] Transacciones cortas; nivel de aislamiento adecuado; estrategia de reintento ante conflictos
- [ ] Estrategia de concurrencia definida (columna `version` u `FOR UPDATE` donde haga falta)
- [ ] `created_at`/`updated_at`; política de soft vs hard delete decidida
- [ ] Migraciones versionadas, reversibles, expand/contract; backfills por lotes
- [ ] Datos sensibles hasheados/cifrados; sin secretos en claro ni en logs
- [ ] Connection pooling configurado y dimensionado
- [ ] Planes revisados con `EXPLAIN ANALYZE` sobre datos representativos

## Referencias

- PostgreSQL — Indexes: https://www.postgresql.org/docs/current/indexes.html
- PostgreSQL — Transaction Isolation: https://www.postgresql.org/docs/current/transaction-iso.html
- PostgreSQL — Explicit Locking / EXPLAIN: https://www.postgresql.org/docs/current/explicit-locking.html · https://www.postgresql.org/docs/current/using-explain.html
- Use The Index, Luke! (índices y SQL performance): https://use-the-index-luke.com/
- Zero-downtime migrations (expand/contract): https://www.postgresql.org/docs/current/ddl-alter.html
- Martin Fowler — Optimistic Offline Lock / EAV: https://martinfowler.com/eaaCatalog/
- ULID spec: https://github.com/ulid/spec · UUIDv7 (RFC 9562): https://www.rfc-editor.org/rfc/rfc9562

**Skills relacionadas:** `performance` (pooling, caché, medición), `security` (cifrado, PII, secretos), `api-design` (paginación, contratos de lectura, exposición de IDs).
