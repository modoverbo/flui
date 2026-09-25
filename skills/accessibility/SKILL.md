---
name: accessibility
description: "Accesibilidad (a11y): WCAG, semántica, teclado, ARIA, contraste, lectores de pantalla."
---

# Accesibilidad (a11y)

> **Cuándo usar:** SIEMPRE que construyas o revises UI. Al crear cualquier componente interactivo (botones, menús, tabs, modales, tooltips), formularios y validaciones, tablas de datos, contenido dinámico (toasts, live regions, carga async), media (video/audio), o al definir tokens de color y estados de foco. Si el usuario menciona "accesible", "a11y", "WCAG", "lector de pantalla", "teclado", "contraste" o "screen reader", esta skill es obligatoria.

La accesibilidad NO es una feature opcional que se "agrega al final". Es una propiedad estructural de la UI, como la seguridad o el rendimiento. Refactorizar a11y al final cuesta 10x más que hacerlo bien desde el markup. Y NO es solo para personas con discapacidad permanente: beneficia a quien usa teclado por preferencia, a quien tiene una lesión temporal, a quien está en un entorno ruidoso o con sol directo, y a TODOS vía mejor SEO y semántica. La regla mental: **si no funciona con teclado y sin ratón, no está terminado.**

## 1. Principios fundamentales: POUR (WCAG)

WCAG (Web Content Accessibility Guidelines) organiza todo bajo 4 principios. Si un contenido falla alguno, no es accesible. Memorizá el acrónimo **POUR**:

- **P — Perceptible:** la información debe poder percibirse por algún sentido. Texto alternativo en imágenes, subtítulos en video, contraste suficiente, no depender solo del color. Si solo se percibe visualmente y de una forma, falla.
- **O — Operable:** todo debe poder manejarse. Teclado completo, sin trampas de foco, tiempo suficiente, sin parpadeos peligrosos, targets táctiles usables.
- **U — Comprensible (Understandable):** contenido y operación predecibles. Idioma declarado, labels claros, errores explicados y sugeridos, navegación consistente.
- **R — Robusto:** compatible con tecnologías de asistencia presentes y futuras. HTML válido, semántica correcta, ARIA bien aplicado. Un lector de pantalla debe poder interpretarlo.

### Niveles de conformidad: A / AA / AAA

| Nivel | Qué es | En la práctica |
|-------|--------|----------------|
| **A** | Mínimo indispensable | Insuficiente por sí solo |
| **AA** | Estándar legal de facto | **OBJETIVO REAL. Apuntá siempre a AA.** |
| **AAA** | Ideal, a veces imposible en todo el sitio | Aspiracional; aplicá donde se pueda |

**AA es la meta.** Es lo que exigen la mayoría de leyes (ADA, EN 301 549, EAA europeo, etc.) y auditorías. WCAG 2.2 es la versión vigente de referencia. AAA no siempre es alcanzable para todo el contenido (p. ej. contraste 7:1 en toda marca), por eso el estándar del sector es AA con AAA "cuando se pueda".

## 2. Reglas de oro

| ✅ Haz | ❌ Evita |
|--------|---------|
| Usar el elemento HTML nativo correcto (`<button>`, `<a>`, `<nav>`) | `<div onClick>` para cosas interactivas |
| Todo interactivo alcanzable y usable con teclado | Depender del hover o del ratón |
| Mantener el indicador de foco visible | `outline: none` sin reemplazo |
| `<label>` asociado a cada input | `placeholder` como si fuera label |
| Texto alternativo significativo; `alt=""` en decorativas | Omitir `alt` o poner "imagen de..." |
| Contraste ≥ 4.5:1 en texto normal | Gris claro sobre blanco "porque queda lindo" |
| Transmitir info con texto/ícono + color | Comunicar SOLO con color ("los rojos son errores") |
| Un solo `<h1>` y jerarquía sin saltos | Elegir encabezados por su tamaño visual |
| ARIA solo cuando el HTML no alcanza | Cubrir con ARIA un markup mal elegido |
| Anunciar cambios dinámicos con `aria-live` | Insertar contenido que el lector nunca menciona |

