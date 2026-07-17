# AGENTS.md — operating manual for coding agents

Canonical instructions for any coding agent (Claude Code, Codex, or other)
working in this repository. `CLAUDE.md` is a thin adapter that points here.
Precedence: explicit task instructions > this file > general habits.

ctxpack is a small Ruby gem: a deterministic CLI that compiles a Rails
`controller#action` anchor into a Markdown "context packet" for AI coding
agents. It is v0, spec-driven, and evidence-gated — the specs and the
pre-registered experiments are as load-bearing as the code.

## Primary session role: orchestrator-DRA

The primary session agent is the **orchestrator-DRA (Directly Responsible
Agent)**. It remains accountable for the project outcome: scope, sequencing,
routing, conflict resolution, verification, acceptance, tracker continuity,
and the final response.

- Handle simple work directly. When the user or the tracker invokes
  agenticons, dispatch focused work to the named Agenticons subagents and keep
  orchestration shallow; subagent output is advisory until the orchestrator-DRA
  accepts it.
- Never trust a delegate's summary as verification. Read the resulting diff,
  run the repository gates session-side, and route confirmed defects back for
  correction before acceptance.
- Preserve cross-repository boundaries and approval gates. The
  orchestrator-DRA may coordinate work across repositories, but committing,
  pushing, publishing GitHub text, dependencies, and other guarded side
  effects still require the approvals defined below.
- Keep `PROJECT_TRACKER.md` authoritative and reconcile its execution plan at
  every completed or redirected work boundary.

## Project map

| Path | What it is | Editability |
|---|---|---|
| `lib/ctxpack/` | The gem. `compiler.rb` (seed(s) → packet object), `git_recon_history_provider.rb` (optional companion → typed history), `markdown_renderer.rb` + `manifest_renderer.rb` (packet → artifacts), `cli.rb` (OptionParser CLI), `packet.rb`, `default_constant_resolver.rb` | Normal code; spec-governed |
| `exe/ctxpack` | Thin executable over `Ctxpack::CLI` | Normal |
| `specs/` | **Normative** v0 requirements with stable codes (`ANCH-1`, `FMT-5`, `CLI-14`, `EVAL-9`, …). Read `specs/README.md` first: dependency order, cross-spec contracts | Amend only with `design.md` reconciled in the same change; never renumber codes |
| `design.md` | Rationale and tradeoffs behind the specs | Must stay reconciled with `specs/` |
| `eval-plan.md` | Three-tier evaluation plan and decision rules | Frozen thresholds; touch only with user sign-off |
| `test/ctxpack/` | The Minitest suite (the only tests that run) | Normal |
| `test/fixtures/apps/` | Static Rails-shaped fixture trees (`minitest_basic/`, `rspec_basic/`). Inert scaffolding — never booted, never loaded by the suite | Extend for new cases; never add runnable test code |
| `test/fixtures/evals/` | Tier 1 YAML eval cases (EVAL-4 shape); the runner generates two tests per case | Grows with every packet bug (EVAL-9) |
| `eval/tier0/`, `eval/tier2/`, `eval/tier2-expansion/` | Offline experiments: pre-registrations, harness, recorded results, transcripts, diffs | **Recorded data — see "Caution" below** |
| `eval/README.md` | **Eval tooling inventory + binding authoring rule**: before writing any new eval/measurement script, check the inventory and record which existing runner was considered and why it doesn't fit; shared spike plumbing in `eval/lib/spike_harness.rb` (future spikes only — never retrofit measured ones) | Keep the inventory current when adding a runner |
| `PROJECT_TRACKER.md` | Working process, execution plan, status, decision log. Fresh sessions resume from here | Update per its own end-of-session ritual |
| `implementation-notes.md` | Per-pass technical decisions | The implementing agent owns pass notes |
| `.agents/skills/` | Mostly the gitignored install root of the `skills` npm CLI (`npx skills`, which owns `skills-lock.json`); four repo-owned skills are carved out in `.gitignore` and committed | Edit only the four carved-out skills |
| `.claude/skills/` | Symlinks into the carved-out `.agents/skills/` dirs | Symlinks only, no copies |
| `tmp/` | Gitignored scratch: Tier 2 workspaces, judging artifacts, `tmp/tier2/claude-config/` (**authenticated credentials — never read out or commit**) | Scratch |
| `docs/agent-learnings/` | Learning notes written by the `extract-approach` skill | Append |

