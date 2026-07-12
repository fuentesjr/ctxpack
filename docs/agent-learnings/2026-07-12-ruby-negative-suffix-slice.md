# Guard Ruby suffix slices by length

## Problem

Anchor-preserving filename truncation made ordinary short anchors disappear,
producing filenames with an empty derived stem.

## Context

This arose in `Ctxpack::CLI#artifact_name` during the CLI-8a ergonomics fix.
The implementation used `anchor_name[-80, 80]` for both long and short anchors.

## Failed approaches

The first implementation treated a negative-start slice as “up to the last N
characters” for every string length; Ruby instead returns `nil` when that start
falls before the beginning of a shorter string.

## Key insight

Ruby's `string[-limit, limit]` is a positional slice, not a clamped suffix
operation, so it is only safe after proving `string.length >= limit`.

## Final approach

Return the original string when it is at or below the limit, and use the
negative-start slice only when it exceeds the limit.

## Verification

The focused CLI suite first failed for ordinary namespaced and `.ctxpack/sub`
anchors, then passed with `24 runs, 148 assertions, 0 failures, 0 errors`; the
full suite passed with `102 runs, 912 assertions, 0 failures, 0 errors`.

## Reusable rule

Guard Ruby negative-start suffix slices with an explicit length comparison.

## When to apply again

Apply this whenever truncating Ruby strings from the right, especially when the
same code path must preserve values both shorter and longer than the limit.
