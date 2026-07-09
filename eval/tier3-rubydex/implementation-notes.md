# Tier 3 offline probe — implementation notes

Terse working notes for the offline Rubydex-recall probe (PROJECT_TRACKER
"OFFLINE Rubydex-recall probe" work order). Orchestrator = Claude (DRA/judge);
heavy script authoring = Codex; execution + verification = session-side.

## Decisions / scope

- **Gate (step 1) resolved 2026-07-08: PASS.** Rubydex 0.2.8 (static Rust
  indexer, no boot/DB) indexes all three pinned apps offline in <1s. See
  `GATE.md`.
- **Reframe after the Fable advisory (verified session-side):** the feature
  recall gap is TWO mechanisms, not one. Rubydex's *demonstrated* reach on this
  corpus is ONE pre-existing file (campfire `user.rb`, reached via call graph
  into a private helper the action-body resolver misses); `user_standing.rb` was
  agent-CREATED (`new file mode 100644`) so no resolver can recall it. Views are
  closable by a Rails path-convention layer (files pre-exist); locale misses are
  newly-added keys → a pointer, not a packet file. Measured harm: the only two
  treatment-arm quality dings in the 72-session grid (P06/P20, publify t1) are
  the view/locale omission.
- **Probe design (steps 2–3): four-column offline recompute.** Reuse
  `eval/tier2-expansion/packet_coverage.rb` metric defs verbatim; build 4 packet
  file-set variants per app×task — convention / +view / +rubydex / +both — and
  recompute recall/precision over the SAME committed diffs. Deliverable:
  `four_column_coverage.rb` + `coverage/` JSON + writeup. Self-check: the
  `convention` column must reproduce the committed coverage numbers exactly.
- **Rubydex variant scoping:** resolved constant references located *in the
  entrypoint controller file* → their declaration definition files, filtered to
  pre-existing `app/`|`lib/` non-test files ≠ the controller. (Captures the
  private-helper `User` win.) Budget-capped at LIM max_total_files=8.
- **Rubydex runs under `~/.local/share/mise/installs/ruby/4.0.1/bin/ruby`** (the
  gem's ABI). Codex authors only (its sandbox lacks the gem + the `tmp/` app
  checkouts); orchestrator runs + verifies.

## Status — probe COMPLETE (2026-07-08)

- [x] Gate resolved (PASS) — `GATE.md`.
- [x] Codex authored `four_column_coverage.rb` (`task-mrcrcnah-qgz24i`, session
  `019f443c-e58c-7c13-ab57-70b1679822fa`); syntax-checked, not run in sandbox.
- [x] Ran session-side under 4.0.1. Convention-column self-check **passed**
  (reproduces committed baseline exactly). Caught + fixed a real bug: Rubydex
  resolution is **cwd-dependent**, not just `workspace_path` — needed
  `Dir.chdir(app_root)` around index/resolve (learning note
  `docs/agent-learnings/2026-07-08-rubydex-cwd-dependent-resolution.md`). Fix
  applied session-side (one-line, non-heavy). Hand-checked added-file cells.
- [x] Judge verdict written — `RESULTS.md`. **Build the view path-convention
  layer + widen the convention constant-scan to the whole controller file;
  locale = pointer; DEFER Rubydex (one file of recall, already convention-
  reachable, for a halved precision + a native Rust dep); no new grid.**
- [x] `rake test` green (55 runs, 0 failures; only `eval/` touched). Corpus
  re-scan skipped (no compiler behavior touched — analysis script only).
- [ ] Update PROJECT_TRACKER (status row, decision log, rewrite Next-step plan)
  — in progress.
- [ ] Nothing committed (awaiting user go).

## Headline numbers (control, production-only, feature tasks)

convention R 0.685/P 0.653 · +view R 0.815/P 0.556 (+0.130R/−0.097P, ratio 1.33)
· +rubydex R 0.769/P 0.341 (+0.083R/−0.312P, ratio 0.27) · +both R 0.898/P 0.342.
Rubydex raises recall on exactly ONE of 12 tasks (campfire t1 `user.rb`, a
literal in-file constant a full-file convention scan would also catch).
