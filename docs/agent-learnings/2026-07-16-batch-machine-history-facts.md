# Batch machine history facts

## Problem

ctxpack needed a cheap, deterministic git-recon interface before attempting a
larger value evaluation, but the first correct-looking adapter did not finish a
representative high-churn Rails path within 35 seconds.

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

## Key insight

A machine context source needs two independent gates: cheap contract tests for
the interface itself and later evidence that its facts deserve packet budget;
real-repository profiling is part of the interface gate because subprocess
shape, not Git computation alone, can dominate runtime.

## Final approach

git-recon now emits a versioned compact JSON facts payload with normalized
commit rows and bounded index references. It batches current-tree membership,
streams candidate diffs through one Git process, skips oversized commits before
partner work, parses NUL separators with explicit state, and keeps ctxpack
responsible for seed translation and packet selection.

## Verification

The git-recon fixture suite passed with regressions for cutoff isolation,
literal paths, typed Git failures, cleanup, caps, provenance, replay, UTF-8,
subdirectory blame, and marker collisions; ShellCheck, Bash 3.2 parsing, schema
JSON parsing, and `git diff --check` were clean. The Rails PostgreSQL-adapter
smoke completed in 10.27–13.02 seconds and produced byte-identical 1,920-byte
payloads across the checked runs, versus the original run killed after more
than 35 seconds.

## Reusable rule

Profile every default machine context adapter on a high-churn real path and batch Git and object queries before accepting its interface.

## When to apply again

Apply this when adding a repository-derived context source, wrapping a
human-oriented CLI for agents, or promoting fixture-green history analysis into
a default packet-building path.
