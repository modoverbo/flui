---
name: ui-design
description: "Diseño de interfaces: sistemas de diseño, tipografía, color, espaciado, consistencia visual."
---

# Diseño de Interfaces (UI)

> **Cuándo usar:** al construir componentes visuales, definir o extender un sistema de estilos, mantener consistencia entre pantallas, elegir tipografía/color/espaciado, revisar un diseño antes de implementarlo, o cuando notes que la interfaz "se siente desordenada" y no sabes por qué. Si estás decidiendo CÓMO se ve algo, esta skill aplica.

Esta guía cubre el QUÉ visual. Para el comportamiento y flujos usa **ux-design**; para contraste, roles ARIA y navegación por teclado usa **accessibility**; para dónde vive el código y cómo se componen los componentes usa **frontend-architecture**.

---

## 1. Principios fundamentales

El diseño no es decoración: es comunicación. Cada decisión visual debería reducir el esfuerzo mental del usuario. Estos siete principios son la física del oficio.

- **Consistencia:** el mismo elemento se ve y se comporta igual en todas partes. La consistencia es el activo más valioso de una UI porque convierte el aprendizaje en transferible: el usuario aprende un patrón una vez y lo reutiliza. Inconsistencia = re-aprendizaje constante = fricción.
- **Jerarquía visual:** no todo puede gritar. Ordena los elementos por importancia usando tamaño, peso, color, contraste y posición. Si todo destaca, nada destaca.
- **Contraste:** la diferencia crea significado. Contraste entre texto y fondo (legibilidad), entre acción primaria y secundaria (jerarquía), entre estados (feedback). Sin contraste no hay lectura ni foco.
- **Alineación:** los elementos alineados crean líneas invisibles que el ojo sigue. Todo debe alinearse con algo. La alineación desprolija se percibe como descuido incluso cuando el usuario no sabe nombrarlo.
- **Proximidad:** los elementos relacionados van juntos; los no relacionados, separados. El espaciado comunica relación antes que cualquier borde o caja.
- **Repetición:** repetir estilos, patrones y componentes crea unidad y refuerza la marca. Es el mecanismo que hace posible la consistencia a escala.
- **Espacio en blanco (whitespace):** el vacío no es desperdicio, es respiración. Da foco, agrupa, jerarquiza y transmite calidad. Las interfaces amateur temen al vacío y lo llenan; las profesionales lo usan como herramienta.

---

## 2. Reglas de oro

| Haz | Evita |
|-----|-------|
| Definir tokens y reutilizarlos | Valores mágicos hardcodeados (`#3b7`, `13px`) dispersos |
| Una escala tipográfica limitada (5-7 tamaños) | Un tamaño distinto en cada componente |
| 1-2 familias tipográficas | 4+ fuentes mezcladas sin sistema |
| Múltiplos de 8 (o 4) para espaciado | Espaciados arbitrarios (`7px`, `13px`, `22px`) |
| Una acción primaria por pantalla | Cinco botones compitiendo por atención |
| Reutilizar componentes existentes | Reinventar el botón en cada feature |
| Diseñar TODOS los estados (hover, focus, error…) | Diseñar solo el estado "feliz" |
| Contraste AA mínimo (4.5:1 en texto) | Gris claro sobre blanco "porque se ve elegante" |
| Tokens semánticos (`color-danger`) | Colores literales acoplados al tema (`red-500`) |
| Alinear todo a una rejilla | Posicionar "a ojo" pixel por pixel |

---

## 3. Sistemas de diseño y design tokens

Un **design token** es la unidad atómica de una decisión de diseño almacenada como variable con nombre. Los tokens son la **fuente única de verdad**: cambias el token, cambia toda la interfaz. Sin tokens, cada cambio de marca es una cacería de valores repetidos por todo el código.

**Capas de tokens (críticas para escalar):**

1. **Primitivos (globales):** la paleta cruda. `blue-500: #3b82f6`, `space-4: 16px`. No tienen significado, solo valor.
2. **Semánticos (de alias):** el propósito. `color-primary → blue-500`, `color-danger → red-500`, `surface-background`, `text-muted`. **El código consume estos, nunca los primitivos.**
3. **De componente (opcional):** `button-primary-bg → color-primary`. Útil en sistemas grandes.

