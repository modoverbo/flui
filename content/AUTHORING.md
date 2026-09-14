# Authoring brief — one flui word, one pass

You are writing **one** file: `content/words/<slug>.yml`. Spanish content,
English nothing. When you are done, run

```bash
cd content && dart run content:validate --word <slug>
```

and fix whatever it prints. The validators are the whole quality system: there
is no human linguistic reviewer downstream, so a rule here is a hard rule.

Two complete, validated reference files are checked in. **Open one before you
start and copy its shape:**

- `content/examples/perspicaz.yml` — an adjective, invariable in gender.
- `content/examples/matizar.yml` — a verb, so the blank takes conjugated forms.

---

## 1. What a flui word is

flui replaces a vague word the reader already says with a precise one they
already half-recognize. A word earns a place only if **all** of these hold
(docs/learning-method.md §8):

1. Useful in three or more everyday areas (work, social, interviews, family).
2. It replaces a frequent vague word or filler ("cosa", "tema", "hacer",
   "muy bueno").
3. Mid-frequency: the reader recognizes it but rarely says it.
4. Pan-Hispanic, or the regional variants are documented.
5. `pedantry_risk` ≤ 2. A word that sounds affected ("solaz", "inexorable")
   is out.
6. Explainable with common words.

`content/data/candidates.csv` ranks candidates by exactly these properties
(`score`, `zipf`, `dp`, `pedantry_proxy`, `comodin_leverage`). When you are
given a theme instead of a word, do not read the CSV by hand — ask for the
candidates that are still free:

```bash
dart run content:shortlist --theme reuniones --limit 20
```

That list is already clear of every catalog clash: no duplicate lemma, no
family member of an existing word, no paronym of one, no semantic-set collision.

If you want to propose a word that is **not** in the pool, justify it with the
corpus instead of asserting it:

```bash
dart run content:metrics --lemma vislumbrar
```

It prints Zipf, dispersion across the 17 country subcorpora, the pedantry
proxy, family size and the flags, for any lemma the corpus contains — and says
so plainly when it contains none. A word the corpus has never seen is not
automatically wrong, but you have no evidence for criteria 3 and 4, so say so
in the pull request rather than inventing numbers.

---

## 2. The file, field by field

Full machine-readable shape: `content/schema/word.schema.json`.

| Field | Rule |
|---|---|
| `schema_version` | always `1` |
| `slug` | kebab-case, **equal to the normalized lemma**; the file must be `<slug>.yml` |
| `status` | `draft` while you write. The gate sets `gated`; a human sets `approved` |
| `lemma` | the dictionary form |
| `part_of_speech` | `adjetivo` · `adverbio` · `conector` · `sustantivo` · `verbo` |
| `syllables` | in order; they must concatenate to the lemma (accents ignored) |
| `stressed_syllable` | 1-based index into `syllables` |
| `ipa_latam` / `ipa_es` | seseo and distinción variants, in brackets |
| `explanation` | **≤ 20 words**, original, common vocabulary, and it must **not** contain the word or any family member |
| `example_sentence` | one natural adult situation |
| `register` | `neutral` · `culto` · `coloquial` |
| `pedantry_risk` | 1 natural … 3 affected. Only 1–2 can ever reach `approved` |
| `usage_tip` | when it lands well |
| `when_not_to_use` | the trap, usually the paronym |
| `collocations` | what it actually combines with |
| `replaces` | **≥ 2** `{before, after}` pairs. `after` must use the word, `before` must not. This is the heart of the product |
| `family` | derivations (`perspicacia`, `perspicazmente`) |
| `themes` | 1–3 entries from `content/themes.yml`, each with `relevance` 1–3 |
| `tags` | `comodin` (what it displaces) · `funcion` · `canal` (`hablado`/`escrito`/`ambos`) · `formalidad` · `variedad` |
| `confusions` | ≥ 1 `{confused_with, difference, memory_trick}`; at least one needs the trick. Never point at the word itself |
| `exercises` | **exactly 8** — see §3 |
| `readings` | **exactly 3** — see §4 |
| `metrics` | **never write this by hand.** `content:corpus` computes it |
| `provenance` | `generator`, `gate`, `checked_on` |

---

## 3. The eight exercises

Eight cloze items, `position` 1…8, each a **new situation**. One `{{blank}}`
per sentence, three options, exactly one correct.

### Distractor budget across the eight

- **≥ 1 `paronym`** — looks or sounds alike, means something else
  (perspicaz / suspicaz, matizar / atizar).
- **≥ 1 `register`** — right meaning, wrong register in *this* scene
  ("finiquitar" at a family lunch, "metiche" as praise).
