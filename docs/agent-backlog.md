# Agent backlog — bounded tasks worth delegating

Top 5 bounded tasks to hand to Claude Code or Codex, derived from
`PROJECT_TRACKER.md` (Next steps, Known debt) and observed doc drift.
Ordering = current priority. Every task inherits the rules in `AGENTS.md`;
prompts below assume the agent reads it first.

---

## 1. P2 — generalize the Tier 2 harness to multi-app config

- **Why it matters:** It is the tracker's frozen immediate next step and the
  gate on the entire Tier 2 expansion (Campfire + Lobsters + Publify, ~72
  sessions). Until `eval/tier2/harness.rb` stops hardcoding Redmine-shaped
  constants (`APP_SHA`, `ANCHORS`, template paths, `bin/rails test` scoring),
  no expansion task can be authored.
- **Recommended driver:** Claude Code (contract-preservation judgment across a
  472-line harness; the Codex loop is reserved for spec passes).
- **Scope:** `eval/tier2/harness.rb` only, plus new config entries. Move
  app-specific data (repo/template identity, pinned SHA, prepared files,
  anchors, task prompts, scoring command, packet inputs, test-command family
  Minitest vs RSpec) into per-app config. Add empty/initial entries for the
  three expansion apps without authoring their tasks.
- **Definition of done:** (a) the completed Redmine run is representable by
  the new config — `ruby eval/tier2/harness.rb status` output is identical
  before/after and all 20 existing `runs.jsonl` records still count as
  complete; (b) `runs.jsonl` schema, status meanings, metric definitions, and
  resume semantics byte-for-byte unchanged; (c) `bundle exec rake test` green.
- **Safety constraints:** never edit `runs.jsonl`, `PREREGISTRATION.md`s,
  transcripts, or diffs; no new dependencies; do not run any agent sessions.
- **Required proof:** before/after `status` output pasted and diffed; suite
  summary line pasted; a grep showing no remaining `Redmine`/`3386d959`
  literals outside config.
- **Claude Code prompt:**
  > Read AGENTS.md, then PROJECT_TRACKER.md section "Next step: execution
  > plan" (P2) and eval/tier2-expansion/PREREGISTRATION.md. Refactor
  > eval/tier2/harness.rb so all app-specific data lives in per-app config
  > (Redmine first, then empty entries for Campfire, Lobsters, Publify with
  > `bundle exec rspec` as the RSpec-family test command). Preserve the
  > runs.jsonl contract, status meanings, metric definitions, artifact paths,
  > and resume semantics exactly. Prove it: capture `ruby
  > eval/tier2/harness.rb status` before and after and show they are
  > identical, and run `bundle exec rake test`. Do not touch runs.jsonl,
  > transcripts/, diffs/, or any PREREGISTRATION.md. Do not commit.
- **Codex prompt:**
  > Read AGENTS.md. Task: refactor eval/tier2/harness.rb (Ruby, no Rails)
  > from Redmine-shaped constants to a per-app config structure covering:
  > repo/template identity, pinned SHA, prepared files, anchors, task
  > prompts, acceptance/scoring command, packet inputs, and test-command
  > family (bin/rails test vs bundle exec rspec). Hard invariants: runs.jsonl
  > schema and status meanings unchanged; existing 20 Redmine records still
  > resolve as complete; `ruby eval/tier2/harness.rb status` output identical
  > pre/post; `bundle exec rake test` green. Add empty config entries for
  > Campfire, Lobsters, Publify (no tasks yet). Never modify runs.jsonl,
  > transcripts, diffs, or PREREGISTRATION files. Report the pre/post status
  > output and the test summary. Do not commit.

## 2. Split `Ctxpack::Compiler` (metz design-pressure refactor)

- **Why it matters:** `lib/ctxpack/compiler.rb` is 678 lines and flagged
  `ClassesTooLong` [504/100] by the advisory metz scan (tracker, Known debt).
  The class grows with every reason-code pass; the tracker names splitting it
  (callbacks / constants / test-candidates collaborators) the
  highest-pressure candidate refactor, to be weighed at a pass boundary.
