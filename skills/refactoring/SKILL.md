---
name: refactoring
description: "Refactorización y deuda técnica: cuándo, técnicas seguras, code smells, red-green-refactor."
---

# Refactorización y Deuda Técnica

> **Cuándo usar:** cuando vayas a modificar código existente y notes fricción (duplicación, funciones largas, nombres opacos); antes de añadir una feature sobre código enredado; cuando aparezca la tercera repetición de un patrón; al leer código para entenderlo y detectes que podrías dejarlo más claro; cuando un `code review` o el linter señale complejidad; cuando trabajes sobre legacy sin tests y necesites una red de seguridad antes de tocar nada. Si tu cambio altera comportamiento observable, NO es refactor: es una feature o un fix, y va por otro camino.

Refactorizar es una disciplina técnica, no un lujo estético. Se hace con red de tests, en pasos pequeños y verificables, y NUNCA mezclado con cambios de funcionalidad. Todo lo demás son ganas de romper producción con buena intención.

---

## 1. Principios fundamentales

1. **Refactorizar = mejorar la estructura interna SIN cambiar el comportamiento observable.** La entrada y la salida del sistema, vistas desde fuera, son idénticas antes y después. Cambia el *cómo*, jamás el *qué*.
2. **Requiere una red de tests.** Sin tests que verifiquen el comportamiento, no estás refactorizando: estás reescribiendo a ciegas y rezando. La red es lo que convierte un cambio arriesgado en uno seguro.
3. **Pasos pequeños y verificables.** Un cambio atómico, ejecutar tests, confirmar verde, commit. Repetir. Si algo se rompe, el paso pequeño hace que el culpable sea obvio y el `revert` barato.
4. **Comportamiento primero, elegancia después.** El objetivo no es que el código sea "bonito", es que sea más fácil de entender y de cambiar. La estética sin valor de cambio es tiempo tirado.

El PORQUÉ: el código se lee muchas más veces de las que se escribe. Refactorizar es pagar por adelantado la legibilidad y la capacidad de cambio futuras. Kent Beck lo resume mejor que nadie: *"make the change easy, then make the easy change"* — primero preparas el terreno, luego el cambio real es trivial.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Tener tests en verde ANTES de empezar | Refactorizar sin red de seguridad |
| Un solo tipo de cambio por commit | Mezclar refactor con features o fixes |
| Pasos pequeños con tests entre cada uno | Grandes reescrituras en un solo salto |
| Usar los refactors automáticos del IDE | Renombrar a mano con buscar-y-reemplazar ciego |
| Commits atómicos y con mensaje claro | Un commit gigante "refactor varios" |
| Aplicar la regla de tres | Abstraer en la primera aparición (abstracción prematura) |
| Escribir tests de caracterización si no hay tests | Tocar legacy sin caracterizar primero |
| Refactorizar en verde (tests pasando) | Refactorizar en rojo (tests fallando) |
| Medir el impacto (complejidad, cobertura) | Refactorizar "porque sí", sin objetivo |
| Dejar el código un poco mejor que como lo encontraste | Reescrituras heroicas de fin de semana |

---

## 3. Definición estricta: preservar el comportamiento observable

Comportamiento observable es todo lo que un consumidor externo puede percibir: valores de retorno, efectos de lado visibles (escrituras en BD, llamadas a servicios), errores lanzados, contratos de API. Un refactor legítimo mantiene TODO eso invariante.

Corolario innegociable: **no mezcles refactor y cambio de funcionalidad en el mismo commit.** Si en medio de un refactor descubres un bug o quieres añadir un caso nuevo:

1. Termina o interrumpe el refactor y haz commit del refactor puro.
2. En un commit SEPARADO, aplica el cambio de comportamiento.

El PORQUÉ: cuando un commit mezcla las dos cosas, el revisor no puede distinguir el movimiento mecánico (que debería ser inocuo) del cambio de lógica (que necesita escrutinio). Un diff de refactor puro es aburrido de revisar a propósito. Ver `code-review` y `git-workflow`.

---

## 4. Cuándo refactorizar

