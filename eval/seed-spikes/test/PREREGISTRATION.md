# Test-seed viability spike — pre-registration

**Status:** Frozen before measurement (2026-07-13), Grok Phase 2 gate.  
**Source:** `docs/seed-based-interface-proposal.md` §3.3; `specs/seeds.md` SEED-5, SEED-14, SEED-22.

## Question

How often do the Phase 2 `test` seed heuristics find a correct existing
production surface for real test/spec files in the pinned sample apps?

## Apps / SHAs (pinned; same as Tier 0)

| App | SHA |
|---|---|
| Mastodon | `163f96cee4dea23365bff9b433871e68d20d9ee7` |
| Discourse | `28b003a38d82c354ffc49bac23b655de9664e478` |
| Zammad | `50384f4c390e8abed07694897956c2f8e176208d` |

Scratch checkouts under `tmp/tier0-rescan/` (or equivalent) at those SHAs.

## Population

All files under each app root matching either:

- `spec/controllers/**/*_spec.rb` or `test/controllers/**/*_test.rb`
- `spec/requests/**/*_spec.rb` or `test/integration/**/*_test.rb`

Exclude paths under `plugins/`, `engines/`, `vendor/`, `node_modules/`,
`.git/`. Discourse core may have few controller specs; the population is
whatever remains after exclusion (N may be small — report N, do not pad).

## Heuristics under test (fixed before scoring)

Applied in order; first hit that names an **existing** file under the app
root counts as a production surface:

1. **Controller path convention**  
   - `spec/controllers/<path>_controller_spec.rb` → `app/controllers/<path>_controller.rb`  
   - `test/controllers/<path>_controller_test.rb` → same  
2. **Request/integration path-token convention**  
   - Strip `_spec`/`_test` suffix and directory prefix; if the basename
     contains a contiguous token that maps to an existing
     `app/controllers/**/<token>_controller.rb` (lexicographically first match
     if multiple), use that.  
3. **`described_class` / top-level constant**  
   - First `described_class` or `RSpec.describe X` / class name in a Minitest
     class that looks like `CamelCase` (not ending in `Test`/`Spec`); resolve
     via Zeitwerk-style path under `app/` (same rules as
     `DefaultConstantResolver`).

## Ground truth

**Success** for a sample file = at least one heuristic returns a path that:

1. Exists on disk under the app root, and  
2. Lives under `app/` (production, not another test).

This is an existence+convention ground truth, not human-labeled “this is the
file the author meant.” Miss taxonomy records why nothing was found.

## Metric and gate (pre-registered)

- **Primary metric:** fraction of population files with success (per app and
  unweighted average of the three app rates).  
- **Gate:** average ≥ **70%** (same numeric bar as Tier 0 anchor viability).  
- **On fail:** do not ship `--from-test` in Phase 2; report taxonomy; campaign
  may continue with `--from-files` only if that spike passes (SEED-22).

## Failure taxonomy (pre-registered labels)

| Label | Meaning |
|---|---|
| `resolved_controller_path` | Hit by heuristic 1 |
| `resolved_request_token` | Hit by heuristic 2 |
| `resolved_constant` | Hit by heuristic 3 |
| `no_surface` | No heuristic produced an existing `app/` path |
| `policy_or_non_controller` | Path looked like a controller test but target is policy/non-app |
| `crash` | Spike script raised |

## Explicit non-goals

- Not evidence that packets help agents (Tier 1 circularity still applies).  
- Not a full recipe quality eval (no snippet correctness).  
- Not CI-wired (EVAL-10).
