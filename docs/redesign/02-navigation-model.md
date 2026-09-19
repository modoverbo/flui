# 02 — Navigation Model

## 1. Target nav: Hoy / Palabras / Habla / Progreso

Four shell destinations, up from the current three (`docs/brand.md` already lists "Habla" as a planned tab, confirming this isn't a new invention). Mapping onto existing code:

| New tab | Existing route | Existing screen | Change needed |
|---|---|---|---|
| Hoy | `/today` | `TodayPage` | none to the route; content redesign only |
| Palabras | `/words` | `WordsPage` | none to the route; content redesign only |
| **Habla** | `/speaking/challenge` | `SpeakingChallengePage` | **promote from a root-navigator full-screen route to a shell branch** |
| Progreso | `/progress` | `ProgressPage` | none to the route; content redesign only |

### Decision (flag to founder): Habla becomes a real 4th `StatefulNavigationShell` branch, not a CTA-launched route

Today `/speaking/challenge` sits outside the shell on the root navigator (same tier as `/session`) — a full-screen takeover you *enter*, not a place you *are*. Making it a tab means it needs a landing state (a "ready to speak" screen with the day's prompt, streak, last-result recap) distinct from mid-challenge phases 2–6 of `04-speaking-spec.md`. Two ways to resolve this, both reusing `SpeakingChallengePage`'s existing `_Phase` enum (`ready, recording, analyzing, feedback, comparison, denied, error`):

- **A. `ready` phase *is* the tab's landing state.** Selecting Habla always shows the `ready` phase (prompt + start button) at the tab's `NavigatorState` root; recording/analyzing/feedback/comparison still push as a full-screen take-over on the *root* navigator, same as `/session` does today (sharedAxisZ), then pop back to `ready` on completion. Minimal change to `SpeakingChallengePage`'s internals — only its entry route changes.
- **B. The whole challenge stays inside the tab's own navigator**, card-stacked like a session, never popping to root.

**Recommended: A.** It matches the existing `/session` precedent exactly (tab → full-screen take-over → back to tab), keeps `SpeakingChallengePage`'s state machine intact, and avoids fighting go_router's shell/root navigator split for something that's inherently a focused, distraction-free 45-second task — a card stack peeking behind a shell nav bar undercuts that focus. Founder should confirm this over B before implementation.

### Decision (flag to founder): speaking stays a standalone surface, not a `SessionStep`

`SessionFlow`'s 9 step variants (`ReviewClozeStep` … `SeedingReadingStep`) don't include speaking — it was built and shipped as an independent feature. Two options: (1) add a `SpeakingStep` variant and graft the 45-second challenge into the daily card stack as its final step, or (2) keep it fully separate, reachable from its own tab and from an end-of-session CTA.

**Recommended: (2), keep it separate.** Reasons: `SpeakingChallengePage` already owns a working state machine, a repository triad (`http`/`supabase`/`fake`), and a live Edge Function contract (`speech-analyze`) — folding it into `SessionFlow` means either duplicating that machinery inside a `SessionStep` or making `SessionFlow` (currently pure, synchronous, immutable) aware of an async network call with its own error/retry lifecycle, which it isn't designed for today. It also matches the founder's own nav decision — a dedicated tab implies "speaking is its own practice mode," not "the last card of today's session." `TodayPage`'s session-summary view can still surface a "practice speaking" CTA that deep-links to Habla; that's a soft integration, not a structural one.

## 2. Inside a session: stay in the stack

Every step of the daily loop (reviews, discover, readings, cloze, form recall, production, final check, requeues) becomes one card in the stack described in `03-card-stack-spec.md`. The existing rule — `SessionPage` is a single full-screen route (`sharedAxisZ` entry from `/today`), and `SessionFlow.completeStep()`/`completeCloze()` advance an immutable cursor with no route push per step — is exactly the substrate the card stack needs: **no navigation change inside a session**, only what `SessionPage` renders for `flow.current` changes (from a full-screen swap keyed on `step.runtimeType` to a stack with lookahead).

Two-tier transition model:

1. **Session-to-session** (leaving `/today`, entering `/session` or `/speaking/challenge`, returning): route-level, `sharedAxisZ`, unchanged from today. "You're going to a different place."
2. **Card-to-card** (inside a session, one step completing): stack-level, spring-driven, described in `03-card-stack-spec.md`. Never a route push. "You're still in the same place; the material in front of you changed."

Confirm this split with the founder — it means the redesign touches `SessionPage`'s body composition heavily but never touches `app_router.dart`'s route table for in-session navigation.

## 3. Route table after the redesign

No paths change. Only `/speaking/challenge`'s navigator placement (root → shell branch) and `AppShell`'s branch count (3 → 4) change structurally; every other route in `00-current-ui-map.md` §1 is unchanged, including the guard chain (`AuthStatus → AccessGate → DailyGate`) and the retired-route redirects.

| Tab | Path | Screen |
|---|---|---|
| Hoy | `/today` | `TodayPage` |
| Palabras | `/words` (+ `/words/:wordId`) | `WordsPage`, `WordDetailPage` |
| Habla | `/speaking/challenge` | `SpeakingChallengePage` (moved into the shell) |
| Progreso | `/progress` | `ProgressPage` |

Full-screen, outside the shell, unchanged: `/session`, `/today/time`, all onboarding/auth/subscription routes.