## Setup / build / test / lint

```sh
bundle install              # deps: prism (runtime), minitest + rake (dev)
bundle exec rake test       # the whole suite; also the default rake task
bundle exec rake metz       # ADVISORY design-pressure scan of lib/ — never gates
ruby -Ilib exe/ctxpack packet <anchor> --task "..."   # CLI smoke, from a Rails-shaped dir
ruby eval/tier2/harness.rb status                     # Tier 2 grid state (offline experiments)
```

- There is **no style linter and no typecheck**. `.rubocop.yml` exists only to
  scope `rake metz` to Metz cops — do not add style cops or a RuboCop gate.
- CI (`.github/workflows/ci.yml`): `bundle exec rake test` on Ruby 3.4 (the
  gemspec floor) plus a non-blocking metz step pinned to metz-scan 0.4.0.
  Local dev may run newer Ruby; code must stay 3.4-compatible.

### Required before claiming success

1. `bundle exec rake test` in this session, whole suite, **0 failures** —
   paste the summary line (e.g. `55 runs, ... 0 failures, 0 errors`). Never
   claim green from a partial run or from memory.
2. If the change altered **compiler behavior** (resolution, callbacks,
   constants, test candidates, limits): run the corpus re-scan
   (`.agents/skills/tier0-corpus-rescan/SKILL.md`) or state explicitly that
   you are deferring it to the pass boundary and why.
3. If the change fixed a **packet bug**: a new YAML eval case exists and was
   red before the fix (`.agents/skills/add-fixture-eval/SKILL.md`).
4. If behavior, API, or workflow changed: the spec, `design.md`, `README.md`,
   and `PROJECT_TRACKER.md` say the same thing as the code.
5. After every non-trivial solved problem, run the **extract-approach** skill
   (`.agents/skills/extract-approach/SKILL.md`) before moving on. A solution
   without its learning note is unfinished work.

## Architecture conventions

- **Layers are one-directional** (specs/README.md): compilation
  (`compiler.rb`) → format (`markdown_renderer.rb`, `manifest_renderer.rb`) →
  CLI (`cli.rb`). Fixture evals exercise the whole. Never make a lower layer
  reach up.
- **The internal packet object is the central contract**: compilation
  produces it, renderers consume it, the manifest serializes it (MAN-2 is its
  de facto schema), eval cases assert on it (EVAL-5). Anything a renderer
  needs must exist on the packet object when compilation finishes.
- **Reason/uncertainty codes are registries** (FMT-6/FMT-7 in
  `specs/packet-format.md`). Never invent a code inline; adding one is a spec
  change (spec + `design.md` in the same commit).
- **Determinism is a feature** (DET codes): same input → byte-identical
  output. No timestamps, no absolute paths, no hash-ordering leaks in packet
  content. The only repo-state marker allowed inside a packet is the repo
  stamp (FMT-10..12).
- **Derive, don't duplicate, limit values**: renderer text that mentions a
  source or history limit reads `Ctxpack::Compiler::LIMITS`, never a literal
  (the FMT-5 "120" drift was a real review defect). History limits are
  independent and never consume `max_total_files`.
- **Dependency policy**: `prism` is the **only** runtime dependency, by
  design. Adding any dependency (runtime or dev) requires explicit user
  approval first. OptionParser was deliberately chosen over Thor.
- **Public API**: `Ctxpack.compile(app_root:, anchor:, seeds:, task:, constant_resolver:, history_provider:)`,
  `Ctxpack.render_markdown`, `Ctxpack.render_manifest`, `Ctxpack::CLI#run(argv)`
  with injectable stdin/stdout/stderr/cwd/clock/history provider. Keep new seams
  injectable the same way.
