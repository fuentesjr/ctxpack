# Method-seed viability spike — results

**Measured:** 2026-07-14, per the frozen `PREREGISTRATION.md` (advisor-reviewed).
Script: `eval/seed-spikes/run_method_spike.rb`. Raw output under `results/`.

## Resolution gate — PASS

| App | Population (pairs) | Resolved | Rate |
|---|---|---|---|
| Mastodon | 4,750 | 3,445 | 72.5% |
| Discourse | 4,994 | 4,190 | 83.9% |
| Zammad | 3,904 | 3,507 | 89.8% |
| **Average** | | | **82.1% ≥ 70% → PASS** |

Miss taxonomy: dominated by `no_file` (Mastodon 1,059 / Discourse 545 /
Zammad 88) and the pre-registered `no_file_concern` sub-label (246 / 259 /
307) — concern modules live under roots the shipped CONST-2b resolver never
probes, a known systematic miss. `file_no_def` is negligible (2, Zammad);
zero `nesting_mismatch`, zero crashes.

## Test-leg precision gate — FAIL (0.6996 < 0.70)

| App | Matched tests | Lenient-true | Precision | Strict share of true |
|---|---|---|---|---|
| Mastodon | 1,517 | 1,209 | 0.797 | 0.951 |
| Discourse | 1,720 | 1,423 | 0.827 | 0.981 |
| Zammad | 8,278 | 3,927 | **0.474** | 0.312 |
| **Average** | | | **0.6996 < 0.70 → FAIL** | |

Failure mechanism (from `false_samples`): generic demodulized tokens. E.g.
Zammad `AI::Agent` → token `agent` matches every `agent_*` browser/request
test in the app. Zammad's low strict share (0.312) shows even its
lenient-true matches mostly reference some other "Agent", not the evidence
constant. The token heuristic fails on apps with generic class names; this
is a real false-inclusion mode, exactly what the gate was pre-registered to
catch. Mastodon/Discourse strict shares (0.95 / 0.98) show the lenient
criterion was not inflating their precision.

## Fan-out (report-only)

Same-constant same-file callee BFS + constant references, per resolved pair:

| App | Callees med / p90 / max | Constants med / p90 / max |
|---|---|---|
| Mastodon | 0 / 3 / 29 | 1 / 4 / 28 |
| Discourse | 0 / 2 / 46 | 1 / 4 / 42 |
| Zammad | 0 / 3 / 36 | 1 / 3 / 25 |

Median method calls nothing else in its file and references one constant;
p90 ≤ 4 constants — comfortably inside CONST-4-style budgets. Supports the
pre-reg's structural-boundedness argument for the same-file legs.

## Outcome (pre-registered; applied without renegotiation)

Resolution PASS + test-leg FAIL → **ship `--from-method` without the
test-candidate leg**: primary (method def + same-file expansion + constant
scan) only. The demotion is recorded in `specs/seeds.md` with the spike as
evidence; re-promoting the test leg requires a new pre-registered spike with
a better-than-token matching rule.
