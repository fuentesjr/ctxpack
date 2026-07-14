# Files-seed neighbor-rule spike — results

Pre-registration: [`PREREGISTRATION.md`](PREREGISTRATION.md) (frozen before measurement).  
Executed 2026-07-13 against pinned sample apps at Tier 0 SHAs.

## Verdict

**Average controller neighbor hit rate: 80.3% → ≥ 40% gate passes. Ship neighbor expansion with `--from-files`.**

| App | Controller primaries | Neighbor hits | Rate |
|---|---|---|---|
| Mastodon | 78 | 72 | 92.3% |
| Discourse | 69 | 65 | 94.2% |
| Zammad | 68 | 37 | 54.4% |
| **Average** | | | **80.3%** |

Precision is 100% by construction (existence-gated). Named-file inclusion was
not under test.

Raw JSON: [`results/`](results/).
