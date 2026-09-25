---
name: testing
description: "Estrategia de tests: pirámide, TDD, unit/integration/e2e, dobles, cobertura con valor."
---

# Testing y Calidad

> **Cuándo usar:** antes de escribir cualquier test nuevo; al diseñar la suite de un módulo o servicio; cuando un bug llega a producción y hay que reproducirlo; cuando los tests son lentos, frágiles o "flaky"; cuando vas a refactorizar y necesitas una red de seguridad; cuando revisas un PR con tests. Si tocas dobles de prueba, cobertura, fixtures o CI, lee esto primero.

Un test no es burocracia: es una AFIRMACIÓN EJECUTABLE sobre el comportamiento de tu sistema. Escrito bien, te deja refactorizar sin miedo y documenta la intención mejor que cualquier comentario. Escrito mal, es un ancla que castiga cada cambio y no atrapa ningún bug. La diferencia casi nunca está en la herramienta; está en QUÉ decides verificar y CÓMO lo aíslas.

---

## 1. Principios fundamentales

1. **Un test verifica COMPORTAMIENTO OBSERVABLE, no detalles internos.** Si el test conoce cómo está construido por dentro el código, cada refactor lo rompe aunque el comportamiento no cambie. Eso es acoplamiento a la implementación, y es la causa número uno de suites que la gente termina odiando.
2. **La confianza es la moneda.** El valor de una suite es cuánto te permite cambiar el código sin miedo. Un test que no te da confianza (o que falla por razones equivocadas) es pasivo, no activo.
3. **Rápido y determinista o no sirve.** Un test que tarda o que falla de forma intermitente deja de ejecutarse. Y un test que no se ejecuta no existe.
4. **El test es el primer CLIENTE de tu diseño.** Si cuesta testear algo, casi siempre es el DISEÑO el que está mal (dependencias ocultas, acoplamiento, funciones que hacen demasiado), no el test. Escucha ese dolor.
5. **Cada bug corregido nace con un test que lo reproduce.** Sin excepción. El test primero falla (demuestra el bug), luego el fix lo pone en verde. Así garantizas que la regresión no vuelve.

> Relación con otras skills: el diseño testeable es diseño limpio (ver `refactoring`); los tests son el input principal de una revisión (ver `code-review`); qué observas y afirmas sobre errores conecta con `error-handling-observability`.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Testear el comportamiento público / los contratos | Testear métodos privados y estado interno |
| Un solo concepto verificado por test | Un test que valida cinco cosas a la vez |
| Nombres que describen el comportamiento esperado | `test1`, `testFoo`, `testItWorks` |
| Fakes/stubs en las fronteras (I/O, red, reloj) | Mockear todo, incluido lo que sí posees |
| Tests deterministas (reloj, semilla, orden fijos) | Depender de `now()`, `random()`, orden de ejecución |
| Muchos unit, algunos integration, pocos e2e | Cono de helado: casi todo e2e/manual |
| Datos mínimos y explícitos por test (builders) | Fixtures gigantes compartidos por media suite |
| Un bug = un test de regresión que lo reproduce | "Ya lo probé a mano, funciona" |
| Assert claro con mensaje útil al fallar | `assert(true)` disfrazados o sin aserción real |
| Aislar dependencias externas | Golpear la DB/red real en un unit test |

---

## 3. La pirámide de tests

La forma de tu suite importa. La proporción sana, de base ancha a punta estrecha:

```
        /\        e2e        pocos, lentos, caros, frágiles
       /  \                  (flujos críticos de negocio)
      /----\    integration  algunos, velocidad media
     /      \                (fronteras reales: DB, HTTP, cola)
    /--------\     unit       muchos, milisegundos, baratos
   /__________\               (lógica pura, ramas, casos borde)
```

- **Unit (base):** rápidos (milisegundos), sin I/O, prueban lógica y ramas. Son la mayoría porque son baratos de escribir, de ejecutar y de diagnosticar. Cuando uno falla, sabes exactamente dónde.
- **Integration (medio):** verifican que dos o más piezas colaboran de verdad a través de una frontera real (repositorio contra una DB en contenedor, cliente HTTP contra un servidor de prueba). Más lentos, más valiosos para detectar errores de contrato.
- **E2E (punta):** ejercen el sistema completo como un usuario. Son los que más confianza dan pero los más lentos y frágiles. Por eso: **pocos y solo para los flujos que, si se rompen, el negocio sangra** (login, checkout, pago).

