# Packet-vs-diff coverage — provenance

Offline recall/precision of each Tier 2 expansion task's ctxpack packet
file-set against the files each subject diff actually touched — the designated
post-v0 north-star for the LIM-1 packet-size limits (decision log 2026-07-05).
Results and interpretation are in [`../RESULTS.md`](../RESULTS.md)
("Packet-vs-diff coverage").

## What is here

- `coverage_summary.json` — aggregates (per app × task × arm, overall per arm,
  by task-kind) for both `all_files` and `production_only` variants; each cell
  carries mean recall/precision, n, and null-count.
- `coverage_by_session.json` — one row per grid session (72): app, task, kind,
  arm, round, the packet file-set, the diff file-set, their intersection, and
  recall/precision for both variants.

## Metric definitions

- `packet_files` = `files[].path` from `<app>/packets/task<N>.json`.
- `diff_files` = repo-relative `b/` paths from each patch's `diff --git`
  headers (`<app>/diffs/*.patch`, pilots excluded).
- `recall = |packet ∩ diff| / |diff|`, `precision = |packet ∩ diff| / |packet|`
  (null when a denominator is empty; excluded from means).
- `production_only` removes top-level `test/` and `spec/` paths from both sets
  (headline variant). `config/locales/en.yml` and views count as production.

Control diffs are the **unbiased** read (the agent never saw the packet);
treatment is a **steering** read (and can overstate recall when an agent
under-touches, shrinking the diff denominator — see RESULTS caveat).

## Reproducing

```
ruby eval/tier2-expansion/packet_coverage.rb
```

Pure offline file parsing (stdlib only); deterministic; no app boot or DB.
