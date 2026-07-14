# Diff-seed viability spike — results

**Measured:** 2026-07-14, per the frozen `PREREGISTRATION.md` (advisor-reviewed).
Script: `eval/seed-spikes/run_diff_spike.rb`. Raw output under `results/`.

## Paired-test agreement gate — PASS

| App | Window | Gated pairs | Non-empty predictions | Agreement |
|---|---|---|---|---|
| Mastodon | 601 | 30 | 29 | 0.759 |
| Discourse | 601 | 55 | 52 | 0.712 |
| Zammad | 601 | 38 | 25 | 0.960 |
| **Average** | | | | **0.810 ≥ 0.70 → PASS** |

Label detail: agreements are all `agree_mirror`; disagreements are genuine
cross-file test relationships the mirror can't see (e.g. Discourse
serializer changes exercised via controller request specs) — a recall
limit, not false inclusion of unrelated tests. `no_prediction` (1/3/13)
counts only against coverage, per the frozen conditioning.

## Report-only metrics

| App | Def-anchoring rate | File survival (both sides) | Attribution-ambiguous excluded |
|---|---|---|---|
| Mastodon | 0.858 | 0.997 | 37 |
| Discourse | 0.874 | 0.999 | 59 |
| Zammad | 0.793 | 0.998 | 37 |

~80–87% of changed hunks sit inside a method def (good snippet anchoring);
survival ≈ 99.8% (deletions/renames are a thin sliver the recipe must
exclude from primaries); ambiguous multi-file commits excluded from the
gate are of the same order as the gated population (denominator context).

Zero crashes in all populations.

## Outcome (pre-registered; applied)

Agreement PASS → **ship `--from-diff` with the paired-test leg** (mirror
conventions only — no basename token matching, per the 5a lesson). Literal
changed files ship as primaries per the SEED-22 files precedent;
def-anchored snippets per hunk; deleted/renamed-away paths are excluded
from primaries with a follow-up.