- **v0 non-goals are binding** (`design.md`): no embeddings/RAG, no Rails
  boot, no engines, no inherited/concern/metaprogrammed action resolution, no
  route-string parsing, no LLM anywhere in packet construction or Tier 1 evals.

## Testing conventions

- Minitest only. Suite pattern is `test/ctxpack/**/*_test.rb` — fixture-app
  test files under `test/fixtures/apps/` are deliberately excluded and must
  stay excluded (they are static scaffolding whose content ctxpack never reads).
- Red-green-refactor for behavior changes and bug fixes: write the failing
  test first, watch it fail for the right reason, make the smallest change
  that passes.
- Tests assert observable behavior (packet object fields, manifest JSON,
  rendered artifacts, CLI exit status/streams), not implementation internals.
- CLI tests run in-process via `Ctxpack::CLI#run` with injected streams — do
  not shell out to `exe/ctxpack` in tests.
- Every packet bug becomes a YAML eval case (EVAL-9) — see the
  `add-fixture-eval` skill. The eval runner raises at load time if the case
  glob is empty; never delete the last case.

## Cross-repo eval process (evalkit)

This repo participates in the process defined in `~/Projects/evalkit`
(shared vocabulary, required artifacts, convergence ledger). Binding rules:

- New evals follow evalkit's artifact discipline: pre-registration frozen
  before measurement (with the reuse line from `eval/README.md`'s authoring
  rule), RESULTS against pre-registered gates, an inventory entry, provenance.
- When `eval/README.md`'s inventory changes — new runner, or an existing
  capability changes shape — update `~/Projects/evalkit/LEDGER.md` in the
  same piece of work.
- `eval/tier2/harness.rb` sits at the ledger's extraction bar. If a task
  requires materially changing it, stop: the recorded trigger says extract
  the shared plumbing into evalkit instead of forking further, as its own
  reviewed work order — never as a side effect, and never retrofitted onto
  already-measured runners.

## Common failure modes — and the rules that prevent them

These are mistakes a capable-but-hasty agent will make in *this* repo. Each
rule is checkable.

1. **Citing Tier 1 as evidence the tool is useful.** Tier 1 is circular by
   design (EVAL-1). Rule: never write "the evals show packets help" from
   Tier 1; usefulness claims cite `eval/tier2*/RESULTS.md` only.
2. **Wiring Tier 0/Tier 2 into CI.** EVAL-10 forbids it. Rule: CI runs
   `rake test` and advisory metz, nothing else.
3. **"Fixing" the Rakefile test pattern to include fixture tests.** Rule: the
   pattern stays `test/ctxpack/**/*_test.rb`; fixture `*_test.rb` files must
   not be loadable (no `test_helper` requires in them).
4. **Editing recorded experiment data.** `eval/*/runs.jsonl`, `transcripts/`,
   `diffs/`, `results/`, `RESULTS.md` tables are recorded evidence. Rule:
   append via the harness or add clearly-marked addenda; never rewrite rows.
5. **Adjusting a frozen pre-registration after seeing data.**
   `eval/*/PREREGISTRATION.md` thresholds/prompts/metrics are frozen at
   sign-off. Rule: only mechanical amendments recorded in the file's own
   amendment section, pre-grid, with user sign-off.
6. **Renumbering or reusing spec requirement codes.** Rule: codes are
   append-only; retired ones are marked *Withdrawn* in place.
7. **Amending a spec without `design.md` (or vice versa).** They must not
   disagree (specs/README.md). Rule: spec + design change in the same commit,
   or neither.
8. **Adding a dependency to "clean things up."** Rule: no new gems without
   the user's explicit yes; prism stays the only runtime dep.
9. **Hardcoding limit values in renderer prose.** Rule: read
   `Compiler::LIMITS`; grep for literal `120`/`8`/`4`/`2` near renderer
   strings before landing.
10. **Editing installed skills.** Everything in `.agents/skills/` except the
    four carved-out dirs in `.gitignore` is gitignored and managed by the
    `skills` npm CLI (`npx skills`, per `skills-lock.json`). Rule: edit only
    `codex-spec-pass`, `tier0-corpus-rescan`, `add-fixture-eval`,
    `extract-approach`; propose upstream changes for the rest. Never install
    a skill whose name collides with those four — the CLI would overwrite
    the committed directory.
