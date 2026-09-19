# 01 — Design System

The new system for the editorial/organic/tactile/kinetic direction. It extends, not replaces, the existing token architecture in `app/lib/core/theme/` — same file layout, same "static testable table" pattern as `FluiColorRules`, same reduced-motion discipline.

## 0. A finding that gates this whole document — palette drift

`app/lib/core/theme/flui_colors.dart` currently holds **two unreconciled palettes**:

1. The documented brand palette (`docs/brand.md`): `cream`/`paper` `#FFF9F2`, `greenDeep #0B3D34`, `greenSecondary #165A4B`, `charcoal`/`ink` `#151426`, `yellowElectric #FFD60A`, `gray #687280`.
2. A newer, undocumented "skill" palette already wired into `flui_theme.dart`'s `ColorScheme.light()` as `primary`/`secondary`/`tertiary`: `electricBlue #536DFF`, `aqua #46D9D0`, `coral #FF6B61`, `acidLime #D9FF57`, `softPink #FFD6EA`, `lavender #B8A7FF`, mapped 1:1 to 6 abstract "skills" (`voice`, `fluency`, `vocabulary`, `progress`, `story`, `coaching`) via `SkillColor`/`FluiColors.skill()`.

Nothing in `content/themes.yml` (410 words, 28 themes) uses either palette for theme identity — that's new work. The skill palette also isn't the founder's "multicolour by theme" decision; it's an orthogonal, currently-live scheme for something else (skill categories), already driving the app's Material `ColorScheme`.

**Decision (flag to founder):** retire the 6-hue "skill" palette from `ColorScheme.primary/secondary/tertiary`. Keep `ink`/`paper`/`gray` as the neutral editorial base (already AA-clean, already brand-documented). Reintroduce `greenDeep`/`yellowElectric` as **state** colors only (correct, streak, progress — see §3). Build the 28 theme colours as a new, dedicated token group (`FluiThemeColors` or similar), independent of both prior palettes. This is the single largest open decision in this document; everything below assumes it's resolved this way.

## 1. Colour

### 1.1 Neutral editorial base (from `docs/brand.md`, unchanged)

| Role | Hex | Notes |
|---|---|---|
| `paper` / `cream` | `#FFF9F2` | page background |
| `ink` / `charcoal` | `#151426` | primary text |
| `gray` | `#687280` | secondary text |
| `outline` | `#D5DBD8` | hairlines |
| `disabled` | `#E6E8E5` | inactive surfaces |

Measured: `ink` on `paper` = **17.32:1** (WCAG AAA, both text sizes). This pairing is the workhorse for all body copy and stays untouched.

### 1.2 The 28 theme colours

One hue per theme in `content/themes.yml`, grouped into 5 hue neighbourhoods by family (`trabajo`, `publico`, `precision`, `social`, `emocion`) so that **family reads as a colour neighbourhood and theme reads as a specific hue inside it** — this is the wayfinding rule: glance at a hue, know the family; recognise the exact hue, know the theme.