Esta indirección es lo que hace posible el dark mode, el theming y el rebranding sin tocar componentes: solo reasignas la capa semántica.

**Categorías de tokens que debes definir:**

- **Color:** paleta primitiva + roles semánticos (fondo, superficie, texto, borde, primario, estados).
- **Tipografía:** familias, escala de tamaños, pesos, alturas de línea, tracking.
- **Espaciado:** escala basada en 8pt.
- **Radios (border-radius):** `sm: 4px`, `md: 8px`, `lg: 16px`, `full: 9999px`. Consistencia en esquinas = coherencia percibida.
- **Sombras (elevation):** escala de 3-5 niveles. Más sombra = más "cerca" del usuario. Úsalas para jerarquía de capas (cards, modales, dropdowns), no decorativamente.
- **Bordes, z-index, duraciones de animación, breakpoints.**

Regla: **si un valor aparece más de una vez, es un token.**

---

## 4. Atomic Design

Metodología de Brad Frost para construir sistemas de componentes de lo simple a lo complejo. Da un lenguaje compartido entre diseño y código.

- **Átomos:** los bloques indivisibles. Botón, input, label, ícono, badge. No se pueden descomponer sin perder función.
- **Moléculas:** grupos pequeños de átomos con una función. Un campo de formulario = label + input + mensaje de error. Un search bar = input + botón.
- **Organismos:** secciones complejas y autónomas. Un header (logo + nav + search + avatar), una card de producto, una tabla.
- **Plantillas (templates):** el esqueleto de una página. Define layout y jerarquía con contenido de relleno (placeholder). Es la estructura, no el contenido real.
- **Páginas:** una plantilla con contenido real. Aquí validas que el diseño resiste datos reales (nombres largos, listas vacías, errores).

Beneficio clave: construyes una vez el átomo, lo reutilizas en todas partes. La consistencia deja de ser disciplina manual y se vuelve estructural. Mapea bien a arquitecturas de componentes (ver **frontend-architecture**).

---

## 5. Escala tipográfica

La tipografía es el 90% del diseño de la mayoría de las interfaces. Domínala y todo lo demás mejora.

**Escala modular:** no elijas tamaños al azar. Usa una razón consistente para generarlos. Razones comunes: **1.25 (tercera mayor)** para UI densa, **1.333** o **1.5** para más contraste. Ejemplo con base 16px y razón 1.25:

```
12 · 14 · 16 (base) · 20 · 25 · 31 · 39 · 49
```

Limita la escala a **5-7 tamaños activos**. Más que eso y la jerarquía se difumina.

**Altura de línea (line-height):**

- Texto de párrafo (body): **1.5 – 1.6**. Da respiración y legibilidad.
- Titulares grandes: **1.1 – 1.25**. Los tamaños grandes necesitan menos espacio proporcional.
- Regla: **a mayor tamaño de fuente, menor line-height**; a mayor longitud de línea, mayor line-height.

**Longitud de línea legible:** **45–75 caracteres** por línea (óptimo ~66). Demasiado corta cansa por saltos constantes; demasiado larga hace perder la línea de retorno. Contrólala con `max-width` (aprox. `60ch – 75ch`), no con el tamaño de fuente.

**Pesos:** define 2-3 (p. ej. 400 regular, 500 medium, 700 bold). El peso es una herramienta de jerarquía tan poderosa como el tamaño y ocupa menos espacio.

**Límite de familias:** **1-2 fuentes** máximo. Una para UI/cuerpo, opcionalmente otra para display/titulares. Empareja por contraste, no por similitud. Cada fuente extra es peso de carga y ruido visual.

**Jerarquía tipográfica de referencia:**

| Rol | Tamaño aprox. | Peso | Line-height |
|-----|---------------|------|-------------|
| Display / H1 | 32–48px | 700 | 1.1 |
| H2 | 24–31px | 600 | 1.2 |
| H3 | 20–25px | 600 | 1.3 |
| Body | 16px | 400 | 1.5 |
| Small / caption | 14px | 400 | 1.4 |
| Micro / label | 12px | 500 | 1.4 |

Nunca uses menos de 12px para texto funcional; 16px es el mínimo cómodo para lectura sostenida en móvil.

