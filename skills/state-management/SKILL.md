---
name: state-management
description: "Gestión de estado: local vs global, server state, inmutabilidad, patrones y anti-patrones."
---

# Gestión de Estado

> **Cuándo usar:** cuando decides DÓNDE vive un dato y QUIÉN lo posee; cuando aparecen bugs de sincronización ("dos pantallas muestran valores distintos"); cuando el store global crece sin control; cuando confundes datos del servidor con estado propio de la app; cuando modelas flujos con muchas banderas booleanas (`isLoading`, `isError`, `isSuccess`) que se contradicen; cuando hay prop drilling o renders excesivos; o cuando necesitas persistir/hidratar estado (SSR, localStorage).

El estado es la parte más cara de mantener de cualquier aplicación. La lógica se prueba; el estado se DESINCRONIZA. La mayoría de los bugs de UI no son bugs de lógica: son dos copias de la misma verdad que dejaron de coincidir. Este skill trata sobre el PORQUÉ de cada decisión, no sobre una librería concreta.

---

## 1. Principios fundamentales

1. **Fuente única de verdad (SSOT).** Cada dato tiene UN dueño. Si el mismo hecho vive en dos lugares, tarde o temprano divergen. No hay excepción que valga el bug que introduce la copia.
2. **Estado mínimo.** Guarda solo lo que NO puedes calcular. Todo lo derivable se deriva; guardarlo es duplicar la verdad. Pregúntate siempre: "¿puedo calcular esto a partir de otra cosa que ya tengo?". Si sí, no lo guardes.
3. **Deriva en vez de duplicar.** El total de un carrito no es estado: es una función de los items. El "usuario filtrado" no es estado: es `items + filtro`. Duplicar y sincronizar a mano es la fábrica de bugs número uno.
4. **Inmutabilidad.** No mutes; produce nuevos valores. Habilita detección de cambios barata (comparación por referencia), predecibilidad, undo/redo y depuración por time-travel.
5. **Colocación (colocation).** El estado vive lo MÁS CERCA posible de donde se usa. Empieza local. Elévalo o globalízalo solo cuando la evidencia (compartición real) lo exija. La sobre-globalización es deuda técnica disfrazada de "por si acaso".
6. **Flujo unidireccional.** Los datos bajan, los eventos suben. Un ciclo de datos predecible (evento → cambio de estado → render) es depurable; el two-way binding descontrolado no.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Distinguir el TIPO de estado antes de elegir herramienta | Meter todo en un único store global |
| Tratar los datos del servidor como CACHÉ (server-state) | Tratar la respuesta de la API como estado de cliente propio |
| Empezar local y elevar solo al compartir | Globalizar "por si algún día se comparte" |
| Derivar valores con selectores/memos | Guardar el valor derivado y sincronizarlo a mano |
| Copiar para actualizar (inmutable) | Mutar objetos/arrays en el sitio |
| Normalizar colecciones por `id` | Anidar duplicados de la misma entidad |
| Modelar estados finitos explícitos (máquina de estados) | Multiplicar booleanos que pueden contradecirse |
| Usar Context para inyección de dependencias / temas | Usar Context como si fuera un state manager de alto tráfico |
| Actualizaciones optimistas CON rollback | Actualización optimista sin plan de reversión |
| Persistir solo lo necesario y versionar el esquema | Volcar todo el store a localStorage sin control |

---

## 3. Tipos de estado y por qué distinguirlos

El error de arquitectura más frecuente es tratar todo el estado igual. NO lo es. Cada tipo tiene un ciclo de vida, un dueño y una herramienta distinta.

