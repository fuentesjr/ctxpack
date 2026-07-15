# Spec: Seeds

Status: Draft. Source: `docs/seed-based-interface-proposal.md` (§14 decisions
accepted 2026-07-13) and inherited acquisition constraints from
`docs/anchor-acquisition-proposal.md` §12 / §12a.

This document is the normative seed surface. Anchor semantics remain in
`packet-compilation.md` (ANCH-*); the anchor seed *uses* those rules as its
expansion recipe. Format carriers for seed-aware packets are in
`packet-format.md` (format v3). CLI sugar and `--from-*` flags are in
`cli.md`.

## Product definition

**SEED-1.** ctxpack is a deterministic context compiler:

```text
task + seed(s) → provenanced, budgeted packet
```

A **seed** is evidence plus a deterministic expansion recipe. An **anchor**
(`controller#action`) is one seed kind, not the identity of the tool.

**SEED-2.** At least one seed is required per compile. Task-only compilation
(prose with no seed evidence) is refused by the gem; prose → seed lives in
skills. **[from seed proposal §14.6 / acquisition §12]**

**SEED-3.** Task text remains optional-but-recommended under the same rules as
CLI-4: when omitted, the packet records that no task was provided and name
derivation uses seed identity alone.

## Terminology

- **Evidence** — what the caller already has (path, test id, stack frames,
  anchor string, …).
- **Recipe** — deterministic rules for what else to pull and why (reason codes).
- **Focus set** — the post-resolution internal form: ordered files (with roles),
  optional method/line ranges for snippets, reason and uncertainty codes per
  inclusion. Renderers consume the focus set via the packet object; focus sets
  are file/method/range oriented and are not “everything becomes an anchor.”
- **Seed identity** — a stable, deterministic string derived from the seed’s
  evidence used for artifact naming (CLI-8/8a) and the `seeds[]` manifest
  entries.

## Catalog

**SEED-4.** Seed kinds admitted by the model, with ship priority:

| Kind | Priority | Status in this campaign |
|---|---|---|
| `anchor` | P0 | Exists (ANCH-*); Phase 1 wraps as a seed |
| `test` | P0 | Ships Phase 2 behind viability spike |
| `files` | P0 | Ships Phase 2 behind neighbor-rule spike |
| `error` | P0 (gated) | Phase 3 go/no-go; demotion to P1 is the stated fallback |
| `method` | P1 | Ships Phase 5a (test-candidate leg demoted by spike — see Method seed) |
| `diff` | P1 | Ships Phase 5b (paired-test mirror leg ships — see Diff seed) |
| `route` | P1 | **Not shipped** — Phase 5c double-gated spike failed its resolution gate 2026-07-14 (0.243 < 0.70; see `eval/seed-spikes/route/RESULTS.md`); route evidence stays CLI-17c coaching-only. Re-opening requires a new pre-registered spike |
| `area` | P2 | Not scheduled |
| task-only | Skill-only | Gem refuses (SEED-2) |

**SEED-5.** Each new seed kind MUST pass a Tier-0-style viability spike against
real sample apps *before* it ships, with scoring pre-registered before
measuring and a failure taxonomy recorded. Fixture evals are regression only
and never substitute for the spike. **[from seed proposal §3.3]** The
pre-registration MUST record which existing eval runner was considered for
reuse and why it doesn't fit (inventory + authoring rule:
`eval/README.md`).

**SEED-6.** Ontology term in model and specs is `seed`. CLI flag spelling is
`--from-<kind>` (e.g. `--from-test`, `--from-files`, `--from-error`,
`--from-anchor`). **[from seed proposal §14.9]**

## Evidence grammar

**SEED-7.** Evidence shapes per kind:

