# Brand kit (condensed)

How flui looks, sounds and names things. Use it for UI copy, content and visual design.
Product copy is Spanish (neutral pan-Hispanic, "tú"); this document is in English.

## 1. Name

| Rule | Example |
|------|---------|
| Always lowercase, also at the start of a sentence | "flui te ayuda a…" |
| Never translated, spaced or stylized | not "Flui", "FLUI", "Flu-i" |
| Parent brand for social media | ModoVerbo |

## 2. Promise and taglines

- **Promise:** flui helps intelligent adults find better words and express themselves naturally.
  It is a communication trainer, **not** a vocabulary or academic app.
- **Primary tagline:** "Habla como quieres sonar."
- **Supporting line:** "No te faltan ideas. Te faltan palabras."
- **Positioning:** you will sound like yourself, only sharper; never "stop saying nonsense".

## 3. Voice

Warm, direct, adult, encouraging. Short sentences. Celebrate progress, never shame mistakes.
Regional usage is variation, not error.

| Do | Don't |
|----|-------|
| "Casi." | "Incorrecto." |
| "Encuentra la palabra que encaja." | "Selecciona la opción correcta." |
| "Una palabra más en tu repertorio." | "Lección completada." |
| "¡Ahí está!" | "Respuesta revelada." |
| "Hoy toca afianzar." | "Tienes 12 repasos atrasados." |
| "Vamos a refrescarla." | "Olvidaste esta palabra." |
| "Hoy estás sembrando; mañana cosechas." | "Has fallado 3 veces." |
| "5 de 7 días esta semana." | "¡Perdiste tu racha!" |
| "7 días gratis. Hoy no te cobramos nada." | Hidden trial terms or surprise charges |

**Words to avoid** (school or exam connotations): lección, examen, alumno, profesor, tarea,
calificación, gramática, memorización, evaluación. Also avoid "incorrecto", guilt, fear of missing
out, income or "99%" claims, and the "#SinMuletillas" trademark.

## 4. Verbal universe

| Concept | flui words |
|---------|-----------|
| Vocabulary | palabras, repertorio, la palabra que encaja, cómo suena |
| Progress | Nueva → Practica → Tuya ("Ya es tuya") |
| Consolidation | afianzar, refrescar, sembrar / cosechar |
| Context | En contexto, escena, "Antes decías… / Ahora:" |
| Session steps | Descubre, Entiende, Mira, Elige, Úsala |
| Navigation | Hoy, Palabras, Practica, En contexto, Tu progreso (future: Habla) |

## 5. Color

| Token | Hex | Role | Share |
|-------|-----|------|------:|
| `cream` | `#FFF9F2` | App background, surfaces | 60% |
| `greenDeep` | `#0B3D34` | Primary brand color, headers, primary buttons, "Tuya" | 25% (with `greenSecondary`) |
| `greenSecondary` | `#165A4B` | Secondary surfaces, "Practica", pressed states | (included above) |
| `charcoal` | `#151426` | Primary text, icons | 10% |
| `yellowElectric` | `#FFD60A` | Single highlight per screen, "Nueva", celebration | 5% |
| `gray` | `#687280` | Secondary text on cream only | as needed |
| `creamMuted` | `#B9C4BF` | Secondary text on any green surface | as needed |
| `amber` | `#B26A00` | The border of a "todavía no" — never red | rare |

**Contrast rules** (WCAG 2.2). They live as data in
`app/lib/core/theme/flui_color_rules.dart` and a test fails when a pairing drifts.

