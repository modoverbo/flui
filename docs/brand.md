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
| `cream` | `#F8F8F6` | App background, surfaces | 60% |
| `greenDeep` | `#0B3D34` | Primary brand color, headers, primary buttons, "Tuya" | 25% (with `greenSecondary`) |
| `greenSecondary` | `#165A4B` | Secondary surfaces, "Practica", pressed states | (included above) |
| `charcoal` | `#0F0F0F` | Primary text, icons | 10% |
| `yellowElectric` | `#FFD60A` | Single highlight per screen, "Nueva", celebration | 5% |
| `gray` | `#687280` | Secondary text, hints, disabled | as needed |

**Contrast rules** (WCAG 2.2):

| Pair | Ratio | Use |
|------|------:|-----|
| `charcoal` on `cream` | ~18:1 | body text |
| `cream` on `greenDeep` | ~11:1 | primary button, headers |
| `cream` on `greenSecondary` | ~7.6:1 | chips, secondary buttons |
| `charcoal` on `yellowElectric` | ~13:1 | highlight chip |
| `yellowElectric` on `greenDeep` | ~8.6:1 | accent on dark surfaces |
| `gray` on `cream` | ~4.6:1 | secondary text (≥ 14 px) |
| `yellowElectric` on `cream` | ~1.3:1 | **never** for text or essential icons |

## 6. Typography

Both families are OFL-1.1 and bundled as assets (no runtime font fetching).

| Level | Family | Weight | Size / line height |
|-------|--------|--------|--------------------|
| Featured word | Plus Jakarta Sans | ExtraBold 800 | 40 / 48 |
| H1 | Plus Jakarta Sans | ExtraBold 800 | 28 / 36 |
| H2 | Plus Jakarta Sans | Bold 700 | 22 / 28 |
| H3 / card title | Plus Jakarta Sans | Bold 700 | 18 / 24 |
| Body | Inter | Regular 400 | 16 / 24 |
| Body emphasis | Inter | SemiBold 600 | 16 / 24 |
| Label / button | Inter | SemiBold 600 | 14 / 20 |
| Caption / hint | Inter | Regular 400 | 12 / 16 |

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
| `nueva` | Nueva | `yellowElectric` | `charcoal` | `sparkles` |
| `practica` | Practica | `greenSecondary` | `cream` | `repeat` |
| `tuya` | Tuya / "Ya es tuya" | `greenDeep` | `cream` | `check` |

## 9. Iconography

- UI icons: **Lucide** (ISC), 24 px grid, 2 px stroke, round caps and joins.
- Keep one stroke weight per screen; icons use `charcoal` or `cream` on dark surfaces.

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
