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

Written 2026-07-05, updated same day after the Tier 2 pre-registration was
frozen (user sign-off in session). If this section disagrees with "Next
steps", Next steps wins.

The pre-registration is FROZEN at `eval/tier2/PREREGISTRATION.md` — app
(Redmine @ pinned SHA), anchors (deterministic draw, committed), task
prompts, acceptance tests, arms, metrics, run counts, and the JSONL
run-record schema are all fixed. Only its explicit amendment rules apply
from here. Remaining work:

1. Build the harness to the re-runnable contract (decision log 2026-07-05)
   and the frozen execution rules: scripted arms, serial pre-registered
   order with alternating arm order per round, resumable via
   `eval/tier2/runs.jsonl` (skip `status: "complete"` tuples), abort vs
   timeout handling, sterile `CLAUDE_CONFIG_DIR`, workspaces from the
   pinned Redmine SHA (task 2 plus seed patch), packets generated once per
   task with recorded SHA-256.
2. Run the 2-session pilot (task 2, both arms, `pilot: true`); record
   per-session usage-window consumption for batch sizing; apply any
   mechanical acceptance-test fixes under the pre-registration's amendment
   rule (allowed only before grid sessions).
3. Run the 18-session grid in usage-window-sized batches, blind-judge the
   diffs per the frozen rubric, analyze per the pre-registered
   interpretation, write `eval/tier2/RESULTS.md`.
4. Close with the end-of-session ritual: update Status/Next steps/Decision
   log here, rewrite this section for what follows (v0 wrap-up or the
   compiler split refactor, depending on the Tier 2 verdict), ask before
   committing.

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
| Tier 2 agent A/B | **Pre-registration FROZEN** (2026-07-05) | `eval/tier2/PREREGISTRATION.md` signed off: Redmine @ `3386d959` (98.2% anchor resolution, 330/336), Claude Code + Sonnet 5 pinned, anchors drawn deterministically pre-packet (`twofa#deactivate_init` / `my#show_api_key` / `roles#create`), 3 runs/arm + pilot, subscription-window-aware execution rules. Next: build harness, pilot, grid. |

## Next steps

1. **Tier 2 agent A/B** (offline, `eval-plan.md`) — all gates cleared; the
   only remaining v0 work item. Pre-registered experiment, not a spec pass:
   the Codex delegation loop does not apply. Harness contract: re-runnable
   (pinned agent setup, scripted arms, recorded SHAs), one JSONL run record
   per session.

## Decision log

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
