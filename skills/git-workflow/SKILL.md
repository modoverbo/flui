---
name: git-workflow
description: "Flujo con Git: ramas, commits atómicos, Conventional Commits, PRs, rebase vs merge."
---

# Flujo de Trabajo con Git

> **Cuándo usar:** al iniciar cualquier trabajo con Git; antes de nombrar una rama, escribir un commit o abrir un PR; cuando dudes entre `rebase` y `merge`; al resolver conflictos; al preparar una release o un tag; o cuando el historial de un repo se haya vuelto ilegible y quieras corregir el rumbo.

Git no es un botón de "guardar". Es la **memoria del proyecto**. Cada decisión que tomas —cómo divides un commit, cómo redactas su mensaje, cuándo integras una rama— la está leyendo alguien dentro de seis meses tratando de entender POR QUÉ el código es como es. Ese alguien probablemente serás tú. Trata el historial como parte del producto, no como un residuo del proceso.

## 1. Principios fundamentales

1. **El historial cuenta una historia.** Alguien debe poder leer `git log` y entender la evolución del sistema sin abrir un solo archivo. Un historial legible es documentación viva y gratuita; un historial ruidoso es deuda que se paga en cada `git blame`, cada `git bisect` y cada revisión.
2. **Commits atómicos.** Un commit es una unidad lógica de cambio: completa, coherente, que **compila y pasa los tests por sí sola**. Poder revertir, revisar o hacer `cherry-pick` de un commit sin arrastrar cambios ajenos es la prueba de que está bien delimitado.
3. **La rama principal siempre está desplegable.** `main` no es tu borrador. En cualquier commit de `main` el sistema debe poder construirse y desplegarse. Lo roto vive en tu rama, nunca en la troncal.
4. **Reescribir historia local es barato; reescribir historia compartida es caro.** Puedes reordenar y limpiar libremente lo que solo existe en tu máquina. En cuanto otra persona depende de un commit, ese commit es un contrato: no lo reescribas.

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Commits pequeños y atómicos que compilan y pasan tests | Commits gigantes que mezclan feature, refactor y fix |
| Mensajes en imperativo que explican el PORQUÉ | Mensajes vacíos: `wip`, `fix`, `.`, `asdf` |
| Ramas de vida corta (horas o pocos días) | Ramas eternas que divergen semanas de `main` |
| `rebase` para limpiar TU rama local antes del PR | `rebase` de una rama que otros ya usan |
| PRs pequeños y de foco único (< ~400 líneas) | PRs de 3.000 líneas que nadie puede revisar de verdad |
| Auto-revisar el diff antes de pedir revisión | Lanzar el PR sin haber leído tu propio cambio |
| `.gitignore` correcto desde el inicio del repo | Commitear `node_modules/`, `.env`, artefactos, secretos |
| `git revert` en ramas compartidas | `git reset --hard` + `push --force` a `main` |

---

## Commits atómicos

Un commit atómico agrupa **un** cambio lógico y solo uno. La regla práctica: si la descripción honesta de tu commit necesita la palabra "y" para enumerar cosas no relacionadas ("agrega login **y** renombra utils **y** corrige typo"), son varios commits disfrazados de uno.

- **Ni gigante ni micro.** Demasiado grande: imposible de revisar, revertir arrastra cambios buenos, el diff esconde el bug. Demasiado pequeño: un commit por cada línea convierte el historial en ruido y rompe la idea de "unidad que compila". El tamaño correcto es *una unidad de trabajo revisable que deja el árbol en verde*.
- **Debe compilar y pasar tests.** Cada commit es un punto al que `git bisect` puede aterrizar. Si un commit intermedio no compila, `bisect` es inútil y el `revert` es peligroso.
- **Separa refactor de comportamiento.** Un commit que mueve/renombra código no debe cambiar comportamiento. Un commit que cambia comportamiento no debe incluir un refactor masivo. Mezclarlos hace imposible saber qué línea causó la regresión.
- Usa `git add -p` para dividir cambios de un mismo archivo en commits distintos cuando pertenecen a unidades lógicas diferentes.

Para planificar cómo trocear una implementación en commits revisables (tests y docs viajando con su código), ver la skill **work-unit-commits**.

## Conventional Commits

Formato estándar del asunto:

```
type(scope): description

[cuerpo opcional]

[footer opcional]
```

Tipos principales:

| Tipo | Uso | Impacto SemVer |
| --- | --- | --- |
| `feat` | Nueva funcionalidad para el usuario | MINOR |
| `fix` | Corrección de un bug | PATCH |
| `docs` | Solo documentación | — |
| `refactor` | Cambio interno sin alterar comportamiento | — |
| `test` | Agrega o corrige tests | — |
| `chore` | Tareas de mantenimiento (deps, config) | — |
| `perf` | Mejora de rendimiento | PATCH |
| `build` | Sistema de build o dependencias | — |
| `ci` | Configuración de integración continua | — |

