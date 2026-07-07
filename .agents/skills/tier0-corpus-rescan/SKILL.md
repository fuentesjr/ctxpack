---
name: tier0-corpus-rescan
description: Re-run the Tier 0 anchor classifier against Mastodon/Discourse/Zammad at the pinned spike SHAs and diff per-anchor resolution against the last recorded run. Mandatory pass-boundary gate for any change to compiler behavior (lib/ctxpack/ resolution, callbacks, constants, test candidates, limits).
---

# tier0-corpus-rescan

Standing pass-boundary regression check (decided 2026-07-05, see
`PROJECT_TRACKER.md` "Working process"). Unlike `rake metz` this is **not**
advisory: every per-anchor regression must be either predicted by the change
or routed back as a defect before the pass is accepted.

## When to use

- A pass changed compiler behavior — anything in `lib/ctxpack/` that affects
  anchor resolution, callback selection, constant extraction, test-candidate
  rules, or limits. Run at the pass boundary, before acceptance.

## When NOT to use

- Passes that don't touch compiler behavior (CLI-only, renderer-prose-only,
  docs, eval harness). Skip it and state the skip reason explicitly — the
  skip itself is part of the pass record.
- As Tier 1 CI — EVAL-10 forbids wiring Tier 0/2 into CI. This is offline only.

## Inputs (all pinned; never re-draw)

| App | Spike SHA |
|---|---|
| Mastodon | `163f96cee4dea23365bff9b433871e68d20d9ee7` |
| Discourse | `28b003a38d82c354ffc49bac23b655de9664e478` |
| Zammad | `50384f4c390e8abed07694897956c2f8e176208d` |

Route tables are already committed at `eval/tier0/routes/<app>.json` — **do
not re-extract them** (the post-amendment addendum in
`eval/tier0/RESULTS.md` set this precedent: same SHAs, committed routes,
apps shallow-fetched at the recorded commits).

## Workflow

1. Fetch each app at its pinned SHA into scratch space (not the repo tree),
   e.g.:
   ```sh
   git clone --filter=blob:none https://github.com/mastodon/mastodon <scratch>/mastodon
   git -C <scratch>/mastodon checkout 163f96cee4dea23365bff9b433871e68d20d9ee7
   ```
   (Shallow clone at an exact SHA needs `fetch origin <sha>` on a bare init —
   whichever route you take, verify `git rev-parse HEAD` matches the table above.)
2. Run the classifier per app against the committed route table:
   ```sh
   ruby eval/tier0/classify_anchors.rb <app_root> eval/tier0/routes/<app>.json <scratch>/results/<app>.json
   ```
3. Diff **per-anchor** resolution against the last recorded run
   (`eval/tier0/results/post_amendment/` is the current baseline — check
   `eval/tier0/RESULTS.md` addenda for anything newer). Three buckets:
   newly-resolved, newly-failed (regressions), unchanged.
4. Judge regressions: each newly-failed anchor must be **predicted by the
   change** (as the ANCH-amendment re-run predicted exactly its 53 flips) or
   it is a defect — route it back into the pass's fix round.
5. Record the run: rates per app + average, flip counts, regression judgment,
   as an addendum in `eval/tier0/RESULTS.md` (and reference it from the
   tracker's decision-log entry for the pass). Keep the per-anchor result
   JSONs under `eval/tier0/results/` if the run becomes the new baseline.

## Verification requirements

- [ ] `git rev-parse HEAD` in each app checkout equals the pinned SHA (paste all three).
- [ ] Classifier ran against the **committed** route tables, not re-extracted ones.
- [ ] Per-anchor diff computed (not just aggregate rates) — regressions listed by anchor.
- [ ] Every regression classified as predicted-by-change or routed back as a defect.
- [ ] Compiler crash count reported (expected: zero; any crash is a defect).

## Expected output

Per-app resolution rates + the engine-excluded average, per-anchor flip lists,
an explicit "zero regressions" or defect list, and the RESULTS.md addendum.

## Escalation

- Any unpredicted regression → do not accept the pass; report the anchors and
  the failing classification.
- Average drops below the 70% Tier 0 gate → stop; that invalidates a
  pre-registered foundation and is the user's call.
- Apps fail to fetch at the pinned SHAs → stop and report; never substitute a
  different SHA silently.