| Pair | Ratio | Use |
|------|------:|-----|
| `charcoal` on `cream` | 18.03:1 | body text |
| `cream` on `greenDeep` | 11.41:1 | primary button, headers |
| `cream` on `greenSecondary` | 7.60:1 | chips, secondary buttons |
| `charcoal` on `yellowElectric` | 13.58:1 | yellow surfaces carry charcoal, never green |
| `yellowElectric` on `greenDeep` | 8.59:1 | accent on dark surfaces |
| `creamMuted` on `greenDeep` | 6.76:1 | secondary text on green |
| `gray` on `cream` | 4.59:1 | secondary text on cream |
| `amber` on `cream` | 3.99:1 | border only, never text |
| `gray` on `greenDeep` | 2.49:1 | **never**: use `creamMuted` |
| `yellowElectric` on `cream` | 1.33:1 | **never** as text or a bare fill |

**Yellow has exactly four roles** (`YellowRole`), and no others: the filled part of a
progress bar, the "tu palabra de hoy" marker, a streak day or unlocked achievement,
and one word of a marketing headline.

## 6. Typography

Both families are OFL-1.1 and bundled as assets (no runtime font fetching).

Eight roles, two viewport variants. A screen picks a **role**, never a size, and takes
it from `context.type` (`FluiTypeScale`); nothing calls `MediaQuery` for sizing.
Display roles grow on the web; text roles do not, because reading measure does not
depend on the window.

| Role | Family | Weight | Mobile | Web | Tracking |
|------|--------|--------|--------|-----|---------:|
| `wordHero` | Plus Jakarta Sans | ExtraBold 800 | 72 / 68 | 112 / 104 | −3 % |
| `displayL` | Plus Jakarta Sans | Bold 700 | 44 / 46 | 64 / 62 | −2 % |
| `titleL` | Plus Jakarta Sans | Bold 700 | 28 / 32 | 34 / 38 | −1.5 % |
| `titleM` | Plus Jakarta Sans | SemiBold 600 | 22 / 28 | 24 / 30 | −1 % |
| `bodyL` | Inter | Regular 400 | 18 / 28 | 18 / 28 | 0 |
| `body` | Inter | Regular 400 | 16 / 26 | 16 / 26 | 0 |
| `label` | Inter | SemiBold 600 | 13 / 16 | 13 / 16 | +6 %, UPPERCASE |
| `phonetic` | Inter | Regular 400 | 15 / 20 | 15 / 20 | 0, `tnum` |

Two rules hold in both variants and are tested: **display leading ≤ 1.05**, **body
leading ≥ 1.55**. Labels are set in caps by `FluiLabel`; the ARB copy stays sentence
case and that is what screen readers announce.

## 6b. Spacing, radii and surfaces

- **Spacing scale:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56 · 80 · 120. Nothing uses
  a value outside it. Block gap 32 mobile / 40 web; section gap 56 / 80.
- **One content max-width policy:** text columns 720, page grids 1120. The web hero is
  a 12-column grid split 7 / 5.
- **Radii, one per role:** 8 chips and inputs · **14 the primary call to action** ·
  16 cards · 28 hero plates and sheets · 999 chips only. A primary action is a
  rectangle; it is never a pill.
- **Surfaces are flat.** Depth comes from hairlines — `rgba(11,61,52,.08)` on cream,
  `rgba(248,248,246,.10)` on green — and from the green plate. There is exactly **one
  shadow** in the app, under the sticky call-to-action dock.
- **Texture:** the green plate is a radial deep-green field lifting to `#165A4B` with
  5 % grain, pre-baked as WebP at 1x / 2x / 3x (`app/tool/generate_texture_plates.mjs`).
  Every empty state and every green section uses a plate, never flat white.

## 6c. Layout patterns

| Pattern | Where | What it does |
|---------|-------|--------------|
| P1 Hero plate + rail | word detail, Descubre | the word owns the top ~55 % at `wordHero`; a horizontal rail shows how it is used |
| P2 Asymmetric bento | Hoy, Tu progreso | 2 columns, one 2×2 dark anchor, 1×1s and a 2×1, fixed aspect ratio so it reaches the fold |
| P3 Section rhythm | long web pages | cream → full-bleed green → cream; never three cream sections in a row |
| P4 Sticky CTA dock | welcome, onboarding, paywall, Hoy, time budget, word detail | content scrolls behind the action instead of a pill floating over empty space |
| P5 Web split hero | welcome, auth | 12 columns, max 1120, 7 / 5 |