| Kind | Evidence | Notes |
|---|---|---|
| `anchor` | `controller#action` (ANCH-1) | Snake_case path form from `bin/rails routes` |
| `test` | Relative path under `test/` or `spec/`, optional `:line`; or `TestClass#method` / RSpec example id shapes admitted by the argv classifier | Path is relative to the application root after normalization |
| `files` | One or more existing relative file paths | Paths relative to application root; multi-file order is user order then stable re-sort only as MERGE rules require |
| `error` | Stack/log paste (flag value or stdin `-`) | Normalized to filtered application frames only (SEED-20); raw paste is never stored |
| `method` | `Namespace::Class#method` for **non-controller** constants | `*Controller#action` is never method evidence (SEED-10) |
| `diff` | Git range ref (`HEAD~1`, `main...HEAD`, `<sha>..<sha>`) or a patch file path relative to the application root | Explicit `--from-diff` only in v1 (no stdin; no positional sugar — SEED-10 rule 6 keeps existing `.patch` paths on the files seed) |
| `route` | Helper, path, or `VERB /path` | P1; may require Rails for resolution |

**SEED-8.** Path normalization for every path-bearing seed:

1. Resolve relative to the application root (CLI-3).
2. Reject paths that escape the application root after normalization
   (`..` segments that leave the root).
3. Store and emit paths as relative POSIX-style paths from the root (no leading
   `./`, no absolute paths, no drive letters).
4. Existence checks use the real filesystem under the root; missing evidence
   fails closed with a message naming the path.

**SEED-9.** Multi-evidence ordering within a single seed (e.g. multiple
`--from-files` paths) preserves caller order for identity and primary
inclusion; merge with other seeds follows MERGE-*.

## Argv dispatch (sugar)

**SEED-10.** When classifying a positional argv token by shape/existence
**before** compile, on ambiguity fail with labeled candidates (no silent wrong
seed kind). Rules, in order:

1. Snake_case token containing `#` (`accounts#upgrade`, `admin/accounts#upgrade`)
   → **anchor** seed.
2. `#`-bearing token whose CamelCase segment ends in `Test` or `Spec`
   (`AccountsControllerTest#test_upgrade_creates_invoice`) → **test** seed —
   checked **before** the method rules.
3. `#`-bearing token whose CamelCase segment ends in `Controller` — including
   nested (`Admin::AccountsController#suspend`) → **anchor evidence**, handled
   by the CLI-17c suggest-only rewrite to the underscore anchor
   (`admin/accounts#suspend`). It coaches and never silently compiles. It is
   **never** routed to the method seed.
4. Any other token containing `::` or CamelCase before `#`
   (`Billing::Upgrade#call`) → **method** seed (Phase 5a). Never silently
   treated as an anchor.
5. Existing path under `test/` or `spec/`, optionally with `:line` → **test**
   seed.
6. Any other existing path → **files** seed. `:line` on a non-test path is
   rejected with coaching (“strip the line, or use `--from-files`”);
   line-focused file seeds stay open in the model but out of v1 sugar.
   Existing `.patch` / `.diff` paths are **files** seeds under this rule —
   the diff seed is explicit-flag-only (`--from-diff`) in v1 so the SEED-11
   single-occupancy matrix does not grow a stdin form.
7. Anything else → fail with labeled input kind and candidates/coaching.

**SEED-11.** Stdin is single-occupancy: `--from-error -` conflicts with
`--task-file -` in either order; the conflict fails before either stream is
read (same discipline as the shipped `--task` / `--task-file` conflict).

**SEED-12.** Explicit `--from-<kind>` flags override sugar classification for
their evidence. Until Phase 4, at most one seed may be supplied per invocation
(positional sugar counts as one seed). Phase 4 lifts this to multi-seed
(MERGE-*).

## Expansion recipes (P0)

### Anchor seed

**SEED-13.** The `anchor` recipe is exactly today’s compilation path:
ANCH-* resolution, PARSE-*, CB-*, VIEW-*, CONST-*, TEST-*, LIM-* as specified
in `packet-compilation.md`. ANCH-* semantics are unchanged for this seed kind.
Reason codes remain those in FMT-6.

### Test seed

**SEED-14.** The `test` recipe (ships Phase 2 after the viability spike):

1. Include the named test/spec file as primary with reason code
   `test_seed_primary` (FMT-6 registry extension at Phase 2).