- **Estado de UI local.** Un menú abierto/cerrado, el texto de un input no enviado, el tab activo, el hover. Efímero, no se comparte, muere con el componente. Herramienta: estado local del componente. NUNCA globalices esto.
- **Estado global de cliente.** Datos propios de la app, compartidos por muchas partes, que NO vienen del servidor: tema claro/oscuro, sesión/preferencias del usuario, contenido de un carrito antes de enviarlo, estado de un wizard multipágina. Herramienta: un store (Flux/Redux, atómico tipo signals/atoms, o equivalente).
- **Estado de servidor (server cache).** Datos que PERTENECEN al backend y tú solo tienes una copia temporal: listas, detalles de entidades, resultados de búsqueda. **Esto no es tu estado: es una caché de un estado remoto.** Herramienta: una librería de server-state (patrón React Query/SWR/TanStack Query).
- **Estado de URL/routing.** Filtros, paginación, `id` seleccionado, término de búsqueda, ordenamiento. Debe vivir en la URL para ser compartible, marcable y sobrevivir a un refresh. Herramienta: el router / query params. Duplicarlo en un store es un anti-patrón: la URL YA es el store.
- **Estado de formulario.** Valores, campos tocados, errores de validación, estado de envío. Tiene reglas propias (dirty, touched, submit). Herramienta: una librería de formularios o estado local acotado; no lo esparzas por un store global.

Regla: **antes de elegir dónde guardar un dato, clasifícalo.** La herramienta correcta cae por sí sola una vez sabes el tipo.

---

## 4. El error más común: server-state tratado como client-state

Esto merece su propia sección porque es el fallo que más código basura genera.

Cuando haces `fetch` y guardas la respuesta en tu store global "para tenerla", cometes el error de asumir que ese dato es TUYO. No lo es. Es una copia de algo que vive en el servidor y que **puede cambiar sin que te enteres**. Ese dato es una **caché**, y las cachés tienen problemas que tu store global no sabe resolver:

- **Staleness (obsolescencia):** ¿desde cuándo tienes ese dato? ¿sigue siendo válido?
- **Invalidación:** cuando haces una mutación (crear/editar/borrar), ¿qué cachés quedan sucias?
- **Refetch / revalidación:** al volver a la ventana, al reconectar, cada X tiempo.
- **Deduplicación:** tres componentes piden el mismo recurso a la vez → una sola petición.
- **Estados de carga/error por recurso**, no un booleano global.
- **Caché entre componentes:** navegar y volver sin re-pedir todo.

Reimplementar esto a mano en un store global es reescribir mal una librería de server-state. El patrón moderno (React Query / SWR / TanStack Query y equivalentes en otros ecosistemas) resuelve caching, dedupe, revalidación en foco/reconexión, reintentos y actualizaciones optimistas **de fábrica**. Enlaza con **api-design** para cómo estructurar las claves de caché y los endpoints, y con **performance** para el impacto de refetch y over-fetching.

**Regla dura:** los datos del servidor NO van a tu store global de cliente. Van a una caché de server-state. Tu store global es solo para estado de cliente que el servidor no posee.

---

## 5. Escalera de decisión: dónde poner el estado

No globalices por defecto. Sube por esta escalera solo cuando el peldaño actual se queda corto:

1. **¿Lo usa un solo componente?** → estado LOCAL. Fin.
2. **¿Lo comparten unos pocos componentes cercanos?** → eleva el estado al ancestro común más cercano (lifting) o compón vía props/children. No hace falta un store.
3. **¿Lo comparten muchas partes lejanas y es estado de CLIENTE?** → store global (Flux/atómico). Solo aquí.
4. **¿Viene del SERVIDOR?** → server-cache (React Query/SWR). Nunca al store global.
5. **¿Debe sobrevivir a un refresh o ser compartible por link?** → URL / query params.

Cada peldaño hacia arriba aumenta el acoplamiento y el coste de mantenimiento. Sube solo con evidencia, nunca por anticipación.

---

## 6. Colocación (colocation) y elevar

**Colocar** es mantener el estado junto al código que lo usa. Un `useState` dentro del componente que lo consume es más fácil de razonar, borrar y mover que un slice global.

Solo **elevas** (lifting state up) cuando dos hermanos necesitan compartir el mismo dato: lo mueves al padre común y lo pasas hacia abajo. Y solo llegas a un store cuando "el padre común" está tan arriba que pasar props se vuelve prop drilling doloroso a través de muchas capas.

Kent C. Dodds lo resume: **el estado debe vivir tan cerca de donde se usa como sea posible.** Empezar global es optimización prematura de acoplamiento: pagas complejidad hoy por flexibilidad que quizá nunca necesites.

---

## 7. Estado derivado

Estado derivado es cualquier valor calculable a partir de otro estado. **No se guarda: se calcula.**