- **Recommended driver:** Codex (behavior-preserving lib/ work fits the
  repo's delegation loop; 55 green tests act as characterization tests).
- **Scope:** `lib/ctxpack/compiler.rb` (+ new collaborator files under
  `lib/ctxpack/`). Zero behavior change; public API
  (`Ctxpack.compile(app_root:, anchor:, task:, constant_resolver:)`) and the
  packet-object shape untouched.
- **Definition of done:** suite green with **no test edits**; corpus re-scan
  (tier0-corpus-rescan skill) shows zero per-anchor changes; `rake metz`
  pressure on the compiler reduced (paste before/after numbers);
  `implementation-notes.md` records the split.
- **Safety constraints:** run only at a pass boundary with explicit user
  go-ahead (tracker rule: not mid-pass); no new dependencies; no spec
  changes needed — if one seems needed, stop, that means behavior moved.
- **Required proof:** test summary; corpus re-scan per-anchor diff (zero
  flips); before/after `rake metz` output for the compiler class.
- **Claude Code prompt:**
  > Read AGENTS.md. At the current pass boundary, refactor
  > lib/ctxpack/compiler.rb into collaborators (suggested seams: callbacks,
  > constants, test candidates — follow the actual cohesion you find) with
  > zero behavior change: no test file edits, `bundle exec rake test` green,
  > public API and packet-object shape identical. Then run the
  > tier0-corpus-rescan skill and confirm zero per-anchor flips, and paste
  > before/after `bundle exec rake metz` findings for Ctxpack::Compiler.
  > Update implementation-notes.md. Do not commit.
- **Codex prompt:**
  > Read AGENTS.md. Behavior-preserving refactor: split the 678-line
  > Ctxpack::Compiler (lib/ctxpack/compiler.rb) into cohesive collaborators
  > under lib/ctxpack/ (candidate seams: callback selection, constant
  > extraction, test-candidate rules). Invariants: no test edits, `bundle
  > exec rake test` green, `Ctxpack.compile` signature and Packet#to_h output
  > byte-identical for the existing fixtures, prism stays the only runtime
  > dependency, Ruby 3.2 compatible. Record the split in
  > implementation-notes.md. Report which methods moved where and the test
  > summary. Do not commit. Note: session-side corpus re-scan happens after
  > your hand-back.

## 3. Packet-vs-diff coverage script (the post-v0 north-star metric)

- **Why it matters:** The decision log (2026-07-05) designates
  packet-vs-diff coverage — files the completed task touched vs files in the
  packet, read as recall/precision — as the north-star metric and the
  evidence source for validating the guessed LIM-1 limits (8/4/2/120). All
  inputs already exist committed: 18+2 diffs in `eval/tier2/diffs/` and the
  packet file lists in `eval/tier2/packets/`. Nobody has computed it.
- **Recommended driver:** Either (self-contained read-only analysis; clear
  testable finish line — good `/goal` candidate for Claude Code).
- **Scope:** one new script `eval/tier2/coverage.rb` + a short results table
  appended nowhere yet (print to stdout; the user decides where it lands).
  Reads `packets/packets.json` + `packets/task*.md`/manifests and
  `diffs/*.patch`; no network, no app checkouts.
- **Definition of done:** script prints, per task and per arm, packet recall
  (fraction of diff-touched files present in the packet) and precision
  (fraction of packet files touched by the diff), plus medians; deterministic
  across runs; handles the pilot runs distinctly; a smoke assertion or test
  documents the expected shape.
- **Safety constraints:** read-only over `eval/tier2/` — must not modify any
  recorded artifact; results are *descriptive*, not a re-litigation of the
  frozen SUPPORT verdict (EVAL-1/pre-registration discipline).
- **Required proof:** script output pasted for all runs; a second invocation
  shown byte-identical (determinism); `bundle exec rake test` still green.
- **Claude Code prompt:**
  > /goal Read AGENTS.md, then eval-plan.md and the 2026-07-05
  > "packet-vs-diff coverage" decision in PROJECT_TRACKER.md. Write
  > eval/tier2/coverage.rb: for each run in eval/tier2/runs.jsonl, parse its
  > diffs/<run_id>.patch for touched files and compare against the packet
  > file list for its task (eval/tier2/packets/). Print per-run recall and
  > precision and per-task/per-arm medians, deterministically. Read-only
  > over recorded artifacts. Done when: output covers all 20 sessions, two
  > consecutive runs produce identical output, and `bundle exec rake test`
  > is still green.
- **Codex prompt:**
  > Read AGENTS.md. Write a standalone Ruby script eval/tier2/coverage.rb
  > (stdlib only): input = eval/tier2/runs.jsonl, eval/tier2/diffs/*.patch,
  > packet file lists under eval/tier2/packets/. Output = per-run packet
  > recall (diff-touched files found in packet / diff-touched files) and
  > precision (packet files touched / packet files), plus per-task, per-arm
  > medians. Deterministic ordering; treat pilot runs separately; never
  > write to eval/tier2/. Prove determinism by running twice and diffing
  > output. Report the full table. Do not commit.

## 4. Fix README status drift

- **Why it matters:** `README.md` still says ctxpack "is currently in **v0
  design/prototype planning**" and labels the CLI/output "Planned", but all
  four passes are Done (PROJECT_TRACKER Status table), the gem compiles
  packets, CI runs, Tier 0 passed at 91.0%→93.9%, and Tier 2 returned
  SUPPORT. Stale docs are exactly the misleading context this project exists
  to prevent.
- **Recommended driver:** Either (small, judgment-light; Claude Code's doc
  pass is fine).
- **Scope:** `README.md` only. Status section, "Planned v0 CLI"/"Planned
  output" phrasing, "Current next step" section (now years behind the
  tracker), and eval-status claims. No behavior claims beyond what specs +
  tracker state.
- **Definition of done:** every README claim about status, commands, and
  eval results matches `PROJECT_TRACKER.md` and `specs/cli.md`; each command
  shown in the README was executed and produced the shown shape; no claim
  contradicts a spec.
- **Safety constraints:** README only; do not restate spec requirements
  (link to them); do not touch specs/design/tracker.
- **Required proof:** paste each README command's actual output (or the
  relevant first lines); a claims-to-sources table (claim → tracker/spec
  line) in the hand-back.
- **Claude Code prompt:**
  > Read AGENTS.md, PROJECT_TRACKER.md (Status + decision log) and
  > specs/cli.md. Update README.md to reflect implemented reality: passes
  > 1–4 done, CLI usable, Tier 0 passed (93.9% post-amendment), Tier 2
  > SUPPORT with the expansion pre-registered. Replace "Planned" phrasing
  > and the stale "Current next step" section. Verify every command you show
  > by running it (e.g. ruby -Ilib exe/ctxpack packet accounts#upgrade from
  > test/fixtures/apps/minitest_basic) and paste outputs in your report.
  > README only; do not commit.
- **Codex prompt:**
  > Read AGENTS.md and PROJECT_TRACKER.md. Task: README.md only. Bring it in
  > line with reality: implementation passes 1–4 complete (see tracker
  > Status table), CLI implemented per specs/cli.md, Tier 0 gate passed,
  > Tier 2 A/B returned directional SUPPORT (eval/tier2/RESULTS.md), Tier 2
  > expansion pre-registered. Remove/replace "Planned" and "Current next
  > step" staleness. Every command you leave in the README must be one you
  > ran successfully from this checkout; include the outputs in your report.
  > Do not edit any other file. Do not commit.

## 5. CI Ruby matrix: floor + current

- **Why it matters:** CI pins Ruby 3.2 (the gemspec floor) while local dev
  runs 4.0.1 — the suite is never exercised on a modern Ruby in CI, so
  floor-vs-current drift is only caught by accident. A two-entry matrix
  closes the gap for one workflow-file change.
- **Recommended driver:** Either (mechanical; a fast/cheap agent is fine).
- **Scope:** `.github/workflows/ci.yml` only: matrix over `ruby-version:
  ["3.2", "3.4"]` (or current stable), metz step unchanged
  (`continue-on-error: true`, pinned 0.4.0) and running on one matrix entry
  only to avoid duplicate advisory noise.
- **Definition of done:** workflow YAML parses; suite passes locally on the
  available Ruby; matrix entries and the metz-once constraint visible in the
  diff. CI itself can only be verified after push — say so explicitly.
- **Safety constraints:** no other CI changes bundled in; do not raise the
  gemspec floor; pushing (which triggers CI) needs user approval.
- **Required proof:** local `bundle exec rake test` summary; a YAML parse
  check (e.g. `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")'`);
  explicit note that green CI is verified only post-push.
- **Claude Code prompt:**
  > Read AGENTS.md. Edit .github/workflows/ci.yml only: run the test job on
  > a Ruby matrix of the gemspec floor "3.2" plus a current stable Ruby.
  > Keep the advisory metz step pinned to 0.4.0 with continue-on-error, and
  > make it run on only one matrix entry. Verify the YAML parses and run
  > `bundle exec rake test` locally. State clearly that CI green can only be
  > confirmed after push, and do not push or commit.
- **Codex prompt:**
  > Read AGENTS.md. Single-file change: .github/workflows/ci.yml. Add a
  > strategy matrix so `bundle exec rake test` runs on Ruby "3.2" (gemspec
  > floor — keep) and one current stable Ruby. The advisory metz step
  > (gem install metz-scan -v 0.4.0; continue-on-error) must run on exactly
  > one matrix entry. Validate the YAML loads, run the suite locally, and
  > report both. No other files. Do not commit or push.
