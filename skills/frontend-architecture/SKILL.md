---
name: frontend-architecture
description: "Arquitectura frontend: componentes, composición, límites, estructura de carpetas, rendimiento."
---

# Arquitectura Frontend

> **Cuándo usar:** al diseñar la estructura de una aplicación cliente nueva; al decidir dónde vive el estado o la lógica; cuando un componente supera las ~150 líneas o acumula responsabilidades; cuando aparece prop drilling profundo o hay `fetch` esparcido por la UI; al organizar carpetas o al revisar un PR frontend en busca de límites mal trazados. Esta guía es agnóstica de framework: los principios aplican a React, Vue, Angular y Svelte por igual. Donde digo "componente" y "hook", lee "composable", "servicio" o "store" según tu stack.

La arquitectura frontend no es "elegir el framework". Es DECIDIR DÓNDE VIVEN LAS COSAS y QUIÉN CONOCE A QUIÉN. Un mal framework con buenos límites se mantiene; un buen framework sin límites se pudre en meses. El PORQUÉ importa más que la sintaxis.

---

## 1. Principios fundamentales

Cuatro ideas sostienen todo lo demás. Si dudas ante una decisión, vuelve aquí.

1. **Separación de responsabilidades (SoC).** La presentación (cómo se ve) NO es lo mismo que la lógica de aplicación (qué hace) ni que el acceso a datos (de dónde viene). Mezclarlas produce componentes que solo puedes entender leyéndolos enteros y que no puedes reutilizar ni probar por partes. Cada capa tiene un lenguaje propio: la UI habla de píxeles y eventos; la lógica habla de casos de uso; los datos hablan de endpoints y modelos.

2. **Composición sobre herencia.** En frontend casi nunca extiendes componentes; los COMPONES. Un `Card` no hereda de `Container`: recibe `children`. La composición te da flexibilidad sin acoplar jerarquías. Cuando pienses "necesito una variante", pregúntate primero si es una nueva pieza que se compone, no una subclase ni un flag más.

3. **Un solo motivo de cambio por componente (SRP).** Si un componente cambia cuando cambia el diseño Y cuando cambia la regla de negocio Y cuando cambia el endpoint, tiene tres motivos de cambio, o sea tres responsabilidades disfrazadas de una. Sepáralas. La prueba práctica: describe el componente en una frase sin usar "y". Si no puedes, es dos componentes.

4. **Fuente única de verdad (SSOT).** Cada dato tiene UN dueño. Duplicar estado (una copia en el padre, otra en el hijo, otra en un contexto) garantiza que tarde o temprano diverjan y aparezca el bug "en pantalla dice X pero el estado dice Y". Deriva; no copies. Si un valor se puede calcular a partir de otro, calcúlalo, no lo almacenes.

---

## 2. Reglas de oro

| Haz | Evita |
| --- | --- |
| Componentes pequeños con una responsabilidad clara | Componentes de 500 líneas que hacen fetch, transforman, validan y pintan |
| Props explícitas y tipadas | Pasar objetos gigantes "por si acaso" o `props: any` |
| Colocar el estado lo más cerca de donde se usa | Subir todo al estado global "para tenerlo a mano" |
| Aislar el acceso a datos en una capa de cliente/API | Llamar `fetch`/`axios` directo dentro de un componente de UI |
| Componer con `children`/slots | Explosión de props booleanas (`isPrimary`, `isSmall`, `isOutlined`, `isLoading`…) |
| Organizar por dominio/feature | Organizar solo por tipo técnico (`components/`, `hooks/`, `utils/`) a gran escala |
| Derivar valores del estado | Duplicar estado y sincronizarlo a mano con efectos |
| Estados explícitos de carga / error / vacío / éxito | Asumir que los datos siempre llegan y llegan bien |
| Probar comportamiento visible | Probar detalles internos (nombre de estado, orden de llamadas) |
| Consumir tokens y componentes del design system | Estilos ad-hoc y colores hardcodeados en cada vista |

---

## 3. Diseño de componentes

Un buen componente es **pequeño, con una responsabilidad y reutilizable**, en ese orden. Pequeño para poder leerlo de una; con una responsabilidad para tener un solo motivo de cambio; reutilizable como consecuencia de lo anterior, no como objetivo forzado (no generalices antes de tener dos usos reales — la abstracción prematura duele más que la duplicación).

