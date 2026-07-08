# Blind diff-quality judging — provenance

Committed artifacts for the Tier 2 expansion blind diff-quality pass (0–8),
which closes the pre-registered "no diff-quality regression" gate. Results and
interpretation are in [`../RESULTS.md`](../RESULTS.md) ("Diff quality").

## What is here

- `groups.json` — per app, the byte-identical code groups + representatives.
  Arm-free (codes only); this is what the judge consulted to know which unique
  diffs to score. 47 unique byte-contents across the 72 grid diffs.
- `scores.json` — the judge's blind 0–8 scores, keyed by representative opaque
  code. One representative scored per byte-identical group; all codes in the
  group inherit it. Four sub-scores (correct-beyond-test, minimal, conventions,
  no-unrelated) + a one-line comment each.
- `mapping.json` — the sealed opaque-code → session/app/sha256 map. **Not read
  during scoring** — the reveal happens only at tabulation.
- `quality_summary.json` — machine-readable aggregate (per app × task × arm
  means, overall, by task-kind), emitted by `tabulate_quality.rb`.

## Reproducing

```
ruby eval/tier2-expansion/build_blind_judging.rb          # rebuild patches + mapping/groups (deterministic; seed = each app SHA)
ruby eval/tier2-expansion/tabulate_quality.rb eval/tier2-expansion/judging   # reveal + aggregate
```

`build_blind_judging.rb` shuffles each app's 24 grid diffs (pilots excluded)
with a PRNG seeded on that app's pinned SHA, so codes/groups/mapping reproduce
byte-identically. The anonymized patch copies land in the gitignored
`tmp/tier2-expansion/judging/patches/` (derivable, not committed).

## Blinding

The judge (orchestrator, judge-of-record) scored reading only the opaque-coded
patches and `groups.json`; `mapping.json` was written but unread until
`scores.json` was finalized. Blinding is on **arm** (control vs treatment), not
task — task is inferable from diff content and does not compromise the
comparison.
