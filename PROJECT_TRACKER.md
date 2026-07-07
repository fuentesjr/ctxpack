# ctxpack project tracker

Tracks implementation progress against the normative specs in [`specs/`](specs/)
and the next steps. Update this file whenever a pass lands or a decision
changes scope. Per-pass technical decisions live in
[`implementation-notes.md`](implementation-notes.md); rationale lives in
[`design.md`](design.md).

## Resuming a session

The only prompt a fresh session needs is: **"Continue from
PROJECT_TRACKER.md."** Concretely, that session reads this file, treats
"Next step: execution plan" as its work order (if it disagrees with
"Next steps", Next steps wins), runs the pass per "Working process"
below, and closes with the end-of-session ritual. Each of those sections
owns its own altitude: this one is only the bootstrap, "Working process"
owns the loop mechanics, and the execution plan carries only
pass-specific content.

## Working process

Each spec is implemented in its own pass, in the dependency order from
[`specs/README.md`](specs/README.md): implementation is delegated to Codex
(via the codex plugin), then reviewed requirement-by-requirement by Claude,
confirmed defects are routed back to the same Codex session, and the result is
re-verified before acceptance. Spec bugs discovered during implementation are
amended in the spec *and* reconciled with `design.md` in the same change.

Codex plugin mechanics (learned in pass 1): the `codex:codex-rescue` agent is
a one-shot forwarder — it hands the brief to Codex and returns a task ID
without waiting. Polling and result retrieval happen from the main session
via the plugin's companion script at
`~/.claude/plugins/cache/openai-codex/codex/<version>/scripts/codex-companion.mjs`
(newest version directory): `status <task-id>` / `result <task-id>`,
backgrounding a polling loop for long runs. Follow-up fix rounds resume the
same Codex session by forwarding a `--resume` request. Always instruct the
forwarder to launch via the companion's own `--background` flag: if it
instead runs the companion in foreground inside a harness background shell,
the shell reap at subagent exit kills the companion mid-turn and the job
wedges at "running" forever (upstream codex-plugin-cc#432, root cause #222;
hit twice on 2026-07-05). Fingerprint of a wedged foreground run: the job
JSON under the plugin's `state/<ws>/jobs/` has no `request` key. The Codex
turn usually completes server-side anyway — verify the working tree, then
`cancel` the stale record. Verification is
always session-side, never trusted from Codex's own summary: run
`bundle exec rake test`, check git state, and review the diff
requirement-by-requirement against the pass's spec codes; route confirmed
defects back via `--resume` and re-verify before acceptance. Codex owns the
pass notes in `implementation-notes.md` — confirm they are current before
accepting the pass.

