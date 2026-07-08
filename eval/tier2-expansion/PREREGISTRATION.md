# Tier 2 expansion — pre-registration

**Status: FROZEN 2026-07-06 (user sign-off in session).** Apps, task mix,
metrics, the test-pointer sub-analysis, and interpretation rules below are
fixed; only the recorded amendment discipline applies. The two prerequisite
build passes (P1, P2) are ordinary engineering and may evolve until they land,
but their delivered SHAs are recorded before the grid runs. This extends the
frozen [`../tier2/PREREGISTRATION.md`](../tier2/PREREGISTRATION.md) under
`eval-plan.md`'s decision rule *"Tier 2 support → expand to more tasks and a
second app; only then consider Rubydex-backed resolution, judged by the same
harness."* Tier 2 returned directional SUPPORT
([`../tier2/RESULTS.md`](../tier2/RESULTS.md)); this experiment widens the
evidence and closes two questions Tier 2 raised but could not answer. Nothing
here is fixed until sign-off; on freeze it inherits the parent's amendment
discipline (every post-freeze change recorded, no assertion weakened after any
agent output exists).

## Why (questions Tier 2 left open)

1. **Does the packet help or hurt *multi-file* feature work?** Tier 2's single
   feature task (`twofa#deactivate_init`) was the one task where treatment did
   *worse* (median calls-to-first-load-bearing-read 5 → 7). n=1 per cell can't
   tell a real effect from noise. This experiment weights the task mix toward
   multi-file features to turn that into a signal.
2. **Does the test-candidate pointer add value?** Redmine's pre-Rails-5
   `test/functional/` layout meant ctxpack's test-candidate rule (TEST-1)
   never fired, so Tier 2 measured only the packet's file/constant/callback
   content. `eval-plan.md` flags this exact confound: *"agents mainly need the
   test pointer" vs "agents need the whole packet" imply very different v1s.*
   Modern-layout apps let the pointer fire, isolating its contribution.
3. **Does the Tier 2 result generalize** beyond one app and one test
   framework? Most of the mature Rails ecosystem is RSpec; a usefulness claim
   that only holds on one Minitest app is weak.

## Prerequisites (must land and be recorded before any expansion grid session)

These are ordinary spec/harness work (Codex-delegated per the working
process), not part of the frozen experiment, but the grid cannot run without
them and their SHAs are recorded in every run record.