**Anti-patrón "cono de helado" (pirámide invertida):** casi toda la cobertura vive en e2e y pruebas manuales, con poquísimos unit tests. Resultado: suite lentísima, flaky, que tarda horas, que nadie confía y que diagnostica mal (falla y no sabes en qué capa). Si tu CI tarda 40 minutos y falla al azar, probablemente tengas un cono de helado. Empuja la lógica hacia unit tests.

> Regla práctica: si puedes verificar la misma regla de negocio con un unit test rápido, NO la subas a integration o e2e. Sube solo lo que no puedes probar más abajo.

---

## 4. Principios FIRST

Todo buen test cumple:

- **F — Fast (rápido):** milisegundos. Una suite lenta se ejecuta menos, y menos ejecución significa menos protección. La velocidad no es lujo, es adopción.
- **I — Isolated / Independent (aislado):** no depende de otros tests ni de su orden. No comparte estado mutable. Puedes ejecutar uno solo, o todos en paralelo, y el resultado es el mismo.
- **R — Repeatable (repetible):** mismo resultado siempre, en tu máquina, en la de tu colega y en CI. Nada de "en mi máquina pasa".
- **S — Self-validating (auto-validante):** el test decide solo si pasó o falló mediante aserciones. Nada de leer logs a ojo o comparar salidas manualmente.
- **T — Timely (oportuno):** escrito en el momento correcto, idealmente junto al código (o antes, con TDD), no seis meses después cuando ya nadie recuerda la intención.

---

## 5. Estructura de un test: AAA y Given-When-Then

Un test se lee de un vistazo cuando tiene tres bloques claros.

**AAA — Arrange, Act, Assert:**

```
test("aplica descuento del 10% a clientes premium", () => {
  // Arrange: preparo el mundo
  const cliente = unCliente({ tier: "premium" });
  const carrito = unCarrito({ total: 100 });

  // Act: ejecuto UNA acción
  const total = calcularTotal(carrito, cliente);

  // Assert: verifico UN concepto
  expect(total).toBe(90);
});
```

**Given-When-Then** es el mismo esqueleto en lenguaje de negocio (BDD): *Given* un cliente premium, *When* calculo el total, *Then* recibe 10% de descuento. Útil para tests de aceptación y para hablar con producto.

**Regla del concepto único:** cada test valida UN comportamiento. Si necesitas la palabra "y" para describir lo que prueba, probablemente son dos tests. No significa "un solo `expect`" (puedes tener varios asserts sobre el mismo resultado); significa una sola razón para fallar.

---

## 6. TDD: Red-Green-Refactor

TDD no es "escribir tests"; es un método de DISEÑO donde el test viene primero y te obliga a definir el comportamiento antes que la implementación.

El ciclo, corto y disciplinado:

1. **RED** — escribe un test que falle. Define QUÉ quieres que pase antes de saber cómo. Ejecuta: debe fallar (si pasa sin escribir código, el test está mal).
2. **GREEN** — escribe el MÍNIMO código para que pase. Nada de elegancia todavía; solo verde. Hasta un `return 90` hardcodeado vale como primer paso.
3. **REFACTOR** — con la red en verde, limpia: elimina duplicación, mejora nombres, extrae funciones. Los tests te protegen mientras mejoras el diseño.

Ejemplo mínimo del ciclo sobre un validador de contraseña:

```
// RED: falla, todavía no existe la función
test("rechaza contraseñas de menos de 8 caracteres", () => {
  expect(esValida("abc")).toBe(false);
});

// GREEN: lo mínimo
function esValida(pw) { return pw.length >= 8; }

// RED de nuevo: nuevo comportamiento
test("exige al menos un dígito", () => {
  expect(esValida("abcdefgh")).toBe(false);
});

// GREEN: extiendo
function esValida(pw) { return pw.length >= 8 && /\d/.test(pw); }

// REFACTOR: reglas como lista, sin romper tests
```

**Beneficios:** diseño guiado por el uso real, cobertura naturalmente alta, feedback inmediato, y código que nace testeable. **Cuándo aplica mejor:** lógica de negocio con reglas claras, corrección de bugs (RED = reproducir), APIs con contrato definido. **Cuándo es forzado:** exploración/spikes, UI muy visual, o cuando aún no sabes qué construir (primero explora, luego formaliza con tests).

---

## 7. Testear comportamiento, no implementación

Este es el principio que más distingue una suite buena de una tóxica.