- ❌ Guardar `items`, `filtro` Y `itemsFiltrados`. Ahora tienes que sincronizar `itemsFiltrados` cada vez que cambie `items` o `filtro`. Olvidarás un caso. Habrá un bug.
- ✅ Guardar `items` y `filtro`. Derivar `itemsFiltrados = items.filter(...)` en el render / en un selector memoizado.

Cuando el cálculo es caro, memoízalo (selectores tipo Reselect, `useMemo`, `computed`/derived atoms). La memoización es una optimización de rendimiento, **no** una excusa para volver a guardar el derivado como estado. Enlaza con **performance** para cuándo la memoización realmente paga.

**Regla:** si puedes calcularlo, no lo almacenes. El estado derivado guardado es una de las mayores fuentes de bugs de desincronización.

---

## 8. Inmutabilidad

**Por qué:**
- **Detección de cambios barata:** si nunca mutas, "¿cambió?" es una comparación de referencia (`prev !== next`), no un recorrido profundo. De esto dependen la memoización, `React.memo`, los selectores y el renderizado eficiente.
- **Predecibilidad:** una función que recibe un objeto y no lo muta no tiene efectos sorpresa a distancia.
- **Time-travel / undo-redo:** si cada cambio produce un nuevo valor, guardar el historial es trivial.

**Cómo:**
- No mutes: copia y reemplaza (`{...obj, campo: nuevo}`, `[...arr, x]`, `arr.map/filter`).
- Para actualizaciones anidadas profundas, usa un helper de inmutabilidad estructural (patrón Immer con drafts, o lentes/updaters) para no escribir spreads ilegibles.
- Trata arrays y objetos del estado como congelados. En desarrollo, puedes congelarlos de verdad para atrapar mutaciones accidentales.

**Regla:** una mutación silenciosa es un bug que no lanza error. Se manifiesta como "la UI no se actualizó" o "se actualizó de más". No mutes el estado, jamás.

---

## 9. Normalización del estado

Para colecciones, trata el store como una base de datos: **entidades indexadas por `id`, no árboles anidados.**

En vez de:

```
posts: [ { id: 1, autor: { id: 9, nombre: "Ana" }, comentarios: [ { id: 5, autor: { id: 9, nombre: "Ana" } } ] } ]
```

normaliza:

```
posts:       { 1: { id: 1, autorId: 9, comentarioIds: [5] } }
comentarios: { 5: { id: 5, autorId: 9 } }
usuarios:    { 9: { id: 9, nombre: "Ana" } }
allPostIds:  [1]
```

**Por qué:**
- El mismo usuario (id 9) existe UNA vez. Si cambia su nombre, se actualiza en un solo sitio; antes había que perseguir cada copia anidada (y olvidarías una → SSOT rota).
- Actualizar/insertar/borrar es O(1) por id, sin recorrer árboles.
- Se acaban los duplicados divergentes.

Aplica normalización cuando manejas colecciones relacionales con entidades compartidas. Para datos simples y planos es sobreingeniería. Muchas librerías de server-state gestionan esta caché normalizada por ti; sopesa antes de rodar la tuya.

---

## 10. Patrón Flux / Redux

**Piezas:**
- **Acción:** un objeto que describe QUÉ pasó (`{ type: 'carrito/itemAgregado', payload }`). Describe, no ejecuta.
- **Reducer:** función PURA `(estado, acción) => nuevoEstado`. Sin efectos, sin mutación, sin aleatoriedad. Misma entrada → misma salida.
- **Store:** guarda el estado y lo actualiza pasando cada acción por el reducer.
- **Unidireccionalidad:** vista despacha acción → reducer produce nuevo estado → vista re-renderiza. Un solo sentido, siempre.

**Cuándo vale la pena:** estado de cliente complejo, compartido por muchas partes, con transiciones no triviales que ganan de tener un log auditable de "qué pasó" (time-travel, debugging determinista, lógica de negocio compleja en cliente).

**Cuándo es sobreingeniería:** para estado de servidor (usa server-cache), para estado local de UI (usa estado local), o en apps pequeñas donde el boilerplate supera el beneficio. Redux mal usado como cajón de sastre de TODO el estado es el anti-patrón clásico. Las variantes atómicas (signals/atoms) reducen boilerplate para muchos casos; evalúa según complejidad real.

---

