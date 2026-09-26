# speech-analyze access gate (U1)

## Objective and authority

Close the live AI-cost leak: `supabase/functions/speech-analyze` validates only the user token (`admin.auth.getUser`) and never checks `public.has_access`, so any signed-in account without a trial or subscription can spend Groq transcription/evaluation. The user authorized implementing work unit U1 of the `flui-eloquence-gym-refactor` plan through the organic route (outside SDD) on 2026-09-26, because the native SDD dispatcher cannot resolve the Engram-stored change yet.

Source plan (Engram, project `flui`): tasks `sdd/flui-eloquence-gym-refactor/tasks` (obs #431, section "U1"), spec `ai-cost-gating` in `sdd/flui-eloquence-gym-refactor/spec/part-1` (obs #423), design part-1 §4.1 (obs #427), decision #422.

## Scope and constraints

- In scope: server-side access check in `speech-analyze` (403 `access_required`, 503 `access_unavailable`, fail closed); Groq call extraction to `groq.ts` with no behavior change; new error codes in `supabase/functions/_shared/http.ts`; app-side `SpeechAnalysisFailure` in the sealed `Failure` hierarchy, repository mapping, and Spanish copy.
- Out of scope: daily quota (U19), payload evolution (U11), any UI flow change, any billing change.
- The existing upstream Groq 429 `rate_limited` path must remain unchanged and distinct from 403/503.
- TDD: on (source: AGENTS.md "test primero para toda la lógica" and user global instructions). Observe RED before GREEN. Runners: `cd supabase/functions && deno task ci`; `cd app && flutter test`.
- Closure checks: `cd supabase/functions && deno task ci`; from `app/`: `dart format --set-exit-if-changed lib test integration_test`, `flutter analyze && dart analyze`, `flutter test`, `flutter test integration_test -d flutter-tester`; `git diff --check`.
- Delivery: branch `fix/speech-analyze-access-gate`, one Conventional Commit, no push or PR without the user's decision. Forecast: ~350 authored changed lines (advisory).

## Tasks and evidence

- [x] **A01 — Server access gate.** Route: delegated direct (writer trigger: 2+ non-trivial files across `supabase/functions` and `app`). Acceptance: has access → 200 and provider called; no access → 403 `access_required`, no provider call; unauthenticated → 401, access check not called; access check error → 503 `access_unavailable`, no provider call; existing 429 unchanged.
  - RED observed: added `hasAccess` to `handler_test.ts`'s `setup()` and three new cases (`denies analysis for an authenticated user without access`, `fails closed with 503 when the access check is unavailable`, plus an assertion that `hasAccessCalls` stays empty on 401); `deno test speech-analyze/` failed to type-check with `TS2353: 'hasAccess' does not exist in type 'SpeechAnalyzeDeps'` (4 errors) before any implementation existed.
  - GREEN: extracted Groq transcribe/evaluate calls into new `supabase/functions/speech-analyze/groq.ts` (`createGroqProvider(apiKey, { timeoutMs })`), added `hasAccess(userId): Promise<boolean>` to `SpeechAnalyzeDeps`, inserted the check in `handler.ts` right after the 401 check and before body parsing (`!hasAccess` → 403 `access_required`; throw → 503 `access_unavailable`), implemented `hasAccess` in `index.ts` via `admin.rpc("has_access", { uid })` (throws on RPC error or non-boolean `data`), set `local.ts`'s dev harness to `hasAccess: () => Promise.resolve(true)`, and added `access_required`/`access_unavailable` to `_shared/http.ts`'s `ErrorCode` union.
  - `cd supabase/functions && deno task ci`: **88 passed, 0 failed** (fmt/lint/check/test all green; up from the pre-existing 86 — the 2 new access-gate cases plus the existing "unauthenticated" test now also asserts `hasAccessCalls.length === 0`). The pre-existing upstream Groq 429 `rate_limited` test still passes unchanged and distinct from the new codes.
  - Deviation: the `groq.ts` extraction unifies the coaching system prompt text between `index.ts` (production) and `local.ts` (dev harness) — they previously differed slightly in wording, and `local.ts` also lacked the per-field coaching validation and used a fixed `speech.wav` filename regardless of mime type. Extraction now gives `local.ts` the same (stricter, production) behavior. This is a dev-only harness with no automated coverage either way, so it does not affect any test result; flagging it because the task asked for "no behavior change" and this is a small one, confined to the manual dev-run path.
- [x] **A02 — Client failure mapping.** Route: same writer. Acceptance: Supabase and HTTP analysis repositories map 403/503 bodies to `SpeechAnalysisFailure` codes; `failure_messages.dart` stays exhaustive; Spanish copy in `app_es.arb`.
  - RED observed: added 4 cases to `speech_analysis_repository_test.dart` (Supabase 403/503, Http 403/503) asserting `result.failureOrNull == SpeechAnalysisFailure(...)`; `flutter test test/features/speaking/data/speech_analysis_repository_test.dart` failed to compile with `Undefined name 'SpeechAnalysisErrorCode'` / `Couldn't find constructor 'SpeechAnalysisFailure'` before any implementation existed.
  - GREEN: added `SpeechAnalysisErrorCode {accessRequired, accessUnavailable, dailyLimitReached, rateLimited, unknown}` and `SpeechAnalysisFailure` to the sealed `Failure` hierarchy (`failure.dart`); added `speech_analysis_error_mapper.dart` (`mapSpeechAnalysisErrorCode`, `readSpeechAnalysisErrorCode`) shared by both repositories; `SupabaseSpeechAnalysisRepository` now catches `FunctionException` (mapping its `details.error.code`) before the generic `mapDataError` fallback, with `FunctionsFetchException` (transport-level, no response) still routed through `mapDataError`; `HttpSpeechAnalysisRepository`'s non-200 branch now decodes the body and maps its `error.code` instead of always returning `UnexpectedFailure('speech_$status')`; added the `SpeechAnalysisFailure` case to `failure_messages.dart` (exhaustive) and 4 new keys to `app_es.arb` (`speechAnalysisAccessRequired`, `speechAnalysisAccessUnavailable`, `speechAnalysisDailyLimitReached`, `speechAnalysisRateLimited`), then ran `flutter gen-l10n`.
  - Deviation (scoped down from the raw task list, per the writer's explicit delegation instructions to "keep it minimal and justified"): the enum omits `noSpeech`/`invalidAudio`/`upstream` that the original Engram task note (#431 U1.7) listed — those server codes (`no_speech`, `invalid_audio`, `upstream_error`) are not part of this unit's required behavior (403/503/429 are), so leaving them unmapped would mean untested, unreachable switch branches. Any such code today falls through to `SpeechAnalysisErrorCode.unknown` → `l10n.errorUnexpected`, which is safe and correct, just less specific. `dailyLimitReached` is kept (server code doesn't exist until U19, but the design/tasks explicitly named it and `failure_messages.dart` needs it to stay exhaustive once U19 adds the 429 `daily_limit_reached` code).
  - `cd app`: `dart format --set-exit-if-changed lib test integration_test` → 0 changed (clean); `flutter analyze && dart analyze` → **No issues found!** (both); `flutter test` → **All tests passed! (1170 tests)**; `flutter test integration_test -d flutter-tester` → **All tests passed! (1 test)**.
- `git diff --check` (repo root): clean, no whitespace errors.

## Authored changed lines

From `git diff --numstat` (tracked files) + `wc -l` on the 2 new files, additions+deletions, no generated files touched (`*.g.dart`/`*.freezed.dart`/`lib/core/l10n/gen/**` regenerated locally but not committed, per repo convention):

| File | +/- |
|---|---|
| `app/lib/core/error/failure.dart` | 25/0 |
| `app/lib/core/l10n/app_es.arb` | 5/1 |
| `app/lib/core/l10n/failure_messages.dart` | 10/0 |
| `app/lib/features/speaking/data/http_speech_analysis_repository.dart` | 5/1 |
| `app/lib/features/speaking/data/supabase_speech_analysis_repository.dart` | 9/0 |
| `app/lib/features/speaking/data/speech_analysis_error_mapper.dart` (new) | 23/0 |
| `app/test/features/speaking/data/speech_analysis_repository_test.dart` | 131/0 |
| `supabase/functions/_shared/http.ts` | 2/0 |
| `supabase/functions/speech-analyze/handler.ts` | 20/0 |
| `supabase/functions/speech-analyze/handler_test.ts` | 36/5 |
| `supabase/functions/speech-analyze/index.ts` | 12/82 |
| `supabase/functions/speech-analyze/local.ts` | 6/69 |
| `supabase/functions/speech-analyze/groq.ts` (new) | 97/0 |

**Total: 539 authored changed lines.** This exceeds the ~350 advisory forecast, mainly because the `groq.ts` extraction (U1.2, explicitly in scope) counts as a full deletion in `index.ts`/`local.ts` (151 lines) plus a full addition in the new file (97 lines) for code that moved rather than grew — the heuristic is advisory, not a cap, per AGENTS.md/ODD rules, and no test or doc was cut to fit it.

## Progress and next step

A01 and A02 done, all closure checks green. Work-unit commit: `c91a771` on `fix/speech-analyze-access-gate`.

Parent verification: reviewed the handler diff (access check runs after the 401 check and before body parsing; RPC error or non-boolean result fails closed with 503) and repeated `cd supabase/functions && deno task ci` → 88 passed, 0 failed.

Review: receipt-driven development is off (global), so no native review ran. `gentle-ai review assess --base-ref dae83a3 --committed-only` reported risk `medium` (595 changed lines incl. the feature document, `review_due_reason: slice_budget_reached`); per the RDD-off tier, writer self-verification plus the parent spot check apply.

Delivery note: the diff is above the ~400-line PR budget, mostly because of the `groq.ts` extraction (moved code). Next step: the user decides push/PR for this branch; U2 waits until the SDD dispatcher/store mismatch is resolved.
