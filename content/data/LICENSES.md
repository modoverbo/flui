# Data sources and licences

Everything in `content/data/` is derived from openly licensed corpora. Nothing
here comes from the RAE: its legal notice forbids reproducing or extracting its
content for commercial use, so flui stores none of it (see
`docs/learning-method.md` § Legal and quality guardrails).

## Leipzig Corpora Collection — CC BY 4.0

`candidates.csv` and `common_lemmas_es.txt` are computed by
`dart run content:corpus` from word-frequency tables of the **Leipzig Corpora
Collection** Spanish packages.

> Leipzig Corpora Collection, Universität Leipzig. D. Goldhahn, T. Eckart,
> U. Quasthoff: *Building Large Monolingual Dictionaries at the Leipzig Corpora
> Collection: From 100 to 200 Languages.* Proceedings of LREC 2012.
> Downloads: <https://wortschatz.uni-leipzig.de/en/download>
> Licence: **Creative Commons Attribution 4.0 International (CC BY 4.0)** —
> <https://creativecommons.org/licenses/by/4.0/>

**The Leipzig web API is not used.** The API is CC BY-NC, which is incompatible
with a commercial product. Only the CC BY 4.0 download packages are fetched,
directly from `downloads.wortschatz-leipzig.de`.

### Packages used

Verified available on 2026-09-13. The exact list lives in
`lib/src/corpus/leipzig.dart` (`defaultPackages`).

| Role | Packages |
|---|---|
| Country subcorpora (17) | `spa-ar_web_2016_100K`, `spa-co_web_2015_100K`, `spa-cr_web_2015_100K`, `spa-cu_web_2015_100K`, `spa-do_web_2015_100K`, `spa-ec_web_2015_100K`, `spa-gt_web_2015_100K`, `spa-hn_web_2015_100K`, `spa-mx_web_2015_100K`, `spa-ni_web_2015_100K`, `spa-pa_web_2016_100K`, `spa-pe_web_2016_100K`, `spa-pr_web_2016_100K`, `spa-py_web_2016_100K`, `spa-sv_web_2016_100K`, `spa-uy_web_2016_100K`, `spa-ve_web_2016_100K` |
| Formal written mix | `spa_news_2023_100K`, `spa_wikipedia_2021_100K` |
| Open web mix | `spa_web_2016_100K` |

**Known gap:** Leipzig publishes no `spa-es`, `spa-cl` or `spa-bo` subcorpus,
so peninsular, Chilean and Bolivian Spanish reach the pool only through the
pan-Hispanic `spa_web` / `spa_news` mixes. The dispersion measure (Gries' DP)
therefore covers 17 countries, not 20, and a peninsular-only word can slip
through with a low DP. The regional blocklist in
`lib/src/validation/brand.dart` is the second line of defence for that case.

## How the metrics are computed

| Column | Method |
|---|---|
| `zipf` | `log10(frequency per billion tokens)` over all packages |
| `dp` | Gries' deviation of proportions across the 17 country subcorpora: `0.5 · Σ \|o_i − e_i\|` |
| `pedantry_proxy` | logistic of `log(formal per-million / web per-million)`. Leipzig has no Spanish **spoken** corpus, so this contrasts news+wikipedia against the open web. It is a written-register proxy, not a spoken one, and it is labelled as such |
| `family_size` | number of other lemmas sharing the same 5-character stem |
| `comodin_leverage` | Zipf gap between the lemma and the most frequent comodín of its part of speech, scaled to 0–1 |
| `suggested_themes` | stem lexicon + part-of-speech defaults. **Advisory**, always confirmed by the author |
| `score` | weighted blend: 0.34 mid-frequency fit · 0.22 spread · 0.18 plainness · 0.18 comodín leverage · 0.08 family |
| `flags` | `regional-only`, `paronym-of:<lemma>`, `semantic-set:<stem>` |

## Lemmatization

No tagger is bundled. spaCy's Spanish models are GPL-3.0 and cannot ship with
flui, so `lib/src/corpus/metrics.dart` folds surface forms onto base forms that
**the corpus itself attests**, using a short table of Spanish inflection
endings plus the z/c plural alternation (`matices → matiz`). A fold only
happens when the candidate base form is more frequent than the surface form, so
the mapping never invents a lemma.

## Fallback

`dart run content:corpus --offline` never invents a number. It reads
`content/data/editorial_fallback.txt` and writes those lemmas with every
numeric column empty and `metrics_pending=true`, so authoring can start while
the corpus is unavailable and no one mistakes an editorial guess for a measured
frequency.

## Not used

- **RAE / DLE / DPD** — reference only, never a data source, never stored.
- **Wiktionary and other CC BY-SA data** — ShareAlike is incompatible with the
  product licence (`docs/learning-method.md`).
- **Leipzig web API** — CC BY-NC.