- `near_synonym` fills the rest — close, but the sentence rules it out.

A good spread is roughly 4 paronym, 2–3 register, 5–6 near_synonym slots across
the sixteen distractors.

### Per option

```yaml
- position: 1
  text: "suspicaz"
  is_correct: false
  distractor_type: "paronym"       # correct option: omit all three
  why_not: "…"                     # declarative: why it fails *in this sentence*
  hint_specific: "…"               # a nudge, never the answer, ≤ 25 words
```

The correct option carries **only** `position`, `text`, `is_correct: true`.

### How the hints escalate

| Moment | Field | Job |
|---|---|---|
| First wrong answer | `hint_general` | points at the **meaning**, ≤ 25 words |
| Second wrong answer | `hint_specific` of the option just chosen | contrasts *that* distractor with the sentence |
| After it resolves | `explanation` | names the answer and why **each** distractor fails |

A hint never mentions spelling: no "empieza por", no "se escribe con", no
quoted letter. Point at meaning and at the evidence already in the sentence
("Relee el inicio: no desconfía de nadie").

### What the exercise `explanation` must contain

All three option texts, spelled **exactly as the options spell them**, plus why
the answer wins. The validator checks the three strings literally.

### The sentence

- One defensible answer. If a distractor also fits, the item is broken — the
  adversarial gate (§6) will catch it and you will rewrite it.
- **No leakage**: the lemma, any family member, or their stem must not appear
  in the sentence or in `hint_general`. For a verb the stem drops the
  infinitive ending, so `zanjar` also blocks `zanjemos`.
- Never use a distractor that is one of your own `collocations` or `family`.
- Vary the openings: at most **two** of the eight sentences may start with the
  same three words.
- Vary the people: use a different name in each sentence. No name may carry
  more than 15 % of the library's sentences.
- Agreement: substitute the answer into the blank and read it. "una pregunta
  tan perspicuo" fails; "Nosotros planteó" fails.

---

## 4. The three readings

Three short scenes, `position` 1…3:

- **distinct `scene`** from `trabajo` · `social` · `entrevista` · `familia`
- **≥ 2 distinct `conversation_type`** from `practica` · `emocional` · `social`
- `title`, `body` (3–5 sentences, dialogue welcome)
- `before_phrase` → `after_phrase`: what the reader used to say, and the line
  they can say now. Keep them short enough to be quoted in the UI.

Readings are fiction, so a character may use "usted". The instructional copy
around them may not.

---

## 5. Voice, and what is banned

flui is warm, direct, adult. Short sentences. It celebrates progress and never
shames a mistake ("Casi.", never "Incorrecto.").

**Never write these words** (docs/brand.md): `lección`, `examen`, `alumno`,
`profesor`, `tarea`, `calificación`, `gramática`, `memorización`, `evaluación`,
`incorrecto`, and the registered `#SinMuletillas`. Do not use "error" as a
verdict ("eso es un error"); "el error de las cifras" as an ordinary noun is
fine.

**Address the reader as "tú".** Never "usted" or "vosotros" in instructional
copy; never a `vosotros` verb (`sabéis`, `habláis`) anywhere.

**Pan-Hispanic only.** Blocked with their country tag: `platicar`, `padrísimo`
(mx) · `chévere` (ve/co) · `guay`, `curro`, `currar`, `ordenador` (es) ·
`laburo`, `laburar` (ar) · voseo (`vos`, `sos`, `tenés`, `querés`, `podés`,
`hacés`, `decís`, `sabés`, `andá`, `mirá`, `vení`, `contá`, `pensá`). Do not
mix `ordenador` and `computadora` across the library.

**Stay off these topics entirely**: politics, religion, immigration, illness and
death, sex, violence, named real people or companies, salary shaming, national
stereotypes. Scenes are ordinary adult life: a meeting, a move, a dinner, an
interview.

**Spanish typography**: `« »` for quotes (never `"` or `'`), opening `¿` and `¡`
for every `?` and `!`, no double spaces, no space before `, . ; : ! ?`.
`20 %` with a space is correct.

---

## 6. Before you hand the file over

```bash
cd content
dart run content:validate --word <slug>     # must exit 0
```

The report prints `blocking` and `warn` lines with the exact field path. Fix
every `blocking` line. A frequent one is `common_vocabulary`: every content
word of your `explanation` must be in `content/data/common_lemmas_es.txt`
(the top-5000 Spanish lemmas, accent-folded). If a word is not there, it is not
common enough for a definition — pick a plainer one.

`dart run content:validate --list` prints every rule and whether it blocks.

After that, the word goes through the blind dual review in
[GATE.md](GATE.md), which is what turns `status: draft` into `status: gated`.
