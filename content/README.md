# content — the flui authoring toolkit

Words are authored as YAML in `content/words/`, checked by a validator suite,
put through a blind dual review, and emitted as `supabase/seed.sql`.

Content is written by LLM agents and there is no human linguistic reviewer, so
**the validators and the adversarial gate are the entire quality system**. They
are strict on purpose.

```
content/
  words/<slug>.yml        the catalog — the source of truth
  examples/               two complete reference words (validated in CI)
  themes.yml              the 16 launch themes
  schema/word.schema.json the file shape
  data/                   candidates.csv, common_lemmas_es.txt, LICENSES.md
  templates/              the seed preamble kept verbatim by the emitter
  AUTHORING.md            the brief an authoring agent follows
  GATE.md                 the blind dual review
```

## Commands

Run them from `content/`.

| Command | What it does |
|---|---|
| `dart run content:validate [--word <slug>] [--all] [--json]` | Runs the whole suite. Exits non-zero on any blocking failure. `--list` prints every rule. `--probe-rae --network` adds the opt-in originality probe |
| `dart run content:emit --out ../supabase/seed.sql` | Deterministic SQL for every `status: approved` word. `--check` fails when the target is stale, `--stdout` prints instead of writing |
| `dart run content:import --from ../supabase/seed.sql` | One-shot converter from the hand-written seed into word files. Already run |
| `dart run content:stats [--json]` | Counts by theme, part of speech and status, exercises per word, days of content, coverage gaps |
| `dart run content:corpus [--offline]` | Rebuilds `data/candidates.csv`, `data/common_lemmas_es.txt` and `data/lexemes_es.tsv` from the Leipzig Corpora Collection and Wikidata Lexemes |
| `dart run content:metrics --lemma <x> [--json] [--evidence]` | Zipf, dispersion, pedantry proxy, family size and flags for **any** lemma in the cached corpus, not only the 1500 in the CSV. Says so plainly when the corpus has never seen it |
| `dart run content:shortlist --theme <slug> [--limit <n>]` | Candidates for one theme, already clear of duplicate-lemma, paronym and semantic-set clashes with the current library. `--all-themes` prints the count per theme |
| `dart run content:gate-prepare [--word <slug>]` | Two blind task packs per word, answers withheld |
| `dart run content:gate-apply --results <file>` | Scores the reviewers and flips `status` to `gated`, or writes precise failure reasons |

## The validator suite

31 validators. `dart run content:validate --list` prints them with their
severity; the source of truth is `lib/src/validation/registry.dart`.

| Group | Rules |
|---|---|
| Schema | `schema` conformance, `file_name` matches `slug`, `model` readability |
| Structural | `slug_matches_lemma` · `syllables` · `exercise_count` · `option_set` · `distractor_fields` · `distractor_type_coverage` · `reading_set` · `confusions` · `replaces` |
| Linguistic | `agreement` · `distractor_overlap` · `answer_leakage` · `hint_cue` · `length_caps` · `explanation_coverage` · `explanation_circularity` · `common_vocabulary` |
| Brand and safety | `banned_words` · `second_person` · `regional_blocklist` · `sensitive_topic` · `typography` |
| Catalog | `themes` · `pedantry_gate` · `duplicate_lemma` · `scheduling_simulation` |
| Library text | `sentence_uniqueness` · `template_diversity` · `name_diversity` |
| Originality | `rae_probe` (opt-in, `--probe-rae`) |

Every rule blocks. `common_vocabulary` is the only one that can downgrade
itself to a warning, and only while `data/common_lemmas_es.txt` is missing.

`scheduling_simulation` is a catalog-scale gate: it replays 90 days of the
session planner per theme under the paronym rule (learning-method §7) and a
semantic-set rule, and fails when a theme would run out of eligible words.
`--word <slug>` turns it off so an authoring agent can check one file.

## How the candidate pool is filtered

Four gates run **before** anything is scored, so noise is dropped rather than
ranked:

1. **Shape** — function word, too short, an inflected form rather than a lemma,
   a spelling Spanish orthography does not produce.
2. **Dictionary** — the lemma must appear in `data/lexemes_es.tsv` (Wikidata
   Lexemes, CC0) *and* be morphologically consistent with the category the
   dictionary gives it. This is what keeps `desir`, `servier` and `heliar` out.
3. **Country attestation** — pan-Hispanic is a selection criterion, so a form
   no country subcorpus attests cannot be judged.
4. **Domain** — the candidate's company, measured from Leipzig's same-sentence
   co-occurrence, must be positively abstract rather than physical. This is
   what keeps `frotar`, `masticar` and `regar` out.

What survives is then ranked. `comodin_leverage` is the substitutability
signal: Leipzig's **immediate-neighbour** table says which words take the same
neighbours as `hacer`, `poner`, `dar`, `decir`, `tener`, `cosa`, `tema`, and a
candidate's leverage is its rank inside that set. It is a rank, not a raw
share, because a raw share saturates — every frequent word keeps company with
everything.

`suggested_themes` is evidence too: a theme appears only when the candidate
keeps that theme's vocabulary at least 4x more than the average candidate
does, and no theme may own more than 15 % of the pool. Around 60 % of rows
carry no theme, which is the honest answer when the evidence does not support
one.

**Limits, stated plainly.** Sentence co-occurrence is a topical signal, not a
dependency parse: it cannot prove a shared syntactic *slot*, only a shared
context, and the neighbour table only approximates the slot through adjacency.
The seed lexicons in `lib/src/corpus/domain_seeds.dart` are markers, not a
taxonomy. Residual noise survives at the edges — trade and medical nouns such
as `albañil` still clear the abstract gate. The column is a ranked suggestion
an author checks, never an authority.

## The seed round trip

`content:emit` reproduces `supabase/seed.sql` **byte for byte** from the word
files, so the generated fake-backend fixture never moves:

```bash
cd content && dart run content:emit --out /tmp/seed.sql && cmp /tmp/seed.sql ../supabase/seed.sql
cd ../app  && dart run tool/seed_fixture_check.dart --seed /tmp/seed.sql
```

`test/sql/round_trip_test.dart` asserts the same thing on every `dart test`.

## Developing

```bash
dart pub get
dart analyze --fatal-infos
dart test
```