2. Infer production surface via deterministic heuristics, in order, stopping
   when a budgeted set of existing files is found:
   - path convention: `test/controllers/X_controller_test.rb` /
     `spec/controllers/X_controller_spec.rb` →
     `app/controllers/X_controller.rb` (and request/integration path-token
     matches under the selected test family);
   - constant / `described_class` literals in the test file resolved by the
     same convention/path constant resolver used for CONST-*;
   - for optional `:line`, prefer defs and references near that line when
     ranking candidates within the recipe (still deterministic).
3. Include conventional factories/fixtures only when a conventional path
   exists and budget remains (Minitest fixtures under `test/fixtures/`,
   FactoryBot `test/factories` / `spec/factories` by path existence — content
   never executed).
4. Emit uncertainty when production surface is empty or only convention-inferred
   (`test_seed_surface_uncertain` — registry at Phase 2).
5. MUST NOT boot Rails. MUST NOT use embeddings.

### Files seed

**SEED-15.** The `files` recipe (ships Phase 2 after the neighbor-rule spike):

1. Include every user-named existing file as primary with reason code
   `files_seed_primary`.
2. For each primary, add budgeted **neighbors** only:
   - conventional test/spec candidates for the path (reuse TEST-1 path rules
     where the path looks like a controller; otherwise path-token match under
     the selected family);
   - same-prefix views under `app/views/` when the primary is a controller;
   - path-token constant neighbors under `app/` when a same-basename constant
     path exists by Zeitwerk convention.
3. Never drop a user-named file without an explicit follow-up (MERGE-4).
4. Neighbor rules are the only non-trivial part of this kind; the viability
   spike measures their precision on sample apps.

### Error seed

**SEED-16.** The `error` recipe (Phase 3; go/no-go on its spike):

1. Normalize the paste per SEED-20 (frame filtering + PII rule).
2. For each retained application frame (`path:line`), include the file with a
   line window around the frame (enclosing method when Prism can find one;
   otherwise a fixed ±N line window with N from `Compiler::LIMITS`).
3. Skip pure framework/gem frames.
4. If no application frames remain, fail or emit a packet with empty focus and
   an explicit follow-up — fail-closed preference is recorded in the spike
   taxonomy; default is fail with coaching unless the spike says otherwise.
5. Reason code `error_seed_frame`.

### Method seed

**SEED-25.** The `method` recipe (ships Phase 5a after the viability spike;
gate evidence: `eval/seed-spikes/method/PREREGISTRATION.md` and
`eval/seed-spikes/method/RESULTS.md`):

1. **Resolve the exact evidence constant** via CONST-2b probing only — no
   segment trimming (CONST-2c does not apply to the evidence constant). Snake-
   case the fully-qualified constant per Zeitwerk inflection, then probe every
   direct `app/` subdirectory except `assets`, `views`, and `javascript`, in
   plain lexicographic order; the first existing `app/<dir>/<path>.rb` wins.
   The evidence constant is exact: a miss is a miss.
2. **Success** requires an instance `def <method>` in the resolved file whose
   enclosing constant's fully-qualified name equals the evidence constant
   (compact `class Foo::Bar` and nested `module Foo; class Bar` are equivalent
   iff the resulting FQN is equal). `def self.` and metaprogrammed methods do
   not match. Otherwise **fail closed** with a coaching message naming what
   was tried (no conventional file / file without matching instance def).
3. **Primary inclusion:** the resolved file with a snippet of the method def
   (Prism enclosing-def range), reason code `method_seed_primary` (FMT-6).
4. **Same-file expansion:** CONST-1a-style BFS from the method def — only
   nil/`self` receiver calls to same-constant same-file instance defs. Constant
   scan over the target method body plus BFS callees feeds the existing
   `referenced_constant` machinery under `max_constant_files` with CONST-4
   append-last semantics (no eviction of the primary or of earlier constant
   groups by later callee constants).
5. **No test-candidate leg.** The pre-registered spike's test-leg precision
   gate failed (unweighted 3-app average 0.6996 < 0.70; failure mode: generic
   demodulized tokens, especially on Zammad). Demotion is recorded here with
   pointer to `eval/seed-spikes/method/RESULTS.md`. Re-promoting the test leg
   requires a new pre-registered spike with a better-than-token matching rule.
6. MUST NOT boot Rails. MUST NOT use embeddings. No new dependencies.

### Diff seed