- **La regla de tres (Fowler).** La primera vez, escribe. La segunda vez que hagas algo parecido, aguántate el impulso de abstraer y duplica. A la TERCERA, refactoriza y unifica. Esperar a tres apariciones evita la abstracción prematura, que suele acoplar cosas que solo *parecían* iguales.
- **Antes de añadir una feature (preparatory refactoring).** Si añadir la feature es difícil por cómo está el código, primero reestructura para que el sitio quede preparado. *Make the change easy, then make the easy change.* El refactor previo no es un desvío, es parte del trabajo.
- **Al entender código (comprehension refactoring).** Cuando descifras qué hace un bloque opaco, vuelca ese entendimiento en el código: renombra variables, extrae funciones con nombres que expliquen la intención. Así el próximo que llegue no tiene que repetir tu arqueología.
- **Boy Scout Rule.** Deja el módulo un poco más limpio que como lo encontraste. Mejoras minúsculas y constantes evitan la degradación acumulada. No hace falta arreglarlo todo: un nombre mejor, una guard clause, y sigues.

---

## 5. Cuándo NO refactorizar

- **Reescritura total sin una razón de negocio clara.** "No me gusta cómo está" no es razón. La reescritura big-bang es el error más caro del oficio (ver anti-patrones).
- **Cerca de un deadline crítico y sin tests.** Refactorizar sin red justo antes de una entrega es maximizar la probabilidad de romper algo sin margen para detectarlo. Anótalo como deuda y hazlo después.
- **Código que se va a borrar.** No pulas lo que vas a tirar. Es esfuerzo con valor de cambio cero.
- **Cuando no entiendes el comportamiento actual.** Si no sabes qué hace, no puedes garantizar que lo preservas. Primero caracteriza, luego refactoriza.

---

## 6. Red de seguridad: tests primero

El refactor descansa sobre los tests. Sin ellos, cada paso es una apuesta.

- Si YA hay tests que cubren la zona: ejecútalos, confirma verde, y adelante.
- Si NO hay tests: escribe **tests de caracterización** (characterization tests) ANTES de tocar nada. Un test de caracterización no verifica lo que el código *debería* hacer, sino lo que *hace hoy* — incluidos sus bugs. Fijas el comportamiento actual para poder cambiar la estructura con confianza. Ver la skill `testing` para el detalle de cómo escribirlos.

El PORQUÉ: sin tests solo tienes tu criterio de que "esto es equivalente". El criterio humano falla en los casos borde justo donde más importa. Los tests son la definición ejecutable de "no rompí nada".

---

## 7. Ciclo Red-Green-Refactor

El tercer paso de TDD es literalmente este trabajo:

1. **Red** — escribes un test que falla (define el comportamiento deseado).
2. **Green** — el mínimo código para que pase, sin preocuparte de la elegancia.
3. **Refactor** — con los tests en VERDE, limpias la estructura: eliminas duplicación, mejoras nombres, extraes funciones.

Regla de hierro: **solo se refactoriza en verde.** Si refactorizas con tests en rojo, no puedes distinguir el fallo que ya existía del que acabas de introducir. Verde es tu punto de retorno seguro; cada vez que vuelves a verde, tienes un checkpoint desde el que retroceder.

---

## 8. Pasos pequeños y herramientas

- **Un cambio atómico a la vez.** Extrae UNA función, ejecuta tests, commit. No encadenes cinco transformaciones antes de comprobar.
- **Ejecuta tests entre pasos.** El coste de correr los tests es minúsculo comparado con depurar un refactor de veinte cambios acumulados.
- **Commit frecuente.** Cada paso verde es candidato a commit. Commits pequeños hacen el `git bisect` y el `revert` triviales. Ver `git-workflow`.
- **Usa los refactors automáticos del IDE.** Rename, Extract Method, Inline, Move — cuando la herramienta los hace, son transformaciones garantizadas por el árbol de sintaxis, no por tu buscar-y-reemplazar. Prefiere siempre la herramienta al cambio manual.

---

## 9. Catálogo de técnicas (Martin Fowler)

Vocabulario compartido de transformaciones seguras. Conocerlas por su nombre te permite pensar y comunicar el cambio con precisión.