- **Comportamiento** = entradas y salidas observables, efectos en colaboradores públicos, contratos. Es estable frente a refactors.
- **Implementación** = estructuras de datos internas, métodos privados, número de veces que se llamó a un helper interno. Cambia constantemente.

Si tu test conoce la implementación, cada refactor —aunque el comportamiento sea idéntico— lo rompe. Eso convierte los tests en un IMPUESTO al cambio en lugar de una red de seguridad, y enseña al equipo a "arreglar los tests" mecánicamente en vez de confiar en ellos.

```
// FRÁGIL: acoplado a internals. Cambiar la caché rompe el test aunque el
// resultado sea idéntico.
expect(servicio._cache.size).toBe(1);
expect(repo.buscarPorId).toHaveBeenCalledTimes(1);

// ROBUSTO: verifica el comportamiento observable.
expect(servicio.obtenerUsuario(42)).toEqual({ id: 42, nombre: "Ada" });
```

Verificar interacciones (spies/mocks sobre llamadas) es legítimo SOLO cuando la interacción ES el comportamiento (p. ej. "debe enviarse exactamente un email"). Para todo lo demás, prefiere afirmar sobre el resultado. Ver también `refactoring`: un test que no se acopla a internals es lo que HABILITA refactorizar con confianza.

---

## 8. Dobles de prueba (test doubles)

Un "doble" reemplaza una dependencia real. Los cinco tipos (taxonomía de Meszaros), de menos a más comportamiento:

| Tipo | Qué hace | Cuándo |
| --- | --- | --- |
| **Dummy** | Se pasa para rellenar un parámetro, nunca se usa | Cumplir una firma que el test no ejercita |
| **Stub** | Devuelve respuestas predefinidas a llamadas | Fijar el estado de entrada (query que "responde" X) |
| **Spy** | Stub que además registra cómo lo llamaron | Verificar que algo se invocó (y con qué) |
| **Mock** | Objeto con expectativas de interacción preprogramadas; falla si no se cumplen | Cuando la interacción ES lo que verificas |
| **Fake** | Implementación real pero simplificada | Frontera con comportamiento (repo en memoria) |

Ejemplos concretos:

```
// STUB: fija la entrada
const tarifas = { obtener: () => 0.21 };            // siempre 21% IVA

// SPY: observa que se notificó
const notificador = { enviar: jest.fn() };
procesarPago(pago, notificador);
expect(notificador.enviar).toHaveBeenCalledWith("ok"); // interacción = comportamiento

// FAKE: repositorio en memoria, se comporta como el real
class RepoUsuariosEnMemoria {
  #datos = new Map();
  guardar(u) { this.#datos.set(u.id, u); }
  buscar(id) { return this.#datos.get(id) ?? null; }
}
```

**Regla clave:** un **fake** en la frontera suele ser mejor que una maraña de stubs, porque se comporta de verdad (guarda y luego encuentra) y no se acopla a la secuencia exacta de llamadas. Los **mocks** son potentes pero es fácil sobre-especificar y volver el test frágil: cada mock es una afirmación implícita sobre la implementación.

---

## 9. Qué mockear y qué NO

- **NO mockees lo que no posees.** Mockear una librería de terceros o un SDK ajeno congela tu suposición sobre cómo se comporta; si cambian su API real, tus tests siguen en verde mintiendo. En su lugar, envuelve lo externo en un ADAPTER tuyo (interfaz que sí controlas) y mockea/fakea ese adapter. Verifica la integración real con el tercero en un test de integración aparte.
- **Prefiere fakes en las fronteras** (DB, HTTP, cola, filesystem, reloj): un repo en memoria, un servidor HTTP de prueba, un reloj inyectable.
- **NO mockees tipos de valor ni lógica pura.** Un objeto de dominio o una función pura se usan de verdad; mockearlos no aporta y esconde bugs.
- **NO mockees el sujeto bajo prueba.** Si terminas mockeando casi todo lo que rodea a tu clase, o el diseño acopla demasiado, o estás testeando la implementación.
- **Sí aísla lo lento, no determinista o con efectos secundarios** (pagos reales, envío de emails, llamadas de red).

> Heurística: si el doble te obliga a describir la secuencia interna exacta de llamadas, huele a acoplamiento. Si describe un contrato ("dado este input, este output"), vas bien.

---

## 10. Nombres de tests

El nombre es documentación. Debe decir el comportamiento esperado, no el método invocado. Ante un fallo en CI, un buen nombre te dice qué se rompió sin abrir el código.

