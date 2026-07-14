# Error-seed viability spike — results

Pre-registration: [`PREREGISTRATION.md`](PREREGISTRATION.md) (frozen before measurement).  
Executed 2026-07-13 against pinned sample apps at Tier 0 SHAs.

## Verdict

**Average precision 1.00 and recall 1.00 → gate passes. Ship `--from-error`.**

| App | Traces | Precision | Recall |
|---|---|---|---|
| Mastodon | 39 | 1.00 | 1.00 |
| Discourse | 40 | 1.00 | 1.00 |
| Zammad | 40 | 1.00 | 1.00 |
| **Average** | | **1.00** | **1.00** |

Synthetic backtraces used real app paths plus fixed gem/stdlib decoys across
three formats (MRI `from`, bare `PATH:LINE`, JSON file/line). Filtering
matches SEED-20 (app/lib/config under app root only).

Raw JSON: [`results/`](results/).
