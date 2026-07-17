# Batch machine history facts

## Problem

ctxpack needed a cheap, deterministic git-recon interface before attempting a
larger value evaluation, but the first correct-looking adapter did not finish a
representative high-churn Rails path within 35 seconds. The first batching fix
still left the direct query at 10.27–13.02 seconds and the ctxpack path close to
its 20-second deadline.

## Context

This arose while replacing the deferred ctxpack issue #6 corpus evaluation
with an interface-first step recorded in `PROJECT_TRACKER.md`. The implementation
and measurements live in git-recon's `bin/git-recon`, `test/run_tests.sh`, and
`implementation-notes.md`; ctxpack integration remains a separate tracer.

## Failed approaches

- A full corpus evaluation was too expensive for deciding whether to expose an
  already-useful, low-cost seam; it mixed interface enablement with the later
  question of whether history earns packet budget.
- The first adapter spawned work per escaped control byte, candidate commit,
  and candidate path. Small fixtures passed, but Rails exposed process
  amplification that fixture scale hid.
- Replacing per-commit Git calls with one streamed diff improved runtime but
  still required careful NUL-stream state; treating an in-band marker-shaped
  path as a commit header caused a typed failure.
- Assuming `git diff-tree` itself dominated was wrong. Trace2 measured that
  process at only 0.197 seconds while Bash spent 4.763 seconds walking its
  38,092 NUL-delimited records.
- A Zig, Rust, or C rewrite would optimize the wrong layer unless it also
  replaced Git's path-limited history semantics; after the targeted fix, the
  remaining non-Git overhead is roughly one second.

## Key insight

A machine context source needs two independent gates: cheap contract tests for
the interface itself and later evidence that its facts deserve packet budget;
real-repository profiling is part of the interface gate because subprocess
shape and shell-side record volume, not Git computation alone, can dominate
runtime. Git child timings and parent wall time must be measured separately.

## Final approach

git-recon now emits a versioned compact JSON facts payload with normalized
commit rows and bounded index references. It batches current-tree membership,
reuses the first path-history commit set for repair matching, and handles
coupling in two passes. A quoted line-oriented pass counts distinct paths and
rejects commits over the 30-path limit; only eligible commits reach the exact
NUL-delimited Bash parser. Epochs travel in commit markers, avoiding repeated
candidate-list searches. ctxpack remains responsible for seed translation and
packet selection.

The ctxpack tracer confirmed that translation is part of the safety boundary,
not glue: normalize files evidence to one application-relative identity before
deduplication and selection, translate that identity to repository-relative
form exactly once at the provider seam, then rebase and filter returned paths
before they enter the packet. This keeps a nested application from confusing
application paths with monorepo paths or enriching a file that did not survive
the packet budget.

## Verification

The git-recon fixture suite passed with regressions for cutoff isolation,
literal paths, typed Git failures, cleanup, caps, provenance, replay, UTF-8,
subdirectory blame, and marker collisions; ShellCheck, Bash 3.2 parsing, schema
JSON parsing, and `git diff --check` were clean. The opt-in 8-second benchmark
was red at 10.776 seconds before the optimization and green at 4.965 seconds.
Final checkout runs took 4.838, 4.845, and 5.192 seconds and produced the same
1,920 bytes with SHA-256
`02c35bdc7c0d73c3b7eaece160ec4f0ad66efcc72558b940cf4f17d329e1ff43`.

Before this optimization, the completed ctxpack path was measured end to end on
the same Rails file: three runs took 19.021, 19.018, and 18.623 seconds. Every
run returned five selected facts with ten additional facts truncated. The
post-optimization consumer measurement remains pending because the original
benchmark invocation was not recorded; two attempted reconstructions exercised
the wrong Ruby and then CLI Rails-root discovery rather than the prior seam.

## Reusable rule

Profile Git subprocess time separately from shell parsing, reject oversized
histories in a cheap quoted-name pass before exact NUL parsing, reuse resolved
commit sets, and remeasure the complete consumer path before considering a
compiled rewrite.

## When to apply again

Apply this when adding a repository-derived context source, wrapping a
human-oriented CLI for agents, or promoting fixture-green history analysis into
a default packet-building path.
