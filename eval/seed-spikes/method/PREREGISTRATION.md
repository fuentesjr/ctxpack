# Method-seed viability spike — pre-registration

**Status:** Frozen before measurement (2026-07-14) after advisor review
(four corrections applied: CONST-2b resolver semantics verbatim, strict
secondary precision metric + undefined-metric-fails rule, `no_file_concern`
sub-label, FQN-equality success wording).
**Source:** `docs/seed-based-interface-proposal.md` §3 (method row: "its §3.3
spike must measure false inclusion, not just recall"); `specs/seeds.md`
SEED-5, SEED-7, SEED-22; Phase 5 plan in `PROJECT_TRACKER.md`.

## Questions

1. **Resolution:** given real `Namespace::Class#method` evidence, how often
   does a Zeitwerk-convention resolver locate an existing file under `app/`
   that contains a matching `def` — from the constant name alone?
2. **False inclusion:** how often does the "tests naming the symbol"
   expansion leg pull in test files that do not actually reference the
   constant? (The same-file callee/constant legs are structurally bounded by
   CONST-4-style append-last budgets; their fan-out is reported as taxonomy,
   not gated.)

## Apps / SHAs (pinned; same as Tier 0)

| App | SHA |
|---|---|
| Mastodon | `163f96cee4dea23365bff9b433871e68d20d9ee7` |
| Discourse | `28b003a38d82c354ffc49bac23b655de9664e478` |
| Zammad | `50384f4c390e8abed07694897956c2f8e176208d` |

Checkouts under `tmp/tier0-rescan/` (verified clean at those SHAs).

## Population

All `(fully-qualified constant, instance method name)` pairs extracted by a
Prism walk (tracking `class`/`module` nesting, including compact
`class Foo::Bar` forms) over `app/**/*.rb` under each app root, **excluding**:

- `app/controllers/**` (SEED-7: `*Controller#action` is never method evidence)
- `app/views/**`
- paths containing `plugins/`, `engines/`, `vendor/`, `node_modules/`, `.git/`

Only plain instance `def` nodes count (no `def self.`, no
`define_method` — metaprogrammed methods are an expected miss class, not
population). Pairs are deduplicated by `(constant, method)`; when the same
pair is defined in multiple files the population keeps the lexicographically
first defining file for reporting only (ground truth below does not use it).
Population is the full extraction, not a sample; per-app N is reported as
found.

## Resolver under test (fixed before scoring)

Given `Namespace::Class#method`, with **no access to where the population
extractor found the pair**:

1. Snake-case the constant per Zeitwerk inflection
   (`Billing::UpgradeService` → `billing/upgrade_service`), same rules as
   the shipped `DefaultConstantResolver`.
2. Probe **exactly the shipped CONST-2b semantics** (the resolver the recipe
   will actually reuse): every direct `app/` subdirectory except `assets`,
   `views`, and `javascript`, in plain lexicographic order; first existing
   `app/<dir>/<path>.rb` wins. No priority ordering beyond lexicographic.
3. Parse the winning file with Prism; **success** requires an instance
   `def <method>` whose enclosing constant's **fully-qualified name equals
   the evidence constant** (compact `class Foo::Bar` and nested
   `module Foo; class Bar` are equivalent iff the resulting FQN is equal).

## Ground truth

- **Resolution success** for a pair = the resolver returns an existing file
  under `app/` containing a matching def per step 3. This is
  existence+convention ground truth (as in the test-seed spike), not
  human-labeled intent.
- **Test-leg false inclusion**: for each resolved pair, the candidate
  heuristic globs `test/**` and `spec/**` for basenames containing the
  constant's demodulized snake token (reusing TEST-1-style family
  selection). A matched test file is a **true** inclusion iff its source
  contains the demodulized constant name as a whole CamelCase token (word
  boundary) or the fully-qualified name; otherwise **false**.

## Metrics and gates (pre-registered)

| Metric | Definition | Gate |
|---|---|---|
| Resolution rate | per-app fraction of population pairs with resolution success; unweighted 3-app average | **≥ 70%** (standing Tier 0 bar) |
| Test-leg precision (primary, lenient) | true matched tests / all matched tests, pooled per app; unweighted average over apps with ≥ 1 match. **If no app yields ≥ 1 matched test, the test leg counts as failing its gate** (unvalidated ≠ validated). | **≥ 70%** |
| Test-leg strict precision (secondary) | among lenient-true matches, fraction whose source contains the **fully-qualified** constant name | report-only |
| Callee/constant fan-out | per resolved pair: count of same-file callees (CONST-1a-style nil/self-receiver BFS from the target def) and of constant references in target+callees | report-only (taxonomy) |

**Outcomes:**

- Resolution gate fails → do **not** ship `--from-method`; record taxonomy;
  continue to 5b (Phase 5 plan).
- Resolution passes but test-leg precision fails → ship `--from-method`
  **without** the test-candidate leg (primary + same-file expansion only);
  record the demotion in the spec.
- Both pass → ship the full SEED-7 method recipe.

## Failure taxonomy (pre-registered labels)

| Label | Meaning |
|---|---|
| `resolved_direct` | Resolver hit an existing file with matching def |
| `no_file` | No conventional path exists for the constant |
| `no_file_concern` | Sub-label of `no_file`: the extractor's defining file lives under `app/*/concerns/` (a root the shipped resolver never probes). Reporting-only label — it may use the extractor's defining file; ground truth is unchanged. |
| `file_no_def` | File resolved but no matching instance def (def lives in a concern/parent/reopened file, or is metaprogrammed) |
| `nesting_mismatch` | Def name found but under a different namespace nesting |
| `crash` | Spike script raised on the pair |

## Explicit non-goals

- Not evidence packets help agents (Tier 1 circularity still applies).
- Not a snippet-quality or line-range eval.
- No Rails boot, no embeddings, no gem code execution from sample apps.
- Not CI-wired (EVAL-10).