Dogfooding metz-scan (decided 2026-07-05): `rake metz` runs an advisory
[metz-scan](https://github.com/fuentesjr/metz-scan) design-pressure scan
over `lib/` (pinned 0.4.0, scoped to Metz cops via the committed
`.rubocop.yml`). It never gates the build or the Codex loop; findings
inform refactors at pass boundaries. Every metz-scan bug or friction
encountered gets logged in [`metz-scan-feedback.md`](metz-scan-feedback.md)
with enough detail to file upstream GitHub issues — we are dogfooding the
tool, not just consuming it. CI (pass 4) runs metz as a non-blocking step
with the pinned version.

Corpus re-scan at pass boundaries (decided 2026-07-05): any pass that
changes compiler behavior re-runs the Tier 0 classifier at the spike SHAs
(Mastodon/Discourse/Zammad; method in
[`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md)) and diffs per-anchor
resolution against the last recorded run before acceptance. Unlike
`rake metz` this is not purely advisory: every per-anchor regression must
be either predicted by the change (as in the ANCH-amendment re-run, which
flipped exactly the 53 taxonomy-predicted pairs) or routed back as a
defect. Passes that don't touch compiler behavior (e.g. the CLI pass)
skip it.

End-of-session ritual: any session that changes the plan — and, always,
any session that completes the plan's work — rewrites the "Next step:
execution plan" section below before its final commit — one plan, covering
only the immediate next step, pointing into this file rather than
duplicating it. To make that self-enforcing, every execution plan's final
step is: rewrite this section for the work that follows. (How a fresh
session picks this up is spelled out in "Resuming a session" above.)

## Next step: execution plan

Written 2026-07-07 after P2 (harness multi-app generalization) landed. If this
section disagrees with "Next steps", Next steps wins.

Both expansion prerequisites are now done. P1 (`21505b0`): ctxpack selects
Minitest vs RSpec test-candidate families with fixture-eval coverage. P2:
`eval/tier2/harness.rb` is now driven by per-app Ruby config objects under
`eval/tier2/apps/` (`redmine.rb` reproduces Tier 2 byte-for-byte, proven by the
new offline `verify` subcommand against `eval/tier2/golden/*`; skeleton
`campfire.rb`/`lobsters.rb`/`publify.rb` load and short-circuit on 0 tasks). The
`runs.jsonl` contract, status/metric definitions, and resume semantics are
unchanged; the record gained an additive `app` field and two pre-registered
treatment-only metrics (`packet_had_test_candidate`,
`ran_suggested_test_before_first_edit`).

**Immediate next step (a fresh session should start here) — author per-app
tasks, anchors, and hidden acceptance tests for Campfire, then Lobsters, then
Publify**, one app at a time, per
[`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md).
Per app: (1) pin the SHA and prepare a low-friction template checkout (clone,
test DB, prepared untracked files) under `tmp/tier2-expansion/<app>/template`,
filling the `sha`/`prepared_files` TODOs in its config; (2) draw anchors
deterministically **before any packet exists** (`draw_anchors.rb`, seed = app
SHA, tightest-shape-first, distinct controllers, skips logged); (3) author the
4-task mix (2 feature / 1 bug / 1 behavior, feature-weighted) as frozen verbatim
files — prompts, seed patches, hidden acceptance tests; (4) capture the app's
golden prompts/schedule so `harness.rb <app> verify` guards the config the way
it does for Redmine; (5) `setup` then a small pilot; apply only mechanical
acceptance-test fixes (recorded, never weakening an assertion). This is the
delegatable unit of work per app.

After all three apps are authored and piloted: run the grid in usage-window
batches (serial, arm order alternating by round, resume via each app's
`runs.jsonl`), then analyze per the frozen per-app-then-across-apps
interpretation (including the test-pointer sub-analysis) and write
`eval/tier2-expansion/RESULTS.md`.

Final step of this plan: rewrite this section for the pass that follows the
first app's authoring (or for the grid run, if all three are authored).

## Status

| Pass | Spec | Status | Notes |
|---|---|---|---|
| 1 | [`packet-compilation.md`](specs/packet-compilation.md) | **Done** (2026-07-05) | `Ctxpack.compile(app_root:, anchor:, task:)` → internal packet object. ANCH amendment mini-pass landed same day (class-by-file matching, tolerant action grammar). 25 tests / 101 assertions green. |
| 2 | [`packet-format.md`](specs/packet-format.md) | **Done** (2026-07-05) | `Ctxpack.render_markdown` / `Ctxpack.render_manifest` over the pass 1 packet object. One review fix round (FMT-5 marker drift, Anchor labels). 34 tests / 193 assertions green. |
| 3 | [`cli.md`](specs/cli.md) | **Done** (2026-07-05) | `Ctxpack::CLI` + `exe/ctxpack` over OptionParser, wiring the pass 1/2 APIs. One review fix round (CLI-14 reminder on implicit `.ctxpack/` creation, CLI-8 anchor-only derivation test). 47 tests / 274 assertions green. |
| 4 | [`fixture-evals.md`](specs/fixture-evals.md) | **Done** (2026-07-05) | `FixtureEvalsTest` generates packet-expectation + CLI-determinism tests from `test/fixtures/evals/*.yml`; CI (`.github/workflows/ci.yml`) runs the suite on Ruby 3.2 plus a non-blocking pinned metz step. One review fix round (empty-glob guard, manifest-inclusive determinism, CI Ruby floor). 49 tests / 311 assertions green. |

Offline experiments (not conformance work, see [`eval-plan.md`](eval-plan.md)):

| Experiment | Status | Notes |
|---|---|---|
| Tier 0 anchor viability spike | **Done** (2026-07-05) | **91.0% engine-excluded average across Mastodon/Discourse/Zammad → ≥ 70% gate passes; proceed as designed.** Post-ANCH-amendment re-run: **93.9%**, zero regressions (addendum in RESULTS.md). Full method, taxonomy, and raw data in [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md). Zero compiler crashes across 1,967 real-app pairs. |
| Tier 2 agent A/B | **Done — SUPPORT** (2026-07-06) | Harness (`eval/tier2/harness.rb`) + 18-session grid + pilot run; all 20 sessions `complete`, zero aborts, 100% `task_success`. 2/3 tasks (bug-fix, behavior-change) show ≥ 30% median reduction in calls-to-first-load-bearing-read; multi-file feature (task 1) mildly worse; diff quality at ceiling (control 8.00 / treatment 7.89, agent first-pass pending author confirmation). Directional support per the frozen rule. Full analysis: [`eval/tier2/RESULTS.md`](eval/tier2/RESULTS.md). |
| Tier 2 expansion | **Pre-registration FROZEN; P1 + P2 done** (2026-07-07) | [`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md) signed off. Adds Campfire (Minitest, modern layout) + Lobsters + Publify (RSpec), 4 tasks/app (feature-weighted), test-pointer sub-analysis. P1 (RSpec test-candidate rules, `21505b0`) landed with fixture-eval coverage. P2 (harness per-app config under `eval/tier2/apps/`, offline `verify` against `eval/tier2/golden/*`, additive `app` field + two treatment-only metrics) landed; Redmine reproduced byte-for-byte. Next: author per-app tasks/anchors/acceptance tests. |

## Next steps

1. **Author per-app tasks/anchors/acceptance tests** (Campfire, then Lobsters,
   then Publify; SHA pinned + template prepared, anchors drawn pre-packet,
   golden captured for `verify`), pilot each app, then run the grid and write
   `eval/tier2-expansion/RESULTS.md`. All per
   [`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md);
   the delegatable unit is one app.
2. **(Open, non-blocking) Author-confirm the Tier 2 diff-quality scores** —
   agent first-pass in `tmp/tier2/judging/` (seed = app SHA); does not change
   the SUPPORT verdict, which rests on the exploration metric.

## Decision log

- **2026-07-07** — P2 (Tier 2 harness multi-app generalization) landed via the
  Codex delegation loop. `eval/tier2/harness.rb` is now driven by per-app Ruby
  config objects (`AppConfig`/`TaskConfig` in `eval/tier2/apps/config.rb`), one
  file per app; `redmine.rb` carries the former Redmine constants (SHA, prepared
  files, anchors, Minitest command/filter, task2 seed + failing-capture,
  scoring). Orchestrator decisions before dispatch: **Ruby config objects (not
  YAML)** — per-task scoring has real logic (task2's forbid-`test/` rule,
  acceptance-test copy) that resists declarative config; **harness stays at
  `eval/tier2/harness.rb` with Redmine's committed tree untouched**, new apps get
  their own artifact trees under `eval/tier2-expansion/<app>/`; **the
  pre-registered test-pointer sub-analysis metrics were plumbed now** (they are
  harness code). New capabilities: an offline `verify` subcommand proving app
  representability (schedule/run-ids, byte-for-byte prompts, prompt determinism,
  packet SHA-256s) against a committed `golden/` oracle; per-app `runs.jsonl`
  with an additive `app` field; `packets.json` now records `had_test_candidate`
  + `suggested_test_commands` from the packet manifest; two treatment-only
  metrics (`packet_had_test_candidate`, `ran_suggested_test_before_first_edit`).
  Skeleton `campfire`/`lobsters`/`publify` configs load and short-circuit on 0
  tasks. `runs.jsonl` schema (additive only), status meanings, existing metric
  definitions, transcript/diff artifacts, and resume semantics are unchanged.
  Session-side verification (never trusting Codex's summary): the on-disk
  `golden/` was regenerated from the **original committed harness** (`git show
  HEAD`) and confirmed byte-identical — so `verify` passing is a real
  representability proof, not circular; `harness.rb verify` prints `OK` and
  `status` lists the frozen 20 tuples; `analyze_transcript` recomputed the
  existing metrics **byte-identical to the committed records** across 4 real
  sessions (both arms, tasks 1–3), with the new metrics correct (`nil` on
  control, `false` on Redmine treatment per the `test/functional/` limitation);
  `bundle exec rake test` green (55 runs); no changes to `lib/`/`exe/`/`specs/`
  or committed Redmine artifacts. Corpus re-scan skipped per its own rule (no
  compiler behavior touched). Both expansion prerequisites (P1 `21505b0`, P2) are
  now landed; the gate is per-app task authoring.
- **2026-07-07** — P1 for the Tier 2 expansion landed: ctxpack now detects an
  RSpec test family when `spec/` plus `spec/rails_helper.rb` or `rspec-rails`
  is present, emits `rspec_candidate` entries for
  `spec/controllers/<controller>_controller_spec.rb` and path-token-matched
  `spec/requests/*_spec.rb`, ignores `spec/system/` for v0, and suggests
  `bundle exec rspec <path>`. Minitest remains the fallback family and keeps
  `bin/rails test <path>`. Specs, `design.md`, README, fixture evals, and
  implementation notes were reconciled; `accounts_upgrade_rspec.yml` covers
  the new path. P2 is now the expansion gate.
- **2026-07-06** — Tier 2 expansion pre-registration frozen (user sign-off in
  session); [`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md).
  Post-SUPPORT fork resolved as **expand** (not the compiler refactor). Verified
  app candidates via two background research agents (Minitest modern-layout hunt
  + runnable-RSpec hunt). Frozen app set: **Campfire** (`basecamp/once-campfire`,
  Minitest, modern `test/controllers/`, MIT/SQLite — fires the test-pointer rule
  Redmine's `test/functional/` layout could not) + **Lobsters** (`lobsters/lobsters`,
  RSpec, Rails 8, MariaDB-only, `spec/controllers` + `spec/requests`) + **Publify**
  (`publify/publify`, RSpec, SQLite, frictionless). Solidus considered, rejected
  for v0 (monorepo + generated-dummy-app, per-engine scoring complexity).
  Sign-off decisions: Publify over Solidus; 4 tasks/app (2 feature / 1 bug /
  1 behavior — feature-weighted to probe Tier 2's one loss, the multi-file
  `twofa` feature); RSpec extension scoped to controllers + requests (no
  `spec/system/`). Design answers three questions: multi-file-feature effect,
  test-pointer contribution (pre-registered sub-analysis splitting deltas by
  `packet_had_test_candidate`), and cross-framework generalization. Two build
  passes gate the grid — P1 (ctxpack RSpec test-candidate rules) then P2
  (harness multi-app config + `bundle exec rspec` scoring); `runs.jsonl`
  contract and metric definitions unchanged. Grid ~72 sessions
  (3 apps × 4 tasks × 2 arms × 3 runs), resumable across usage windows.
- **2026-07-06** — Tier 2 grid executed; verdict **SUPPORT** (directional).
  Harness (`eval/tier2/harness.rb`) ran the 2-session pilot then the
  18-session grid in two same-day batches (round 1, then rounds 2+3) on the
  user's subscription; all 20 sessions `complete`, zero aborts/timeouts,
  ≈10.64M grid tokens, ~44 min elapsed. No acceptance-test or harness
  amendment was needed (pilot diffs correct first try). Per the frozen rule
  (≥30% median reduction in calls-to-first-load-bearing-read or distraction,
  ≥2/3 tasks, no success/quality regression): tasks 2 (bug-fix, LBR 4→2) and 3
  (behavior, 2→1) clear the bar; task 1 (multi-file feature) is mildly *worse*
  (5→7) — the packet aids small-surface tasks and adds exploration overhead on
  spread-out feature work, the study's key nuance. `task_success` is 100% in
  both arms (saturated → non-discriminating); blind diff quality is at ceiling
  (control 8.00 / treatment 7.89, no regression) but those 0–8 scores are an
  agent first-pass (`tmp/tier2/judging/`, seed = app SHA) pending author
  confirmation, so the load-bearing claim is the exploration metric, not the
  quality gap. Pre-registered follow-up rule ("support → expand to more tasks
  and a second app") now live; task-1 regression + Redmine's structurally
  empty test-candidate pointer (`test/functional/` layout, TEST-5) make a
  modern-layout, multi-file-feature follow-up the sharpest next probe. Full
  method and tables: `eval/tier2/RESULTS.md`.
- **2026-07-05** — Tier 2 pre-registration frozen (user sign-off in session);
  full design in `eval/tier2/PREREGISTRATION.md`. Key decisions: app is
  Redmine @ `3386d959` — the only large conventional Minitest candidate
  (Tier 0 trio are RSpec; ctxpack test rules and task shape 2 assume
  Minitest); its anchor scan gave 98.2% resolution (330/336, zero crashes),
  data under `eval/tier2/{routes,results}/`. Subject pinned to Claude Code +
  Sonnet 5 — the current Sonnet is the honest strong control (same sticker
  price as older Sonnets, cheaper on intro pricing; downgrading the subject
  would inflate the packet's measured benefit; if budget ever binds, cut
  runs, not the control). Anchors drawn deterministically before any packet
  existed (`draw_anchors.rb`, seed = app SHA, skips logged). 3 runs/arm
  (18 sessions + 2-session pilot) with a pre-registered all-tasks-at-once,
  no-post-peek extension rule to 5. Grid runs on the user's Claude
  subscription: serial sessions, arm order alternating by round, batches
  resumable across 5-hour usage windows via `runs.jsonl`, throttled
  sessions recorded `aborted` + re-run (vs `timeout` = agent failure,
  metrics kept). Known limitation recorded: Redmine's `test/functional/`
  layout means packet test candidates are structurally empty — this
  instance measures code-content value, not the test pointer. Runner shape:
  a Minitest test file (`test/ctxpack/fixture_evals_test.rb`) that globs
  `test/fixtures/evals/*.yml` and defines two tests per case (packet
  expectations against the internal packet object per EVAL-5; CLI
  determinism per EVAL-7 via in-process `Ctxpack::CLI#run` with fixed
  `--out --manifest`, SHA-256 over both artifacts), so `bundle exec rake
  test` runs Tier 1 with zero extra wiring and EVAL-11 re-runnability holds
  by construction. First CI workflow authored: push/PR, Ruby 3.2 (the
  gemspec floor; local dev covers newer), `rake test`, plus the
  non-blocking metz step pinned to 0.4.0. Session-side review confirmed one
  defect, fixed in one `--resume` round: an empty case-file glob silently
  defined zero tests — CI would stay green with the whole Tier 1 net gone
  — now a load-time raise; the same round removed a redundant
  `bundle install` CI step, made determinism manifest-inclusive, and moved
  the CI Ruby pin to the floor. The fix round hit the known stale-"running"
  failure mode (work complete, log dead ~29 min); record cancelled after
  session-side verification per the playbook. Corpus re-scan skipped per
  its own rule (no compiler behavior touched). Metz split refactor weighed
  at the pass boundary per plan: stays deferred — pass 4 added zero lines
  to `lib/`, so pressure is unchanged; re-weigh at the next pass that
  touches the compiler. Suite: 49 tests / 311 assertions green.
- **2026-07-05** — Pass 3 landed via the Codex delegation loop. OptionParser
  chosen over Thor at pass start (spec doesn't demand Thor; keeps prism the
  only runtime dependency). `Ctxpack::CLI#run(argv)` behind a thin
  `exe/ctxpack`, with injectable stdout/stderr/cwd/clock for in-process
  tests; gemspec ships the executable. Session-side review verified all 19
  CLI requirements and confirmed one defect, fixed in one `--resume` round:
  the CLI-14 gitignore reminder was skipped when `.ctxpack/` was created
  implicitly as a parent (e.g. `--dir .ctxpack/sub`) — directory creation
  now compares `.ctxpack/` existence before/after instead of matching
  created dirnames. The same round added the missing CLI-8 anchor-only
  derivation test. Corpus re-scan skipped per its own rule (no compiler
  behavior touched). Suite: 47 tests / 274 assertions green.
- **2026-07-05** — Eval platforms (promptfoo, Langfuse, Braintrust) evaluated
  and deferred. Rationale: Tiers 0/1 have no LLM output to score — their value
  is being boring, deterministic, and CI-native (EVAL-8) — and Tier 2's
  metrics are custom mechanical scorers over transcripts and diffs that no
  platform provides; what a platform would add (run storage, comparison UI)
  doesn't pay for itself at 18–30 pre-registered sessions, and
  prompt-iteration-oriented tooling pressures against the pre-registered
  discipline. Revisit trigger: the eval-plan decision rule "Tier 2 support →
  expand to more tasks and a second app," when bookkeeping pain is real and
  specific. If adopted then, Braintrust is the closest fit (experiment/dataset
  model, custom scorers); promptfoo is the weakest (prompt-matrix testing;
  the wrapper prompt is fixed across arms by design). Hedge adopted now
  instead: the Tier 2 harness emits a stable JSONL run record per session
  (recorded in `eval-plan.md`, Tier 2 setup), so any later platform adoption
  is an import problem, not a redesign.
- **2026-07-05** — Three feedback-loop decisions adopted (in-session
  discussion): (a) the corpus re-scan is now a standing pass-boundary step
  for compiler-behavior changes (mechanics in "Working process" above) —
  it had already run twice as habit and paid off both times; (b) pass 4's
  eval runner must be designed re-runnable at any SHA, and the Tier 2
  harness follows the same principle, so Tier 2 becomes a repeatable
  usefulness-regression check at release boundaries rather than a one-shot
  gate; (c) packet-vs-diff coverage — files the completed task actually
  touched vs. files in the packet, read as recall/precision — is the
  post-v0 north-star metric and the designated evidence source for
  validating the LIM-1 limits. No telemetry or `ctxpack feedback` command
  gets built until real usage exists to measure. Reconciled into the durable
  docs in the same change: EVAL-11 (re-runnable runner) added to
  `specs/fixture-evals.md`; `design.md` ("Simple v0 evals", "v0 packet
  limits") and `eval-plan.md` (Tier 0 classifier reuse, Tier 2 re-runnable
  harness) updated to match.
- **2026-07-05** — Pass 2 landed via the Codex delegation loop.
  `Ctxpack.render_markdown` / `Ctxpack.render_manifest` render the pass 1
  packet object; snippets are read at render time from `packet.app_root`
  (new read-only packet metadata, excluded from the manifest); the manifest
  is `JSON.pretty_generate(packet.to_h)`. Session-side review confirmed two
  defects, fixed in one `--resume` round: the FMT-5 truncation marker now
  derives its line count from `Compiler::LIMITS[:max_snippet_lines_per_file]`
  (LIM-1 values are provisional, a hardcoded "120" would drift), and the
  Anchor section's mislabeled lines were split into correctly labeled
  Anchor/Controller/Action lines. Known coupling recorded in
  `implementation-notes.md`: the renderer's test-candidate Why templates
  match the compiler's stored `why` strings exactly. Suite: 34 tests /
  193 assertions green.
- **2026-07-05** — metz-scan adopted as an advisory dev linter on ctxpack's
  own `lib/` (dogfooding; mechanics in "Working process" above): pinned
  0.4.0, `rake metz`, Metz-only via committed `.rubocop.yml`, never gating.
  Explicitly *not* a packet-content integration — that idea is deferred
  post-v0, gated on Tier 2 evidence. Day-one dogfooding filed
  [metz-scan#31](https://github.com/fuentesjr/metz-scan/issues/31)
  (full-suite default noise) and
  [metz-scan#32](https://github.com/fuentesjr/metz-scan/issues/32)
  (Metz/Metrics duplication); log in `metz-scan-feedback.md`.
- **2026-07-05** — ANCH amendment mini-pass landed (in-session TDD, per the
  prior decision): ANCH-1 action grammar tolerates trailing `?`/`!` and
  leading `_`; ANCH-2/3 switched to class-by-file matching (first class in
  the resolved file matching the anchor path underscore-insensitively);
  TEST-1 action tokens normalized as a grammar ripple. Specs, `design.md`,
  and the Tier 0 classifier's error-message mapping reconciled in the same
  change. Suite: 25 tests / 101 assertions green. Classifier re-run at the
  spike SHAs confirmed the prediction: 93.9% average (Mastodon 94.8 /
  Discourse 96.4 / Zammad 90.4), exactly the 53 taxonomy-predicted pairs
  flipped, zero per-anchor regressions, zero crashes — addendum in
  `eval/tier0/RESULTS.md`.
- **2026-07-05** — Both Tier 0-surfaced ANCH amendments adopted: (a)
  class-by-file matching (51/169 spike failures were acronym-inflection
  class-name mismatches with the literal `def <action>` present — the
  acronyms live in per-app `inflections.rb` initializers, unreachable
  without booting, so the fix is to trust the resolved file's class rather
  than guess its name); (b) ANCH-1 grammar admits `?`/`!`-suffixed and
  `_`-prefixed actions (2 real routed actions rejected). To be implemented
  in-session as a mini-pass before pass 2 — a deliberate deviation from the
  Codex delegation loop, which is reserved for full spec passes.
- **2026-07-05** — Tier 0 spike executed per the pre-registered plan:
  91.0% engine-excluded average (Mastodon 92.2 / Discourse 96.3 /
  Zammad 84.4) → gate passed, vertical slice proceeds unchanged. Route
  tables came via the plan's documented fallback (stubbed `routes.rb` eval
  against real actionpack, no app boot); limitations recorded in
  `eval/tier0/RESULTS.md`. Failure taxonomy promoted two candidate spec
  amendments (class-by-file matching, ANCH-1 action grammar) into next
  steps — recommendations only, not gate-forced rework.
- **2026-07-05** — Specs README reordered to dependency/build order
  (compilation → format → CLI → evals) and a "Cross-spec contracts" section
  added (packet object schema, code registries, repo stamp timing, root/task
  as inputs, fixture dual-use).
- **2026-07-05** — CB-2 amended: literal `only:`/`except:` filters now include
  single symbol/string literals, not just arrays — the array-only rule pushed
  the dominant Rails style (`only: :upgrade`) into uncertainty notes.
  `design.md` reconciled.
- **2026-07-05** — CB-4 amended: "list names of callbacks declared outside the
  controller file" was unimplementable (v0 never reads superclasses/concerns);
  now scoped to in-file declarations whose method has no direct definition in
  the file. FMT-7's `unresolved_external_callbacks` row and `design.md`
  reconciled.

## Known debt / open questions

- LIM-1 values (8/4/2/120) are unvalidated guesses until Tier 0/Tier 2 produce
  evidence (tracked in `design.md`). Long-term, packet-vs-diff coverage is the
  designated evidence source (decision log 2026-07-05).
- The `max_total_files` guard is untested because it is unreachable by v0
  construction (see `implementation-notes.md`).
- Generic validators that auto-load every `*_test.rb` will trip over the
  static fixture tests under `test/fixtures/apps/`; the Rake task excludes
  them deliberately (TEST-4: content is never read).
- metz-scan baseline (2026-07-05, advisory; re-scanned at the pass 3
  boundary): `Ctxpack::Compiler` is flagged `ClassesTooLong` [504/100],
  `MarkdownRenderer` [216/100], and now `Ctxpack::CLI` [145/100], plus long
  methods across all three. Splitting the compiler (e.g. callbacks /
  constants / test-candidates collaborators) remains the highest-pressure
  candidate refactor to weigh at a pass boundary, not mid-pass; the class
  will grow again when future reason codes land. Weighed at the pass 4
  boundary: deferred (pass 4 added zero lines to `lib/`); re-weigh at the
  next compiler-touching pass.