**Componer funciones**
- **Extract Function/Method** — sacar un fragmento a una función con nombre que explique su intención. La técnica más usada. Cuándo: un bloque necesita un comentario para entenderse, o se repite. El nombre sustituye al comentario.
- **Inline Function** — lo inverso: cuando el cuerpo es tan claro como el nombre, elimina la indirección y mete el cuerpo en la llamada. Cuándo: la función no aporta más que su firma.
- **Extract Variable** — dar nombre a una subexpresión compleja mediante una variable explicativa. Cuándo: una condición o cálculo enrevesado necesita una etiqueta que diga qué significa.
- **Replace Temp with Query** — sustituir una variable temporal por una función que la calcula. Cuándo: quieres que el valor sea accesible desde otros sitios y evitar temporales que estorban al extraer.

**Nombres y firmas**
- **Rename (Variable/Function/Field)** — el refactor más barato y más subestimado. Un buen nombre elimina la necesidad de un comentario. Cuándo: el nombre miente, es vago o exige memorizar contexto.
- **Change Function Declaration** — cambiar nombre, parámetros u orden de la firma. Cuándo: la firma no comunica bien el propósito o los parámetros están mal modelados.
- **Introduce Parameter Object** — agrupar parámetros que siempre viajan juntos en un objeto con nombre. Cuándo: ves los mismos 3-4 parámetros repetidos en varias firmas (data clumps).

**Mover elementos**
- **Move Function/Field** — reubicar un miembro a la clase/módulo donde de verdad pertenece. Cuándo: una función usa más datos de otra clase que de la suya (feature envy).
- **Extract Class** — partir una clase que hace demasiado en dos con responsabilidades claras. Cuándo: la clase tiene subconjuntos de datos y métodos que cambian juntos y aparte del resto.
- **Inline Class** — fusionar una clase anémica que ya no justifica su existencia dentro de otra. Cuándo: una clase quedó vacía tras mover casi todo fuera.
- **Encapsulate Variable/Collection** — controlar el acceso a un dato mutable tras accesores; para colecciones, devolver copias o vistas y exponer add/remove. Cuándo: un dato compartido se muta desde muchos sitios sin control.

**Simplificar condicionales**
- **Decompose Conditional** — extraer la condición y cada rama a funciones con nombre. Cuándo: un `if/else` con condiciones y cuerpos densos que cuesta leer.
- **Replace Nested Conditional with Guard Clauses** — convertir anidamiento profundo en cláusulas de salida temprana. Cuándo: pirámide de `if` anidados; las guard clauses aplanan y dejan claro qué es caso excepcional y qué es camino normal.
- **Replace Conditional with Polymorphism** — sustituir un `switch`/`if` sobre un tipo por polimorfismo. Cuándo: el mismo `switch` sobre un discriminador se repite en varios sitios; cada `case` pasa a ser una subclase/estrategia.
- **Replace Magic Literal with Constant** — dar nombre a números o strings mágicos. Cuándo: aparece un `0.15`, un `"ADMIN"` o un `42` sin explicación. La constante documenta la intención y centraliza el cambio.

**Bucles y datos**
- **Split Loop** — partir un bucle que hace dos cosas en dos bucles, cada uno con una responsabilidad. Cuándo: un `for` calcula dos agregados no relacionados a la vez; separarlos abre la puerta a extraer cada uno.

> Estas son las de uso diario. El catálogo completo de Fowler tiene decenas más, pero dominar estas cubre la enorme mayoría de los casos reales.

---

## 10. Code smells y su refactor

Un *smell* no es un bug: es una señal en la superficie de un problema estructural más profundo. Cada uno tiene un refactor asociado.

| Smell | Qué es | Refactor sugerido |
| --- | --- | --- |
| **Código duplicado** | La misma estructura en varios sitios | Extract Function; Move Function; Extract Class |
| **Función larga** | Hace demasiado; cuesta seguirla | Extract Function; Decompose Conditional; Replace Temp with Query |
| **Clase grande (God Class)** | Demasiadas responsabilidades y campos | Extract Class; Move Function/Field |
| **Lista larga de parámetros** | Firma con muchos argumentos | Introduce Parameter Object; Replace Parameter with Query |
| **Feature Envy** | Un método usa más datos de otra clase que de la propia | Move Function; Extract Function |
| **Data Clumps** | Los mismos grupos de datos viajan juntos por todos lados | Introduce Parameter Object; Extract Class |
| **Primitive Obsession** | Modelar conceptos del dominio con primitivos (string, int) | Extract Class; crear tipos de valor (Value Objects) |
| **Switch Statements** | El mismo `switch` sobre un tipo repetido en varios sitios | Replace Conditional with Polymorphism |
| **Comentarios que explican código malo** | El comentario disculpa un código ilegible | Extract Function (nombre en vez de comentario); Rename |
| **Shotgun Surgery** | Un cambio obliga a tocar muchas clases a la vez | Move Function/Field para juntar lo que cambia junto |
| **Divergent Change** | Una clase cambia por razones distintas y sin relación | Extract Class para separar los ejes de cambio |