## 3. HTML semántico primero

> **La primera regla de ARIA: NO uses ARIA si existe un elemento HTML nativo con la semántica y el comportamiento que necesitás.**

El HTML nativo te da GRATIS: foco, activación por teclado, rol, estado, y comportamiento esperado por cada tecnología de asistencia. Un `<button>` ya es focuseable, se activa con Enter y Espacio, y se anuncia como "botón". Un `<div>` no es NADA de eso hasta que reimplementás todo a mano (y casi siempre lo hacés peor).

```html
<!-- ✅ BIEN: nativo, accesible por defecto -->
<button type="button" onclick="toggleMenu()">Menú</button>
<a href="/perfil">Perfil</a>
<nav aria-label="Principal">…</nav>

<!-- ❌ MAL: reinventa la rueda, rota y frágil -->
<div class="btn" onclick="toggleMenu()">Menú</div>   <!-- no focuseable, no teclado, sin rol -->
<span onclick="location='/perfil'">Perfil</span>      <!-- no es un enlace real -->
```

**Landmarks y estructura semántica.** Usá los elementos que describen regiones de la página. Los lectores de pantalla permiten saltar entre ellos:

- `<header>` — cabecera (banner cuando es de página)
- `<nav>` — navegación (poné `aria-label` si hay varias)
- `<main>` — contenido principal (UNO por página)
- `<aside>` — contenido complementario
- `<footer>` — pie (contentinfo cuando es de página)
- `<section>` con encabezado, `<article>`, `<figure>`

`<button>` vs `<a>`: **`<a>` navega** (cambia de URL/ancla), **`<button>` ejecuta una acción** en la misma página. No los intercambies; el usuario espera comportamientos distintos (un enlace se puede abrir en pestaña nueva; un botón no).

## 4. Navegación por teclado

Todo lo que se pueda hacer con ratón DEBE poder hacerse con teclado. Es la prueba más rápida y reveladora: guardá el ratón y recorré tu UI.

- **Tab / Shift+Tab:** avanza/retrocede entre elementos focuseables.
- **Enter:** activa enlaces y botones (también botones).
- **Espacio:** activa botones, marca checkboxes, abre selects.
- **Flechas:** navegan DENTRO de un widget compuesto (radios, tabs, menús, listbox, sliders). Un grupo de tabs se recorre con flechas, no con Tab.
- **Esc:** cierra modales, popovers, menús.

**Orden de foco lógico.** El orden de tabulación sigue el orden del DOM. Si reordenás visualmente con CSS (flex/grid `order`, `position`), el foco puede quedar incoherente. Solución: ordená el DOM correctamente, no parchees con `tabindex` positivos.

**`tabindex` — usá con criterio:**
- `tabindex="0"` — hace focuseable un elemento que no lo es por defecto (solo si de verdad lo necesitás y le das rol y teclado).
- `tabindex="-1"` — NO entra en el orden de Tab, pero es focuseable por JS (útil para mover foco a un contenedor).
- `tabindex="1"` o mayor — **NUNCA.** Rompe el orden natural y crea un infierno de mantenimiento.

**Sin trampas de foco (focus trap no deseado).** El usuario debe poder salir de cualquier componente con teclado. La excepción legítima es el modal: ahí SÍ atrapás el foco a propósito mientras está abierto, y lo liberás al cerrar. Un widget de terceros (video embebido, iframe) que "come" el foco y no lo suelta es un fallo grave.

**Atajos.** Si agregás atajos de una sola tecla, permití desactivarlos o remapearlos (WCAG 2.1). Un usuario de reconocimiento de voz puede disparar atajos sin querer.

## 5. Indicador de foco visible

El foco visible es cómo un usuario de teclado sabe DÓNDE está. Quitarlo es como apagar el cursor del ratón para todos los demás.