**API clara y explícita.** La firma de props ES el contrato del componente. Debe leerse como documentación: nombres que dicen intención (`onConfirm`, no `handleClick`), tipos precisos (una unión `'sm' | 'md' | 'lg'`, no `string`), y el mínimo de props necesarias. Una prop que "a veces se usa" es una señal de que ahí dentro hay dos componentes.

**Regla del tamaño.** Si un componente pasa de ~150 líneas o tiene más de 3-4 responsabilidades visuales/lógicas, divídelo. No por dogma, sino porque a partir de ahí el costo de entenderlo crece más rápido que su valor.

**Un componente por archivo.** El nombre del archivo == el nombre del componente. Facilita búsqueda, imports y navegación. Los subcomponentes privados que solo usa ese archivo pueden convivir, pero en cuanto uno se reutiliza, sale a su propio archivo.

---

## 4. Container / Presentational (smart vs dumb)

Separa la **lógica y el estado** (container / "smart") de la **presentación** (presentational / "dumb").

- **Presentational (dumb):** recibe datos por props y emite eventos hacia arriba. No sabe de dónde vienen los datos ni a dónde van los eventos. Es puro, predecible y trivial de probar y de mostrar en un catálogo (Storybook). Idealmente no tiene estado más allá de UI local (un `hover`, un input controlado).
- **Container (smart):** orquesta. Obtiene datos (vía hook/composable/servicio), maneja estado de aplicación, decide qué mostrar y pasa todo hacia abajo. No debería tener casi JSX propio: delega la pintura.

El valor: puedes rediseñar la vista sin tocar la lógica, y cambiar el origen de datos sin tocar el diseño. En frameworks modernos esta separación a menudo se expresa como "componente que usa un hook/composable de datos" + "componente de presentación", más que como dos clases; el principio es el mismo. No lo apliques a TODO componente ciegamente: úsalo donde hay lógica real que aislar.

---

## 5. Composición sobre configuración

Cuando un componente crece en variantes, la tentación es añadir props de configuración. Ese camino lleva a la **explosión de props booleanas** y a un `if` interno por cada combinación.

Prefiere COMPONER:

- **`children` / slots** para inyectar contenido arbitrario en lugar de una prop `content`.
- **Componentes compuestos** (compound components): en vez de `<Menu items={[...]} withIcons dense />`, expón `<Menu><Menu.Item/><Menu.Item/></Menu>`. El consumidor arma justo lo que necesita.
- **Slots con nombre** (header/body/footer) para layouts flexibles sin una prop por región.

Regla práctica: si vas a añadir la tercera prop booleana a un componente, detente. Probablemente lo que necesitas es exponer piezas componibles, no otro flag. La configuración se acumula; la composición escala.

---

## 6. Estructura de carpetas

Dos filosofías:

- **Por tipo técnico:** `components/`, `hooks/`, `services/`, `utils/`. Funciona en proyectos pequeños. A escala, para tocar UNA feature abres cinco carpetas y el código relacionado queda disperso.
- **Por dominio / feature (screaming architecture):** la estructura GRITA qué HACE la app, no con qué está hecha. `features/checkout/`, `features/auth/`, `features/dashboard/`, cada una con sus componentes, hooks, servicios y tipos dentro.

**Recomendación:** por dominio para la lógica de negocio; por tipo técnico solo dentro de un dominio o para lo verdaderamente transversal (`shared/ui`, `shared/lib`). Una forma común y sólida:

```
src/
  app/                 # composición raíz, rutas, providers
  features/
    checkout/
      components/       # UI propia de checkout
      hooks/            # lógica/estado de checkout
      api/              # acceso a datos de checkout
      types.ts
      index.ts          # API pública de la feature (barrel controlado)
  shared/
    ui/                 # design system, componentes tontos reutilizables
    lib/                # utilidades puras transversales
    api/                # cliente HTTP base
```

**Colocación (colocation):** lo que cambia junto, vive junto. El test, los estilos, los tipos y los subcomponentes de un componente van a su lado, no en carpetas espejo lejanas. Reduce la fricción de encontrar y de borrar.