**SEED-26.** The `diff` recipe (ships Phase 5b after the viability spike;
gate evidence: `eval/seed-spikes/diff/PREREGISTRATION.md` and
`eval/seed-spikes/diff/RESULTS.md` — paired-test agreement 0.810 ≥ 0.70 PASS
→ ship with the paired-test mirror leg):

1. **Evidence:** a git range ref (`HEAD~1`, `main...HEAD`, `<sha>..<sha>`) or
   a patch file path relative to the application root. No stdin form in v1
   (avoids growing the SEED-11 single-occupancy matrix). No positional sugar —
   SEED-10 rule 6 routes existing paths (including `.patch` files) to the
   files seed and that stays unchanged. `--from-diff` is explicit-flag-only.
2. **Enumerate changed files** deterministically:
   - Range: `git diff --name-status -M <range>` shell-out following the FMT-11
     degradation pattern — unavailable git / not a repo / unresolvable range
     **fails closed** with a coaching message (never crashes, never guesses).
   - Patch path: parse with `git apply --numstat --summary <path>` (still git,
     but repo-independent); unparseable or missing patch fails closed.
3. **Primaries:** changed files that exist in the **current working tree**
   under the app root, in git's output order, reason code `diff_seed_primary`
   (FMT-6). Deleted or renamed-away old paths are excluded from primaries,
   each recorded as an omitted-candidate follow-up naming the path (spike
   file survival ≈ 99.8% — thin but real). Budget: `max_total_files` via
   MERGE-4 semantics (keep earlier files in diff order, omit later with
   follow-ups).
4. **Snippets** for `.rb` primaries: post-image hunk line ranges; when a
   changed line sits inside a Prism-locatable def, snippet the enclosing def
   range; otherwise a fixed window matching the SEED-16 error-frame pattern
   (`Compiler` snippet window helper). Respect `max_snippet_lines_per_file`
   with truncation + omitted-candidate, as the method seed does.
5. **Paired-test leg** for production primaries (`app/**/*.rb`): mirror
   conventions ONLY, existing on disk — no basename token matching (the 5a
   spike showed token matching floods on generic names):
   - `app/controllers/<p>_controller.rb` →
     `test/controllers/<p>_controller_test.rb`,
     `spec/controllers/<p>_controller_spec.rb`,
     `spec/requests/<p>_spec.rb`,
     `spec/requests/<p>_controller_spec.rb`
   - `app/<dir>/<p>.rb` → `test/<dir>/<p>_test.rb`, `spec/<dir>/<p>_spec.rb`
   - `lib/<p>.rb` → `test/lib/<p>_test.rb`, `spec/lib/<p>_spec.rb`
   Include via the packet's test-candidate surface with reason code
   `diff_seed_paired_test` (FMT-6), under the existing `max_test_files` /
   remaining `max_total_files` budget.
6. **Determinism:** the packet is deterministic *given repo state + range*
   (or patch bytes). Seed identity derives from the resolved range (short-SHA
   form, sanitized per CLI-8a) or the patch basename stem.
7. MUST NOT boot Rails. Git shell-out only. No new dependencies. MUST NOT use
   embeddings.

## Multi-seed merge

**MERGE-1.** Multi-seed is admitted in the model from day one; the CLI ships
single-seed through Phase 3 and enables multiple seeds per invocation in
Phase 4. **[from seed proposal §14.3]**

**MERGE-2.** Union focus candidates from each seed’s recipe with stable
ordering: seeds in CLI flag order (then positional sugar if present), and
within each seed the recipe’s own deterministic order; then global DET-2-style
ordering for render (see packet-format DET-2 as amended for seed packets).

**MERGE-3.** Deduplicate files by normalized path. When the same path arrives
from multiple seeds, merge reason codes into a multi-reason list on that file
(primary order = first seed that contributed the path; secondary codes append
in seed order without duplicates).

**MERGE-4.** Apply global budgets (LIM-1) once after merge. Conflict policy:

1. Prefer explicit seed primaries over inferred neighbors.
2. Never drop a user-named file (anchor controller, test primary, files
   primary, error-frame file, method-seed primary, diff-seed primary) without
   recording an omitted-candidate follow-up that names the path and limit key.