---

## 6. Color

El color comunica marca, jerarquía y estado. Úsalo con intención, no por gusto.

**Estructura de paleta:**

- **Primario:** el color de marca y de la acción principal. Define una rampa de 9-10 tonos (50 → 900) para tener flexibilidad.
- **Secundario / acento:** complementa al primario; úsalo con moderación para destacar.
- **Neutros (grises):** el 80% de una UI es neutro. Necesitas una rampa rica de grises (5-10 tonos) para texto, bordes, fondos y superficies. Los grises con un ligero tinte del primario se sienten más cohesivos que grises puros.
- **Semánticos:** estados con significado universal:
  - **Éxito:** verde.
  - **Error / peligro:** rojo.
  - **Aviso / advertencia:** ámbar/amarillo.
  - **Información:** azul.
  Define cada uno con al menos 3 tonos (fondo suave, base, texto/borde fuerte).

**Teoría básica útil:**

- Trabaja en **HSL/HSB**, no en HEX: ajustar luminosidad y saturación por separado es cómo construyes rampas coherentes.
- Para generar una rampa, mantén el hue y varía luminosidad/saturación; sube la saturación en los extremos oscuros para evitar grises apagados.
- No uses negro puro (`#000`) ni blanco puro para grandes superficies: usa neutros muy oscuros/claros con leve tinte. Es más suave para el ojo.

**Accesibilidad de contraste (no negociable):** cumple WCAG AA — **4.5:1** para texto normal, **3:1** para texto grande (≥24px o ≥18px bold) y para componentes/iconos funcionales. El color **nunca** debe ser el único portador de información (un error no puede distinguirse solo por ser rojo): acompaña con ícono, texto o forma. Detalle completo en **accessibility**.

Regla práctica: menos colores, mejor. Un primario + neutros + semánticos alcanzan para la mayoría de productos.

---

## 7. Sistema de espaciado

El espaciado inconsistente es la causa número uno de que una UI "se sienta amateur" sin que el usuario sepa por qué.

**Rejilla de 8pt (recomendada):** todos los espacios (padding, margin, gaps, tamaños) son múltiplos de 8: `8, 16, 24, 32, 40, 48, 64…`. Para ajustes finos (iconos, texto denso) usa una **sub-rejilla de 4pt**: `4, 8, 12, 16…`. La escala de 8 alinea con densidades de pantalla comunes y reduce decisiones.

**Escala de espaciado con nombres (tokens):**

```
space-1: 4px   space-2: 8px   space-3: 12px  space-4: 16px
space-5: 24px  space-6: 32px  space-7: 48px  space-8: 64px
```

**Ritmo vertical:** mantén un espaciado consistente entre bloques para crear un pulso predecible al recorrer la página. El espacio antes de un titular debe ser mayor que el espacio después (el titular pertenece al contenido que le sigue — principio de proximidad).

**Padding vs margin:**

- **Padding:** espacio interno, dentro del borde del componente. Controla la "densidad" del componente (aire alrededor del contenido).
- **Margin:** espacio externo, la separación entre componentes. Controla la relación entre elementos.
- Regla útil para evitar colapsos y descontrol: **empuja con padding hacia adentro, separa con gap/margin hacia afuera.** En layouts modernos prefiere `gap` (flex/grid) sobre márgenes sueltos.

---

## 8. Jerarquía visual

Guía el ojo del usuario en el orden en que quieres que lea. Herramientas, de mayor a menor impacto:

1. **Tamaño:** lo grande se ve primero.
2. **Peso / grosor:** negrita atrae sin ocupar más espacio.
3. **Color y contraste:** lo saturado y de alto contraste domina; lo apagado retrocede.
4. **Posición:** arriba e izquierda (en lectura occidental) tiene prioridad; el centro atrae.
5. **Espacio:** aislar un elemento con whitespace lo destaca.

**Una acción primaria por pantalla (o por sección):** debe haber un único botón que grite "haz esto". El resto son secundarios (outline/ghost) o terciarios (link). Si hay dos botones primarios del mismo peso, obligas al usuario a decidir sin ayuda. Esto conecta con la Ley de Hick (ver **ux-design**): menos opciones destacadas, decisión más rápida.