- **`scope`** (opcional) acota el área afectada: `feat(auth): ...`, `fix(api): ...`.
- **Relación con SemVer:** `fix` → PATCH, `feat` → MINOR, y un cambio incompatible → MAJOR.
- **BREAKING CHANGE:** marca la ruptura con `!` tras el tipo y/o un footer explícito. Esto dispara un incremento MAJOR.

```
feat(api)!: elimina el endpoint /v1/users

BREAKING CHANGE: /v1/users se retira. Usar /v2/users, que exige el header
X-Tenant-Id. Los clientes que no migren recibirán 410 Gone.
```

Ejemplos correctos:

```
feat(cart): permite aplicar cupones de descuento
fix(auth): corrige expiración prematura del token de refresco
refactor(orders): extrae la validación a un value object
```

## Mensajes de commit de calidad

Un buen mensaje se escribe para quien lee, no para quien escribe.

- **Asunto:** imperativo, ≤ 50 caracteres, sin punto final. "Agrega", no "Agregado" ni "Agregando". Truco: debe completar la frase *"Si se aplica, este commit va a ___"*.
- **Línea en blanco** obligatoria entre asunto y cuerpo (muchas herramientas dependen de ella).
- **Cuerpo:** envuelto a ~72 columnas, explica el **PORQUÉ** y el contexto, no el qué. El *qué* ya está en el diff; el *por qué* solo vive en tu cabeza hasta que lo escribes.

```
fix(payments): reintenta cobros ante timeouts del gateway

El proveedor devuelve 504 de forma intermitente bajo carga. Antes
marcábamos la orden como fallida al primer timeout, lo que generaba
cobros perdidos y tickets de soporte. Ahora reintentamos hasta 3 veces
con backoff exponencial antes de darla por fallida.

Refs: #482
```

Qué **NO** poner en el mensaje: ruido sin información (`wip`, `arreglos varios`), tu nombre (ya está en los metadatos), narrativa de tu día ("por fin funciona!!"), ni el detalle línea a línea que el diff ya muestra.

## Estrategias de branching

| Estrategia | Cómo funciona | Ideal para |
| --- | --- | --- |
| **Trunk-Based Development** | Todos integran a `main` a diario, en ramas muy cortas o directo; feature flags para lo incompleto | Equipos con CI/CD maduro y despliegue continuo |
| **GitHub Flow** | Una rama por cambio, PR a `main`, deploy tras el merge | La mayoría de equipos y productos web |
| **Git Flow** | Ramas de larga vida: `develop`, `release/*`, `hotfix/*`, `feature/*` | Software con releases versionadas y múltiples versiones soportadas |

**Regla transversal: prefiere ramas de vida corta.** Cuanto más vive una rama, más diverge de `main`, más doloroso es el merge y más grande —e irrevisable— el PR. Una rama de días, no de semanas. Git Flow suele ser excesivo para entrega continua; empieza por GitHub Flow o Trunk-Based salvo que tengas una razón concreta para lo contrario.

### Nombres de ramas convencionales

```
feature/checkout-con-cupones
fix/expiracion-token-refresco
hotfix/fuga-memoria-worker
chore/actualiza-deps-eslint
docs/guia-de-onboarding
```

Un prefijo por tipo, `kebab-case`, descriptivo pero breve. Incluye el id del ticket si tu equipo lo usa: `feature/PROJ-123-checkout-cupones`.

## Pull Requests

El PR es donde el trabajo se vuelve conocimiento compartido. Optimízalo para el revisor.

- **Pequeño.** Apunta a menos de ~400 líneas de cambio. Por encima de eso la calidad de la revisión cae en picado: el revisor aprueba por cansancio, no por convicción.
- **Foco único.** Un PR = un objetivo. Nada de "y de paso arreglé estos otros tres detalles".
- **Descripción con estructura:**
  - **Contexto / Por qué:** qué problema resuelve y por qué ahora.
  - **Qué:** resumen de los cambios.
  - **Cómo probar:** pasos concretos para verificar el comportamiento.
  - Enlaces a issues, capturas si hay UI, notas sobre migraciones o riesgos.
- **Auto-revisión primero.** Lee tu propio diff completo ANTES de asignar revisores. Encontrarás `console.log` olvidados, código muerto, nombres pobres. Respeta el tiempo de quien revisa: no le des lo que tú mismo no leíste.

Para el detalle de qué mirar en una revisión (propia o ajena), ver la skill **code-review**.

### PRs encadenados (stacked)

Cuando un cambio es intrínsecamente grande, no lo mandes como un solo PR gigante: divídelo en una **pila** de PRs pequeños y dependientes, cada uno construido sobre el anterior. El PR #2 parte de la rama del #1, el #3 del #2, y así. Cada eslabón es revisable de forma aislada y se mergea en orden. Ver la skill **chained-pr** para el flujo completo.