```css
/* ❌ CRIMEN DE ACCESIBILIDAD: deja al usuario de teclado a ciegas */
*:focus { outline: none; }

/* ✅ BIEN: estilo propio, visible y con buen contraste */
:focus-visible {
  outline: 3px solid #1a56db;
  outline-offset: 2px;
  border-radius: 2px;
}
```

Usá `:focus-visible` para mostrar el anillo SOLO cuando el foco llega por teclado (no en cada click de ratón), lo que da buena UX sin sacrificar a11y. El indicador debe tener contraste suficiente contra el fondo (WCAG 2.2 exige área y contraste mínimos: criterio "Focus Appearance").

**Focus management en modales y SPA.** Este es el punto donde más UIs fallan:

- **Al abrir un modal/diálogo:** mové el foco al diálogo (o a su primer control / al título con `tabindex="-1"`). Atrapá el foco dentro mientras esté abierto.
- **Al cerrar:** DEVOLVÉ el foco al elemento que lo abrió. Si no, el usuario "aparece" al principio de la página.
- **En navegación de SPA (cambio de "página" sin recarga):** mové el foco al nuevo `<h1>` o al contenedor `<main>` y anunciá el cambio; el router no lo hace por vos.

## 6. ARIA: roles, states y properties

ARIA (Accessible Rich Internet Applications) añade semántica que el HTML no puede expresar. Es un cinturón de herramientas potente y peligroso: **ARIA mal usado es PEOR que nada**, porque miente al lector de pantalla.

**Las 5 reglas de ARIA (resumen):**
1. No uses ARIA si hay un elemento nativo que ya lo hace.
2. No cambies la semántica nativa salvo que sea imprescindible (`<button role="heading">` es un disparate).
3. Todo control ARIA interactivo debe ser usable con teclado.
4. No pongas `role="presentation"` ni `aria-hidden="true"` sobre elementos focuseables (los ocultás al lector pero siguen recibiendo foco → confusión total).
5. Todo elemento interactivo necesita un nombre accesible.

**Los tres tipos:**
- **Roles** — qué ES el elemento: `role="dialog"`, `role="tablist"`, `role="alert"`, `role="navigation"`.
- **States** — estado actual y cambiante: `aria-expanded="true"`, `aria-checked`, `aria-selected`, `aria-disabled`, `aria-current="page"`.
- **Properties** — relaciones y config más estable: `aria-controls`, `aria-haspopup`, `aria-required`.

**Nombre accesible — cómo dárselo:**

```html
<!-- aria-label: texto directo cuando no hay texto visible -->
<button aria-label="Cerrar diálogo">✕</button>

<!-- aria-labelledby: referencia a texto YA visible (mejor, es reutilizable y traducible) -->
<h2 id="titulo-modal">Confirmar borrado</h2>
<div role="dialog" aria-labelledby="titulo-modal">…</div>

<!-- aria-describedby: descripción/ayuda/error adicional -->
<input id="pass" aria-describedby="pass-hint">
<p id="pass-hint">Mínimo 12 caracteres.</p>
```

Preferí `aria-labelledby` sobre `aria-label` cuando el texto ya existe en pantalla: no duplicás strings y se traduce solo.

**`aria-live` para contenido dinámico** (ver sección 12). Nunca uses ARIA para simular componentes complejos "a ojo": seguí el patrón exacto de las APG (ver Referencias); un combobox o un tree mal implementado con ARIA es una trampa.

## 7. Contraste de color

El contraste es medible y no negociable. Ratios mínimos WCAG **AA**:

| Elemento | Ratio mínimo AA |
|----------|-----------------|
| **Texto normal** (< 24px, o < 18.66px/14pt si es bold) | **4.5:1** |
| **Texto grande** (≥ 24px, o ≥ 18.66px/14pt bold) | **3:1** |
| **Componentes de UI e íconos** (bordes de input, íconos informativos, estados de foco) | **3:1** |