---

## 9. Layout y rejillas

- **Grid de 12 columnas:** el estándar de layout. 12 divide en 2, 3, 4 y 6, cubriendo casi cualquier distribución. Define columnas + **gutters** (canales) consistentes + márgenes de contenedor.
- **Alineación:** todo se ancla a la rejilla. Los bordes compartidos entre elementos crean orden percibido.
- **Agrupación por proximidad:** usa el espaciado (no líneas ni cajas) como primer recurso para agrupar. Recurre a bordes/fondos solo cuando el espacio no basta.
- **Ancho de contenido:** limita el contenedor de lectura (`max-width` ~640–768px para texto largo). El contenido a todo el ancho de un monitor es ilegible.
- **Densidad intencional:** decide si la UI es densa (dashboards, herramientas pro) o espaciada (marketing, onboarding) y sé consistente. No mezcles densidades sin razón.

---

## 10. Estados de componentes (OBLIGATORIOS)

Un componente NO está diseñado hasta que todos sus estados existen. Diseñar solo el estado default es la causa más común de bugs visuales y experiencias rotas. Para cada componente interactivo define:

- **Default (reposo):** el estado base.
- **Hover:** el puntero encima. Señala interactividad (no aplica en táctil, no dependas de él).
- **Focus:** foco por teclado. **Obligatorio y visible** — un anillo/outline claro. Nunca lo elimines sin reemplazo (ver **accessibility**).
- **Active / pressed:** durante el clic/toque. Feedback inmediato de que la acción se registró.
- **Disabled:** no disponible. Contraste reducido pero legible; cursor `not-allowed`; explica por qué si es posible.
- **Loading:** procesando. Spinner en el botón, deshabilitar reenvío, mantener el ancho para evitar saltos de layout.
- **Error:** validación fallida. Borde/texto de estado + mensaje claro y accionable.
- **Selected / active-state:** para tabs, items de lista, toggles, opciones elegidas.

Documenta la matriz de estados en el sistema de diseño para que todos los construyan igual.

---

## 11. Estados de datos

Toda vista que muestra datos debe diseñar sus cuatro estados. El "estado feliz con datos perfectos" es solo uno de ellos.

- **Vacío (empty state):** no hay datos aún. **No lo dejes en blanco.** Explica qué es esta pantalla, por qué está vacía y da una acción clara ("Crea tu primer proyecto"). Un buen empty state es onboarding gratis.
- **Cargando (loading):** usa **skeletons** que imiten la forma del contenido real en lugar de un spinner centrado; reduce la percepción de espera y evita saltos de layout. Spinner solo para esperas cortas o acciones puntuales.
- **Error:** algo falló. Mensaje humano (no un código crudo), causa probable y una vía de recuperación (reintentar, contactar). Nunca una pantalla en blanco silenciosa.
- **Éxito / con datos:** el contenido cargado. Y considera el estado **parcial** (paginación, "cargar más") y el **de un solo item** vs. **muchos**.

Diseña también los extremos: nombres larguísimos, listas de 1000 filas, textos vacíos, imágenes rotas.

---

## 12. Consistencia

La consistencia es el resultado de todo lo anterior aplicado con disciplina.

- **Reutiliza componentes:** un solo `Button`, un solo `Input`, un solo `Modal`. Variantes controladas por props/tokens, no copias divergentes.
- **Mismos patrones para mismas acciones:** si "eliminar" pide confirmación en un lugar, la pide en todos. Si guardar es un botón primario abajo a la derecha, lo es siempre.
- **Consistencia interna > moda externa:** es mejor un patrón propio aplicado en todas partes que tres patrones "mejores" mezclados.
- **No reinventes:** antes de crear un componente, busca si ya existe. La proliferación de variantes casi-iguales es deuda de diseño.
- **Consistencia de contenido:** mismo tono, misma capitalización (title case vs. sentence case — elige una), mismos verbos para mismas acciones.

---

## 13. Iconografía