## 11. Máquinas de estado (statecharts)

Cuando un flujo tiene estados finitos con transiciones definidas, modélalo como máquina de estados explícita (patrón XState/statecharts) en vez de con un puñado de booleanos.

El problema de los booleanos: con `isLoading`, `isError`, `isSuccess`, `isEmpty` tienes 2⁴ = 16 combinaciones, pero solo 4 o 5 son válidas. Nada impide `isLoading && isError && isSuccess = true`: un estado imposible que igual ocurre por un bug de sincronización, y tu UI muestra algo absurdo.

Con una máquina de estados declaras estados MUTUAMENTE EXCLUYENTES: `idle | loading | success | error`. Solo puedes estar en UNO. Las transiciones son explícitas (`loading --éxito--> success`, `loading --fallo--> error`). Los estados imposibles dejan de ser representables. Ganas: diagramas del flujo, transiciones inválidas bloqueadas por diseño, y lógica testeable sin tocar la UI.

**Regla:** si te encuentras escribiendo `if (isLoading && !isError && ...)`, tu estado quiere ser una máquina de estados.

---

## 12. Actualizaciones optimistas y rollback

Una actualización optimista aplica el cambio en la UI **antes** de que el servidor confirme, para que la interfaz se sienta instantánea. El riesgo: si el servidor falla, tu UI muestra una mentira.

Toda actualización optimista necesita un plan de reversión:

1. **Guarda el estado previo** (snapshot).
2. **Aplica el cambio** optimista en la UI.
3. **Lanza la petición.**
4. **En error → rollback** al snapshot y muestra el fallo.
5. **En éxito → confirma / revalida** contra la respuesta real del servidor (por si el server ajustó algo).

Las librerías de server-state ofrecen este ciclo (`onMutate` / `onError` / `onSettled` en el patrón React Query). No hagas optimismo sin rollback: es peor que no ser optimista, porque el usuario cree que su acción funcionó cuando no.

---

## 13. Context / provider: no es un state manager

El Context (patrón provider/inyección) resuelve el paso de valores por el árbol sin prop drilling. Es ideal para dependencias estables y de baja frecuencia: tema, idioma (i18n), usuario autenticado, cliente de API.

**No** es un gestor de estado de alto tráfico. Cuando el valor del provider cambia, **todos** los consumidores re-renderizan, sin selectores finos que acoten el impacto. Meter estado que cambia rápido (posición del cursor, texto que se teclea, datos de servidor) en un Context es una fuente clásica de renders excesivos.

**Regla:** Context para inyección de dependencias y valores casi-estáticos; store real (con selectores) o server-cache para estado que cambia seguido. Enlaza con **frontend-architecture** (composición, separación de capas) y **performance** (coste de re-render por Context).

---

## 14. Persistencia, hidratación y SSR

- **Persistencia (localStorage/sessionStorage/IndexedDB):** persiste SOLO lo que debe sobrevivir a un refresh (preferencias, borradores, sesión). No vuelques todo el store: agrandas el arranque y arriesgas guardar datos sensibles o efímeros. `sessionStorage` para lo que muere con la pestaña; `localStorage` para lo persistente.
- **Versiona el esquema persistido** y ten migraciones. Un usuario con un store viejo en disco romperá tu app tras un deploy si el shape cambió.
- **No persistas server-state:** deja que la caché de server-state gestione su propia persistencia/revalidación; un dato del servidor guardado en localStorage nace obsoleto.
- **Hidratación / SSR:** el servidor renderiza con un estado inicial y el cliente debe "hidratar" con EXACTAMENTE el mismo estado, o hay mismatch (parpadeos, warnings, re-renders). Serializa el estado inicial del servidor y reconstrúyelo idéntico en cliente. El server-state suele exponer deshidratar/rehidratar la caché para SSR.
- **Cuidado con valores no deterministas** (fechas, aleatorios, acceso a `window`) en el render inicial: rompen la coincidencia servidor↔cliente.

---

## 15. Efectos secundarios y sincronización con el exterior

El estado a veces debe sincronizarse con el mundo fuera de tu app: red, WebSockets, `localStorage`, timers, media, `document`/`window`.