```
// MAL
test("testCalcularTotal")
test("caso 3")

// BIEN — patrón: [sujeto] [condición] [resultado esperado]
test("calcularTotal aplica 10% de descuento a clientes premium")
test("login con contraseña incorrecta devuelve 401")
test("parseFecha con string vacío lanza InvalidDateError")
```

Convenciones útiles: `should_<resultado>_when_<condición>`, `given_<contexto>_when_<acción>_then_<resultado>`, o simplemente una frase declarativa. Elige una y sé consistente en toda la suite.

---

## 11. Cobertura: qué mide y qué NO

La cobertura mide **qué líneas/ramas se EJECUTARON** durante los tests. NO mide si afirmaste algo útil sobre ellas. Puedes tener 100% de cobertura sin un solo `assert` valioso (código ejecutado, comportamiento no verificado).

- **100% no es la meta.** Perseguir el número lleva a tests basura que ejecutan líneas sin verificar nada, solo para subir la métrica.
- **La cobertura de RAMAS importa más que la de líneas.** Un `if` con las dos ramas ejercitadas vale más que diez líneas triviales cubiertas.
- **Úsala como DETECTOR DE HUECOS, no como objetivo.** "Esta rama de error nunca se prueba" es información oro. "Estamos en 87%" no dice nada por sí solo.
- **Prioriza cubrir lo que duele si falla:** lógica de negocio, cálculos, manejo de errores, autorización. Un getter trivial no necesita test dedicado.

> Un umbral en CI (p. ej. no bajar de la cobertura actual) previene regresiones de cobertura, pero nunca sustituye al juicio sobre QUÉ afirmas.

---

## 12. Casos borde y datos

Los bugs viven en los bordes, no en el camino feliz. Para cada input, pregúntate por los límites:

- **Numéricos:** 0, -1, el máximo, el mínimo, overflow, punto flotante y redondeo, división por cero.
- **Colecciones/strings:** vacío (`[]`, `""`), un solo elemento, muy grande, con duplicados, orden inverso.
- **Nulos/ausencia:** `null`, `undefined`, campo faltante, valor por defecto.
- **Fechas y zonas horarias:** cambio de día por UTC vs local, horario de verano (DST), 29 de febrero, fin de mes, timestamps futuros/pasados.
- **Texto/Unicode:** acentos, emojis, caracteres de control, mayúsculas/minúsculas, espacios al inicio/fin, inyección (`'; DROP TABLE`), longitud máxima.
- **Estados inválidos:** transición no permitida, doble ejecución, entrada duplicada, concurrencia.

**Análisis de valores límite:** si la regla es "≥ 8 caracteres", prueba 7 (falla), 8 (pasa) y 9 (pasa). El bug casi siempre está justo en el límite (`>` vs `>=`).

---

## 13. Tests deterministas: matar el flakiness

Un test flaky (que a veces pasa y a veces falla sin cambios en el código) es peor que no tener test: erosiona la confianza en TODA la suite y la gente empieza a re-ejecutar CI a ciegas. Fuentes típicas y su antídoto:

- **Tiempo:** no uses `Date.now()` / `sleep`. Inyecta un reloj (`clock`) o usa fake timers. Nunca esperes con `sleep(500)`; espera por una CONDICIÓN (polling con timeout).
- **Aleatoriedad:** fija la semilla del RNG, o inyecta el generador. Nada de UUIDs reales si el test compara valores.
- **Orden:** los tests no deben depender de ejecutarse en cierto orden ni compartir estado mutable. Limpia el estado en cada uno (setup/teardown aislados).
- **Concurrencia / async:** usa `await`/esperas explícitas; nada de "esto ya habrá terminado". Evita depender de timing entre hilos.
- **Red y servicios externos:** un unit test NUNCA debe salir a la red. Usa fakes; deja la red real para integration controlado.
- **Datos compartidos:** una DB compartida entre tests paralelos produce colisiones. Aísla por transacción, esquema o contenedor efímero.

> Política sana: un test flaky se arregla o se cuarentena YA. Tolerarlo normaliza la desconfianza.

---

## 14. Integration vs unit: fronteras reales

Los unit tests aíslan; los de integración verifican que las piezas hablan de verdad a través de una frontera.

