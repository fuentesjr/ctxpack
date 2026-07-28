# Implementation notes — current pass and standing recipes

Completed pass notes are recoverable with:

```sh
git log -- implementation-notes.md
git show 2bf1c86:implementation-notes.md
```

## Compiler split pass (2026-07-19)

### Current boundary

- Behavior-preserving refactor only: keep `Ctxpack::Compiler`'s public
  constructor and `#compile` interface, packet/manifest bytes, reason codes,
  ordering, limits, errors, and existing injected seams unchanged.
- Prefer cohesive internal modules with narrow interfaces over mixins or
  mechanical file shuffling. Add no dependency, configuration, or generalized
  extension layer.
- Keep the compiler split separate from the method-test-leg respike. The
  respike begins only after this pass closes and cannot promote production
  behavior without a later work order.

### Verification plan

- Capture whole-suite and advisory Metz baselines before implementation.
- Preserve behavior with existing observable tests; add characterization only
  if the chosen seam exposes an uncovered contract.
- Run focused tests during extraction, then the whole suite, SSD validation
  and clean-context design review, and the mandatory Tier 0 corpus byte diff.
- Record before/after advisory Metz evidence and reconcile tracker state before
  closeout.

### Design decision

- Keep `Ctxpack::Compiler` as the public facade and composition root.
- Use `SeedCompiler#compile(seed)` as the one-seed internal interface. It hides
  recipe selection, source analysis, candidate discovery, and per-seed packet
  construction.
- Use `PacketFileBudget.enforce` for total-file truncation in both single-seed
  and merged packets.
- Use one lazy `RepositorySnapshot` for packet stamps and history enrichment.
- Reject a new evidence-plan representation because it would reshape behavior.
  Defer per-recipe classes until separate change pressure proves their value.

### Baseline and current verification

- Baseline and post-extraction suites match: 263 runs, 2,256 assertions, zero
  failures, zero errors, and zero skips.
- Advisory Metz baseline: 142 findings. Post-extraction: 147 findings. The
  compiler facade falls from 1,529 to 113 measured class lines; `SeedCompiler`
  retains 1,386 measured class lines behind one internal entry point.
- Syntax checks pass for all four compiler modules. `git diff --check` passes.
- Tier 0 uses the committed route tables and verified pinned checkouts. All
  1,967 anchor rows are byte-identical to `results/post_amendment/`: zero
  regressions, zero newly resolved anchors, zero label changes, and zero
  crashes.
- SSD executable gates pass. Red-green and lint are skipped for this refactor;
  the placeholder-comment gate passes. The validator reports that RuboCop cannot load the
  repo's Metz-only configuration, so lint/security and head-metric deltas are
  unavailable.
- The clean-context SSD audit reports no blocker or concern. Its DEPTH-1 nit
  notes that `SeedCompiler#test_framework` is a pass-through. It remains because
  removing it would change observable diff/files packet state.

## Method test-candidate leg respike (2026-07-19)

### Current boundary

- Treat the 2026-07-14 Mastodon/Discourse/Zammad result as calibration only.
- Use pinned Redmine, Campfire, and Lobsters checkouts as held-out confirmation;
  exclude Publify because the pinned unit is an engine.
- Test exact production-to-test mirror paths. Score them with an independent
  structural relevance oracle that requires constant and method evidence.
- The user approved the exact preregistration text on 2026-07-19. Its corpus,
  candidate rule, oracle, metrics, gates, and consequences are frozen before
  runner implementation or measurement.
- A passing verdict authorizes only a later production work order. This pass
  cannot change SEED-25 or production behavior.

### Verification

- All three checkout `HEAD` values match their recorded Tier 2 pins.
- Redmine and Campfire are clean. Lobsters has only the recorded prepared-file
  changes outside `app/`, `test/`, and `spec/`.
- No held-out source has been enumerated or measured.
- Runner tests were red with the runner absent, then green after implementation:
  3 runs, 16 assertions, zero failures or errors. They cover pair-level scoring,
  framework-specific mirror order, and frozen verdict precedence.
- The runner reuses `SpikeHarness` and the shipped exact constant resolver. It
  adds no dependency and has not executed against the held-out corpus.
- Full suite: 266 runs, 2,272 assertions, zero failures, errors, or skips.
  `spike_harness_check.rb` passes all 15 checks; syntax, whitespace, and strict
  tracker checks pass.
- The initial SSD audit found a population-integrity blocker and two concerns.
  Extraction now aborts with path context, mirror selection is tested through
  `evaluate_app`, and revalidation uses the original two-item task statement.
  The fix-cycle re-review is clean with no blocker or concern.
- SSD retains one DEPTH-1 nit on `SeedCompiler#test_framework`. It stays for the
  compiler pass's behavior-preservation reason recorded above.
- The frozen runner was committed at `abe74ca82bcc3289286cc4f01b65925193c4bc51`
  before the first measurement.
- Frozen verdict: **DROP**. Mean precision is 0.1998 and the per-app floor is
  0.1163, both below their gates. Mean coverage is 0.6757 and minimum candidate
  yield is 86, so both evidence-volume gates pass.
- Exact mirrors find class-level tests but usually not evidence for the named
  method. `mirror_constant_only` dominates, and candidate paths repeat across
  many methods in each class.
- SEED-25 and production behavior remain unchanged. Any later rule requires a
  new preregistration and work order.

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
