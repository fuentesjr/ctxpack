# Work-start corpus (re-scoped, Phase 2)

**Status:** Authored 2026-07-13 with Phase 2 (SEED-24).  
**Metric:** work-start scenario → correct seed kind + useful packet focus (not steps-to-anchor).

Scored against fixture apps and the three pinned sample apps where noted.
This is offline evidence for seed-kind coverage; not CI (EVAL-10).

| ID | Scenario | Expected seed | Correct packet signal |
|---|---|---|---|
| WS-1 | Red controller test path in hand | `test` | primary = that test; surface includes matching controller when conventional |
| WS-2 | Explicit service/model file open | `files` | primary = named file; neighbor test if conventional path exists |
| WS-3 | Classic `controller#action` known | `anchor` | full vertical slice (pre-existing Tier 0/1 coverage) |
| WS-4 | Class-style `FooController#action` | coach only | suggest-only rewrite; no silent compile |
| WS-5 | Route helper name only | coach only | CLI-17c helper diagnostic; no seed |
| WS-6 | Multi-file + test (Phase 4) | multi | deferred to Phase 4 enablement |

## Phase 2 scoring (fixture-backed)

| ID | Result |
|---|---|
| WS-1 | **PASS** — `test_seed_accounts_controller` fixture eval |
| WS-2 | **PASS** — `files_seed_accounts_controller` fixture eval |
| WS-3 | **PASS** — existing anchor fixture evals + Tier 0 baseline |
| WS-4 | **PASS** — CLI-17c class-style diagnostic (suite) |
| WS-5 | **PASS** — CLI-17c helper diagnostic (suite) |
| WS-6 | **DEFERRED** — Phase 4 |

Re-score at Phase 3/4 gates.

## Phase 5 scoring (2026-07-14, fixture-backed; suite 205 runs / 0 failures)

| ID | Result |
|---|---|
| WS-1..WS-5 | **PASS** — unchanged; covered by the same fixture evals + CLI diagnostics in the green suite |
| WS-6 | **PASS** — multi-seed shipped Phase 4; now also exercised by `multi_seed_method_and_anchor` and `multi_seed_diff_and_files` fixture evals |
| WS-7 (new) | Non-controller `Constant#method` in hand → `method` seed. **PASS** — `method_seed_billing_upgrade` fixture eval + SEED-10 rule 4 sugar (unit suite) |
| WS-8 (new) | Local diff/patch in hand → `diff` seed via `--from-diff`. **PASS** — `diff_seed_patch_accounts` fixture eval; positional `.patch` stays a files seed (SEED-10 rule 6, unit suite) |
| WS-9 (new) | Route path / `VERB /path` in hand → **coach only** (5c spike NO SHIP). **PASS** — CLI-17c route-shaped diagnostics (suite); no silent compile |

Re-score at the next phase gate that ships a seed kind or changes dispatch.