- **Cuándo integration:** mapeo objeto-relacional, queries SQL reales, serialización, contratos HTTP, migraciones, colas. Un fake de DB no atrapa un error de sintaxis SQL; una DB real sí.
- **Cómo, sin dolor:** contenedores efímeros (p. ej. Testcontainers) para levantar una DB/broker real por test-run; servidores HTTP de prueba (WireMock, MSW, `httptest`) para simular terceros con respuestas controladas.
- **Aislamiento del estado:** cada test parte de un estado conocido — transacción que se revierte, esquema limpio, o base recreada. Nunca dependas de datos dejados por otro test.
- **Regla de proporción:** integration cubre las COSTURAS, no re-verifica toda la lógica de negocio (eso ya está en unit).

---

## 15. Tests e2e

Ejercen el sistema completo por sus interfaces reales (UI, API pública). Máxima confianza, máximo coste.

- **Pocos y críticos:** solo los flujos que, rotos, detienen el negocio (registro, login, checkout, pago). No repliques aquí lo que ya cubren capas inferiores.
- **Estables:** selecciona elementos por atributos estables (`data-testid`), no por texto o posición que cambian con el diseño.
- **Page Object Pattern:** encapsula cada pantalla en un objeto que expone acciones de negocio (`loginPage.iniciarSesion(user, pass)`) en vez de repartir selectores por todos los tests. Cuando la UI cambia, tocas un solo lugar.
- **Esperas por condición, nunca por tiempo fijo:** espera a que un elemento aparezca/desaparezca, no `sleep(3000)`.

---

## 16. Contract testing (consumer-driven)

En microservicios, los tests e2e de todo el grafo de servicios son lentos y frágiles. El **contract testing** (p. ej. Pact) invierte el enfoque: el CONSUMIDOR define un contrato con las peticiones/respuestas que espera del proveedor, y el proveedor verifica en SU CI que sigue cumpliéndolo. Cada servicio se testea aislado contra el contrato, sin desplegar todo junto. Detecta rupturas de API entre equipos antes de integrar, con la velocidad de un unit test.

---

## 17. Mutation testing y property-based testing (breve)

- **Mutation testing:** mide la CALIDAD de tus tests, no del código. Introduce mutaciones (cambia `>` por `>=`, borra una línea, niega una condición) y comprueba si algún test falla ("mata" el mutante). Mutantes que sobreviven = tests que no verifican esa lógica aunque la cubran. Es la mejor respuesta al engaño de la cobertura. Coste alto: úsalo periódicamente sobre módulos críticos, no en cada commit.
- **Property-based testing:** en vez de ejemplos fijos, declaras PROPIEDADES que deben cumplirse para cualquier input, y la herramienta genera cientos de casos (incluidos bordes que no imaginaste) y reduce ("shrink") el fallo al caso mínimo. Ejemplo: `descomprimir(comprimir(x)) === x` para todo `x`. Ideal para parsers, serializadores, funciones puras, invariantes matemáticos.

---

## 18. Fixtures, factories y builders

Los datos de prueba deben ser MÍNIMOS y EXPLÍCITOS: solo lo relevante para ESE test, visible en ESE test.

- **Anti-patrón: fixture gigante compartido.** Un "mega objeto" que media suite reutiliza acopla los tests entre sí (cambiarlo rompe cosas lejanas) y oculta qué dato importa realmente en cada caso.
- **Factory / Builder:** una función/clase que produce objetos válidos por defecto y te deja sobrescribir SOLO lo relevante:

```
function unUsuario(overrides = {}) {
  return { id: 1, nombre: "Ada", tier: "free", activo: true, ...overrides };
}

// El test grita qué importa: solo el tier.
const premium = unUsuario({ tier: "premium" });
```

Ventajas: el test comunica su intención (solo el campo relevante es explícito), resiste cambios de esquema (defaults en un lugar) y evita duplicación. Object Mother (nombres semánticos como `unClientePremium()`) y Test Data Builder (encadenable) son variantes válidas del mismo principio.

---

## 19. Tests como documentación y red de seguridad

- **Documentación viva:** una suite bien nombrada es la especificación EJECUTABLE del sistema. A diferencia de un doc en Confluence, no puede quedar desactualizada: si miente, falla. Un dev nuevo debería entender qué hace un módulo leyendo los nombres de sus tests.
- **Red de seguridad para refactorizar:** el permiso para mejorar el diseño sin miedo (ver `refactoring`) VIENE de una suite en la que confías. Refactor = cambiar estructura sin cambiar comportamiento; los tests de comportamiento son justamente lo que lo garantiza. Sin ellos, todo refactor es una apuesta.

---

## 20. Regresiones: cada bug nace con su test

Flujo obligatorio ante un bug:

1. **Reproduce** el bug con un test que FALLE. Esto prueba que entendiste la causa, no solo el síntoma.
2. **Arregla** el código hasta que el test pase.
3. **Deja el test en la suite** para siempre: es la garantía de que esa regresión concreta no vuelve.

Si no puedes escribir un test que reproduzca el bug, aún no lo entiendes lo suficiente para arreglarlo bien. El test de regresión es la diferencia entre "parece que ya no pasa" y "está demostrado que no vuelve a pasar".

---

## 21. Anti-patrones comunes

- **Tests frágiles (over-specification):** afirman sobre internals o secuencias exactas de llamadas; se rompen en cada refactor sin que cambie el comportamiento.
- **Lógica en el test:** `if`, bucles, cálculos o ramas dentro del test. Si el test tiene lógica, ¿quién testea al test? Un test debe ser lineal y obvio.
- **Múltiples conceptos por test:** un test que valida cinco comportamientos falla por la primera aserción y oculta las demás; el nombre no puede describir qué se rompió.
- **Aserciones débiles o ausentes:** `expect(resultado).toBeDefined()` cuando podías verificar el valor exacto; peor aún, tests sin ningún `assert` real.
- **Mystery Guest:** el test depende de datos externos (un archivo, una fila en una DB compartida) que no están a la vista; falla y no sabes por qué.
- **Test que sigue al código:** copiaste la implementación dentro del test (mismo cálculo repetido). Verifica el RESULTADO esperado escrito a mano, no re-ejecutes la fórmula.
- **Slow suite tolerada:** nadie corre los tests en local porque tardan; solo se enteran en CI. La lentitud mata la adopción.
- **Flaky tolerado / re-run culture:** "dale a re-run y pasa". Cada flaky no atendido baja la confianza en toda la suite.
- **Testear el framework/librería:** verificar que el ORM o el router de terceros hacen su trabajo. No es tu responsabilidad; testea TU lógica.
- **Comentar/skippear tests que molestan:** `it.skip` permanente = mentira verde. O se arregla o se borra con criterio.
- **Assert Roulette:** varios asserts idénticos sin mensaje; cuando falla uno, no sabes cuál.

---

## 22. Checklist de un buen test / suite

Un TEST individual:

- [ ] Verifica UN comportamiento observable (una razón para fallar)
- [ ] Nombre describe el comportamiento esperado, no el método
- [ ] Estructura AAA / Given-When-Then legible de un vistazo
- [ ] Sin lógica (if/loop/cálculo) dentro del test
- [ ] Datos mínimos y explícitos vía builder/factory
- [ ] Aserción concreta sobre el resultado (no solo "definido")
- [ ] Determinista: reloj, aleatoriedad y orden controlados
- [ ] No conoce internals del sujeto (sobrevive a un refactor)
- [ ] No sale a la red ni golpea la DB real (si es unit)

La SUITE completa:

- [ ] Forma de pirámide: muchos unit, algunos integration, pocos e2e
- [ ] Rápida en local (segundos) y estable en CI (cero flaky tolerados)
- [ ] Cubre ramas y casos borde de valor, no persigue el 100%
- [ ] Fronteras externas con fakes/contenedores, terceros vía adapter
- [ ] Cada bug histórico tiene su test de regresión
- [ ] Los tests se pueden ejecutar en paralelo y aislados
- [ ] Sirve como documentación: un dev nuevo entiende el módulo leyéndola

---

## 23. Referencias

- Beck, Kent. *Test-Driven Development: By Example* — https://www.oreilly.com/library/view/test-driven-development/0321146530/
- Meszaros, Gerard. *xUnit Test Patterns* (taxonomía de dobles y anti-patrones) — http://xunitpatterns.com/
- Fowler, Martin. *Test Pyramid* — https://martinfowler.com/bliki/TestPyramid.html
- Fowler, Martin. *Mocks Aren't Stubs* — https://martinfowler.com/articles/mocksArentStubs.html
- Cohn, Mike. *The Forgotten Layer of the Test Automation Pyramid* — https://www.mountaingoatsoftware.com/blog/the-forgotten-layer-of-the-test-automation-pyramid
- Google Testing Blog — https://testing.googleblog.com/
- Pact (contract testing) — https://docs.pact.io/
- Testcontainers — https://testcontainers.com/
- Hillel Wayne. *Property-Based Testing* — https://hypothesis.works/articles/what-is-property-based-testing/
- Skills relacionadas: `refactoring` (la red que habilita refactorizar), `code-review` (los tests como evidencia en la revisión), `error-handling-observability` (qué observar y afirmar sobre errores y fallos).
