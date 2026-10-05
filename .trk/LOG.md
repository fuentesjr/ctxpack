# LOG

## 2026-07-18T08:03Z log
Migrated from PROJECT_TRACKER.md (see git log -- PROJECT_TRACKER.md and docs/history/ for full chronology). Key state at migration: upstream verified through 4da5523; evalkit ledger b3f7eb4 unpushed. Files-seed history tracer + git-recon facts companion shipped (3e7cf79/05f293e; git-recon 7682b2c). Issue #6 closed as not planned. Issue #7 spike: frozen DROP verdict under be8e9fb (precision 0.067, zero rotated-focus lift, 52/60 rows insufficient excerpt context); retry requires a new preregistration with materially different deterministic recipes — measured failure points to source-family discovery beyond root READMEs and separating document selection from bounded excerpt quality. Markdown cleanup: tickets #1/#2 resolved, ticket #3 ablation inconclusive under the frozen 900k cap.

## 2026-07-20T00:38Z log
Compiler split closed locally: full suite 263/2256 green; Tier 0 post_amendment byte-identical across 1,967 anchors; SSD verdict clean with one DEPTH-1 nit; no commit/push authorized. See eval/tier0/RESULTS.md compiler split addendum.

## 2026-07-20T01:20Z log
Method test-leg respike measured at runner commit abe74ca: frozen DROP. Mean precision 0.1998 and per-app floor 0.1163 failed; mean coverage 0.6757 and minimum yield 86 passed. SEED-25 remains no-test-leg; see eval/seed-spikes/method-test-leg-respike/RESULTS.md.
## 2026-09-24T02:28Z resolve fix-encoding
Outcome: Merged uncommitted: UTF-8 task/argv/error-paste input + explicit UTF-8 source reads; suite 289/0 in UTF-8 and C locales

## 2026-09-24T02:28Z resolve fix-diff-seed
Outcome: Merged uncommitted: review items 1,3,5-8,10 + reviewer follow-ups (realpath confinement, ceiling test, invalid-UTF-8 path); item 9 parked on spec conflict (limit_key for non-budget omissions)

## 2026-09-24T02:28Z log
tier0-corpus-rescan deferred for encoding/diff-seed fix pass: only anchor-path changes are explicit UTF-8 on seed_compiler controller read and rspec Gemfile read, identical when Encoding.default_external is UTF-8 (verified locally); diff-seed changes are outside the Tier 0 anchor classifier. Revisit if classifier runs under a non-UTF-8 locale.