- Aísla los efectos en el borde (capa de efectos, hooks dedicados, middleware/sagas/listeners), no dispersos en la lógica de render.
- Un efecto que sincroniza debe **limpiarse** (cerrar sockets, cancelar timers, quitar listeners) para no fugar ni duplicar suscripciones.
- Evita "efectos que copian estado a estado": si un efecto solo existe para reflejar un valor en otro, casi siempre querías estado DERIVADO, no un efecto.
- Para datos remotos, prefiere el server-cache antes que orquestar `fetch` a mano dentro de efectos: te ahorra el ciclo de carga/error/cancelación/dedupe.

---

## 16. Anti-patrones comunes

- **Todo en el store global.** Convertir el store en un cajón de sastre para estado local de UI, formularios y server-state. Acopla todo, dispara renders y hace imposible razonar sobre ownership.
- **Duplicar estado de servidor.** Copiar la respuesta de la API a tu store "para tenerla". Nace obsoleta y te obliga a reimplementar invalidación mal. Usa server-cache.
- **Estado derivado guardado.** Almacenar el total, el filtrado o el "hay errores" cuando son calculables. Sincronización manual → desincronización garantizada.
- **Mutaciones en el sitio.** `obj.campo = x` / `arr.push(y)` sobre el estado. Rompe detección de cambios; la UI no refleja el cambio o refleja de más.
- **Prop drilling vs sobre-globalizar (los dos extremos).** Pasar props por 8 capas es doloroso; pero "resolverlo" metiendo todo en global es peor. La respuesta suele ser composición, colocación correcta o un Context acotado, no globalizar.
- **Booleanos que se contradicen.** `isLoading`, `isError`, `isSuccess` como banderas sueltas que permiten estados imposibles. Usa una máquina de estados o una enum de estado único.
- **URL ignorada.** Guardar filtros/paginación en un store en vez de la URL: pierdes compartir por link, back/forward y sobrevivir al refresh.
- **Context para todo.** Usar Context como store de alto tráfico y luego pelear con renders.
- **Optimismo sin rollback.** Aplicar cambios optimistas sin snapshot ni reversión: la UI miente cuando el servidor falla.

---

## 17. Checklist de gestión de estado

- [ ] Clasifiqué cada dato por tipo (UI local / cliente global / servidor / URL / formulario).
- [ ] El estado de servidor vive en un server-cache, NO en el store global.
- [ ] Cada dato tiene UN dueño (fuente única de verdad); no hay copias que sincronizar.
- [ ] Empecé local y elevé/globalicé solo con evidencia de compartición real.
- [ ] Los valores derivados se CALCULAN (selectores/memos), no se guardan.
- [ ] Ninguna actualización muta; todo produce nuevos valores (inmutabilidad).
- [ ] Las colecciones relacionales están normalizadas por `id`.
- [ ] Los flujos con estados finitos usan máquina de estados, no un enjambre de booleanos.
- [ ] Las actualizaciones optimistas tienen snapshot y rollback.
- [ ] Context se usa para inyección/valores casi-estáticos, no como store de alto tráfico.
- [ ] Filtros/paginación/selección relevantes viven en la URL.
- [ ] Solo persisto lo necesario, con esquema versionado; el server-state no se persiste crudo.
- [ ] La hidratación SSR reconstruye un estado inicial idéntico servidor↔cliente.
- [ ] Los efectos que sincronizan con el exterior se limpian y no copian estado a estado.

---

## 18. Referencias

- **Redux — Style Guide / "Deriving Data with Selectors" / "Normalizing State Shape"** — reducers puros, unidireccionalidad, selectores y normalización.
- **TanStack Query (React Query) / SWR** — patrón de server-state: caching, dedupe, revalidación, invalidación y actualizaciones optimistas.
- **XState / statecharts (David Harel)** — máquinas de estado finito y jerárquicas para modelar flujos complejos sin estados imposibles.
- **Kent C. Dodds — "State Colocation will make your React app faster" / "Application State Management"** — colocación y clasificación de estado.
- **Immer** — inmutabilidad ergonómica mediante drafts para actualizaciones anidadas.

**Skills relacionados:** `frontend-architecture` (composición, capas, dónde encaja el estado en la arquitectura), `performance` (memoización, coste de renders y refetch), `api-design` (claves de caché, forma de endpoints y contrato con el server-state).