3. When budget still conflicts among primaries, keep earlier seeds’ primaries
   (CLI order) and omit later ones with follow-ups.

**MERGE-5.** Uncertainty and follow-ups from all seeds are unioned,
deduplicated by `(code, subject)`.

## Budgets

**SEED-17.** Seed expansion uses the same `Compiler::LIMITS` constants as
anchor compilation (LIM-1). New kinds MUST NOT invent parallel limit tables
without a LIM amendment. Category ceilings apply after role assignment
(controller/view/constant/test/primary/neighbor) as specified per recipe;
global `max_total_files` always applies post-merge.

## Inherited acquisition constraints

These transfer from `docs/anchor-acquisition-proposal.md` §12 and are not
reopened:

**SEED-18.** Classification and coaching are **suggest-only**: a rewrite or
candidate message never compiles on the user’s behalf.

**SEED-19.** Candidate JSON (if/when resolve surfaces emit it) carries
`match_count` and `evidence[]` only — **no `confidence` field**. No
auto-compile on unique match; revisit only with false-unique ≈ 0 corpus data.
Prose ranking stays skill-only.

## Error-seed normalization (PII)

**SEED-20.** Error-seed provenance is a PII/secret hazard. Normalization
persists **only filtered application frames** as `path:line` (relative to the
application root) into the packet and manifest — never the raw paste, never
request parameters, never headers, never message bodies beyond what is
required to identify the frame location. Frame-filtering rules MUST be
deterministic and fixed before the error spike is scored:

- An **application frame** is a stack frame whose path normalizes under the
  application root into `app/`, `lib/`, or `config/` (and optionally
  `test/`/`spec/` when the frame is in application test code). Paths under
  gem install locations, Ruby stdlib, Rails framework gems, and bundler paths
  are never application frames.
- Ground truth for the viability spike uses this definition; changing it after
  measuring is a gate violation.

## Pipeline

**SEED-21.** Compilation generalizes to:

```text
task + seed(s)
  → validate + parse seeds
  → resolve each seed → raw candidates
  → merge + budget → focus set
  → packet object
  → render Markdown / manifest
```

Layers remain one-directional: seed resolution → focus assembly → format →
CLI. Today’s `compiler.rb` is “anchor seed resolver + focus assembly”; physical
split may be incremental (Phase 1 wrap first).

## Viability spikes (gates)

**SEED-22.** Spike locations and outcomes live under `eval/` (not CI — EVAL-10).
Pre-registration documents scoring before any measurement. Outcomes:

| Kind | Phase | On fail |
|---|---|---|
| `test` | 2 | Do not ship `--from-test`; stop Phase 2 non-anchor work for that kind and report |
| `files` (neighbors) | 2 | Same for neighbor rules; bare named-files-only may still ship if pre-reg allows |
| `error` | 3 | **Demote to P1**, record demotion in the proposal + tracker, continue to Phase 4 without `--from-error` |
| `method` | 5a | Resolution fail → do not ship `--from-method`. Resolution pass + test-leg fail → ship without test-candidate leg (applied 2026-07-14; see SEED-25) |
| `diff` | 5b | Agreement fail → ship without paired-test leg. Agreement pass → ship with paired-test mirror leg (applied 2026-07-14; see SEED-26). Literal changed-file primaries ship either way |
| `route` | 5c | Double gate (resolution ≥ 70% AND Front B margin ≥ +10pt vs the ritual-only baseline). Resolution FAILED 2026-07-14 (0.243) → `--from-route` not shipped; coaching-only stands (see `eval/seed-spikes/route/RESULTS.md`) |

**SEED-23.** Seed work MUST NOT change anchor-resolution classification on the
Tier 0 corpus. Every compiler-behavior boundary re-runs the Tier 0 corpus
re-scan; expect zero per-anchor change unless a change is predicted and named
in the commit.

## Work-start corpus

**SEED-24.** The re-scoped work-start corpus (seed proposal §8) is authored at
Phase 2 with seed-kind labels and scored as *work-start scenarios → correct
packet*. It is re-scored at later phase gates. It is not the same as Tier 1
fixture evals and is not wired into CI.