El PORQUÉ de mirar smells: son heurísticas, no leyes. Te dicen *dónde mirar*, no *qué hacer siempre*. Un método largo puede estar bien si es una secuencia lineal clara. Usa el juicio; el smell abre la conversación, no la cierra.

---

## 11. Deuda técnica

**La metáfora (Ward Cunningham).** Tomar un atajo en el diseño es como pedir un préstamo: te da velocidad hoy, pero pagas **intereses** en forma de esfuerzo extra en cada cambio futuro sobre ese código. Si nunca amortizas el principal (refactorizando), los intereses te ahogan y el sistema se vuelve intocable.

**El cuadrante de Fowler** — no toda deuda es igual:

| | Prudente | Imprudente |
| --- | --- | --- |
| **Deliberada** | "No hay tiempo de hacer el diseño perfecto; asumimos esta deuda y la anotamos." Decisión consciente y justificada. | "No hay tiempo para diseñar." Se sacrifica calidad a sabiendas sin plan de pago. |
| **Inadvertida** | "Ahora que entiendo el dominio, sé cómo debí diseñarlo." Se aprende algo que antes no se sabía. Inevitable y sana. | "¿Qué es una capa de dominio?" Deuda por desconocimiento de fundamentos. La más peligrosa. |

La deuda **deliberada y prudente** es una herramienta legítima de ingeniería. La **imprudente e inadvertida** es simplemente no saber lo que se hace.

**Cómo gestionarla:**
- **Regístrala.** Anota la deuda donde se vea (issue, backlog, comentario `// TODO(deuda): ...`). La deuda invisible no se paga nunca.
- **Presupuesto de refactor continuo.** Dedica una fracción constante de cada tarea a mejorar lo que tocas (Boy Scout Rule). La deuda se paga a plazos, no de golpe.
- **No pidas el "sprint de limpieza" heroico.** Un sprint entero de refactor sin features es carísimo de justificar, se recorta al primer apuro y no ataca la causa. La limpieza continua e incremental gana siempre a la heroica.

---

## 12. Refactor de legacy

Legacy = código sin tests (definición operativa de Michael Feathers). El problema del huevo y la gallina: para refactorizar con seguridad necesitas tests, pero para testear necesitas romper las dependencias que hacen el código intestable.

- **Seams (costuras).** Un *seam* es un punto donde puedes alterar el comportamiento sin editar ese código en ese lugar — inyectando una dependencia, sobrescribiendo un método, sustituyendo una interfaz. Encontrar seams es el primer paso para poner el código bajo test.
- **Tests de caracterización.** Antes de tocar, fija el comportamiento actual con tests (aunque documenten bugs). Ver §6 y la skill `testing`.
- **Branch by Abstraction (ramificación por abstracción).** Para reemplazar una implementación grande: (1) introduce una abstracción sobre el componente viejo, (2) haz que todos los consumidores pasen por la abstracción, (3) construye la nueva implementación detrás de la misma abstracción, (4) conmuta, (5) elimina la vieja. Permite migrar sin romper `main` y trabajando en pequeños commits integrados.
- **Strangler Fig (higuera estranguladora).** Para reemplazar un sistema entero: envuelve el sistema viejo e intercepta sus entradas; ve reimplementando funcionalidad en el nuevo sistema pieza a pieza y redirige cada pieza cuando esté lista. El viejo se va "estrangulando" hasta que puedes retirarlo. Reemplazo incremental, nunca big-bang.

---

## 13. Refactor a gran escala

- **Incremental sobre big-bang, siempre.** Los cambios grandes se descomponen en una secuencia de pasos pequeños, cada uno con tests en verde y integrable en `main`. Una rama de refactor que vive semanas se convierte en un infierno de merge.
- **Feature flags.** Para cambios que no se pueden completar en un commit, esconde la nueva ruta tras un flag. Integras código incompleto en `main` sin exponerlo, evitas ramas de larga vida y puedes conmutar/revertir en producción sin desplegar.
- **Branch by Abstraction + Strangler Fig** (§12) son las técnicas de referencia para lo grande. Ambas convierten un cambio aterrador en una serie de pasos aburridos, que es exactamente el objetivo.