**Barrels (`index.ts`) con cuidado:** úsalos para definir la API PÚBLICA de una feature (qué puede importar el resto), no para reexportar todo indiscriminadamente. Los barrels grandes rompen el tree-shaking, crean dependencias circulares y hacen que un import barato arrastre medio módulo. Un barrel por feature, curado a mano, no autogenerado sobre todo el árbol.

**Regla de dependencia:** las features NO se importan entre sí directamente; comparten a través de `shared/` o se comunican por eventos/rutas. `shared/` nunca importa de `features/`. Esta dirección única evita el plato de espagueti.

---

## 7. Prop drilling y cómo resolverlo

El prop drilling es pasar una prop a través de varios niveles que no la usan, solo para que llegue a un nieto. Un nivel o dos es normal; cuatro es un olor. Soluciones, de menor a mayor artillería:

1. **Composición / inversión:** en lugar de pasar datos hacia abajo, pasa el COMPONENTE ya armado como `children`. Muchas veces el drilling desaparece porque el dato se resuelve donde ya existe.
2. **Elevar el estado (lifting state up):** si dos hermanos necesitan el mismo dato, súbelo al ancestro común MÁS CERCANO, no más arriba.
3. **Contexto / provide-inject:** para datos verdaderamente transversales a un subárbol (tema, usuario, i18n, locale). No es un almacén global de propósito general: úsalo para dependencias de subárbol estables, no para estado que cambia a cada tecla (provoca renders masivos).
4. **Gestión de estado dedicada:** para estado compartido complejo, ver **state-management**.

No saltes directo a un store global para evitar pasar una prop dos niveles. La solución más barata suele ser componer mejor.

---

## 8. Estado: dónde vive

Reglas de ubicación del estado:

- **Colócalo lo más cerca posible de donde se usa.** Estado que solo importa a un componente vive en ese componente. Subirlo "por si acaso" convierte cambios locales en re-renders globales y acopla lo que debería ser independiente.
- **Elévalo solo cuando se comparte** de verdad, y solo hasta el ancestro común más cercano.
- **Distingue estado de servidor de estado de UI.** Son animales distintos:
  - *Estado de servidor:* datos que el backend posee (listas, perfiles, catálogos). Son asíncronos, se cachean, se invalidan, pueden quedar obsoletos. Merecen una herramienta de datos de servidor (query cache), no `useState` + `useEffect` a mano.
  - *Estado de UI:* modales abiertos, pestaña activa, texto de un input, paso de un wizard. Es local y síncrono.
  Mezclarlos (guardar la respuesta de la API en el mismo store que el estado de un modal) es una fuente clásica de bugs de sincronización.
- **Deriva, no dupliques.** Si puedes calcular un valor a partir del estado existente, hazlo en render; no lo guardes en otro estado que tendrás que mantener sincronizado.

Profundiza en patrones, librerías y trade-offs en **state-management**.

---

## 9. Separación de capas en frontend

Aunque el frontend "solo pinta", tiene capas tan reales como el backend. Trázalas:

1. **UI (presentación):** componentes que reciben datos y emiten eventos. Sin `fetch`, sin reglas de negocio.
2. **Lógica de aplicación:** hooks / composables / servicios que orquestan casos de uso ("confirmar pedido", "aplicar cupón"). Aquí vive la coordinación, la validación de flujo y la transformación de datos para la vista.
3. **Acceso a datos:** cliente de API que sabe de endpoints, headers, serialización y errores de red. Es lo ÚNICO que conoce URLs.
4. **Modelos / tipos:** las formas de datos y los contratos. Compartidos entre capas como lenguaje común.

Dirección de dependencia: UI → lógica → datos. La UI nunca salta directo a datos; la capa de datos nunca conoce la UI. Cuando esto se respeta, cambiar el endpoint no toca un solo componente y rediseñar la vista no toca un `fetch`.

---

## 10. Patrón de acceso a datos

Aísla TODA comunicación con el backend en una capa de cliente/API. Un componente de UI que hace `fetch('/api/orders')` inline es deuda inmediata: no se puede probar sin red, repite manejo de errores, y cuando cambie la URL o el header de auth tendrás que cazarlo por toda la app.

En su lugar:

- Un **cliente base** (instancia HTTP) con configuración central: base URL, auth, interceptores, manejo de errores uniforme, timeouts.
- **Funciones/servicios por recurso** (`ordersApi.getById`, `ordersApi.create`) que devuelven modelos tipados, no respuestas crudas. Aquí traduces del contrato del backend al modelo del frontend.
- La UI consume esos servicios a través de la capa de lógica (hooks/composables), nunca directamente el `fetch`.

Beneficio: un solo lugar donde cambiar cuando el backend cambia, mocks triviales en tests, y errores de red manejados una vez.

---

## 11. Rendimiento

El rendimiento se gana con criterio, no rociando memoización por todas partes (memoizar tiene costo y a veces empeora las cosas). Prioridades:

- **Evita renders innecesarios** entendiendo qué los dispara: props que cambian de identidad en cada render (objetos/funciones inline), estado elevado de más, contextos que cambian demasiado.
- **Memoización con criterio:** memoiza cálculos caros y estabiliza referencias que cruzan límites de componentes memoizados. No memoices cálculos triviales.
- **Listas virtualizadas** para colecciones grandes: renderiza solo lo visible. Una tabla de 10.000 filas sin virtualizar mata el frame.
- **Keys correctas** en listas: estables y únicas por ítem (el ID del dato, NUNCA el índice si la lista se reordena o filtra). Keys malas causan estado cruzado entre filas y re-renders erróneos.
- **Code splitting / lazy loading:** carga diferida por ruta y por componente pesado. El usuario no debería descargar el panel de admin para ver la home.
- **Presupuesto de bundle:** vigila el tamaño; una dependencia pesada por una función se paga en cada carga.

Mide antes de optimizar. Profundiza en **performance**.

---

## 12. Manejo de errores en UI

Toda vista que depende de datos asíncronos tiene, como mínimo, CUATRO estados: **cargando, error, vacío y éxito**. Diseñar solo el "éxito" es la causa número uno de UIs que se sienten rotas.

- **Estado de carga:** feedback inmediato (skeleton, spinner con contexto). Nunca pantalla congelada.
- **Estado de error:** mensaje claro, accionable y con reintento cuando aplique. No un `null` silencioso ni un stack técnico.
- **Estado vacío:** "no hay resultados" bien diseñado con siguiente acción, distinto de "error" y distinto de "cargando".
- **Error boundaries:** captura fallos de render de un subárbol para que un componente roto no tumbe toda la app; muestra un fallback y permite recuperación. No sustituyen el manejo de errores de datos: son la red de seguridad para lo inesperado.

Los estados de carga/error/vacío también son diseño de experiencia: coordina con **ux-design**. El registro, correlación y reporte de errores se cubre en **error-handling-observability**.

---

## 13. Estrategias de renderizado

Elegir dónde y cuándo se genera el HTML es una decisión arquitectónica con impacto en rendimiento, SEO y complejidad.

| Estrategia | Qué es | Cuándo | Trade-off |
| --- | --- | --- | --- |
| **CSR** (client-side) | El navegador arma todo con JS | Apps privadas tras login, dashboards | SEO pobre, primer pintado lento; simple de operar |
| **SSR** (server-side) | HTML por request en el servidor | Contenido dinámico y personalizado que necesita SEO | Costo de servidor por request, más complejo |
| **SSG** (static) | HTML en build, servido estático | Contenido que cambia poco (docs, blog, marketing) | Rebuild para actualizar; rapidísimo y barato |
| **ISR** (incremental) | Estático + regeneración bajo demanda | Muchas páginas semi-estáticas (e-commerce, catálogos) | Complejidad de invalidación; casi lo mejor de ambos |

Regla: empieza por lo más simple que cumpla los requisitos de SEO y frescura. No pagues el costo operativo de SSR si un dashboard privado se sirve bien con CSR, ni renderices en cada request algo que cambia una vez al día.

---

## 14. Formularios

Los formularios concentran estado, validación y accesibilidad; trátalos como un subdominio, no como inputs sueltos.

- **Controlado vs no controlado:** *controlado* = el estado del framework es la fuente de verdad de cada campo (control fino, validación en vivo, costo de render). *No controlado* = el DOM guarda el valor y lo lees al enviar (más simple y performante para formularios grandes y simples). Elige según necesidad de feedback en tiempo real, no por defecto.
- **Validación:** define el esquema una vez (idealmente compartido con tipos), valida en el momento correcto (al enviar, al salir del campo, o en vivo según UX) y muestra errores junto al campo, accesibles.
- **Componentes de formulario reutilizables:** encapsula label + input + error + estados en un `Field` del design system, en lugar de repetir el mismo markup y el mismo cableado de accesibilidad en cada formulario.