(AAA sube a 7:1 texto normal y 4.5:1 texto grande.) El contraste se calcula sobre el fondo REAL detrás del texto, incluyendo gradientes e imágenes: verificá el peor caso.

**No dependas solo del color para transmitir información.** ~1 de cada 12 hombres tiene algún tipo de daltonismo. Si el único indicador de un error es "el borde se pone rojo", quien no distingue rojo/verde no lo percibe.

```html
<!-- ❌ MAL: solo el color comunica el estado -->
<input class="input-error">   <!-- borde rojo y nada más -->

<!-- ✅ BIEN: color + ícono + texto -->
<input aria-invalid="true" aria-describedby="err-email">
<p id="err-email" class="error"><span aria-hidden="true">⚠️</span> Email inválido</p>
```

Lo mismo para gráficos (usá patrones/etiquetas además de color), enlaces dentro de texto (subrayado, no solo color), y estados de "seleccionado".

## 8. Texto alternativo

El `alt` es lo que "ve" quien no ve la imagen. Debe transmitir la MISMA información o función, no describir píxeles.

```html
<!-- Imagen informativa: alt que cumple la función -->
<img src="grafico-ventas.png" alt="Ventas subieron 30% en Q2 respecto a Q1">

<!-- Imagen decorativa: alt VACÍO para que el lector la ignore -->
<img src="ornamento.svg" alt="">

<!-- Imagen que ES un enlace/botón: alt describe el DESTINO/acción -->
<a href="/"><img src="logo.png" alt="Inicio - Acme"></a>
```

Reglas:
- **No empieces con "imagen de..." / "foto de..."**: el lector ya anuncia que es una imagen. Es redundante.
- **Decorativa → `alt=""`** (nunca omitas el atributo; sin `alt` algunos lectores leen el nombre del archivo).
- **Función > apariencia:** en un ícono-botón, el alt/label describe la acción ("Buscar"), no el dibujo ("lupa").
- **Imágenes complejas** (gráficos, diagramas): alt corto + descripción larga cercana en el texto o vía `aria-describedby`/`<figcaption>`.
- **SVG inline** interactivo/informativo: `role="img"` + `<title>`, o `aria-label`; decorativo: `aria-hidden="true"`.

## 9. Formularios accesibles

Los formularios son donde más se pierde gente. Reglas duras:

**Cada input necesita un `<label>` asociado** (no un texto suelto al lado):

```html
<!-- ✅ Asociación explícita por id (la más robusta) -->
<label for="email">Correo electrónico</label>
<input id="email" type="email" autocomplete="email" required>

<!-- ✅ También válido: envolver -->
<label>Correo <input type="email" autocomplete="email"></label>
```

**El `placeholder` NO es un label.** Desaparece al escribir, suele tener contraste pobre y muchos lectores no lo anuncian como nombre del campo. Usalo como ejemplo de formato, jamás como única etiqueta.

**Agrupá controles relacionados** con `<fieldset>` + `<legend>` (radios, checkboxes, dirección):

```html
<fieldset>
  <legend>Método de envío</legend>
  <label><input type="radio" name="envio" value="std"> Estándar</label>
  <label><input type="radio" name="envio" value="exp"> Exprés</label>
</fieldset>
```

**Errores asociados y anunciados:**

```html
<label for="cp">Código postal</label>
<input id="cp" inputmode="numeric" aria-invalid="true" aria-describedby="cp-err" required>
<p id="cp-err" role="alert">El código postal debe tener 5 dígitos.</p>
```

- Vinculá el mensaje con `aria-describedby` para que el lector lo lea al enfocar el campo.
- `role="alert"` (o una live region) para que el error se ANUNCIE al aparecer.
- Marcá el campo con `aria-invalid="true"`.
- Al enviar con errores, mové el foco al primer campo con error o a un resumen de errores.