Each hex was generated at fixed saturation (62%) and solved per-hue for lightness so that **contrast against `paper` (#FFF9F2) is 4.6:1 for every single one** — verified by script (`colorsys` HSL → sRGB → WCAG relative luminance, binary search on L; not eyeballed). 4.6:1 clears `aaText` (4.5:1) with a small margin, so each theme colour is safe as a **filled background with paper-coloured text/icons on top**, and equally safe as a **coloured label/icon directly on the paper page background** (same ratio, contrast is symmetric). On-colour for all 28 is therefore uniformly **paper** — one rule, no per-theme exceptions.

| Family | Slug | Name | Hex | On-colour | Contrast vs paper |
|---|---|---|---|---|---|
| trabajo | reuniones | Reuniones | `#2977AF` | paper | 4.6:1 |
| trabajo | entrevistas | Entrevistas | `#3071CC` | paper | 4.6:1 |
| trabajo | negociacion | Negociación | `#496CD4` | paper | 4.6:1 |
| trabajo | liderazgo-feedback | Liderazgo y feedback | `#5C66D9` | paper | 4.6:1 |
| trabajo | correos-mensajes | Correos y mensajes | `#6B61DA` | paper | 4.6:1 |
| trabajo | redaccion-ejecutiva | Escribir para que te lean | `#7B5CD9` | paper | 4.6:1 |
| trabajo | ventas | Ventas | `#8B55D7` | paper | 4.6:1 |
| trabajo | networking | Hacer contactos | `#9B4BD5` | paper | 4.6:1 |
| publico | presentaciones-oratoria | Presentaciones | `#916C22` | paper | 4.6:1 |
| publico | persuasion-storytelling | Convencer y contar | `#82721F` | paper | 4.6:1 |
| publico | redes-sociales | Redes sociales | `#76761C` | paper | 4.6:1 |
| publico | docencia | Enseñar | `#6A791C` | paper | 4.6:1 |
| publico | medios-entrevistas | Hablar con medios | `#5C7C1D` | paper | 4.6:1 |
| precision | matices-precision | Matices | `#1E7F77` | paper | 4.6:1 |
| precision | conectores-estructura | Conectores | `#1F7E86` | paper | 4.6:1 |
| precision | paronimos | Palabras que se parecen | `#247B98` | paper | 4.6:1 |
| social | elogio-reconocimiento | Reconocer a otros | `#CE307F` | paper | 4.6:1 |
| social | conversacion-cotidiana | Conversación diaria | `#CF346A` | paper | 4.6:1 |
| social | humor | Humor | `#D03756` | paper | 4.6:1 |
| social | citas | Citas | `#D13941` | paper | 4.6:1 |
| social | amistad | Amistad | `#CD4030` | paper | 4.6:1 |
| social | small-talk | Romper el hielo | `#BD512C` | paper | 4.6:1 |
| social | familia-crianza | Familia y crianza | `#AC5D28` | paper | 4.6:1 |
| emocion | conflicto-desacuerdo | Desacuerdos | `#AD3DD2` | paper | 4.6:1 |
| emocion | conversaciones-dificiles | Conversaciones difíciles | `#BB2FC8` | paper | 4.6:1 |
| emocion | decir-que-no | Decir que no | `#C22EB6` | paper | 4.6:1 |
| emocion | empatia-escucha | Escuchar | `#C82FA1` | paper | 4.6:1 |
| emocion | pedir-disculparse | Pedir y disculparse | `#CC308B` | paper | 4.6:1 |

Note: these hexes are **saturated/dark values**, correct for icons, chips, progress fills, and small accent surfaces. They are deliberately too dark/saturated to use as a full-bleed card background with `ink` body text on top (contrast vs `ink` is only ~3.76:1, which clears `aaLargeText` but not `aaText`).

**Tint** — every theme colour has a light tint for card/section backgrounds: `mix(themeColor, paper, 12%)`. Spot-checked (not exhaustive, pattern holds across all 28 since tints stay within a narrow luminance band close to `paper`): `ink` on a 12%-mixed tint measures **14.6–14.95:1** — i.e. safely AAA regardless of hue, because a 12% mix barely moves luminance off `paper`'s 0.93. This is the same mechanism as the existing `greenTint`/`E2EDE9` pattern in `flui_color_rules.dart` — reuse it verbatim: `ColorPair('ink on <theme>Tint', ink, tint)` added to `FluiColorRules.readable` per theme (28 new generated entries, not hand-authored — see implementation note below).

**Implementation note**: generate this table (hex + tint) from a script, not by hand — 28 hand-tuned hex values will drift the first time someone edits `themes.yml`. Store the generator inputs (hue range per family, saturation, target ratio) as the source of truth; `FluiColorRules`-style tests assert every generated pair still clears AA, the same way `forbidden` pairs are asserted to fail. `flui_color_rules.dart`'s existing pattern (`aaText = 4.5`, `aaLargeText = 3`, `ColorPair(name, foreground, background)`, `readable`/`borders`/`forbidden` lists, tested by a script) is the one to extend, not reinvent.

### 1.3 When colour means what

Three, and only three, meanings — never overload a fourth:

1. **Theme** — the 28 colours above. Used for: theme chips/badges, the active theme's accent inside a session (card top-edge hairline tint, small icon), theme-scoped empty states, the speaking-challenge prompt card. Never used for pass/fail or generic UI chrome.
2. **State** — `greenDeep`/`greenSecondary` (correct/positive), `amber`/`alert` (needs attention/error, never red-as-alarm per brand voice), `yellowElectric` restricted to the existing 4 `YellowRole`s (`progressFill`, `wordOfTheDayMarker`, `streakMoment`, `headlineWord`). These are constant regardless of theme — a correct answer is always green, in every theme.
3. **Progress** — `yellowElectric` fill on `progressSurface` (`ink`), exactly as today (`FluiProgressBar`). Theme colour never substitutes for progress colour, even inside that theme's session — mixing the two would make "how am I doing" ambiguous with "what am I practising."

## 2. Typography

Unchanged from `flui_type_scale.dart` — the existing scale already reads as "editorial, oversized numerals and words" and needs no redesign, only wider *use*: the new screens should reach for `wordHero`/`displayL` far more often than today's mostly-`titleM`/`body` composition.

| Role | Compact | Wide | Leading rule |
|---|---|---|---|
| `wordHero` | 72/68 | 112/104 | ≤1.05 (0.944 / 0.929 measured) |
| `displayL` | 44/46 | 64/62 | ≤1.05 |
| `titleL` | 28/32 | 34/38 | — |
| `titleM` | 22/28 | 24/30 | — |
| `bodyL` | 18/28 | 18/28 | ≥1.55 (1.556 measured) |
| `body` | 16/26 | 16/26 | ≥1.55 (1.625 measured) |
| `label` | 13 | 13 | uppercase via `labelText()` |
| `phonetic` | 15 | 15 | — |

Fonts unchanged: `PlusJakartaSans` (display), `Inter` (text). New usage guidance for the redesign: the front card's headword renders at `wordHero`; the streak/progress numerals on Progreso render at `displayL` or larger via a new `numeralHero` treatment (see below) — numbers are content, not metadata, and should be sized like it.

**New role — `numeralHero`**: 96/88 compact → 144/128 wide, tabular figures, `PlusJakartaSans`, for streak counts, "45 s" speaking timer, and session-complete counters. Same leading invariant as `wordHero` (≤1.05).

## 3. Spacing, radii, surfaces — unchanged

No redesign needed; these already support an editorial layout and the card stack reuses them directly:

- Spacing scale (`flui_spacing.dart`): `[4, 8, 12, 16, 20, 24, 32, 40, 56, 80, 120]` (`xxs`…`hero`), `contentMaxWidth 720`, `pageMaxWidth 1120`, `minTapTarget 44`.
- Radii (`flui_radii.dart`): `chip 8`, `cta 14`, `card 16`, `plate 28`. Rule holds: **a CTA is a 14px rectangle, never a pill.** The card stack's front card uses `card` (16) or a new `cardStack` radius (see `03-card-stack-spec.md`) — kept close to 16 so it still reads as "the same card system," not a new shape language.
- Surfaces (`flui_surfaces.dart`): hairline-only depth, exactly one shadow in the app (`ctaDockShadow`). The card stack introduces the **second** shadow the app will ever have — a soft, large-blur shadow under the front card to sell physical depth against the two cards behind it (spec'd in `03-card-stack-spec.md` — new token `cardStackShadow`, not a reuse of `ctaDockShadow`, since the compositing need is different: multiple stacked shadows, not one docked panel).

## 4. Iconography — unchanged

`flutter_lucide` + 10 custom SVG glyphs on the wave motif, 3 sizes (22/20/18), 24 grid, 2px stroke. No change required; the organic blob (logo/bubble) is a new, separate visual object, not a glyph, and shouldn't be forced into the icon grid.

## 5. Motion tokens as first-class citizens

Today's `flui_motion.dart` is entirely duration+curve based — **no `SpringDescription` exists anywhere in the codebase today**. The three spring tokens below are a genuine addition, not a reuse of prior art, and should live alongside the existing constants in `flui_motion.dart` (or a new `flui_springs.dart` in the same directory, re-exported from `flui_motion.dart` so call sites don't need to know which file).

```dart
import 'package:flutter/physics.dart';

/// Snappy — gesture-driven interactions the user's finger is still touching
/// (drag release, swipe-to-dismiss the front card). Underdamped, visible
/// but brief overshoot so a released card feels caught, not just stopped.
const fluiSpringFast = SpringDescription(mass: 1, stiffness: 500, damping: 30);
// damping ratio ≈ 0.67 (underdamped)

/// The default — card-to-card advance, the next card moving into front
/// position, feedback card arriving. This is the spring most motion in
/// 03/06 refers to unless stated otherwise.
const fluiSpringStandard = SpringDescription(mass: 1, stiffness: 300, damping: 24);
// damping ratio ≈ 0.69 (underdamped, slightly softer overshoot than fast)

/// Idle/ambient — bubble breathing, gentle emphasis, anything looping or
/// unprompted by direct touch. Near-critically damped: reaches its target
/// smoothly, no bounce, so a looping breath doesn't read as jittery.
const fluiSpringGentle = SpringDescription(mass: 1, stiffness: 170, damping: 26);
// damping ratio ≈ 0.997 (critically damped)
```

Drive these with `SpringSimulation` inside an `AnimationController` (`controller.animateWith(SpringSimulation(fluiSpringStandard, from, to, velocity))`), not `Curves` — springs need a starting velocity (from a drag's release velocity, or 0 for programmatic triggers) which curve-based `Tween`+`Duration` can't express. This is *why* the card stack needs springs and the rest of the app didn't: everything the app animates today is programmatic (tap → advance); the card stack is the first thing driven by a **drag gesture with real release velocity**.

Existing duration/curve tokens are kept unchanged and continue to cover everything that isn't gesture-driven:

| Token | Value | Used for |
|---|---|---|
| `instant` | 120ms | micro state flips |
| `quick` | 200ms | section entrance |
| `standard` | 320ms | word reveal, most transitions |
| `celebration` | 900ms | streak milestones |
| `enter` | `Curves.easeOutCubic` | |
| `exit` | `Curves.easeOut` | |
| `emphasized` | `Cubic(0.2, 0, 0, 1)` | shared-axis route transitions |

`FluiMotion.reduced(context)` / `.resolve(context, duration)` extend naturally to springs: a reduced-motion spring simulation is replaced with an immediate `Tween` jump to the end value (`Duration.zero`), never removed from the widget tree — see `06-motion-spec.md` for the per-animation reduced-motion table.
