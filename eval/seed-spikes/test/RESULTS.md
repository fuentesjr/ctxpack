# Test-seed viability spike — results

Pre-registration: [`PREREGISTRATION.md`](PREREGISTRATION.md) (frozen before measurement).  
Executed 2026-07-13 against pinned sample apps at Tier 0 SHAs.

## Verdict

**Average success rate: 78.2% → ≥ 70% gate passes. Ship `--from-test`.**

| App | Population | Success | Rate |
|---|---|---|---|
| Mastodon | 296 | 271 | 91.6% |
| Discourse | 153 | 140 | 91.5% |
| Zammad | 126 | 65 | 51.6% |
| **Average (pre-registered metric)** | | | **78.2%** |

## Taxonomy notes

- Mastodon: dominated by `resolved_request_token` (238) + controller path (22).
- Discourse: dominated by `resolved_constant` (124) — request/controller path
  population is thin after excluding `plugins/`.
- Zammad: weakest (51.6%); many request specs without a matching controller
  path token (`no_surface` 61). Still contributes above a floor that keeps the
  three-app average over the gate.

Raw JSON: [`results/`](results/).