**`autocomplete`** con los tokens estándar (`email`, `name`, `tel`, `street-address`, `cc-number`…) ayuda a todos y es criterio WCAG (AA) para campos sobre el usuario. **No deshabilites el zoom** ni uses inputs con `font-size < 16px` en móvil (iOS hace zoom forzado). Indicá los campos requeridos con texto/`required`, no solo con un asterisco de color.

## 10. Lectores de pantalla

Entender CÓMO navegan explica el PORQUÉ de casi todo lo anterior. Un usuario de lector de pantalla NO lee linealmente de arriba a abajo: SALTA.

- **Por encabezados:** el atajo más usado. Recorre `<h1>`…`<h6>` para mapear la página. Por eso la jerarquía importa tanto (sección 11).
- **Por landmarks:** salta entre `<nav>`, `<main>`, `<aside>`, etc.
- **Por listas y elementos:** links, botones, form fields, tablas. El lector anuncia "lista de 5 elementos", "botón", "campo de edición requerido".

Consecuencia práctica: **un markup semántico bueno = navegación rápida; un mar de `<div>` = el usuario está perdido.**

**Texto solo para lectores (visually-hidden).** A veces necesitás dar contexto que sobra visualmente pero ayuda a quien no ve. NO uses `display:none` ni `visibility:hidden` (ocultan también al lector). Usá la clase clásica:

```css
.visually-hidden {
  position: absolute;
  width: 1px; height: 1px;
  padding: 0; margin: -1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
  border: 0;
}
```

```html
<a href="/carrito">
  <svg aria-hidden="true">…</svg>
  <span class="visually-hidden">Ver carrito, 3 productos</span>
</a>
```

**Evitá texto dentro de imágenes:** el lector no lo lee, no se puede traducir, no se puede seleccionar y se ve borroso al hacer zoom. Usá texto real estilado con CSS.

## 11. Estructura: encabezados, landmarks y skip links

**Jerarquía de encabezados.** Los encabezados son el índice de la página para lectores de pantalla:

- **Un solo `<h1>`** por página, que describe el contenido principal.
- **Sin saltos de nivel:** de `<h2>` NO pases a `<h4>`. Bajá de a un nivel.
- **Elegí el nivel por SIGNIFICADO, no por tamaño.** Si necesitás un h2 chico, estilalo con CSS; no uses un `<h4>` "porque se ve mejor".

```html
<h1>Panel de control</h1>
  <h2>Ventas</h2>
    <h3>Este mes</h3>
    <h3>Comparativa</h3>
  <h2>Usuarios</h2>          <!-- ✅ vuelve a h2, no salta -->
```

**Skip link.** El primer elemento focuseable de la página debe permitir saltar la navegación repetida e ir directo al contenido. Sin él, un usuario de teclado tabula por 30 enlaces de menú en CADA página.

```html
<body>
  <a href="#main" class="skip-link">Saltar al contenido</a>
  <header>…</header>
  <main id="main" tabindex="-1">…</main>
</body>
```

```css
.skip-link { position:absolute; left:-9999px; }
.skip-link:focus { left:8px; top:8px; /* visible al enfocar */ }
```

Declará también el idioma: `<html lang="es">` (y `lang` en fragmentos en otro idioma). El lector elige la voz/pronunciación correcta con esto.

## 12. Contenido dinámico y live regions

Cuando algo cambia en pantalla SIN que el usuario navegue hasta ahí (un toast, un resultado de búsqueda que se actualiza, un contador, un error async), el lector de pantalla NO se entera... a menos que se lo digas con una **live region**.

```html
<!-- Cambios no urgentes: se anuncian al terminar la acción en curso -->
<div aria-live="polite" aria-atomic="true">
  Se guardaron los cambios.
</div>

<!-- Cambios urgentes/errores: interrumpen -->
<div role="alert">   <!-- role="alert" implica aria-live="assertive" -->
  Error: no se pudo conectar.
</div>

<!-- Estado de un status/contador -->
<div role="status" aria-live="polite">Cargando resultados…</div>
```

