# Handle unavailable executables at the owning boundary

## Problem

Packet compilation crashed when the Git executable was unavailable, even
though ctxpack already had a deterministic unknown repo-stamp state.

## Context

The failure arose in `Compiler#repo_stamp` under FMT-11. The static Tier 1
fixture DSL cannot vary executable availability, so the regression belongs in
the public repo-stamp test rather than a YAML fixture case.

## Failed approaches

The first boundary stub used `Open3.stub`, but Minitest 6 no longer provides
that helper in this bundle. Loading `minitest/mock` also failed because that
file is absent, and adding a dependency would violate project policy.

## Key insight

Missing executables surface as `Errno::ENOENT` at the process boundary, and the
module method can be replaced temporarily without changing production seams or
mutating the global `PATH`.

## Final approach

The test temporarily replaces `Open3.capture2`, restores it in `ensure`, and
asserts through `Ctxpack.compile` that the packet exposes `commit: nil` and
`dirty: false`. `Compiler#repo_stamp` rescues only `Errno::ENOENT` and returns
that existing state.

## Verification

Before the fix, the focused test produced 1 run and 1 `Errno::ENOENT` error at
`Compiler#repo_stamp`. After the fix, the repo-stamp test file passed with 3
runs, 7 assertions, 0 failures, and 0 errors.

## Reusable rule

Translate a missing optional executable into the module's existing fallback state at the process-owning boundary.

## When to apply again

Apply this when ctxpack shells out to optional developer tooling and a missing
binary should degrade deterministically rather than abort the primary workflow.
