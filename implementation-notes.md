# Implementation notes — current pass and standing recipes

Completed pass notes are recoverable with:

```sh
git log -- implementation-notes.md
git show 2bf1c86:implementation-notes.md
```

## Repository-documentation retrieval spike (issue #7, 2026-07-17)

### Current boundary

- Reuse the 15 committed Tier 2 tasks across Redmine, Campfire, Lobsters, and
  Publify Core. All four local subject templates were verified at their pinned
  SHAs without enumerating or reading their documentation.
- Reuse `eval/lib/spike_harness.rb` for deterministic spike plumbing. Do not
  retrofit the paid/frozen Tier 2 harness or packet-coverage runner; neither
  answers offline documentation-retrieval relevance.
- `eval/documentation-spike/PREREGISTRATION.md` was approved and frozen before
  subject-document inspection. The runner and synthetic controls are now
  implemented locally; candidate generation, labels, and measurement remain
  blocked until this reviewed and fully verified runner pass is committed.

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
- Keep recipe outputs uncapped for per-recipe analysis while applying the
  frozen three-candidate/2,048-byte budget only to the fixed combined result.
  Plain-text documents remain whole units; only Markdown participates in
  reverse-link and heading-section parsing.
- Reuse the shared spike harness through parameterized path exclusions,
  checkout verification, percentiles, omission taxonomy, per-app JSON, and
  gate summaries. The documentation spike supplies its narrower frozen path
  exclusion set rather than inheriting the older seed-spike plugin/engine set.

### Scope boundary

- This pass can produce a frozen preregistration, stdlib-only runner, synthetic
  fixtures, raw evidence, and a Proceed/Defer/Drop verdict.
- It cannot change production Ruby, dependencies, CI, normative specs, packet
  format, existing frozen evidence, GitHub issue state, or evalkit without
  separate authorization.
- Retrieval viability is not agent-benefit evidence. A Proceed verdict only
  authorizes a later design issue and separately approved behavioral A/B.

### Verification

- All four subject templates resolve to the pinned revisions, and all 15 tasks
  have a committed, complete, task-successful treatment diff selected by the
  frozen lowest-run-index rule.
- Red-green runner slices cover the four recipes, exact sections and whole-file
  handling, fixed ordering/de-dup/budgets, typed omissions, instruction
  exclusion, pinned revisions, corpus/oracle reuse, opaque label artifacts,
  frozen scoring, replay matching, and CLI artifact writes.
- Focused runner coverage contributes 38 runs and 280 assertions, with zero
  failures/errors in the whole-suite run.
- `run_documentation_spike.rb self-check`: all five frozen synthetic controls
  pass without subject-repository access. `preflight` verifies all 15 task
  records and four pinned checkouts without enumerating subject documentation.
- `ruby eval/lib/spike_harness_check.rb`: all 15 checks pass after adding custom
  exclusion support. `bundle exec rake test`: 263 runs, 2,256 assertions, zero
  failures/errors. Syntax and whitespace checks pass.
- The Agenticons review found and the DRA fixed four pre-measurement blockers:
  combined truncation provenance, rotated-oracle blinding, committed-runner
  provenance, and replay independence. Its clean re-review independently
  reproduced the bounded combined output and found no remaining blocker.
- Subject documentation was first inspected by the invalidated generation
  attempt. The final valid measurement artifacts now live under
  `eval/documentation-spike/` and record the frozen **DROP** verdict.

### Measurement restart

- The first C/UTC generation at runner commit `cea6534` aborted before writing
  any artifact: a punctuation-only source-comment token was trimmed to an empty
  string, whose fragment split yielded `nil` for `File.extname`.
- The exact CLI failure reproduced twice; Redmine task 1 isolated the fault;
  `# >` was the minimal fixture. The regression is red before the empty-token
  filter and green after it.
- The frozen protocol invalidated that attempt. Its reviewed repair landed in
  `76b4295`, after which the measurement restarted from zero.
- Repair commit `76b4295` passed guarded preflight for all 15 tasks. Its first
  restarted C/UTC generation also aborted before artifact write: `Open3` tagged
  Git stdout as US-ASCII, and a valid UTF-8 checkmark in Campfire's rotated
  accounts-controller focus raised during source-line matching.
- The failure was minimized from the full 15-task CLI to Campfire task 1's
  rotated arm and then to one focus file. A retrieve-seam regression is red
  under US-ASCII external encoding and green when `Repository#git` force-tags
  successful stdout as UTF-8; the same regression proves a non-ASCII referenced
  Markdown excerpt remains retrievable. Truly invalid UTF-8 stays on the frozen
  typed-omission path because only the encoding tag changes.
- The second attempt at runner commit `76b4295` is also invalidated. No candidate,
  label, replay, timing, result, or verdict artifact survived that attempt. The
  next measurement restarted all three legs from zero under `be8e9fb`.

### Frozen measurement verdict

- Canonical C/UTC, UTF-8/Los Angeles, and repeated C/UTC generations each
  emitted 60 rows and produced byte-identical candidate JSON with SHA-256
  `61f4e5fb7b4649529084bff54ab34e8cd9ba9f7f2620438d0d340e777d4b3434`.
- The opaque sheet contained 15 distinct visible candidates repeated across 60
  measurement rows. A blinded local interface grouped only rows with identical
  visible fields and copied one human judgment to each group's four opaque IDs;
  hidden recipe/arm/population/rank metadata was never consulted. Human labels
  were complete: 4 `relevant_unique`, 12 `repository_background`, and 44
  `unrelated`; 52/60 rows recorded that missing excerpt context hindered
  classification.
- Frozen verdict: **DROP**. Combined precision was 0.067, incremental task-hit
  rate was 1/15, rotated-focus lift was 0, and byte-weighted distraction was
  0.874. Safety, budget, latency, determinism, provenance, and synthetic-control
  gates passed.
- All 60 emitted rows came from `ancestor_conventional`; the only document paths
  were root `README.md`/`README.rdoc`. Eligible ADR/RFC/design documents were not
  retrieved by the measured recipes. The result therefore drops this recipe and
  excerpt configuration, not documentation enrichment generally.
- The runner counted four mechanical truncations, while the labeler reported
  insufficient context on 52 rows. The measurement evaluates bounded emitted
  excerpts, so this is a failure of the current payload; it also means the study
  cannot support a broader claim that the underlying full documents were
  irrelevant. A retry needs a new preregistration that separates source-family
  discovery from excerpt selection and supplies fairer labeling context.

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
