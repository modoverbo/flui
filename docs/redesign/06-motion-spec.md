# 06 — Motion Spec

Full motion inventory: what animates, which token drives it, how long, what it communicates, and its reduced-motion behaviour. Every row must have all five — a motion with no stated "what it explains" is decoration and should be cut, not spec'd.

| # | Motion | Token | Duration/spring | Explains | Reduced motion |
|---|---|---|---|---|---|
| 1 | Card stack: front card exits | `fluiSpringStandard` | spring-settled (~380–450ms) | This step is done; leaving | Instant removal, no animation (`03-card-stack-spec.md` §6) |
| 2 | Card stack: position 1→0, 2→1 promotion | `fluiSpringStandard` | spring-settled, slight overshoot (damping ratio ≈0.69) | The next card is now yours | Instant, positions 1/2 not rendered at all |
| 3 | Card stack: new card enters position 2 | `quick` (200ms) + `enter` curve | 200ms | A card is now queued behind | Unaffected (positions 1/2 don't render, so this never fires) |
| 4 | Card stack: drag-follow (active gesture) | 1:1 with pointer, no token | continuous | Direct manipulation — the card is under your finger | Swipe gesture disabled entirely; no drag-follow to reduce |
| 5 | Card stack: release below threshold (springback) | `fluiSpringFast` | spring-settled (~250–320ms) | That wasn't enough to dismiss it | N/A — swipe disabled |
| 6 | Bubble: idle/ready breathing | `fluiSpringGentle` | 2–3s loop, scale 1.00→1.015 | Alive, waiting | Fixed rest scale, no loop (`05-bubble-state-machine.md` §5) |
| 7 | Bubble: recording amplitude wobble | amplitude pipeline (custom, not a spring token) | continuous, 120ms sample + interpolation | You're being heard, right now | Capped range, stepped not continuous — kept, not removed (it's informational) |
| 8 | Bubble: processing ambient motion | `fluiSpringGentle` | loop, scale 1.00→1.02 | Still working, not frozen | Disabled, fixed rest scale |
| 9 | Bubble: result settle pulse | `fluiSpringStandard` | one-shot | This attempt is scored; look at the feedback now | Instant, no pulse |
| 10 | Bubble: error contraction | `fluiSpringFast` | one-shot, small | Something needs your attention | Instant, no contraction (colour change alone communicates it) |
| 11 | Word reveal (existing, `RevealLines`) | `standard` (320ms), 40ms stagger, scale 1.02→1.0 | 320ms | New content is arriving, line by line | Snap to end-state, per existing `FluiMotion.reduced` |
| 12 | Correct-answer underline draw (existing, `DrawUnderline`) | `underlineDraw` (220ms) | 220ms | That answer is confirmed correct | Snap to fully-drawn |
| 13 | Wrong-answer shake (existing, `ShakeBox`) | `shake` (260ms, 3 cycles, 6px) | 260ms | Try again, not quite | Snap — amber border appears without the shake (colour still signals it) |
| 14 | Progress bar fill (existing, `FluiProgressBar`) | `progress` (400ms) | 400ms | You've made measurable headway | Instant fill to new value |
| 15 | Section entrance (existing, `SectionEntrance`) | `sectionEntrance` (200ms) + 60ms stagger, 12px rise | 200ms | New section is now in view | Snap to final position |
| 16 | Streak milestone celebration (existing) | `celebration` (900ms) | 900ms | A meaningful threshold was crossed (3/7/14/30 days) | Shortened to a static badge state-change, no confetti/motion-heavy celebration |
| 17 | Route transitions: onboarding chain (`sharedAxisX`) | `emphasized` curve | ~300ms (Material shared-axis default) | Moving forward through a linear sequence | Collapses to a cut (already implemented in `flui_transitions.dart`) |
| 18 | Route transitions: entering `/session`, `/speaking/challenge` (`sharedAxisZ`) | `emphasized` curve | ~300ms | You've left the surrounding app for a focused task | Collapses to a cut |
| 19 | `TrainingTimer` countdown (45s cap) | none — numeral update, no easing | per-second tick | Time remaining in the challenge | Unaffected — a numeral changing isn't motion in the reduced-motion sense |
| 20 | `FeedbackCard` arrival (after `processing`) | `standard` (320ms) + `enter` curve | 320ms | Your result is ready | Snap to visible |
| 21 | Theme colour application (card top-edge tint, chip fill) when entering a themed session/card | `quick` (200ms), colour cross-fade | 200ms | This card belongs to theme X | Instant colour swap, no cross-fade |
| 22 | Nav bar indicator (existing `NavigationBar`/`NavigationRail`) | Material default | Material default (~300ms) | You're now on this tab | Unaffected (Material's own indicator motion is minor enough not to warrant an override; revisit only if user testing says otherwise) |

## Cross-cutting rules

- Every row's reduced-motion column must be an intentional design decision, not "animation off" by default rule — items 7 and 16 deliberately keep *some* motion because it's informational (amplitude) or because a full stop would remove positive reinforcement (milestone), just scaled down rather than eliminated.
- No motion in this table animates layout properties (size, position-affecting-siblings) per frame — everything is `Transform`/`Opacity`/colour, consistent with `03-card-stack-spec.md` §5's performance rule, extended app-wide.
- Springs (rows 1, 2, 5, 6, 8, 9, 10) are new; everything else reuses `flui_motion.dart`'s existing duration/curve tokens unchanged — the redesign adds a motion *type* (physics-based) without discarding the existing duration/curve system, which still covers the majority of the app's non-gesture-driven motion.