## Rebase vs Merge

Ambos integran trabajo entre ramas; producen historiales distintos.

- **`git merge`** crea un commit de merge que une dos líneas de historia. **Preserva** el historial real, no lo reescribe. Es seguro sobre ramas compartidas. Coste: el historial gana bifurcaciones y commits de merge.
- **`git rebase`** reaplica tus commits **sobre** la punta de otra rama, reescribiendo sus hashes. Produce un historial lineal, limpio, fácil de leer. Coste: reescribe historia; sobre commits compartidos, rompe a todos los demás.

Cuándo usar cada uno:

- **Rebase** para **limpiar tu rama local** antes de abrir/actualizar el PR: `git rebase main` para ponerte al día de forma lineal, o `git rebase -i` para reordenar/agrupar tus propios commits.
- **Merge** para **integrar** trabajo ya revisado (mergear el PR a `main`) y para actualizar ramas que otros comparten.

> **La regla de oro del rebase:** **NUNCA hagas rebase de commits que ya están publicados en una rama compartida.** Reescribir el hash de un commit del que otros dependen los obliga a reconciliar historias divergentes a mano. Rebase solo de lo que es exclusivamente tuyo.

### Squash, fixup y rebase interactivo

`git rebase -i` te permite reordenar, fusionar (`squash`/`fixup`), editar o eliminar commits. Es la herramienta para convertir un caótico "wip, wip, arreglo, wip" en una secuencia de commits atómicos y con sentido, **antes** de que nadie los vea.

- Usa `fixup` para absorber un "corrige lo anterior" dentro del commit que corrige.
- Muchos equipos hacen **squash merge** del PR: toda la rama colapsa en un commit limpio en `main`. Bien para historial troncal ordenado; a cambio, pierdes la granularidad interna de la rama.
- **Cautela absoluta:** interactivo solo sobre historia **no compartida**. Si ya la publicaste y alguien la usa, no la reescribas.

## Resolución de conflictos

Un conflicto no es un error tuyo: es Git diciendo "dos cambios tocaron lo mismo, decide tú". Con calma:

1. `git status` te dice qué archivos están en conflicto.
2. Abre cada archivo y localiza los marcadores `<<<<<<<`, `=======`, `>>>>>>>`.
3. **Entiende ambos lados** antes de tocar nada: qué intentaba cada cambio y por qué. No borres a ciegas "el otro lado" para que compile.
4. Resuelve dejando el código correcto (que puede ser una combinación de ambos, no uno u otro).
5. Ejecuta los tests. Un merge que compila pero rompe comportamiento es peor que el conflicto.
6. `git add` de los archivos resueltos y continúa (`git merge --continue` / `git rebase --continue`).

Conflictos frecuentes y dolorosos suelen ser síntoma de ramas que viven demasiado: intégrate a `main` más seguido y los conflictos serán pequeños.

## .gitignore

Configura `.gitignore` desde el primer commit. Lo que **nunca** se versiona:

- **Secretos y credenciales:** `.env`, `*.pem`, claves de API, tokens.
- **Dependencias instalables:** `node_modules/`, `vendor/`, entornos virtuales.
- **Artefactos de build:** `dist/`, `build/`, `target/`, `*.o`, binarios compilados.
- **Ruido de entorno:** `.DS_Store`, `.idea/`, `*.log`, cachés locales.

Si algo ya fue commiteado por error, agregarlo a `.gitignore` no lo borra del repo: sigue rastreado. Usa `git rm --cached <archivo>` y commitea la eliminación (y si era un secreto, ver abajo). Para qué constituye material sensible, ver la skill **security**.

## Nunca commitear secretos

Un secreto en el historial es un secreto **comprometido**, aunque lo borres en el commit siguiente. Git recuerda todo: cualquiera con acceso al repo puede recuperarlo del historial.

Si commiteaste un secreto:

1. **Rótalo YA.** Invalida la credencial en su proveedor y genera una nueva. Este es el único paso que de verdad te protege.
2. Solo **después**, limpia el historial (`git filter-repo`, BFG) si procede, y fuerza el push coordinando con el equipo.
3. **Borrar el archivo en un nuevo commit NO es suficiente:** la credencial sigue en la historia y probablemente ya fue clonada o indexada.

Previene con hooks de detección de secretos (`gitleaks`, `trufflehog`) y con `.gitignore` correcto. Ver la skill **security**.

## Tags y releases (SemVer)

Marca las versiones publicadas con tags anotados, siguiendo **Semantic Versioning** `MAJOR.MINOR.PATCH`:

- **MAJOR:** cambios incompatibles (rompes la API pública).
- **MINOR:** funcionalidad nueva compatible hacia atrás.
- **PATCH:** correcciones compatibles hacia atrás.

