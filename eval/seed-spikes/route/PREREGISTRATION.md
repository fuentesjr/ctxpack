# Route-seed viability spike — pre-registration (double-gated)

**Status:** Frozen before measurement (2026-07-14) after advisor review
(four corrections applied: symmetric arm-success predicate; generalized
stub exclusion per population; helper variant demoted from the resolution
gate; margin rationale stated).
**Source:** `docs/seed-based-interface-proposal.md` §3 (route row: "Resolve
via Rails router or cache → then apply anchor or method recipe") + §11
Phase 5; `docs/anchor-acquisition-proposal.md` §12a (Front B gate: route
resolution ships only if it beats the ritual-only baseline by a
pre-registered margin); user decision 2026-07-14: the baseline is scored
**offline/analytically**, no agent sessions.

## Questions

1. **Resolution (§3.3 gate):** given route evidence (helper name, concrete
   path, or `VERB /path`), how often does a deterministic cache resolver
   find the unique correct `controller#action`?
2. **Front B margin gate:** does that resolver beat the "ritual-only"
   baseline — an agent grepping `bin/rails routes` output itself — by the
   pre-registered margin on the same population?

Both gates must pass to ship `--from-route`. Failing either leaves route
evidence **coaching-only** (CLI-17c guidance) — a valid, recorded outcome.

## Apps / SHAs / route corpus

Pinned Tier 0 apps and SHAs (Mastodon `163f96ce…` actionpack 8.1.3,
Discourse `28b003a3…` 8.0.5, Zammad `50384f4c…` 8.0.5). Evidence corpus:
**full route rows** (`helper`, `verb`, `path_spec`, `controller#action`)
extracted at those SHAs by the accepted no-boot Tier 0 extraction method
(`eval/tier0/extract_routes.rb`, extended to emit rows instead of pair
counts; same stub-world limitations recorded there — engine-mount
internals absent, env-conditional routes drawn as production). Extraction
is corpus construction and happens before freezing measurement; scoring
below is fixed now.

**Stub exclusion (per population):** a row enters a given evidence
population only if **every field that population's evidence and ground
truth uses** is free of `spike_stub_` tokens — stub-helper rows leave the
helper population; stub-contaminated `path_spec` rows leave the
path/verb+path populations (e.g. Zammad's `match api_path + '/tickets'`
draws as `spike_stub_N/tickets`); a stub-contaminated `controller#action`
excludes the row from everything. Internal routes only (rack/redirect/
engine-mount rows excluded). Exclusion counts reported per population.

## Evidence variants (population = each variant of each eligible row)

1. **helper** — `<helper>_path` (rows with a real helper).
2. **verb+path** — `VERB /concrete/path`: `:param` segments filled with
   `1`, `*glob` with `x`, optional-format suffix dropped.
3. **path** — the same concrete path, no verb.

## Resolver under test (fixed before scoring)

Deterministic cache resolver over the extracted table:

- helper evidence: strip `_path`/`_url`; exact helper-name lookup.
- path evidence: segment-wise match against `path_spec` (static segments
  equal; dynamic `:param` matches any single non-slash token; `*glob`
  matches a non-empty remainder; trailing `(.:format)` optional); verb
  filters when given.
- **Arm success (symmetric, both arms):** the arm's candidate set is
  non-empty AND every candidate maps to the source row's
  `controller#action`. The resolver's candidates are its matched rows; the
  ritual's candidates are its grep hits. Pair identity is what feeds the
  anchor recipe, so row multiplicity within one pair
  (`resolved_convergent`) is success in either arm. Anything else fails
  (`ambiguous_multi`, `no_match`, `wrong_match`).

## Ritual baseline (offline analytic, fixed before scoring)

Simulates `bin/rails routes -g TOKEN` + reading the output:

- TOKEN: helper evidence → the helper base (sans `_path`); path/verb+path
  evidence → the **last static segment** of the path (what a person greps).
- Grep = case-sensitive substring over rendered route lines
  (`helper verb path_spec controller#action`), mirroring Rails' `-g`.
- **Ritual success** uses the same symmetric predicate above (hits
  non-empty, all mapping to the correct pair). The ritual's hit-count
  distribution (zero-hit / wrong-unique / multi-hit-with-correct-present)
  is reported alongside, preserving the original steps-vs-dead-ends
  character as reporting while the gate stays binary.

## Metrics and gates (pre-registered)

| Metric | Definition | Gate |
|---|---|---|
| Resolution rate | per app: successes / population over **path + verb+path variants only** (the helper variant is same-table exact lookup — ~1.0 by construction — and would pad the gate); unweighted 3-app average | **≥ 70%** (standing bar) |
| Helper-variant rate | resolver success on helper evidence; expectation ≈ 1.0 | report-only |
| Front B margin | per app: resolver success rate − ritual success rate, **pooled over all three variants** (in production a helper resolves against a cache built from the same app, so same-table lookup is the product claim there; both arms see identical evidence); unweighted 3-app average of the difference | **≥ +10 points** |
| Per-variant rates | resolver + ritual rate per evidence variant; ritual hit-count distribution | report-only |
| Exclusions | per-population stub and non-internal row counts | report-only |

Margin rationale (stated so the number reads as chosen, not plucked): +10
points means the resolver removes the read-and-judge step for at least
1 in 10 inputs — a materiality margin in the same round-number discipline
as the standing 70% bar; population sizes (hundreds to thousands of rows)
make significance-style margins vacuous.

**Outcomes:**

- Both gates pass → ship `--from-route` resolving via a **documented cache**
  (committed/generated route table; the gem still never boots Rails —
  design.md's carve-out stays cache-first with the `bin/rails routes`
  ritual as the documented fallback), then applying the anchor recipe
  (SEED-13) to the resolved pair.
- Either gate fails → route evidence stays coaching-only; record and close
  5c. No renegotiation, no threshold shopping.

## Failure taxonomy (pre-registered labels)

`resolved_unique`, `resolved_convergent`, `ambiguous_multi`, `no_match`,
`wrong_match`, `crash` (+ per-variant breakdown).

## Explicit non-goals

- No agent sessions, no token spend on subject runs (user decision
  2026-07-14) — this is the offline analytic scoring of the Front B gate.
- Not evidence packets help agents; not a route-cache staleness policy eval
  (the ship spec must document staleness handling, but it is not scored
  here).
- No Rails boot in the shipped gem; extraction's bundler/inline actionpack
  is eval-side tooling only (same standing as Tier 0).
- Not CI-wired (EVAL-10).
