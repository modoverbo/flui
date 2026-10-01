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
| `themes` | 1–3 entries from `content/themes.yml` — see §2b |
| `semantic_set_id` | kebab-case, or omitted — see §2c |
| `tags` | `comodin` (what it displaces) · `funcion` · `canal` (`hablado`/`escrito`/`ambos`) · `formalidad` · `variedad` |
| `confusions` | ≥ 1 `{confused_with, difference, memory_trick}`; at least one needs the trick. Never point at the word itself — see §2d |
| `exercises` | **exactly 8 when you author it** — see §3 |
| `readings` | **exactly 3** — see §4 |
| `metrics` | **never write this by hand.** `content:corpus` computes it |
| `provenance` | `generator`, `gate`, `checked_on` |

### 2b. `themes`

One to three entries, each `{slug, relevance}`, taken from
`content/themes.yml`. The slug must exist there; nothing else is accepted.

| `relevance` | Means |
|---|---|
| **3** | The word **is** the theme. Someone who picked this theme came for exactly this word. At most one or two per word |
| **2** | Clearly useful inside the theme, but not what the theme is about |
| **1** | Adjacent. It would not be wrong to meet this word here, but nobody picked the theme for it |

A theme decides which *new* word the planner may introduce; it never touches
the review queue. So a word with three honest themes is reachable from three
entry points, and a word with three optimistic 3s is noise in all of them.
Rank them: put the 3 first.

`dart run content:emit` turns these entries into the `word_themes` rows, so the
YAML file is the only place they are written.

### 2c. `semantic_set_id`

Set it **only** for a genuine synonym, antonym or category-mate group — words
that are the same kind of thing and would interfere if taught together.
Tinkham (1993, 1997) and Nation (2000) found exactly that cluster slows
learning down; two words sharing an id are never introduced within 7 days of
each other.

The eight starter words contain exactly one such group:

```yaml
semantic_set_id: "fuerza-de-la-afirmacion"   # contundente <-> matizar
```

`contundente` reinforces an assertion, `matizar` softens it: two ends of one
axis, so they are the same kind of word.

**Leave it out otherwise.** Sharing a theme is *not* a semantic set —
a thematic cluster is the arrangement the same research found harmless, and
`plantear`, `concretar` and `pertinente` all live in `reuniones` without
interfering. Setting the id because two words feel related costs you a 7-day
block between them for nothing.

An id is kebab-case and names the axis, not the words:
`fuerza-de-la-afirmacion`, not `contundente-matizar`.

### 2d. `confusions`

At least one `{confused_with, difference, memory_trick}`; one of them must
carry the trick. `confused_with` is the word as a reader would write it,
accents included. Most of them are words flui never teaches, and that is
normal: a paronym is usually outside the catalog.

**When the confusable word *is* in the catalog, both files declare the pair.**
If `talante.yml` names `tajante`, then `tajante.yml` names `talante`, in its
own words — same pair, different explanation, written from that word's side.
This is not bookkeeping:

- The interference rule of learning-method §7 is declaration-driven. Two words
  are confusable because a file says so, and the planner keeps them 6 days
  apart for it. A pair only one file declares still works — until that one file
  is edited, and then the protection disappears with nothing failing.
- `dart run content:emit` resolves `confused_with` against the catalog — by
  lemma or by a `family` member, ignoring case and accents — and writes
  `word_confusions.confused_word_id`. That column is what the app matches on
  first, so a link survives a renamed lemma or a re-slugged word.

`confusion_symmetry` is blocking and runs over the whole library
(`dart run content:validate --all`), so a one-sided pair cannot ship. It says
nothing when you self-check one file with `--word <slug>`: the other side is
not loaded. `dart run content:stats` prints how many confusions reach a catalog
word and how many pairs are still one-directional.

When you add a confusion that names a word already in `content/words/`, open
that file and add the mirror entry. Never point at the word itself, not even
through one of its own `family` members.

---

## 3. The eight exercises

Eight cloze items, `position` 1…8, each a **new situation**. One `{{blank}}`
per sentence, three options, exactly one correct.

> **Author eight. Six is a floor, not a target.** The validator accepts 6–8
> because `content:prune` removes the items the adversarial gate found
> ambiguous (GATE.md §4), and a word with six verified exercises is worth more
> than one with eight where two are broken. A word that *arrives* with seven
> has simply been written short: the review queue is what earns a lower count,
> never the first draft.