- **P1 — ctxpack RSpec test-candidate rules.** Today TEST-1..6 key on Minitest
  paths only (`test/controllers/<ctrl>_controller_test.rb`,
  `test/integration/*_test.rb`, `minitest_candidate` reason,
  `bin/rails test <path>` command). Add an analogous RSpec family: framework
  detection (RSpec when `spec/` + `rails_helper.rb`/rspec-rails present),
  `spec/controllers/<ctrl>_controller_spec.rb`, `spec/requests/*_spec.rb`
  (RSpec's request specs — the modern integration analog), an
  `rspec_candidate` reason code, and a `bundle exec rspec <path>` suggested
  command. **v0 scope: controllers + requests only** — `spec/system/*_spec.rb`
  is out (slow, browser-dependent). This is a real product
  capability (the tool must serve RSpec apps to be broadly useful), specced
  and reviewed like any pass, with fixture-eval coverage before it feeds the
  experiment. **Framework choice is per-app and deterministic** (detected from
  the checkout), not a flag.
- **P2 — harness generalization to multiple apps.** `harness.rb` currently
  hardcodes Redmine specifics (single `APP_SHA`, `PREPARED_FILES`, `ANCHORS`,
  `bin/rails test` scoring, one seed patch). Introduce a per-app config
  (pinned SHA, prepared untracked files, anchors, task set, seed patches,
  acceptance tests, and a scoring command — `bin/rails test` vs
  `bundle exec rspec`). The re-runnable contract, `runs.jsonl` schema,
  abort/timeout rules, sterile `CLAUDE_CONFIG_DIR`, and metric definitions are
  unchanged; only app-parameterization is added. Redmine's Tier 2 results
  remain valid and are not re-run.

## Apps (candidates — final pick at sign-off)

All pinned to a commit SHA, recorded verbatim. Each must clone, prepare a test
DB, and run its acceptance suite in a fresh scoring checkout with low friction
(the Tier 2 constraint). Verified framework/layout/runnability from repo
Gemfiles, `spec/`|`test/` listings, and CI files (2026-07-06).

| App | Framework / layout | Why | Runnability |
|---|---|---|---|
| **Campfire** (`basecamp/once-campfire`) | Minitest, **modern** `test/controllers/` (30) | Fires the Minitest test-pointer rule that Redmine could not; real ActionCable chat app | **High** — MIT, SQLite, pure `fixtures :all`, `bin/rails test` (Redmine-like zero friction) |
| **Lobsters** (`lobsters/lobsters`) | RSpec, `spec/controllers/` + `spec/requests/` | Primary RSpec app; 43 controllers, real domain (stories/comments/mod) | **High** — Rails 8, MariaDB-only (no Redis/ES), CI runs plain `bundle exec rspec` |
| **Publify** (`publify/publify`) | RSpec, `spec/controllers/` | Second RSpec app | **High** — SQLite, no Redis, ~10–15 controllers, smaller but frictionless |

**Frozen app set: Campfire + Lobsters + Publify** — all three run trivially and
all fire the controller-test/-spec rule. Solidus was considered and rejected
for v0 (its monorepo + generated-dummy-app, per-engine scoring adds harness
complexity for marginal gain); it stays a candidate for any later widening.
Redmine (Tier 2, Minitest old-layout) stays in the analysis as the
code-content-only baseline.

## Task shapes and mix

Same three shapes as `eval-plan.md`, **weighted toward multi-file features** to
answer question 1. Per app, propose **4 tasks: 2 feature + 1 bug-fix +
1 behavior-change** (vs Tier 2's 1/1/1). Feature tasks are chosen to genuinely
span files (controller + model/service + mailer/view/locale), the regime where
Tier 2 saw the packet struggle. Task prompts, seed bugs, and hidden acceptance
tests are authored per app before any run, frozen as verbatim files, exactly as
in Tier 2.

## Anchor selection

Unchanged method: deterministic draw from each app's route table
(`draw_anchors.rb`, seed = that app's pinned SHA), **before any packet is
generated or read**, tightest-shape-filter-first, distinct controllers, every
skip logged. Per-app anchor sets committed alongside the tasks.

## Arms

Identical to Tier 2 and unchanged: same wrapper prompt; control =
`{context_block}` empty, treatment = the inline packet. Packets generated once
per task by `ctxpack packet` (now framework-aware via P1) from the recorded
ctxpack SHA, SHA-256 recorded, identical bytes across a task's treatment runs.

## Metrics

Identical mechanical definitions to Tier 2 (`task_success`,
`calls_to_first_load_bearing_read`, `distraction_reads`, `discarded_edits`,
`total_tool_calls`, `total_tokens`, `wall_time_s`) plus the same blind 0–8
diff-quality rubric (four dimensions, arm labels stripped, seeded shuffle,
author-judged).

**Added, pre-registered — test-pointer sub-analysis (question 2).** For every
treatment session, record two booleans from the packet actually shown:
`packet_had_test_candidate` (did TEST rules resolve ≥1 test file) and, on the
apps where it fires, whether the agent ran a suggested test command before its
first load-bearing edit (from the transcript). Report exploration/success
deltas split by `packet_had_test_candidate` so a "wins concentrate on the test
pointer" effect is visible rather than hidden — the `eval-plan.md`
test-suggestion-confound record made observable.

## Pre-registered interpretation

The parent rule is applied **per app** (support if, in ≥ 2 of that app's tasks,
treatment shows ≥ 30% median reduction in calls-to-first-load-bearing-read or
distraction reads, with no regression in success rate or diff quality), then
read across apps:

- **Generalizes:** the per-app support bar is met on a majority of the new apps
  (≥ 2 of 3), across both frameworks.
- **Feature-specific caveat confirmed/refuted:** compare feature-task deltas to
  bug/behavior-task deltas pooled across apps — does the Tier 2 "packet hurts
  multi-file features" pattern hold with more instances, or was it noise?
- **Test-pointer contribution:** from the sub-analysis — are the wins present
  (or larger) when the packet carried a test candidate?

At 3 runs/arm/task this remains directional evidence, not statistics. The
parent's all-tasks-at-once, no-post-peek extension-to-5 rule carries over.

## Runs and budget

3 runs/arm/task (extension-to-5 rule inherited). Grid size at the recommended
3 apps × 4 tasks × 2 arms × 3 runs = **72 sessions** (+ small per-app pilots).
Tier 2 calibration: ~1–2 min/session, ~0.6M tokens/session median → order
**~30–45M tokens, ~2–3 h wall** across the whole expansion, resumable across
usage windows via `runs.jsonl` exactly as before. Serial, pre-registered order,
arm order alternating by round, per app.

## Threats to validity (this instance)

Inherits Tier 2's (author bias, agent nondeterminism, model drift,
single-app→now-multi-app generalization, read-tool-only counting). New:

- **Two frameworks, one tool maturity gap.** RSpec test-candidate support (P1)
  is new code; a weak RSpec result could reflect an immature rule, not a real
  null. Mitigation: fixture-eval coverage for the RSpec rules before the grid,
  and the sub-analysis separates test-pointer effects from content effects.
- **App heterogeneity.** Different apps have different baseline difficulty; the
  A/B *within* an app controls for this, but cross-app pooling is descriptive,
  not inferential.
- **Author-authored tasks across 3 new apps** amplify task-selection bias;
  mitigated by pre-packet anchor draws and hidden acceptance tests, not
  eliminated.

## Decisions resolved at sign-off (2026-07-06)

1. **Third app:** Publify (not Solidus) — frictionless wins over realism for
   v0; Solidus deferred to any later widening.
2. **Task count:** 4 per app (2 feature / 1 bug / 1 behavior) — the extra
   feature instances are the point.
3. **RSpec extension scope (P1):** controllers + requests only;
   `spec/system/` out of scope for v0.
4. **Solidus monorepo:** out of scope, to keep per-engine scoring out of the
   harness.

## Amendments (post-freeze)

Recorded per the inherited amendment discipline. None weakens an assertion or
changes the frozen design (apps, task mix, metrics, interpretation); all are
operational/robustness decisions. Full detail in `PROJECT_TRACKER.md`.

- **2026-07-07 — Lobsters authored (user-approved read of the CLAUDE.md).**
  Pinned SHA `430d864b…`, Ruby 4.0.0, local MariaDB. Lobsters ships a committed
  `CLAUDE.md`/`AGENTS.md` forbidding LLM *contributions*; the user confirmed this
  is PR-scoped and does not cover offline benchmark use (pinned read-only
  checkout, subject diffs discarded, nothing sent upstream). Those files are
  neutralized in the sterile workspaces (new additive `remove_files` config) so
  the subject session sees the task, not the repo's agent policy — also removing
  an A/B confound. Anchors were drawn blind before this (`anchors.json`).
- **2026-07-07 — Scoring timeout (`SCORE_TIMEOUT_S`, 6 min).** Additive harness
  robustness: a subject diff can leave the app in a non-terminating state for the
  acceptance test (Lobsters `users#standing` base loops on a `.json` request). A
  scoring run past the bound is killed and scored `false` (the correct outcome
  for an unimplemented task) rather than wedging the serial grid. Metric
  definitions and `runs.jsonl` schema unchanged; Redmine/Campfire scoring never
  reaches the bound.
- **2026-07-08 — Third app is `publify/publify_core` (the engine), not
  `publify/publify` (the deploy app); user-approved.** Discovered at template
  prep that the Publify *deploy app* is a thin shell — its only app controller is
  `application_controller.rb`; the 31 real controllers live in the `publify_core`
  engine gem (the frictionless-monolith premise behind picking Publify over
  Solidus was false for the deploy app). Rather than drop to two apps or take
  monolithic Publify v8 (ancient Rails), the user chose to pin the **engine repo**
  `publify_core` v10.0.3 (commit `80ede867`) — a self-contained single engine
  with a committed `spec/dummy` app, SQLite, and RSpec (milder than the multi-gem
  Solidus monorepo the pre-reg rejected). This does **not** weaken any frozen
  assertion (apps=3, 2 feature / 1 bug / 1 behavior, metrics, interpretation
  unchanged); it changes only the third app's identity and adds three additive,
  benchmark-only template shims, none of which touch ctxpack compiler behavior or
  the `runs.jsonl`/metric contract: (a) a stub `config/application.rb` that only
  satisfies ctxpack's app-root discovery (`File.file?`), never booted (RSpec
  loads `spec/dummy/config/environment`); baked into the workspace baseline so it
  never appears in a subject diff; (b) a `concurrent-ruby 1.3.4` pin in the
  Gemfile (>= 1.3.5 dropped the implicit `require "logger"` Rails 6.1 needs);
  (c) prepared `Gemfile.lock` + dummy-app `test.sqlite3` (both gitignored
  upstream). The route table is built by running `bin/rails routes` from
  `spec/dummy` with `BUNDLE_GEMFILE` pointed at the engine Gemfile (the engine's
  non-isolated routes draw into the dummy host app). Anchors were drawn blind
  from the resulting route table (`anchors.json`, seed = the engine SHA) before
  any packet was inspected. All four anchors fire `had_test_candidate=true`
  (4/4, like Campfire; the within-app test-pointer contrast still comes from
  Lobsters' 2/2). Redmine/Campfire/Lobsters `verify` remain OK (no harness
  contract change).

## Sign-off

- [x] User approves apps, task mix, and the two prerequisite passes (2026-07-06)
- [x] P1 (ctxpack RSpec rules) landed + fixture-eval covered; SHA `21505b0`
      (the packet-generation `ctxpack_sha` recorded per run captures it at grid time)
- [x] P2 (harness multi-app generalization) landed (2026-07-07); Redmine
      reproduced byte-for-byte via `harness.rb verify` against `eval/tier2/golden/*`
- [x] Per-app tasks/anchors/acceptance tests authored and frozen (Campfire +
      Lobsters + Publify, all red-green validated session-side; 2026-07-08)
- [x] Pilot per new app + grid per the execution rules (all 72 grid sessions +
      6 pilots complete; 2026-07-08)
- [x] Analysis + `RESULTS.md` per the interpretation rules
      ([`RESULTS.md`](RESULTS.md); verdict SUPPORT/generalizes; blind
      diff-quality pass flagged as pending follow-up)
