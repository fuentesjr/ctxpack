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
