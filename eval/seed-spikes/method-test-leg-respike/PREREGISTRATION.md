# Method test-candidate leg respike — pre-registration

**Status:** Frozen before measurement (2026-07-19), with user sign-off. No
held-out source was enumerated or measured before freezing.

**Source:** `specs/seeds.md` SEED-25 requires a new pre-registered spike with a
better-than-token matching rule before the method test-candidate leg can be
reconsidered. The 2026-07-14 method spike is calibration evidence only.

## Question

Across held-out Rails applications, can exact production-to-test mirror paths
identify test candidates for resolved method seeds with adequate structural
relevance and non-trivial coverage?

## Reuse line

Existing runner considered: `eval/seed-spikes/run_method_spike.rb`; not used
because it is a frozen historical runner for the demodulized basename-token
rule and the original three-app calibration corpus. The new runner will reuse
`eval/lib/spike_harness.rb` for pinned-corpus checks, exclusions, taxonomy,
percentiles, and gate summaries.

## Calibration boundary

The existing Mastodon, Discourse, and Zammad results supply calibration only.
They establish the failure mechanism: generic demodulized tokens can match
unrelated test files, especially `AI::Agent` on Zammad. No new recipe will be
selected or scored on those applications before the held-out measurement.

## Held-out corpus

These applications were not used by the original method-seed spike. Their
existing Tier 2 pins are reused; Tier 2 task artifacts and outcomes are not
scoring inputs.

| App | Framework | SHA | Checkout |
|---|---|---|---|
| Redmine | Minitest | `3386d9595767b3d0c455ace9281e056e9f61bd56` | `tmp/tier2/template` |
| Campfire | Minitest | `71ffeeea789599a334311f28bcb6816863985488` | `tmp/tier2-expansion/campfire/template` |
| Lobsters | RSpec | `430d864b0d7bf1b30913ee42e6cca3d9fbddcaa4` | `tmp/tier2-expansion/lobsters/template` |

Before measurement, the runner MUST verify each `HEAD`. It MUST also verify
that tracked files under `app/`, `test/`, and `spec/` match the pinned commit.
Lobsters' prepared `Gemfile.lock` and removed agent-instruction files are
outside those source trees and are not inputs.

Publify is excluded because the pinned unit is an engine, which v0 treats as
out of scope. The original three apps are excluded because they informed the
recipe choice.

## Population

For each held-out app, extract every unique `(fully-qualified constant,
instance method name)` pair from `app/**/*.rb` with Prism. Preserve the
2026-07-14 method-spike rules:

- Track nested and compact class/module names.
- Include plain instance `def` nodes only.
- Exclude `app/controllers/**`, `app/views/**`, and paths containing
  `plugins`, `engines`, `vendor`, `node_modules`, or `.git`.
- Deduplicate by `(constant, method)`.
- Resolve the evidence constant through the shipped
  `Ctxpack::DefaultConstantResolver#resolve_exact` seam.
- Count a pair as resolved only when the selected file contains the matching
  instance method under the exact fully-qualified constant.

The full extracted population is measured. No sampling or post-measurement
exclusion is allowed.

## Candidate rule under test

For each resolved pair, derive candidates only from the resolved production
path. If the path is `app/<family>/<relative>.rb`, probe existing files in this
fixed order:

1. For a Minitest app: `test/<family>/<relative>_test.rb`.
2. For a Minitest `app/models/**` path:
   `test/unit/<relative>_test.rb` as the legacy Rails mirror.
3. For an RSpec app: `spec/<family>/<relative>_spec.rb`.

Use the shipped framework detection rule. Do not mix Minitest and RSpec
candidates. Keep at most `Compiler::LIMITS[:max_test_files]` existing paths in
the order above. Do not search basenames, tokens, file contents, Git history,
or task text when selecting candidates.

The proposed production behavior is exactly this path rule. The scoring oracle
below is measurement-only and MUST NOT filter candidates.

## Structural relevance oracle

Parse each candidate with Prism. A candidate is structurally relevant to its
`Const#method` pair only when both conditions hold:

1. **Constant evidence:** the source contains the fully-qualified constant or
   its demodulized constant as a whole CamelCase token.
2. **Method evidence:** the AST contains a call whose name equals the method,
   or a symbol/string literal whose complete value equals the method name.

This oracle is independent of candidate selection because selection uses paths
and existence only. It is a deterministic relevance proxy, not proof that the
test executes the method.

Report a strict secondary oracle requiring the fully-qualified constant and a
matching call node. The strict oracle is report-only.

## Executable and provenance

The measurement command will be:

```sh
ruby -Ilib eval/seed-spikes/run_method_test_leg_respike.rb \
  eval/seed-spikes/method-test-leg-respike/results
```

The runner will use Ruby's existing Prism dependency and
`eval/lib/spike_harness.rb`; it adds no dependency and does not boot Rails. It
will emit one JSON file per app plus `summary.json`, recording pins, population,
resolution counts, candidate counts, oracle labels, per-rule counts, metrics,
gates, failure taxonomy, and bounded examples. The runner and this frozen
document will be committed before the first measurement; the runner commit SHA
will be recorded in `RESULTS.md`.

## Metrics and gates

All rates are pair-weighted within an app and averaged equally across the three
apps. An undefined metric fails its gate.

| Gate | Definition | Threshold | Consequence if failed |
|---|---|---:|---|
| Mean precision | structurally relevant candidate pairs / all candidate pairs; unweighted app average | `>= 0.70` | DROP this mirror rule; retain SEED-25 without a test leg |
| Per-app precision floor | lowest app precision | `>= 0.60` | DROP this mirror rule; no app may hide behind the mean |
| Mean resolved-pair coverage | resolved pairs with at least one candidate / all resolved pairs; unweighted app average | `>= 0.05` | DEFER; precision alone is too sparse to justify promotion |
| Per-app candidate yield | candidate pairs in each app | `>= 25` | DEFER; the app provides insufficient confirmation evidence |

Report-only metrics: extraction and resolution rates, strict precision,
candidates per resolved constant, duplicate candidate paths, candidate count by
modern/legacy mirror rule, and source-parse failures.

All four gates pass: record **PROCEED**, authorizing only a separate production
design and implementation work order. Any precision gate fails: record
**DROP**. Precision passes but a coverage/yield gate fails: record **DEFER**.
No outcome changes production behavior in this pass.

## Failure taxonomy

| Label | Meaning |
|---|---|
| `resolved_no_mirror` | Pair resolved, but no candidate path exists. |
| `mirror_relevant` | Candidate satisfies both structural relevance conditions. |
| `mirror_constant_only` | Candidate has constant evidence but no method evidence. |
| `mirror_method_only` | Candidate has method evidence but no constant evidence. |
| `mirror_neither` | Candidate has neither condition. |
| `candidate_parse_failure` | Prism cannot parse an existing candidate. |
| `resolution_failed` | Exact resolver or exact constant/method verification fails. |
| `crash` | The runner raises while processing a pair. |

Unexpected observed subtypes may be reported in `RESULTS.md` but cannot change
scoring or gates.

## Explicit non-goals

- Not evidence that packets improve agent outcomes.
- Not a recall estimate over all tests that could exercise a method.
- Not a method-body, snippet-range, inherited-method, concern, engine, or
  metaprogramming expansion.
- No Rails boot, embeddings, LLM judging, task-text matching, or Git-history
  matching.
- No production code, spec, CLI, packet-format, dependency, or CI change.
- Not CI-wired.

## Amendments

None. Any non-mechanical change after freezing requires a new preregistration.