La accesibilidad de formularios (labels asociados, `aria-invalid`, foco en el primer error) es obligatoria: ver **accessibility**.

---

## 15. Integración con el design system

Consume tokens y componentes; no inventes estilos ad-hoc. Un color hardcodeado, un `margin: 13px` mágico o un botón artesanal son fugas del sistema que rompen consistencia y hacen imposible un cambio global de marca o tema.

- Usa **tokens** (color, espaciado, tipografía, radios) en vez de valores literales.
- Consume los **componentes base** del sistema (`Button`, `Input`, `Card`) y compón sobre ellos; no re-implementes lo que ya existe.
- Si el sistema no cubre un caso, la solución es EXTENDER el sistema, no parchear localmente con estilos sueltos.

El fundamento visual, tokens y jerarquía se tratan en **ui-design**.

---

## 16. Tipado (TypeScript)

El tipado es el contrato que hace que los límites que dibujaste se respeten en compilación, no solo en tu cabeza.

- **Tipa las props y el estado.** Nada de `any`. Las props tipadas son documentación viva y previenen el 80% de los errores tontos de integración entre componentes.
- **Tipa las respuestas de la API** en la capa de datos y traduce al modelo del frontend ahí mismo. No dejes que la forma cruda del backend se filtre a la UI.
- **Contratos con el backend:** deriva tipos del esquema compartido cuando sea posible (OpenAPI, GraphQL codegen, esquemas de validación). Un tipo escrito a mano que "debería" coincidir con el backend mentirá tarde o temprano.
- Prefiere **uniones discriminadas** para modelar estados excluyentes (`{status:'loading'} | {status:'error', error} | {status:'success', data}`): hacen imposible representar estados inválidos como "cargando y con error a la vez".

---

## 17. Testing de componentes

Prueba **comportamiento visible, no detalles internos**. Un test que verifica "el estado interno `count` vale 3" se rompe al refactorizar aunque la UI funcione perfecto; un test que verifica "el usuario ve 3" sobrevive al refactor y protege lo que de verdad importa.

- Interactúa como el usuario: busca por rol/texto accesible, dispara eventos reales, verifica lo que aparece en pantalla.
- No pruebes nombres de funciones internas, orden de llamadas ni props privadas.
- Los componentes presentational (dumb) son triviales de probar: entra props, sale UI. Otra ventaja de la separación de capas.
- Mockea la capa de datos (el cliente API), no `fetch` esparcido: otro beneficio de aislar el acceso a datos.

Estrategia, pirámide y herramientas en **testing**.

---

## 18. Convenciones

- **Nombres que dicen intención:** componentes en PascalCase con nombre de dominio (`OrderSummary`, no `Comp2`); hooks/composables con prefijo claro (`useCart`, `useOrders`); handlers `onX`/`handleX` consistentes.
- **Un componente por archivo**, archivo nombrado como el componente.
- **Límites de tamaño** como guía, no ley: ~150 líneas por componente, ~3-4 responsabilidades máx. Al pasarlo, divide.
- **Hooks/composables reutilizables** para lógica compartida (fetching, formularios, suscripciones). Si copias la misma lógica de estado en dos componentes, extráela a un hook.
- **Consistencia > preferencia personal:** el equipo elige un estilo y lo mantiene. Un linter y un formateador lo hacen cumplir sin discusiones en cada PR.

---

## 19. Anti-patrones comunes