11. **Trusting a delegate's summary.** The tracker's standing rule:
    verification is session-side, never trusted from Codex's (or any
    subagent's) own report. Rule: run the suite and read the diff yourself.
12. **Committing without being asked.** Rule: ask before committing, pushing,
    or opening PRs; never commit `tmp/`, `.agents/` synced content, or
    anything under `tmp/tier2/claude-config/`.
13. **Breaking Ruby 3.4 compatibility** because local Ruby is newer. Rule: no
    syntax/stdlib features beyond 3.4; CI is the arbiter.

## Quality bars (checkable)

A change is done when **all** of these are true:

- [ ] `bundle exec rake test` → 0 failures, run in-session, summary pasted.
- [ ] New behavior has a test that failed before the change (state where you saw it red).
- [ ] Diff reviewed against the relevant spec codes; each in-scope code named as satisfied.
- [ ] No new runtime dependency; `Gemfile.lock` unchanged unless the gemspec deliberately changed (with approval).
- [ ] Specs/`design.md`/`README.md`/tracker reconciled if behavior or workflow moved.
- [ ] No edits under `eval/*/` recorded data, `PREREGISTRATION.md`s, or synced `.agents/` skills — unless the task was explicitly that.
- [ ] Compiler-behavior changes: corpus re-scan run (zero unpredicted per-anchor regressions) or an explicit deferred-to-pass-boundary note written.
- [ ] Non-trivial problem solved along the way → learning note exists in `docs/agent-learnings/`.

## Caution list

- `tmp/tier2/claude-config/` — **live authenticated agent credentials**. Never
  print, copy, or commit. (All of `tmp/` is gitignored; keep it that way.)
- `eval/*/PREREGISTRATION.md` — frozen experiment designs; user sign-off required.
- `eval/*/runs.jsonl`, `transcripts/`, `diffs/`, `results/`, `RESULTS.md` — recorded evidence; append-only.
- `specs/*.md` — normative; stable codes; reconcile with `design.md`.
- `Gemfile.lock` — committed and tiny; changes only via approved gemspec changes.
- `skills-lock.json`, `.agents/` (except the four carved-out skills) — managed
  by the `skills` npm CLI; hands off.
- `.github/workflows/ci.yml` — keep Ruby pinned to the gemspec floor; metz
  step stays `continue-on-error: true` and version-pinned.
- Secrets: the repo contains none and must stay that way; there are no
  migrations and no generated source files.

## Escalation rules

- **Two failed attempts on the same issue** → stop; report what you tried,
  what happened, your best hypothesis, and the recommended next move.
- **Spec ↔ design.md conflict** → treat as a bug in one of them; propose the
  reconciliation, don't silently follow either.
- **Anything requiring**: a new dependency, a CI change, touching frozen
  pre-registrations or recorded results, committing/pushing, or deleting
  non-generated files → ask first.
- **Ambiguous multi-file work with no execution plan** → check
  `PROJECT_TRACKER.md` "Next step: execution plan" first; if it doesn't
  cover the task, propose a plan and wait.

## PR review checklist

- [ ] Suite green in the PR branch (`bundle exec rake test` output shown).
- [ ] Every in-scope spec requirement code checked off individually against the diff.
- [ ] No unrelated cleanup bundled in; refactors split from behavior changes.
- [ ] Reason/uncertainty codes used all exist in FMT-6/FMT-7.
- [ ] Determinism preserved: no timestamps/absolute paths/hash-order output in packet content.
- [ ] Fixture-eval case added for any packet bug fixed (red-then-green stated).
- [ ] Docs reconciled: spec, `design.md`, `README.md`, `PROJECT_TRACKER.md` status/decision log.
- [ ] `implementation-notes.md` pass notes current if this is a pass.
- [ ] No changes to gitignored/synced/recorded paths; no lockfile drift.
- [ ] Learning note written if the work surfaced a non-obvious lesson.