Claves:
- `aria-live="polite"` para la mayoría (no interrumpe); `assertive` solo para cosas críticas.
- La región debe existir en el DOM **antes** de meterle contenido; si la creás y la poblás en el mismo tick, muchos lectores no la anuncian. Renderizá el contenedor vacío y luego actualizá su texto.
- `aria-busy="true"` mientras cargás una zona.
- **Estados de carga:** anunciá "Cargando…" y luego "N resultados". Un spinner puramente visual es invisible para el lector.

## 13. Media (audio y video)

- **Subtítulos (captions)** sincronizados en todo video con audio (WCAG A/AA). No son transcripción: van en el tiempo.
- **Transcripción** textual completa para audio y video (permite leer, buscar y traducir).
- **Audiodescripción** de la información visual relevante que no está en el diálogo (AA).
- **Controles accesibles:** play/pausa/volumen operables por teclado y con nombres accesibles. Los reproductores nativos `<video controls>` ya lo traen; los custom hay que construirlos con cuidado.
- **Nada de autoplay con sonido.** Si algo suena solo, debe poder pausarse/silenciarse fácil (criterio "Audio Control").

## 14. Movimiento y animación

- **`prefers-reduced-motion`:** respetá la preferencia del sistema. Muchas personas sienten mareo/náuseas con parallax, zooms y transiciones grandes.

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

- **Nada de parpadeos > 3 veces por segundo.** Es un riesgo REAL de convulsiones fotosensibles (criterio "Three Flashes"). Regla dura, no estética.
- **Contenido en movimiento/autoscroll/carruseles:** deben poder **pausarse, detenerse u ocultarse** si duran más de 5 s o son automáticos (criterio "Pause, Stop, Hide").

## 15. Touch targets y zoom

- **Tamaño mínimo de target táctil:** apuntá a **44×44px** (guía de plataformas) — WCAG 2.2 exige **24×24px** como mínimo AA ("Target Size (Minimum)"), pero 44px es lo recomendable. Aplica a botones, íconos clicables, checkboxes, enlaces sueltos. Separá targets pequeños para evitar toques erróneos.
- **Zoom hasta 200% sin pérdida** (AA) e idealmente reflow hasta 400% (AA, "Reflow") sin scroll horizontal ni contenido cortado. Consecuencia: usá unidades relativas (`rem`), layouts fluidos, y NO fijes `user-scalable=no` en el viewport.
- **Orientación:** no bloquees portrait/landscape salvo que sea esencial.

## 16. Testing de accesibilidad

Ninguna de estas técnicas basta sola. Combinalas:

1. **Teclado (manual, primero y gratis):** soltá el ratón. ¿Llegás a todo? ¿Ves siempre el foco? ¿El orden es lógico? ¿Podés cerrar todo con Esc? ¿Hay trampas? Esto detecta la mayoría de fallos graves en minutos.
2. **Lector de pantalla (manual):** probá con uno real — **NVDA** (Windows, gratis), **VoiceOver** (macOS/iOS, integrado), **TalkBack** (Android). Escuchá cómo se anuncia tu componente.
3. **Herramientas automáticas:** **axe DevTools**, **Lighthouse** (pestaña Accessibility), **WAVE**. Integrá `axe-core`/`jest-axe`/`playwright-axe` en CI.
4. **Zoom y reflow:** probá a 200% y 400%. Probá `prefers-reduced-motion` y modo de alto contraste.

> ⚠️ **Las herramientas automáticas solo detectan ~30–40% de los problemas de accesibilidad.** Encuentran contraste, `alt` faltante, labels ausentes. NO detectan si el orden de foco es lógico, si el `alt` es *significativo*, si un modal gestiona bien el foco, o si un widget ARIA se entiende. **El testing manual con teclado y lector NO es opcional.** Una UI con "100 en Lighthouse" puede ser inutilizable con lector de pantalla.

