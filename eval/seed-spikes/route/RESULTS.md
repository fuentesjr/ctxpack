# Route-seed viability spike — results (double gate)

**Measured:** 2026-07-14, per the frozen `PREREGISTRATION.md`
(advisor-reviewed; symmetric arm predicate). Corpus:
`rows_{mastodon,discourse,zammad}.json` extracted at the pinned SHAs by
`extract_route_rows.rb` (the accepted no-boot Tier 0 method emitting full
rows). Scorer: `run_route_spike.rb`. Raw output under `results/`.

## Gate 1 — §3.3 resolution (path + verb+path pooled) — FAIL

| App | Path n | Verb+path n | Gated resolution |
|---|---|---|---|
| Mastodon | 743 | 742 | 0.487 |
| Discourse | 1,110 | 1,110 | 0.182 |
| Zammad | 34 | 34 | 0.059 |
| **Average** | | | **0.243 < 0.70 → FAIL** |

## Gate 2 — Front B margin (all variants pooled) — pass, moot

Average margin +0.124 ≥ +0.10 (Mastodon +0.328 / Discourse −0.092 /
Zammad +0.138). Both gates must pass; Gate 1's failure decides.

## Why it failed (taxonomy — genuine, not scorer artifact)

- **Bare path is inherently ambiguous under REST set-semantics:** the same
  concrete path maps to different actions across verbs (`GET/PUT/DELETE
  /accounts/1` → show/update/destroy), so `ambiguous_multi` covers
  essentially the whole bare-path population (Mastodon 742/742, Discourse
  1,109/1,110, Zammad 33/34; only `/` resolves unique). Every concrete path
  matched at least its own spec — `no_match` is zero, ruling out a matcher
  bug.
- **Verb+path splits by app convention:** Mastodon 720/742 (97%) unique —
  conventional REST resolves nearly perfectly with a verb; Discourse stays
  63% ambiguous even with verbs (many same-verb dynamic top-level specs
  like `/:slug` families that a constraint-free, order-free cache matcher
  cannot separate). The real Rails router disambiguates these by **route
  order and constraints** — a first-match, router-order-faithful resolver
  is the obvious candidate for any future re-spike (new pre-registration
  required; this one is closed).
- **Zammad's population collapsed** (34/640 path rows survive the
  pre-registered stub exclusion): its routes draw via `api_path +` string
  concatenation, which the no-boot extraction stubs. An extraction
  limitation, honestly excluded and reported — but it means Zammad's rates
  carry little weight either way.
- Helper-variant resolver rate 1.0 on all apps, as pre-registered
  (report-only expectation ≈ 1.0 by construction).

## Outcome (pre-registered; applied)

Gate 1 FAIL → **`--from-route` does not ship. Route evidence stays
coaching-only** (CLI-17c guidance to `bin/rails routes`), per the
pre-registration and the Phase 5 plan ("a valid recorded outcome"). 5c is
closed with no implementation pass. Re-opening requires a new frozen
pre-registration — plausibly a router-order-faithful first-match resolver
scored on verb-qualified evidence only.