```
git tag -a v2.3.0 -m "Release 2.3.0: cupones de descuento en checkout"
git push origin v2.3.0
```

Si adoptaste Conventional Commits, la versión se puede derivar automáticamente del historial (`feat` → MINOR, `fix` → PATCH, `BREAKING CHANGE` → MAJOR) con herramientas como semantic-release.

## Protección de la rama principal

`main` se protege con reglas, no con buena voluntad. Configura en tu forja:

- **CI en verde obligatorio** antes de mergear (build + tests + lint).
- **Revisiones aprobadas requeridas** (una o más, según el equipo).
- **Sin push directo:** todo entra por PR.
- **Historial lineal** si tu equipo lo prefiere (fuerza rebase/squash).
- **Sin `force-push`** a la rama protegida.

## Hooks

Los hooks automatizan la disciplina para que no dependa de que te acuerdes.

- **`pre-commit`:** corre lint, formateo y tests rápidos antes de crear el commit. Frena la basura en el origen.
- **`commit-msg`:** valida el formato Conventional Commits.
- **`pre-push`:** corre la suite más pesada antes de publicar.

Usa gestores como `pre-commit`, `husky` o `lefthook` para versionar los hooks con el repo y que todo el equipo los comparta. Regla: los hooks deben ser **rápidos**; si tardan minutos, la gente los saltará con `--no-verify`.

## Comandos de recuperación

Git casi nunca pierde tu trabajo; solo hay que saber recuperarlo.

- **`git reflog`** — el salvavidas. Registra dónde estuvo `HEAD` aunque hayas hecho `reset` o rebase destructivo. Encuentra el hash "perdido" y vuelve a él con `git reset --hard <hash>` o `git checkout <hash>`.
- **`git revert <commit>`** — crea un **nuevo** commit que deshace otro. **Es la forma segura de deshacer en ramas compartidas**: no reescribe historia, solo la añade.
- **`git reset`** — mueve `HEAD` (y opcionalmente el índice/árbol). `--soft` conserva cambios staged, `--mixed` los deja sin stage, `--hard` los **destruye**. **Solo en historia local.** `reset --hard` sobre lo que ya publicaste es cómo se pierde el trabajo del equipo.
- **`git cherry-pick <commit>`** — reaplica un commit concreto en tu rama actual. Útil para llevar un fix puntual a otra rama; úsalo con criterio para no duplicar historia.

> Advertencia: `reset --hard`, `push --force` y `rebase` de historia compartida son las tres formas más comunes de perder trabajo ajeno. Ante la duda, prefiere `revert` y `push --force-with-lease` (que aborta si alguien empujó cambios que no tienes).

---

## Anti-patrones comunes

- **Commits "wip"/"fix" en serie.** Historia ilegible e imposible de bisectar. Si necesitas checkpoints mientras trabajas, límpialos con `rebase -i` antes del PR.
- **Ramas eternas.** Cuanto más viven, más divergen y más duele el merge. Intégrate seguido.
- **`push --force` a ramas compartidas.** Reescribes historia bajo los pies del equipo. Usa `--force-with-lease` y solo sobre ramas propias.
- **Commitear archivos generados o dependencias.** Infla el repo, genera conflictos absurdos y ensucia los diffs. Va a `.gitignore`.
- **Mensajes vacíos o mentirosos.** `.`, `asdf`, `arreglos` o un asunto que no describe el cambio. Cada mensaje pobre es contexto perdido para siempre.
- **PRs gigantes de foco múltiple.** Nadie los revisa de verdad; se aprueban por fatiga.
- **Commitear con los tests en rojo.** Rompe la premisa de que cada commit es un punto sano del historial.

## Checklist antes de abrir un PR

- [ ] La rama parte de `main` actualizado y es de vida corta.
- [ ] Cada commit es atómico, compila y pasa los tests.
- [ ] Los mensajes siguen Conventional Commits y explican el PORQUÉ.
- [ ] Revisé mi propio diff completo, línea por línea.
- [ ] No hay secretos, `console.log`, código muerto ni archivos generados.
- [ ] `.gitignore` cubre lo que no debe versionarse.
- [ ] El PR es pequeño (< ~400 líneas) y de foco único; si no, lo dividí en PRs encadenados.
- [ ] La descripción incluye contexto, qué cambió y cómo probarlo.
- [ ] Lint, formato y tests pasan en local (y CI está configurado para verificarlo).
- [ ] Enlacé el issue/ticket relacionado.

## Referencias

- **Conventional Commits** — https://www.conventionalcommits.org
- **Pro Git** (libro oficial, gratuito) — https://git-scm.com/book
- **Semantic Versioning** — https://semver.org
- Skills relacionadas: **code-review**, **work-unit-commits**, **chained-pr**, **security**, **testing**.