## Anti-patrones comunes

- **`<div>`/`<span>` clicable** en vez de `<button>`/`<a>`: sin foco, sin teclado, sin rol. El clásico #1.
- **`placeholder` como label:** desaparece, mal contraste, no siempre se anuncia.
- **`outline: none`** sin reemplazo visible: deja ciego al usuario de teclado.
- **Comunicar solo con color:** "los rojos son errores", gráficos sin patrones, enlaces sin subrayado.
- **`alt` genérico o ausente:** "imagen", "foto", nombre de archivo, o describir píxeles en vez de función.
- **Saltar niveles de encabezado** o elegirlos por tamaño visual.
- **`tabindex="1+"`:** rompe el orden de foco de toda la página.
- **`aria-label` sobre un `<div>` no interactivo** esperando que "arregle" algo: no le da comportamiento.
- **`aria-hidden="true"` sobre algo focuseable:** el usuario lo enfoca pero el lector no dice nada.
- **Modal sin gestión de foco:** no atrapa el foco, no lo devuelve al cerrar, no cierra con Esc.
- **Live region creada y poblada en el mismo tick:** el cambio no se anuncia.
- **Iconos-botón sin nombre accesible** (`<button>✕</button>` sin label).
- **`user-scalable=no`** en el viewport: impide el zoom.

## Checklist de accesibilidad

- [ ] Cada elemento interactivo usa el HTML nativo correcto (`button`, `a`, `input`…)
- [ ] Toda la UI es 100% operable solo con teclado (Tab/Enter/Espacio/flechas/Esc)
- [ ] El indicador de foco es siempre visible y con buen contraste (`:focus-visible`)
- [ ] No hay trampas de foco; los modales atrapan y devuelven el foco correctamente
- [ ] Un solo `<h1>`, jerarquía de encabezados sin saltos
- [ ] Landmarks presentes (`header`, `nav`, `main`, `footer`) y skip link al contenido
- [ ] Contraste ≥ 4.5:1 (texto normal), ≥ 3:1 (texto grande, íconos, foco)
- [ ] La información nunca depende SOLO del color
- [ ] Toda imagen tiene `alt` significativo; decorativas con `alt=""`
- [ ] Cada input tiene `<label>` asociado; grupos con `fieldset`/`legend`
- [ ] Errores de formulario asociados (`aria-describedby`) y anunciados (`role="alert"`)
- [ ] `autocomplete` en campos de datos del usuario
- [ ] ARIA usado solo donde el HTML no alcanza y siguiendo las APG
- [ ] Cambios dinámicos anunciados con `aria-live`/`role="status"`/`role="alert"`
- [ ] Video con subtítulos + transcripción; sin autoplay con sonido
- [ ] `prefers-reduced-motion` respetado; sin parpadeos > 3/s
- [ ] Targets táctiles ≥ 24px (idealmente 44px); zoom a 200% sin romper
- [ ] `<html lang>` declarado
- [ ] Probado con teclado, con lector de pantalla (NVDA/VoiceOver) y con axe/Lighthouse

## Referencias

- **WCAG 2.2** — https://www.w3.org/TR/WCAG22/ (y *How to Meet WCAG*, la quick reference)
- **WAI-ARIA Authoring Practices (APG)** — https://www.w3.org/WAI/ARIA/apg/ (patrones de widgets con markup y teclado)
- **MDN — Accessibility** — https://developer.mozilla.org/en-US/docs/Web/Accessibility
- **The A11Y Project** — https://www.a11yproject.com/ (checklist y guías prácticas)
- **WebAIM** — https://webaim.org/ (contrast checker, guías por tema)

## Skills relacionadas

- **ui-design** — tokens de color y estados (contraste, foco) nacen del diseño visual.
- **ux-design** — flujos, mensajes de error, jerarquía y claridad de interacción.
- **frontend-architecture** — dónde viven los componentes accesibles, focus management en SPA y patrones reutilizables.
