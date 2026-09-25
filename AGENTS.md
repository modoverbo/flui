# AGENTS.md

> Guía maestra de desarrollo para agentes de IA y personas.
> Formato abierto [AGENTS.md](https://agents.md/): Markdown vivo que los agentes de codificación
> leen automáticamente. En un monorepo, el `AGENTS.md` más cercano en el árbol tiene precedencia.
> Este archivo es **reutilizable en cualquier proyecto**: contiene principios, reglas de clean code,
> patrones de diseño y arquitecturas que aplican siempre, más un índice de _skills_ especializadas.

---

## 0. Cómo usar este archivo

**Si eres un agente de IA:** antes de escribir o modificar código, aplica por defecto los
principios de las secciones 2 a 6. Cuando la tarea encaje con un dominio concreto (API, UI, testing,
seguridad, etc.), abre la _skill_ correspondiente de la tabla de la sección 8 y sigue sus reglas.
Ante conflicto, gana la regla más específica: convención del proyecto > skill de dominio > este archivo.

**Si eres una persona:** trátalo como documentación viva. Cuando una regla deje de aplicar,
edítala; no acumules reglas muertas.

**Regla de oro transversal:** **primero entender, luego codificar.** El código es la consecuencia
de una decisión de diseño, no el punto de partida. Si no puedes explicar *por qué* algo funciona,
todavía no estás listo para escribirlo.

---

## 1. Filosofía

- **Conceptos por encima de código.** Un patrón mal entendido es peor que no usarlo.
- **La IA es una herramienta.** La persona dirige y verifica; la IA ejecuta bajo criterio.
- **Fundamentos sólidos.** Arquitectura, límites y tests antes que frameworks de moda.
- **Contra la inmediatez.** No se cambia corrección ni aprendizaje por velocidad aparente.
- **Optimiza para lectura.** El código se lee muchas más veces de las que se escribe.
- **Deja el campamento más limpio de como lo encontraste** (Boy Scout Rule).

---

## 2. Principios de desarrollo (reglas principales)

### 2.1 SOLID

| Principio | Significado | Para qué sirve | Síntoma de violación |
|-----------|-------------|----------------|----------------------|
| **S** — Single Responsibility | Una clase/módulo tiene **una sola razón para cambiar**. | Aísla el impacto del cambio; facilita testear y nombrar. | Clases "God", nombres con "And"/"Manager", cambios que tocan cosas no relacionadas. |
| **O** — Open/Closed | Abierto a extensión, cerrado a modificación. | Añadir comportamiento sin reabrir código probado. | `switch`/`if` gigantes que crecen con cada caso nuevo. |
| **L** — Liskov Substitution | Un subtipo debe poder sustituir a su tipo base sin romper el contrato. | Herencia y polimorfismo seguros. | Subclases que lanzan `NotSupported`, que endurecen precondiciones o debilitan postcondiciones. |
| **I** — Interface Segregation | Muchas interfaces pequeñas y específicas mejor que una grande. | El cliente no depende de métodos que no usa. | Interfaces con métodos que algunas implementaciones dejan vacíos. |
| **D** — Dependency Inversion | Depende de **abstracciones**, no de concreciones. El detalle depende de la política, no al revés. | Desacopla el dominio de la infraestructura; permite testear con dobles. | El dominio importa el ORM, el cliente HTTP o el framework directamente. |

### 2.2 Principios de simplicidad

- **DRY** (Don't Repeat Yourself): cada conocimiento tiene **una única representación** autoritativa.
  Ojo: DRY es sobre *conocimiento duplicado*, no sobre *código que casualmente se parece*. Abstraer
  demasiado pronto crea acoplamiento falso (ver **AHA** / **WET**: "Write Everything Twice" —
  espera a la tercera repetición antes de abstraer).
- **KISS** (Keep It Simple): la solución más simple que resuelva el problema real. Complejidad solo
  cuando la exija el dominio, no el ego.
- **YAGNI** (You Aren't Gonna Need It): no construyas para un futuro hipotético. El código no
  escrito es el más barato de mantener.

### 2.3 Otros principios que aplican siempre

- **SoC** (Separation of Concerns): cada parte resuelve una preocupación (UI, dominio, persistencia).
- **Law of Demeter** ("no hables con extraños"): un objeto solo llama a sus vecinos directos; evita
  cadenas `a.b().c().d()` que exponen estructura interna.
- **Composition over Inheritance**: prefiere componer comportamientos a heredar jerarquías rígidas.
- **Fail Fast**: valida en la frontera y falla ruidosamente cerca del error, no tres capas después.
- **Principle of Least Astonishment** (POLA): el código hace lo que su nombre promete, sin sorpresas.
- **Least Privilege**: cada componente accede solo a lo que necesita (aplica a código y a seguridad).
- **Make it work → make it right → make it fast**, en ese orden. Nunca optimices lo que no mides.
- **High cohesion, low coupling**: lo que cambia junto vive junto; lo que no, se separa.

### 2.4 Estrategia *free-first* (obligatoria)

- Empieza por la opción de menor coste operativo: estático/local → BaaS gratuito → edge/serverless → backend dedicado → autoalojamiento.
- Escalar a una opción pagada, backend dedicado o autoalojamiento exige una excepción escrita: requisito no cubierto, alternativas descartadas, coste, responsable operativo, seguridad, respaldo y salida/migración.
- **No existe acoplamiento cero.** El objetivo es mínimo acoplamiento necesario, dependencias hacia abstracciones en fronteras volátiles y máxima cohesión por responsabilidad.
- Las skills, instrucciones y documentación creadas por este proyecto se escriben en español; skills externas instaladas pueden conservar su idioma original.

---

## 3. Clean Code

### 3.1 Nombres

- Revelan intención: `elapsedTimeInDays`, no `d`. El nombre debe responder qué es, qué hace y cómo se usa.
- Pronunciables y buscables. Evita abreviaturas crípticas y números mágicos (usa constantes con nombre).
- Clases → sustantivos (`Invoice`, `PaymentGateway`). Métodos → verbos (`send()`, `calculateTotal()`).
- Un concepto, una palabra: no mezcles `fetch`/`get`/`retrieve` para lo mismo.
- Booleanos afirmativos: `isActive`, `hasPermission` (no `isNotDisabled`).

### 3.2 Funciones

- **Pequeñas.** Hacen **una sola cosa** y a un solo nivel de abstracción.
- Pocos argumentos (0-2 ideal; 3 con cuidado). Muchos parámetros → agrúpalos en un objeto.
- Evita **banderas booleanas** como parámetro: suelen indicar que la función hace dos cosas → divídela.
- **Sin efectos secundarios ocultos.** Comando (cambia estado) o consulta (devuelve dato), no ambos (CQS).
- Extrae hasta que no puedas extraer más sin inventar nombres absurdos.

### 3.3 Comentarios

- El mejor comentario es el que no necesitas porque el código se explica solo.
- Comenta el **porqué**, no el **qué** (el qué lo dice el código). Documenta decisiones, trade-offs y "gotchas".
- No dejes código comentado: para eso está el control de versiones. Borra.
- Evita comentarios que mienten: un comentario desactualizado es peor que ninguno.

### 3.4 Formato y estructura

- Consistencia > preferencia personal. Usa formateador y linter automáticos (Prettier, ESLint, gofmt, Black…).
- Líneas y funciones cortas; una idea por línea. Espaciado vertical para separar bloques conceptuales.
- Lo relacionado, cerca. Declara variables junto a su uso.

### 3.5 Manejo de errores

- Usa **excepciones/Result**, no códigos de retorno que se ignoran silenciosamente.
- No tragues errores (`catch` vacío). Falla ruidosamente o propaga con contexto.
- No uses excepciones para flujo de control normal.
- Define el "happy path" primero; los errores en los bordes. Ver skill `error-handling-observability`.

### 3.6 Code smells a cazar

Código duplicado · funciones largas · clases God · listas largas de parámetros · comentarios que
explican código malo · nombres genéricos (`data`, `manager`, `util`) · acoplamiento excesivo ·
"feature envy" (un método usa más otra clase que la propia) · números y strings mágicos ·
anidamiento profundo (>3 niveles) · condicionales complejas sin nombrar.

---

## 4. Patrones de diseño

> Un patrón es una **solución probada a un problema recurrente**, no una meta. Úsalo cuando el
> problema aparezca, no "porque sí". Conocerlos también sirve para **comunicar** ("esto es un Adapter").

### 4.1 Creacionales — *cómo se crean los objetos*

| Patrón | Para qué sirve |
|--------|----------------|
| **Factory Method** | Delegar a subclases qué objeto concreto crear; desacoplar el "new". |
| **Abstract Factory** | Crear familias de objetos relacionados sin fijar clases concretas. |
| **Builder** | Construir objetos complejos paso a paso; evitar constructores telescópicos. |
| **Prototype** | Crear nuevos objetos clonando uno existente (evita coste de construcción). |
| **Singleton** | Una única instancia global. **Úsalo con cautela**: suele ser estado global disfrazado y complica el testeo. |

### 4.2 Estructurales — *cómo se componen los objetos*

| Patrón | Para qué sirve |
|--------|----------------|
| **Adapter** | Hacer compatibles dos interfaces incompatibles (envolver una API ajena). |
| **Bridge** | Separar abstracción de implementación para que varíen independientemente. |
| **Composite** | Tratar objetos individuales y composiciones de forma uniforme (árboles). |
| **Decorator** | Añadir responsabilidades a un objeto dinámicamente sin heredar. |
| **Facade** | Ofrecer una interfaz simple sobre un subsistema complejo. |
| **Flyweight** | Compartir estado común entre muchos objetos para ahorrar memoria. |
| **Proxy** | Un sustituto que controla el acceso (lazy loading, caché, permisos, remoto). |

### 4.3 De comportamiento — *cómo interactúan y reparten responsabilidad*

| Patrón | Para qué sirve |
|--------|----------------|
| **Strategy** | Intercambiar algoritmos en tiempo de ejecución; matar `switch` de comportamiento. |
| **Observer** | Notificar a múltiples suscriptores cuando algo cambia (eventos, reactividad). |
| **Command** | Encapsular una petición como objeto (undo/redo, colas, logs de acciones). |
| **State** | Cambiar el comportamiento de un objeto según su estado interno. |
| **Template Method** | Definir el esqueleto de un algoritmo y dejar pasos a las subclases. |
| **Iterator** | Recorrer una colección sin exponer su representación interna. |
| **Mediator** | Centralizar la comunicación entre objetos para reducir acoplamiento. |
| **Chain of Responsibility** | Pasar una petición por una cadena de manejadores (middlewares). |
| **Visitor** | Añadir operaciones a una jerarquía sin modificar sus clases. |
| **Memento** | Guardar y restaurar el estado de un objeto (snapshots). |
| **Interpreter** | Evaluar sentencias de un lenguaje/gramática. |

### 4.4 Patrones de arquitectura/empresa muy usados

- **Repository**: abstrae el acceso a datos; el dominio no sabe si es SQL, HTTP o memoria.
- **Unit of Work**: agrupa operaciones en una transacción coherente.
- **Dependency Injection**: inyecta dependencias desde fuera (habilita DIP y testeo con dobles).
- **DTO** (Data Transfer Object): objeto plano para transportar datos entre capas/servicios.
- **Value Object**: objeto inmutable definido por su valor (Money, Email), no por identidad.
- **CQRS**: separa el modelo de lectura del de escritura.
- **Event Sourcing**: el estado es la suma de eventos, no un snapshot mutable.
- **Saga**: coordina transacciones distribuidas de larga duración con compensaciones.

---

## 5. Arquitecturas de software

> La arquitectura define **los límites**: qué depende de qué. Una buena arquitectura mantiene las
> decisiones importantes (framework, base de datos, UI) como **detalles reemplazables**, no como el centro.

### 5.1 Estilos de organización interna

| Arquitectura | Idea central | Para qué sirve / cuándo |
|--------------|--------------|--------------------------|
| **Layered (N-capas)** | Presentación → Aplicación → Dominio → Infraestructura. | Simple y familiar. Riesgo: capas que filtran detalles hacia el dominio. |
| **Hexagonal (Ports & Adapters)** | El dominio expone *puertos*; los *adaptadores* (DB, HTTP, UI) se conectan a ellos. | Aísla el núcleo de la tecnología; testeo sin infraestructura. |
| **Onion** | Capas concéntricas; las dependencias apuntan **hacia adentro**, al dominio. | Igual espíritu que hexagonal, con énfasis en el modelo de dominio. |
| **Clean Architecture** | Entidades → Casos de uso → Adaptadores de interfaz → Frameworks. Regla de dependencia. | Independencia de framework, UI, DB y agentes externos. Ver sección 6. |
| **Screaming Architecture** | La estructura de carpetas **grita el dominio** (`billing/`, `orders/`), no el framework. | Que el propósito del sistema sea obvio al abrir el repo. |
| **Vertical Slice** | Organiza por funcionalidad completa (feature) en vez de por capa técnica. | Cohesión por caso de uso; menos saltos entre carpetas. |
| **Modular Monolith** | Un solo despliegue con módulos de límites fuertes y explícitos. | Casi todos los beneficios de microservicios sin el coste operativo. |

### 5.2 Patrones de presentación (UI)

| Patrón | Idea |
|--------|------|
| **MVC** | Model / View / Controller: separa datos, vista y coordinación de entrada. |
| **MVP** | Model / View / Presenter: la vista es pasiva, el presenter tiene la lógica. |
| **MVVM** | Model / View / ViewModel con binding: muy usado en frontend reactivo. |
| **Container / Presentational** | Componentes "listos" (estado/lógica) vs "tontos" (solo presentación). |
| **Atomic Design** | Átomos → Moléculas → Organismos → Plantillas → Páginas. Ver skill `ui-design`. |

### 5.3 Estilos de sistema distribuido

| Estilo | Para qué sirve | Coste |
|--------|----------------|-------|
| **Monolito** | Empezar rápido, un solo despliegue, transacciones simples. | Escala organizativa limitada. |
| **Microservicios** | Escalar equipos y servicios de forma independiente. | Complejidad operativa, red, consistencia eventual. |
| **Event-Driven** | Desacoplar productores y consumidores vía eventos/mensajes. | Difícil de depurar; requiere idempotencia. |
| **Serverless** | Escalado automático, pago por uso, sin gestionar servidores. | Cold starts, límites del proveedor, lock-in. |
| **SOA** | Servicios reutilizables a nivel empresa con contratos claros. | Gobernanza pesada. |

> **Regla práctica:** empieza con un **monolito modular** bien separado. Extrae a microservicios solo
> cuando exista una razón real (escala, equipos, despliegue independiente). No pagues el coste antes de tiempo.

---

## 6. Clean Architecture en profundidad

**La Regla de Dependencia:** el código fuente solo puede depender **hacia adentro**. Nada de un
círculo interior conoce nada del exterior. Los nombres del exterior (framework, DB, web) no aparecen
en el código interior.

```
        ┌─────────────────────────────────────────┐
        │  Frameworks & Drivers (Web, DB, UI, IO)   │  ← detalles reemplazables
        │   ┌───────────────────────────────────┐   │
        │   │  Interface Adapters               │   │  ← controllers, gateways, presenters
        │   │   ┌───────────────────────────┐   │   │
        │   │   │  Application (Use Cases)  │   │   │  ← reglas de aplicación
        │   │   │   ┌───────────────────┐   │   │   │
        │   │   │   │  Entities (Domain) │   │   │   │  ← reglas de negocio puras
        │   │   │   └───────────────────┘   │   │   │
        │   │   └───────────────────────────┘   │   │
        │   └───────────────────────────────────┘   │
        └─────────────────────────────────────────┘
              Las dependencias apuntan  →  hacia adentro
```

- **Entities:** reglas de negocio más estables; no saben nada del mundo exterior.
- **Use Cases:** orquestan las entidades para cumplir una acción del usuario. Definen *puertos* (interfaces).
- **Interface Adapters:** traducen entre el mundo exterior y los casos de uso (controllers, repositorios).
- **Frameworks & Drivers:** el detalle (Express, React, Postgres). Se conectan por inversión de dependencias.

**Beneficio:** puedes cambiar de framework, base de datos o UI **sin tocar el dominio**, y testear la
lógica de negocio sin levantar infraestructura. Si al testear una regla de negocio necesitas una base de
datos o un servidor, la arquitectura está mal.

---

## 7. Reglas globales del proyecto

> Reglas concretas de **flui**. El detalle vive en `README.md`, `app/README.md`, `content/README.md`
> y `docs/`; aquí solo lo que un agente necesita para construir, probar y contribuir.

### Mapa del monorepo

| Ruta | Qué es | Tests |
|------|--------|-------|
| `app/` | App Flutter 3.47.4 (Dart 3.13), web primero; Android e iOS habilitados. Riverpod, go_router, freezed. | `flutter test` |
| `content/` | Paquete Dart puro: valida las palabras YAML y genera `supabase/seed.sql`. | `dart test` |
| `supabase/` | Migraciones Postgres, RLS, seed y tests pgTAP. | `npx supabase@latest test db` (requiere Docker) |
| `supabase/functions/` | Edge Functions Deno (Whop, análisis de voz). | `deno task ci` |

No hay un comando único que pruebe todo: ejecuta el del proyecto que tocaste.

### Setup de la app

```bash
cd app
cp config/fake.example.json config/fake.json      # backend falso en memoria, sin red
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

Los archivos generados (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/gen/`) no se commitean.

### Ejecutar la app

| Destino | Comando (desde `app/`) |
|---------|------------------------|
| Chrome (iteración rápida; vista móvil con `Ctrl+Shift+M`) | `flutter run -d chrome --web-port 3000 --dart-define-from-file=config/fake.json` |
| Teléfono Android por USB | `flutter run -d <device-id> --dart-define-from-file=config/fake.json` |
| Contra Supabase local | igual, con `config/local.json` (ver `README.md`) |

Para el teléfono: activar la depuración USB y aceptar el aviso en el teléfono; `adb devices` debe
mostrarlo como `device`, no `unauthorized`. No hace falta Android Studio. Problemas conocidos
(primer build lento, firma incompatible, Supabase inalcanzable desde el teléfono, emulador y grupo
`kvm`) en [`app/README.md`](app/README.md#on-a-phone-or-emulator).

Un agente que lanza `flutter run` en segundo plano no puede usar hot reload (necesita stdin): si la
persona va a iterar, que lo ejecute en su propia terminal.

### Verificar antes de dar una tarea por buena (desde `app/`)

```bash
dart format --set-exit-if-changed lib test integration_test
flutter analyze && dart analyze
flutter test
flutter test integration_test -d flutter-tester
```

### Convenciones

- **Idioma:** código, identificadores, comentarios y docs técnicas en inglés; textos de UI y
  contenido en español neutro, con "tú".
- **TDD:** test primero para toda la lógica.
- **Estilo:** `very_good_analysis` + `riverpod_lint` en la app; se ejecuta en CI.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `type(scope): description`
  (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`…). Sin atribución de IA en los commits.
- **Ramas y PRs:** una unidad de trabajo revisable por PR; PRs pequeños (< ~400 líneas). Ver skill `code-review`.
- **Tests:** todo cambio de comportamiento va con test. No se baja cobertura de lógica de dominio.
- **Seguridad:** nunca commitear secretos; validar toda entrada externa. Ver skill `security`.

---

## 8. Índice de Skills

> Cada skill es una guía extensa y accionable para un dominio del desarrollo. Ábrela cuando la tarea
> encaje con su disparador. Todas viven en `skills/<nombre>/SKILL.md`.

| Skill | Descripción | Ir a |
|-------|-------------|------|
| **api-design** | Diseño de APIs y endpoints: REST, versionado, errores, paginación, idempotencia, contratos. | [`skills/api-design/SKILL.md`](skills/api-design/SKILL.md) |
| **database-design** | Modelado de datos: normalización, índices, transacciones, migraciones, N+1, integridad. | [`skills/database-design/SKILL.md`](skills/database-design/SKILL.md) |
| **testing** | Estrategia de tests: pirámide, TDD, unit/integration/e2e, dobles, cobertura con valor. | [`skills/testing/SKILL.md`](skills/testing/SKILL.md) |
| **security** | Seguridad aplicada: OWASP, autenticación/autorización, secretos, validación, defensa en profundidad. | [`skills/security/SKILL.md`](skills/security/SKILL.md) |
| **performance** | Rendimiento: medir antes de optimizar, caché, Big-O, concurrencia, lazy loading, presupuestos. | [`skills/performance/SKILL.md`](skills/performance/SKILL.md) |
| **ui-design** | Diseño de interfaces: sistemas de diseño, tipografía, color, espaciado, consistencia visual. | [`skills/ui-design/SKILL.md`](skills/ui-design/SKILL.md) |
| **ux-design** | Experiencia de usuario: heurísticas de usabilidad, flujos, formularios, feedback, jerarquía. | [`skills/ux-design/SKILL.md`](skills/ux-design/SKILL.md) |
| **accessibility** | Accesibilidad (a11y): WCAG, semántica, teclado, ARIA, contraste, lectores de pantalla. | [`skills/accessibility/SKILL.md`](skills/accessibility/SKILL.md) |
| **frontend-architecture** | Arquitectura frontend: componentes, composición, límites, estructura de carpetas, rendimiento. | [`skills/frontend-architecture/SKILL.md`](skills/frontend-architecture/SKILL.md) |
| **state-management** | Gestión de estado: local vs global, server state, inmutabilidad, patrones y anti-patrones. | [`skills/state-management/SKILL.md`](skills/state-management/SKILL.md) |
| **git-workflow** | Flujo con Git: ramas, commits atómicos, Conventional Commits, PRs, rebase vs merge. | [`skills/git-workflow/SKILL.md`](skills/git-workflow/SKILL.md) |
| **code-review** | Revisión de código: qué mirar, tamaño de PR, feedback con criterio, checklist de revisor. | [`skills/code-review/SKILL.md`](skills/code-review/SKILL.md) |
| **refactoring** | Refactorización y deuda técnica: cuándo, técnicas seguras, code smells, red-green-refactor. | [`skills/refactoring/SKILL.md`](skills/refactoring/SKILL.md) |
| **error-handling-observability** | Manejo de errores, logging estructurado, métricas, trazas, alertas y resiliencia. | [`skills/error-handling-observability/SKILL.md`](skills/error-handling-observability/SKILL.md) |
| **software-architecture** | Arquitectura de software: límites, puertos/adaptadores, dirección de dependencias y ADRs. | [`skills/software-architecture/SKILL.md`](skills/software-architecture/SKILL.md) |
| **design-patterns** | Patrones GoF, empresariales, de integración y distribuidos: problema, coste y cuándo usarlos. | [`skills/design-patterns/SKILL.md`](skills/design-patterns/SKILL.md) |
| **free-first-architecture** | Decisión obligatoria de coste: estático, BaaS, edge, backend o autoalojamiento. | [`skills/free-first-architecture/SKILL.md`](skills/free-first-architecture/SKILL.md) |
| **backendless-apps** | Apps sin backend dedicado: PWA, BaaS, RLS y funciones edge seguras. | [`skills/backendless-apps/SKILL.md`](skills/backendless-apps/SKILL.md) |
| **product-discovery** | Descubrimiento de producto: hipótesis, MVP, experimentos y métricas de validación. | [`skills/product-discovery/SKILL.md`](skills/product-discovery/SKILL.md) |
| **deployment-strategy** | Despliegue gratuito, límites de proveedor, observabilidad y migración. | [`skills/deployment-strategy/SKILL.md`](skills/deployment-strategy/SKILL.md) |
| **design-system** | Sistema de diseño: tokens, componentes, temas y consistencia visual. | [`skills/design-system/SKILL.md`](skills/design-system/SKILL.md) |
| **motion-design** | Motion design: animaciones útiles, rendimiento y movimiento reducido. | [`skills/motion-design/SKILL.md`](skills/motion-design/SKILL.md) |
| **visual-quality** | Calidad visual: responsive, regresión visual y estados de interfaz. | [`skills/visual-quality/SKILL.md`](skills/visual-quality/SKILL.md) |

---

_Documentación viva. Cuando una regla deje de ser cierta, edítala. Mantén este archivo en la raíz del repo._