- **Un solo set de íconos:** mismo estilo (outline vs. filled), mismo grosor de trazo, misma métrica. Mezclar sets se nota de inmediato.
- **Tamaños consistentes:** alinéalos a la rejilla (16, 20, 24px). Ajusta el peso óptico para que un ícono de 16px no se vea más delgado que el texto que acompaña.
- **Íconos con etiqueta cuando sean ambiguos:** un ícono solo es aceptable si su significado es universal (búsqueda, cerrar, menú). Ante la mínima duda, acompáñalo con texto. "Reconocer un ícono" no debería ser un acertijo.
- **Alineación óptica:** centra los íconos ópticamente respecto al texto (a menudo requiere un ajuste manual de 1px), no solo matemáticamente.
- Los íconos son de apoyo, no reemplazan el texto en acciones críticas.

---

## 14. Responsive

- **Mobile-first:** diseña primero la pantalla pequeña (obliga a priorizar contenido) y luego expande. Es más fácil añadir espacio que quitar contenido.
- **Breakpoints de referencia** (ajústalos a tu contenido, no a dispositivos concretos):

```
sm: 640px   md: 768px   lg: 1024px   xl: 1280px   2xl: 1536px
```

  Añade breakpoints donde el diseño se "rompe", no donde está de moda.
- **Unidades relativas:** usa `rem`/`em` para tipografía y espaciado (respeta la preferencia del usuario), `%`/`fr`/`ch` para layout. Evita `px` fijos para texto. `clamp()` es tu aliado para tipografía y espaciado fluidos.
- **Touch targets mínimos: 44×44px** (guía de Apple; Material sugiere 48×48dp). Con separación suficiente entre objetivos táctiles para evitar toques erróneos. Esto también es accesibilidad (ver **accessibility**).
- Refluye, no encojas: en móvil reorganiza la jerarquía (menús colapsados, columnas apiladas), no solo escales el desktop.

---

## 15. Dark mode y temas

El dark mode NO es "invertir colores". Es un tema alternativo que exige que tu sistema esté bien construido.

- **Tokens semánticos, no colores hardcodeados:** el componente usa `surface-background` y `text-primary`; cada tema reasigna esos tokens. Si tienes `#fff` en el código, el dark mode será un infierno de parches.
- **No uses negro puro de fondo:** usa un gris muy oscuro (`#121212`–`#1a1a1a`). El negro puro con texto blanco genera fatiga y "halo" (smearing).
- **Baja la saturación de los colores en dark:** los colores vibrantes sobre fondo oscuro vibran demasiado; desatúralos un poco.
- **La elevación se comunica con luz, no con sombra:** en dark mode, las superficies "más altas" son más claras (las sombras casi no se ven).
- **Verifica el contraste en AMBOS temas** por separado: un color que pasa AA en claro puede fallar en oscuro.
- Respeta `prefers-color-scheme` y permite override manual persistente.

---

## 16. Feedback visual y microinteracciones

Cada acción del usuario merece una respuesta visible. El silencio genera dudas ("¿funcionó?").

- **Feedback inmediato:** estados active/loading, ripples, cambios de estado al instante. La percepción de velocidad importa tanto como la velocidad real.
- **Transiciones con propósito:** anima para explicar cambios de estado y continuidad espacial, no para lucirte. Duraciones cortas: **150–300ms** para UI; usa easing (`ease-out` para entradas, `ease-in` para salidas).
- **Respeta `prefers-reduced-motion`:** desactiva o reduce animaciones para quien lo pide.
- **No animes lo crítico en el camino:** las animaciones no deben retrasar tareas frecuentes.

El QUÉ del feedback (cuándo, qué mensaje, qué flujo) pertenece a **ux-design**; aquí definimos el CÓMO se ve y se mueve.

---

## 17. Componentes reutilizables y librerías

- **No reinventes el botón.** Un botón "simple" tiene 8+ estados, accesibilidad, foco, loading, iconos, tamaños y variantes. Multiplicado por cada componente, reconstruir es tirar semanas y sembrar inconsistencia.
- **Apóyate en librerías de calidad** (Radix, React Aria, shadcn/ui, MUI, etc.) para primitivos accesibles y comportamiento complejo (menús, diálogos, comboboxes), y aplícales TUS tokens encima. Obtienes accesibilidad y robustez gratis; personalizas la piel.
- **Construye tu capa de componentes** sobre esos primitivos: una sola definición por componente, dirigida por tokens. Es la implementación viva de tu sistema de diseño (ver **frontend-architecture** para su ubicación y composición).
- **Documenta** cada componente con sus variantes y estados (Storybook o similar). Un componente sin documentación se re-implementa.

