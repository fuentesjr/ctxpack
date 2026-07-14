# Files-seed neighbor-rule spike — pre-registration

**Status:** Frozen before measurement (2026-07-13), Grok Phase 2 gate.  
**Source:** `docs/seed-based-interface-proposal.md` §3.3; `specs/seeds.md` SEED-15, SEED-22.

## Question

For real production files in the pinned sample apps, how often do the Phase 2
**neighbor rules** surface a conventional test (or view) that actually exists?

Named-file inclusion is trivial (evidence is the path). This spike measures
only neighbors.

## Apps / SHAs

Same pinned trio as Tier 0 / test-seed spike.

## Population

Deterministic sample of up to **80** files per app:

- All `app/controllers/**/*_controller.rb` (excluding `plugins/`, engines,
  concerns-only paths if not `*_controller.rb`), sorted, take every
  *k*-th file so the sample size ≤ 80 (k = ceil(N/80)).
- Plus, if fewer than 40 controller files, pad with sorted
  `app/models/**/*.rb` and `app/services/**/*.rb` under the same sampling.

## Neighbor rules under test (fixed before scoring)

For each primary path, candidates (existence-gated — never invent):

1. **Conventional controller test** (if primary is `app/controllers/<p>_controller.rb`):  
   - `test/controllers/<p>_controller_test.rb`  
   - `spec/controllers/<p>_controller_spec.rb`  
2. **Conventional request/integration test** (controller primaries only):  
   - basename token match under `test/integration/` or `spec/requests/`  
     (file exists and path includes a normalized controller path token).  
3. **Same-action views** (controller primaries only):  
   - any file under `app/views/<controller_path>/` (directory existence).  
4. **Path-token test for non-controllers:**  
   - basename without extension appears in a `test/` or `spec/` path
     (existence of at least one such file under a 1-level basename search
     capped at reporting yes/no).

## Metrics and gate (pre-registered)

- **Neighbor hit rate:** fraction of sampled primaries for which ≥1 neighbor
  rule returns an existing path.  
- **Precision:** 100% by construction (existence-gated). Reported only to
  state that fact.  
- **Gate:** average neighbor hit rate ≥ **40%** across the three apps for
  **controller primaries only** (non-controllers are descriptive).  
  Rationale: many controllers legitimately lack co-located tests in large
  apps; 40% shows the rule fires often enough to be useful without requiring
  universal coverage.  
- **On fail:** ship `--from-files` with **named files only** (no neighbor
  expansion) and record the demotion of neighbor rules in RESULTS; do not
  block Phase 2 named-files shipping.

## Failure / miss taxonomy

| Label | Meaning |
|---|---|
| `has_controller_test` | Rule 1 hit |
| `has_request_test` | Rule 2 hit |
| `has_views` | Rule 3 hit |
| `has_basename_test` | Rule 4 hit |
| `no_neighbor` | No rule found an existing neighbor |

## Explicit non-goals

- Not measuring multi-file seed merge.  
- Not CI-wired.
