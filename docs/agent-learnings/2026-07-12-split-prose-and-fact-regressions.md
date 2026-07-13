# Split prose and fact regressions

## Problem

A packet-format bug needed the permanent Tier 1 regression required by EVAL-9, but its failure mode was user-supplied Markdown escaping the `## Task` section.

## Context

The tension arose between EVAL-9's YAML-case requirement and EVAL-5's preference in [`specs/fixture-evals.md`](../../specs/fixture-evals.md) for packet or manifest facts over rendered Markdown prose. The Format 2 work is recorded in [`specs/packet-format.md`](../../specs/packet-format.md) and [`implementation-notes.md`](../../implementation-notes.md).

## Failed approaches

Adding a rendered-Markdown expectation to the fixture YAML was rejected because it would make Tier 1 depend on prose and heading shape, directly weakening EVAL-5 just to satisfy EVAL-9 mechanically. Treating the public renderer test alone as the entire EVAL-9 case was also insufficient because the repo requires packet bugs to grow the YAML regression set when a stable fact seam exists.

## Key insight

One reported bug can have separate prose and fact contracts: test containment through the public Markdown renderer, then constrain the same motivating input's durable semantics through the manifest-backed fixture DSL.

## Final approach

The public renderer test supplies multiline task Markdown containing a heading, list, blank lines, and a fence, then asserts that only ctxpack's fixed headings remain top-level. The `multiline_task_manifest_v2.yml` case uses that same input and asserts only stable manifest facts—the raw task and schema version—through `expect.manifest`.

## Verification

The renderer test failed before the fix because `## Injected heading` became a peer section, then passed after every task line was blockquoted. The YAML replay against manifest v1 failed at `1 run, 10 assertions, 1 failure` (`expected 2, actual 1`); manifest v2 passed at `1 run, 31 assertions, 0 failures, 0 errors`. After review fixes, the full suite passed at `147 runs, 1325 assertions, 0 failures, 0 errors`.

## Reusable rule

Split presentation-only regressions into a public-renderer test and a YAML fixture assertion on the nearest stable packet or manifest facts without teaching Tier 1 to parse prose.

## When to apply again

Use this approach whenever EVAL-9 applies to a Markdown rendering defect and EVAL-5 makes stable packet or manifest facts the preferred fixture-eval assertion surface.
