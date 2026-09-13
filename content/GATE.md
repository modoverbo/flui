# The adversarial gate

Content is written by agents and there is no human linguistic reviewer, so the
validators cannot be the only check. The validators prove a word file is
*well formed*. The gate proves each exercise has **exactly one defensible
answer** — the one thing a static rule cannot decide.

The gate is a blind dual review. Two independent reviewing agents answer the
same eight items with the options in different orders and the answer withheld.
A word passes only if both of them answer all eight correctly.

## Why two passes with different orderings

One pass tells you a reviewer agreed with you. Two passes with different
option orders separate "the sentence forces this answer" from "the reviewer
picked the first plausible option". If the two passes disagree, the item is
ambiguous, not the reviewer.

---

## 1. Prepare

```bash
cd content
dart run content:gate-prepare --word <slug>          # or --status validated
```

For each word this writes two files into `content/gate/`:

```
gate/<slug>.pass-a.json
gate/<slug>.pass-b.json
```

Each file is a self-contained task pack:

```jsonc
{
  "schema_version": 1,
  "word": "perspicaz",
  "pass": "a",
  "instructions": "Elige la única opción que encaja en el hueco {{blank}} …",
  "response_format": { … },
  "tasks": [
    {
      "exercise": 1,
      "sentence": "Andrés confía plenamente en su equipo, pero es tan {{blank}} que …",
      "hint": "La palabra describe a alguien que capta rápido lo que no es evidente.",
      "options": [
        { "id": "7b8e12", "text": "perspicuo" },
        { "id": "4a1c05", "text": "suspicaz" },
        { "id": "9f2d33", "text": "perspicaz" }
      ]
    }
  ]
}
```

What the pack deliberately does **not** contain: `is_correct`, `why_not`,
`hint_specific`, the exercise `explanation`, the word's own `explanation`, or
anything else that would reveal the answer. The option `id` is a hash of the
option text, so there is no answer key sitting next to the task file — the
scorer recomputes it from the word file.

The two passes contain the same options in a different, deterministic order.
The same word and pass always produce the same file, so the packs are
reproducible and diffable.

## 2. Review

Hand `pass-a.json` to one agent and `pass-b.json` to a **different** one. They
must not see the word file, the other pass, or each other's answers.

The reviewer answers with exactly this shape:

```json
{
  "pass": "a",
  "reviewer": "reviewer-a",
  "answers": {
    "perspicaz": [
      { "exercise": 1, "choice": "9f2d33", "ambiguous": false },
      { "exercise": 2, "choice": "1c40ab", "ambiguous": false }
    ]
  }
}
```

`ambiguous: true` means "two options fit here". That fails the item even when
the choice is the intended one — an ambiguous cloze is a broken cloze.

One results file may carry several words, so a reviewer can take a whole batch
in one go.

## 3. Apply

```bash
dart run content:gate-apply --results gate/results-a.json --results gate/results-b.json
```

For each word:

- **Both passes perfect** → `status` becomes `gated` in
  `content/words/<slug>.yml`, and `provenance.gate` records both reviewer ids
  and the date.
- **Anything else** → the word file is untouched and
  `content/gate/<slug>.failures.json` gets one precise reason per problem:

```
FAILED  perspicaz
        exercise 3: pass b (reviewer-b) chose "sagaz" (near_synonym) instead of
        "perspicaz" — the sentence does not force a single answer, or the
        distractor is too defensible
```

The command exits non-zero when any word failed. `--dry-run` reports without
writing.

## 4. What to do with a failure

Rewrite the **exercise**, not the reviewer.

| Reason | Fix |
|---|---|
| Reviewer chose a `near_synonym` | Add evidence to the sentence that rules it out, or replace the distractor |
| Reviewer chose a `register` distractor | The scene is not clearly formal/informal enough; make the setting explicit |
| Reviewer chose a `paronym` | The sentence does not contrast the two meanings; add the clause that does |
| `ambiguous: true` | Two readings are genuinely open; narrow the context |
| "did not answer" | The reviewer's output was incomplete; rerun that pass |

Then re-run `content:validate --word <slug>` and prepare the gate again. The
task packs are regenerated from the edited file, so the reviewers see the new
sentence with a fresh ordering.

## Status lifecycle

```
draft  ──content:validate passes──▶  validated
       ──content:gate-apply, both passes clean──▶  gated
       ──human sign-off──▶  approved  ──content:emit──▶  supabase/seed.sql
```

`content:emit` only ever writes words with `status: approved`, so nothing
reaches the database before it has been through both halves of the system.