---

## 14. Medir

- **Complejidad ciclomática.** Cuenta los caminos independientes de una función. Alta complejidad = difícil de testear y de entender = candidato a Decompose Conditional / Extract Function. Útil para priorizar dónde refactorizar.
- **Cobertura como habilitador.** La cobertura no es el objetivo; es lo que te da permiso para refactorizar con confianza. Zonas de baja cobertura son zonas donde primero hay que caracterizar. No persigas el 100% ciego: persigue cobertura en lo que vas a cambiar.
- **Antes/después.** Cuando puedas, mide el smell que atacas (líneas por función, número de parámetros, complejidad) antes y después. Convierte "quedó más limpio" en un dato defendible ante el equipo y en `code-review`.

---

## 15. Anti-patrones comunes

- **Refactor sin tests.** El pecado capital. Sin red, no refactorizas: reescribes a ciegas. Si no hay tests, caracteriza primero.
- **Mezclar refactor con features/fixes.** Hace el diff irrevisable y esconde los cambios de comportamiento entre ruido mecánico. Un commit, un propósito.
- **Big Rewrite.** "Lo reescribimos desde cero." Tiras el conocimiento acumulado (incluidos los bugs corregidos que ya no recuerdas), tardas el triple de lo estimado y durante meses mantienes dos sistemas. Prefiere Strangler Fig.
- **Gold plating.** Refactorizar y generalizar más allá de lo que el problema pide, "por si acaso". Añade complejidad especulativa que casi nunca se usa. YAGNI.
- **Refactor por estética sin valor.** Reordenar imports, cambiar comillas o reindentar por gusto personal genera ruido en el diff, conflictos de merge y cero valor de cambio. Si no hace el código más fácil de cambiar o entender, no lo hagas (o déjaselo al formateador automático).
- **Abstracción prematura.** Extraer una abstracción en la primera aparición, antes de que el patrón se confirme. Suele acoplar cosas que solo parecían iguales. Regla de tres.

---

## 16. Checklist

**Antes de empezar**
- [ ] ¿Existe un objetivo concreto (smell, feature que viene, comprensión)? No refactorizo "porque sí".
- [ ] ¿Hay tests que cubren la zona y están en VERDE?
- [ ] Si no hay tests, ¿escribí tests de caracterización primero?
- [ ] ¿El working tree está limpio y commiteado (punto de retorno seguro)?
- [ ] ¿Esto es refactor puro (sin cambio de comportamiento)? Si mezcla, lo separo.

**Durante**
- [ ] ¿Estoy haciendo UN tipo de cambio a la vez?
- [ ] ¿Uso el refactor automático del IDE cuando existe?
- [ ] ¿Ejecuto los tests después de cada paso pequeño?
- [ ] ¿Hago commit en cada verde relevante, con mensaje claro de "refactor"?

**Al terminar**
- [ ] ¿Todos los tests siguen en verde?
- [ ] ¿El comportamiento observable es idéntico al de partida?
- [ ] ¿El diff es solo refactor, sin cambios de lógica colados?
- [ ] ¿Registré la deuda que decidí NO pagar ahora?
- [ ] ¿Pasé por `code-review` si el cambio lo amerita?

---

## 17. Skills relacionadas

- **testing** — tests de caracterización, red de seguridad, ciclo red-green-refactor en detalle, cobertura.
- **code-review** — cómo presentar y revisar un diff de refactor puro; separar movimiento mecánico de cambio de lógica.
- **git-workflow** — commits atómicos, mensajes de refactor, `bisect`/`revert`, ramas cortas y feature flags.

## Referencias

- Martin Fowler — *Refactoring: Improving the Design of Existing Code* (2ª ed.). El catálogo de técnicas y los code smells.
- Michael Feathers — *Working Effectively with Legacy Code*. Seams, tests de caracterización y cómo poner legacy bajo test.
- Kent Beck — *"Make the change easy, then make the easy change."* El principio del preparatory refactoring.
- Ward Cunningham — la metáfora original de la deuda técnica.