---

## Anti-patrones comunes

- **Inconsistencia:** el mismo botón con tres estilos distintos; espaciados que no siguen escala. Muerte por mil cortes.
- **Demasiadas fuentes:** 4 familias tipográficas sin sistema. Ruido y peso de carga.
- **Demasiados colores:** paleta arcoíris sin roles semánticos. Todo compite, nada guía.
- **Contraste insuficiente:** gris claro sobre blanco "porque se ve elegante". Falla AA y excluye usuarios.
- **Valores mágicos:** `margin: 13px`, `#3a7bd5` repetido a mano. Imposible de mantener y de tematizar.
- **Solo el estado feliz:** sin empty, loading ni error. Se rompe con datos reales.
- **Sin foco visible:** eliminar el outline por estética rompe la navegación por teclado.
- **El color como único indicador:** errores distinguidos solo por rojo. Excluye daltonismo.
- **Whitespace inconsistente o ausente:** todo pegado o espaciado al azar. Se percibe como descuido.
- **Iconos ambiguos sin etiqueta:** adivinanzas visuales.
- **Botones primarios múltiples:** varias acciones compitiendo por ser "la principal".
- **Copiar en vez de tokenizar:** duplicar componentes en lugar de parametrizar. Deuda de diseño que crece.

---

## Checklist de UI

- [ ] Existen design tokens (color, tipografía, espaciado, radios, sombras) y el código consume los **semánticos**, no valores literales.
- [ ] La escala tipográfica está limitada (5-7 tamaños) y hay jerarquía clara (H1→body→caption).
- [ ] Máximo 1-2 familias tipográficas; line-height 1.5–1.6 en cuerpo; longitud de línea 45–75 caracteres.
- [ ] Paleta con primario, neutros ricos y semánticos (éxito/error/aviso/info) definidos.
- [ ] Todo el espaciado sigue la rejilla de 8pt (o 4pt para ajustes finos).
- [ ] Hay **una** acción primaria clara por pantalla/sección.
- [ ] Layout alineado a una rejilla; agrupación por proximidad.
- [ ] Cada componente interactivo tiene: default, hover, **focus visible**, active, disabled, loading, error, selected.
- [ ] Cada vista de datos tiene: empty state útil, loading (skeleton), error recuperable y estado con datos.
- [ ] Componentes reutilizados, no duplicados; mismos patrones para mismas acciones.
- [ ] Un solo set de íconos, tamaños consistentes; íconos ambiguos con etiqueta.
- [ ] Responsive mobile-first; unidades relativas; touch targets ≥ 44×44px.
- [ ] Dark mode/temas vía tokens semánticos; contraste verificado en cada tema.
- [ ] Contraste de texto cumple WCAG AA (4.5:1 / 3:1); el color no es el único indicador (ver **accessibility**).
- [ ] Transiciones cortas (150–300ms) con propósito; respeta `prefers-reduced-motion`.
- [ ] Se validó el diseño con datos reales y extremos (textos largos, listas vacías/enormes, imágenes rotas).

---

## Referencias

- **Refactoring UI** (Adam Wathan & Steve Schoger) — jerarquía, espaciado, color práctico. Lectura obligada.
- **Material Design** (Google) — sistema completo: tokens, elevación, tipografía, componentes.
- **Apple Human Interface Guidelines** — touch targets, claridad, consistencia por plataforma.
- **Laws of UX** (Jon Yablonski) — Hick, Fitts, Miller, Jakob aplicadas a interfaces.
- **Atomic Design** (Brad Frost) — metodología de sistemas de componentes.
- **WCAG 2.2** (W3C) — criterios de contraste y accesibilidad (ver skill **accessibility**).
- **Design Tokens** (W3C Community Group) — formato y estructura de tokens.
- **Type Scale / Modular Scale** — herramientas para generar escalas tipográficas coherentes.

**Skills relacionadas:** `ux-design` (comportamiento, flujos, feedback), `accessibility` (contraste, foco, semántica, teclado), `frontend-architecture` (dónde vive y cómo se compone el sistema de componentes).
