# AGENTS.md — ctxpack operating rules

ctxpack is a small Ruby context-engineering CLI. It deterministically compiles
a task plus explicit evidence seeds (including Rails `controller#action`) into
a Markdown packet and manifest for coding agents. v0 is spec-driven and
evidence-gated.

## Authority and routing

- Fresh sessions resume from `PROJECT_TRACKER.md`; keep its current execution
  plan authoritative and compact.
- Read `specs/README.md` before spec-governed work. `specs/*.md` are normative;
  stable requirement codes are append-only. Reconcile any spec amendment with
  `design.md` in the same change.
- `design.md` owns rationale and binding v0 non-goals. `eval/README.md` routes
  eval work. Frozen pre-registrations and recorded results are evidence: append
  through the owning harness or a marked addendum, never rewrite them.
- `implementation-notes.md` contains the current pass plus standing
  reproducibility recipes only. Git history recovers completed pass notes.
- `README.md`, `docs/examples.md`, and `docs/faq.md` are the current user-facing
  surface. Dated proposals and learnings are historical/routed evidence, not
  current product authority.

## Orchestration and approvals

The primary agent is the orchestrator-DRA: it owns scope, sequencing,
verification, tracker continuity, and the final response. Delegates are
advisory until the DRA reads the diff and runs the gates itself. Use shallow
Agenticons delegation only when the user or tracker requests it.

Ask before dependencies, CI changes, frozen evidence changes, commits, pushes,
GitHub mutations, or deletion of non-generated files unless the current task
explicitly grants that action. Never push or publish under the user's name
without exact approval. Do not read or commit `tmp/tier2/claude-config/`.

Three failed attempts on the same issue require a stop/report unless the user
explicitly overrides that limit for the task. Treat a spec/`design.md`
conflict as a bug to reconcile, not permission to choose silently.

## Commands

```sh
bundle install
bundle exec rake test
bundle exec rake metz      # advisory only
ruby -Ilib exe/ctxpack packet <anchor> --task "..."
ruby eval/tier2/harness.rb status
```

CI and compatibility target Ruby 3.4. There is no style lint or typecheck;
`.rubocop.yml` scopes only the advisory Metz scan. `prism` is the sole runtime
dependency. Record metz-scan bugs/UX friction in `metz-scan-feedback.md`.

## Architecture

- Layers point one way: compilation (`lib/ctxpack/compiler.rb`) -> packet ->
  Markdown/manifest renderers -> CLI. Lower layers never reach upward.
- The completed packet object is the shared contract for renderers, manifest,
  and fixture evals.
- Reason and uncertainty codes come from the FMT-6/FMT-7 registries; never
  invent one inline.
- Preserve determinism: no timestamps, absolute paths, or hash-order leaks.
  Renderer prose derives limits from `Compiler::LIMITS`; history has its own
  bounded budget and never consumes `max_total_files`.
- Public seams stay injectable. Do not boot Rails or add embeddings/RAG, LLM
  packet construction, engines, route resolution, or inherited/concern/
  metaprogrammed action resolution in v0.

## Tests and completion gates for ctxpack changes

These gates apply when work changes this repository. Subject repositories or
workspaces nested under ctxpack follow their own instructions; do not project
ctxpack's Minitest or corpus gates onto them.

- Minitest only. The suite glob remains `test/ctxpack/**/*_test.rb`; fixture
  app tests are inert scaffolding and must not be loaded.
- Behavior changes and bug fixes use red-green-refactor and assert observable
  behavior. CLI tests run `Ctxpack::CLI#run` in process.
- Every packet bug gets a red-then-green YAML case via `add-fixture-eval`.
- Any compiler-behavior change requires the `tier0-corpus-rescan` pass-boundary
  gate or an explicit deferral note.
- Before success, the DRA must run the whole `bundle exec rake test` suite in
  session, report its zero-failure summary, review the diff against each
  in-scope requirement code, reconcile behavior/workflow docs, and state what
  remains unverified.

Check `debt.md` only when task work is hindered. Use `extract-approach` after a
non-trivial solution, but create a separate learning note only when the lesson
has no better authoritative home and its rediscovery cost is substantial.

## Eval and repository boundaries

- New evals follow `eval/README.md` and `~/Projects/evalkit`: freeze the
  pre-registration before measurement, record the existing-runner decision,
  publish results against the frozen gate, and keep the inventory/ledger in
  sync. Do not retrofit measured runners.
- Before a representative cross-repo benchmark's first measured run, record
  the executable, production seam, arguments, pinned revisions/paths, checkout
  assumptions, reported fields, and decision rule. Measure the narrow seam
  directly unless CLI discovery is the subject.
- Tier 1 is circular regression evidence, not proof packets are useful; cite
  Tier 2 results for usefulness. Tier 0/Tier 2 never run in CI.
- Do not renumber requirement codes, hardcode renderer limits, broaden the test
  glob, or edit synced `.agents/skills/` content.
- The four repo-owned skills are `codex-spec-pass`, `tier0-corpus-rescan`,
  `add-fixture-eval`, and `extract-approach`; edit only their canonical
  `.agents/skills/<name>/SKILL.md` paths. `.claude/skills/` contains symlinks.
- Keep `Gemfile.lock`, `.github/workflows/ci.yml`, and recorded eval artifacts
  unchanged unless the task explicitly covers them. The repository contains no
  secrets or migrations and must stay that way.