### Distractor budget across the eight

- **≥ 1 `paronym`** — looks or sounds alike, means something else
  (perspicaz / suspicaz, matizar / atizar).
- **≥ 1 `register`** — right meaning, wrong register in *this* scene
  ("finiquitar" at a family lunch, "metiche" as praise).
- `near_synonym` fills the rest — close, but the sentence rules it out.

A good spread is roughly 4 paronym, 2–3 register, 5–6 near_synonym slots across
the sixteen distractors.

**Never leave `register` on a single exercise.** It is the type the gate flags
most often — "right meaning, wrong register" is a judgement call, and a
reviewer who disagrees is not wrong. When the only `register` distractor sits
in the item the gate rejects, `content:prune` has to refuse and the word goes
back to authoring. Two register slots in two different exercises is what makes
a word survivable.

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
| First wrong answer | `hint_general` | points at the **meaning**, ≤ 24 words |
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
- Vary the openings: at most **two** sentences of a word may start with the
  same three words.
- Vary the people: use a different name in each sentence. No name may carry
  more than 15 % of the library's sentences.
- Agreement: substitute the answer into the blank and read it. "una pregunta
  tan perspicuo" fails; "Nosotros planteó" fails.

### Distractors that look fine and are not

The rule underneath every item: **an exercise must be answerable only by
knowing what the word means.** Six ways an item passes the validators, and
sometimes even the gate, while breaking that rule. Round 3 dropped thirteen
words to (a)-(d); round 5 added (e) and (f) after losing words to the same
kind of mistake — a distractor with no sentence able to rule it out.

**(a) Orthographic noise.** The distractor differs from the answer by a letter
and means something unrelated, so the reader solves the item by reading
carefully, not by knowing the word. All eight items of `gesto` pitted it
against `gasto`; `dominio` ran on `domicilio` / `domingo`, `oficio` on
`orificio` / `edificio`. A paronym earns its slot when the two words are
*plausible in the same sentence* (perspicaz / suspicaz) — not when only one of
them makes any sense at all.

**(b) Syntactic giveaway.** The grammar picks the answer before the meaning
does. Every `contrariamente` stem ended "___ a lo que…", and of the three
options only the target takes that *a* — the reader matches the preposition and
never reads the clause. `renunciar` failed the same way: "___ a" decided all of
it. Check it by blanking the meaning out: if you can still answer from the
function words around the gap, the item is broken.

**(c) A "wrong spelling" that is not wrong.** `asimismo` set its items against
`así mismo`, but the RAE accepts "así mismo" in two words for that same
meaning. The contrast the item asks the reader to make does not exist, so the
"correct" answer is only correct by our say-so. Before you build an item on a
spelling contrast, confirm the variant is actually rejected — not merely less
common.

**(d) The word is already everyday vocabulary.** Above roughly **Zipf 5.0** the
reader says the word daily, so every item is trivial no matter how the
distractors are built: `sino` (5.75), `asimismo` (5.40), `finalmente` (5.26),
`tampoco` (5.20), `salvo` (5.09), `apenas` (5.05). This is criterion 3 of §1
("recognizes it but rarely says it") failing late, at the exercise, where it is
expensive. Run `content:metrics --lemma <word>` before you write eight items,
not after.

**(e) Dictionary-circular distractor.** The distractor is a word a dictionary
defines *using* the target — so no sentence can separate them, because the two
words mean the same thing by definition, not just in this context. `eco` and
`resonancia` are both defined via `repercusión`; `subterfugio` is defined via
`pretexto`; `revoltoso` is defined via `travieso`. Check the distractor against
a dictionary entry for the target *before* you write the sentence: if the
definition of one names the other, no amount of context will make the item
answerable, and rewriting it a second time only teaches you that.

**(f) A hint that contains a distractor.** `desvelo`'s `hint_general` used the
word "cuidado" as a generic gloss for the meaning, while "cuidado" was also one
of the options in that exercise — the hint told the reader the answer wasn't
worth picking. Three reviewers flagged the same three items for it. Unlike
(a)-(e), this one a validator now catches: `hint_option_leakage` blocks any
`hint_general` or `hint_specific` that names an option it should not (§6).

None of (a)-(e) is caught by a validator, and the gate only catches them by
accident — reviewers answer these items correctly, because they *are*
answerable. They are answerable for the wrong reason, which is the thing you
have to check yourself.

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