- **Componentes gigantes ("God components"):** una sola pieza que hace fetch, transforma, valida, maneja estado y pinta 400 líneas. Imposible de leer, probar o reutilizar. → Divide por responsabilidad y capa.
- **Lógica de negocio en la vista:** cálculos de precios, reglas de permisos o transformaciones metidas en el JSX. → Súbela a hooks/servicios; la vista solo pinta.
- **Prop drilling profundo:** una prop viajando por 4+ niveles que no la usan. → Composición, contexto o estado elevado (§7).
- **Estado global para todo:** meter en el store hasta el `isOpen` de un modal. Convierte cambios locales en re-renders globales y crea acoplamiento invisible. → Estado local por defecto; global solo lo verdaderamente compartido.
- **`fetch` dentro de componentes de UI:** acopla la vista a la red y repite manejo de errores. → Capa de datos aislada (§10).
- **Explosión de props booleanas:** `isPrimary isSmall isOutlined isLoading isDisabled…` con un `if` interno por combinación. → Composición y variantes explícitas (§5).
- **Sincronizar estado con efectos:** copiar una prop a estado local y "actualizarla" con un efecto. → Deriva en render; no dupliques (§8).
- **Duplicar estado de servidor a mano:** `useState` + `useEffect` para cachear datos del backend en vez de una herramienta de datos. → Estado de servidor con su propia solución.
- **Barrels sobre todo el árbol:** un `index.ts` que reexporta el mundo. → Rompe tree-shaking y crea ciclos; barrel curado por feature (§6).
- **Estilos ad-hoc:** colores y espaciados mágicos hardcodeados. → Tokens y componentes del design system (§15).
- **Ignorar los estados de carga/error/vacío:** diseñar solo el éxito. → Los cuatro estados siempre (§12).
- **Abstracción prematura:** generalizar un componente para un solo uso "por si acaso". → Espera al segundo o tercer uso real; la duplicación temprana es más barata que la abstracción equivocada.

---

## 20. Checklist de arquitectura frontend

- [ ] Cada componente se describe en una frase sin usar "y" (una responsabilidad).
- [ ] Ningún componente supera ~150 líneas ni mezcla fetch + lógica + presentación.
- [ ] La lógica y el estado están separados de la presentación donde hay lógica real (container/presentational).
- [ ] Las props son explícitas, mínimas y tipadas; no hay `any` en props ni estado.
- [ ] No hay explosión de props booleanas; las variantes se resuelven por composición.
- [ ] La estructura de carpetas grita el dominio; el código relacionado está colocado junto.
- [ ] Las features no se importan entre sí; comparten vía `shared/` (dependencia unidireccional).
- [ ] Los barrels son curados por feature, no autogenerados sobre todo el árbol.
- [ ] El estado vive lo más cerca posible de su uso; se eleva solo cuando se comparte.
- [ ] El estado de servidor y el de UI están separados y gestionados con la herramienta adecuada.
- [ ] No hay `fetch`/`axios` dentro de componentes de UI; todo pasa por la capa de datos.
- [ ] La dirección de dependencia UI → lógica → datos se respeta.
- [ ] Toda vista asíncrona maneja carga, error, vacío y éxito.
- [ ] Hay error boundaries protegiendo subárboles críticos.
- [ ] La estrategia de renderizado (CSR/SSR/SSG/ISR) es la más simple que cumple SEO y frescura.
- [ ] Las listas grandes están virtualizadas y usan keys estables (no índices volátiles).
- [ ] La memoización se aplica con criterio y medición, no por reflejo.
- [ ] Hay code splitting por ruta y por componente pesado.
- [ ] Los estilos consumen tokens y componentes del design system; sin valores mágicos.
- [ ] Las respuestas de API están tipadas y traducidas al modelo del frontend.
- [ ] Los tests verifican comportamiento visible, no detalles internos.
- [ ] La accesibilidad de formularios y estados interactivos está cubierta.

---

## 21. Referencias

- **patterns.dev** — patrones de diseño, renderizado y rendimiento en frontend moderno.
- **Bulletproof React** — arquitectura por features, límites y convenciones (los principios trascienden React).
- **Refactoring UI** — fundamentos visuales para consumir/extender un design system.
- **Kent C. Dodds — "State Colocation"** y artículos sobre composición y testing de comportamiento.
- **The Twelve-Factor App** (adaptado) y principios SOLID aplicados a componentes.

### Skills relacionadas

- **state-management** — patrones de estado, estado de servidor vs UI, librerías y trade-offs.
- **ui-design** — tokens, jerarquía visual y design systems.
- **ux-design** — estados de carga/error/vacío como experiencia, flujos y feedback.
- **performance** — medición, optimización de renders, bundle y carga.
- **testing** — pirámide de pruebas, herramientas y estrategia de componentes.
- **accessibility** — roles, foco, formularios accesibles y navegación por teclado.