## 6d. Motion

Four durations — 120 / 200 / 320 / 900 ms — `easeOutCubic` arriving, `easeOut` leaving
at 0.8× the duration, and Material's emphasized curve for shared-axis route
transitions. Everything resolves through `FluiMotion.resolve`, so "reduce motion"
turns motion **off**, never merely shortens it.

| Moment | Motion |
|--------|--------|
| Word reveal | per-line mask slide-up, 40 ms stagger, 1.02 → 1.0, 320 ms |
| Right answer | yellow underline draws left to right, 220 ms, one light haptic on mobile |
| Wrong answer | three 6 px cycles in 260 ms and an **amber** border, never red |
| Progress | 400 ms `easeOutCubic` with a brief yellow glow |
| Streak | celebrated only at 3, 7, 14 and 30 days |
| Web sections | 200 ms fade plus a 12 px rise, 60 ms apart |

## 7. UI principles

1. **Una acción principal por pantalla.** One primary button; everything else is secondary.
2. One yellow highlight per screen at most.
3. Short text blocks; the featured word is the hero.
4. Feedback is immediate and kind: "Casi." plus a hint, never a red "wrong" state.
5. Respect time: the chosen budget is visible and honored.
6. No dark patterns: no guilt notifications, no paid streak repair, no shaming leaderboards,
   clear trial terms and a reminder before the first charge.

## 8. Word states

| State | Label | Chip background | Chip text | Icon (Lucide) |
|-------|-------|-----------------|-----------|---------------|
| `nueva` | Nueva | `yellowElectric` | `charcoal` | `palabra del día` |
| `practica` | Practica | `greenSecondary` | `cream` | `repaso` |
| `tuya` | Tuya / "Ya es tuya" | `greenDeep` | `cream` | `logro` |

The chip label is set in caps; the word itself is what a screen reader announces.

## 9. Iconography

Ten concepts are ours, and only those ten get a drawing of their own. Everything else
is boring on purpose.

- **Custom glyphs** (`app/assets/icons`, generated by `app/tool/generate_glyphs.mjs`):
  `onda` · `palabra-del-dia` · `reemplaza` · `racha` · `en-contexto` ·
  `matiz-registro` · `microfono` · `meta` · `logro` · `repaso`. All are drawn on the
  logo's wave on a 24 grid with a 2 px stroke and round terminals, so they read as one
  family; a test checks every asset against those numbers.
- **Everything else:** Lucide (ISC, `flutter_lucide`), same 24 grid and 2 px stroke.
- **Three sizes only:** 22 tab bar, 20 section headers, 18 inline.
- Icons are never placed inside a tinted square, and they take `charcoal`,
  `greenSecondary` or `cream`/`creamMuted` on green.

## 10. Logo

- **Symbol:** three stacked soft waves ("fluir"), **derived from Tabler Icons `ripple`**
  (MIT license). Adjust wave height, phase or stroke before registering it as a trademark: an MIT
  icon is not exclusive.
- **Attribution requirement:** the MIT license requires keeping the copyright and permission notice
  of Tabler Icons (Copyright (c) Paweł Kuna) with the distributed app. Register it with Flutter's
  `LicenseRegistry` and keep it in the repository's third-party notices alongside the asset.
- **Wordmark:** "flui" in Plus Jakarta Sans ExtraBold, lowercase.
- **Usage:** `greenDeep` symbol on `cream`, or `cream` symbol on `greenDeep`; a `yellowElectric`
  symbol is allowed only on dark green. Keep clear space equal to the symbol's stroke height × 3.
  Do not stretch, rotate, outline, add shadows or place on busy photos.
- The asset itself is added by the app (`app/assets/`).
