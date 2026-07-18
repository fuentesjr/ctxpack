# Implementation notes — current pass and standing recipes

Completed pass notes are recoverable with:

```sh
git log -- implementation-notes.md
git show 2bf1c86:implementation-notes.md
```

## Repository-documentation retrieval spike (issue #7, 2026-07-17)

### Current boundary

- Reuse the 13 committed Tier 2 tasks across Redmine, Campfire, Lobsters, and
  Publify Core. All four local subject templates were verified at their pinned
  SHAs without enumerating or reading their documentation.
- Reuse `eval/lib/spike_harness.rb` for deterministic spike plumbing. Do not
  retrofit the paid/frozen Tier 2 harness or packet-coverage runner; neither
  answers offline documentation-retrieval relevance.
- `eval/documentation-spike/PREREGISTRATION.md` was approved and frozen before
  subject-document inspection. Candidate generation, labels, and measurement
  remain blocked until the runner and synthetic fixtures are implemented,
  reviewed, and committed.

### Design decisions

- Treat agent-governing files as control-plane input and exclude them before
  documentary retrieval. Record their presence/count only.
- Candidate generation uses only pinned revision, task ID, and the committed
  seed focus. Task prose, acceptance artifacts, reference diffs, and labels are
  scoring inputs only.
- Test four fixed recipe families: source-to-doc exact references, doc-to-focus
  exact links, mirrored doc paths, and ancestor conventional docs. No keyword
  search or model selection.
- Keep supplemental results separate from primaries: three candidates and
  2,048 excerpt bytes per task, with exact provenance and no primary eviction.
- Use next-task rotated focuses within each app as the real-corpus negative
  control; use synthetic fixtures for missing/broken/oversized/instruction
  cases.

### Scope boundary

- This pass can produce a frozen preregistration, stdlib-only runner, synthetic
  fixtures, raw evidence, and a Proceed/Defer/Drop verdict.
- It cannot change production Ruby, dependencies, CI, normative specs, packet
  format, existing frozen evidence, GitHub issue state, or evalkit without
  separate authorization.
- Retrieval viability is not agent-benefit evidence. A Proceed verdict only
  authorizes a later design issue and separately approved behavioral A/B.

### Draft verification

- All four subject templates resolve to the pinned revisions, and all 13 tasks
  have a committed, complete, task-successful treatment diff selected by the
  frozen lowest-run-index rule.
- `ruby eval/lib/spike_harness_check.rb`: all 14 checks pass.
- `bundle exec rake test`: 225 runs, 1,976 assertions, zero failures/errors;
  `git diff --check` passes.
- The draft covers every issue #7 acceptance-criteria input: runner reuse,
  corpus/tasks, oracle, recipes, control-plane separation, negative controls,
  metrics/gates, budgets, provenance, replay, failure handling, verdict, and
  the no-product/no-agent-benefit boundary. The preregistration freeze is
  approved; runner implementation is next.

## Standing provider-seam benchmark recipe

This recipe exercises the production history-provider seam directly; it does
not invoke CLI Rails-app discovery. Run it from the ctxpack root with the
repository bundle's Ruby. The Rails checkout must be clean at
`1d19b2a1f90eb64f7cda2209621eb21a43511be0`, and PATH-discovered `git-recon`
must resolve to optimized commit `7682b2c`.

```sh
bundle exec ruby -Ilib -rjson -rctxpack -e '
repo = "/Users/sal/Projects/rails"
revision = "1d19b2a1f90eb64f7cda2209621eb21a43511be0"
target_path = "activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb"
provider = Ctxpack::GitReconHistoryProvider.new(limits: Ctxpack::Compiler::LIMITS)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
history = provider.fetch(
  app_root: repo,
  repo_root: repo,
  path: target_path,
  revision: revision
)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
puts JSON.generate(
  ruby: RUBY_VERSION,
  revision: revision,
  path: target_path,
  deadline_seconds: Ctxpack::Compiler::LIMITS.fetch(:max_history_seconds),
  elapsed_seconds: elapsed.round(3),
  status: history.status,
  facts: history.facts.length,
  truncated: history.truncated_count,
  reason: history.reason
)
'
```

Healthy margin requires `status=included`, 5 facts, 10 truncated, no error
reason, and elapsed time below the existing 8-second representative-query
benchmark. This is a landing aid, not a normative timeout; production remains
20 seconds. The recorded run passed in 6.020 seconds on Ruby 4.0.1, leaving
13.98 seconds before the provider deadline.
