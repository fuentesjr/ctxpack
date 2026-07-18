# Repository-documentation retrieval spike — pre-registration

**Status: FROZEN before measurement on 2026-07-17 with user approval. Do not
inspect subject documentation, generate candidates, label, or measure until
the runner is implemented, reviewed, and committed.**

Issue: [#7](https://github.com/fuentesjr/ctxpack/issues/7). This spike tests
offline retrieval viability only. It does not authorize product behavior or
claim that documentation improves agent outcomes.

## Question

Can deterministic structural and exact-reference recipes retrieve bounded,
task-relevant repository documentation around an existing seed-resolved focus
with enough precision and incremental value to justify a later design pass?

## Existing-runner decision

Existing runner considered: `eval/tier2/harness.rb`; not used because it runs
paid agent A/B sessions and measures task outcomes, while this spike performs
deterministic offline retrieval and human relevance labeling.

The future spike runner will reuse `eval/lib/spike_harness.rb` for checkout
verification, path exclusions, percentile calculation, failure taxonomy, JSON
artifacts, and gate summaries. It will not modify or retrofit any measured
runner. `eval/tier2-expansion/packet_coverage.rb` was also considered and not
used: it scores packet paths against final diffs, not documentation excerpts.

No runner exists yet, so `eval/README.md` does not gain an inventory row until
the runner is implemented. The runner will be stdlib-only and experiment-local.

## Population and pinned corpus

The population is the 15 already-authored Tier 2 tasks. Their committed prompts,
seed-resolved packet artifacts, acceptance artifacts, and reference diffs are
reused; no task is invented for this spike.

| App | Repository SHA | Tasks | Focus artifact |
|---|---|---:|---|
| Redmine | `3386d9595767b3d0c455ace9281e056e9f61bd56` | 3 | `eval/tier2/packets/task*.md` |
| Campfire | `71ffeeea789599a334311f28bcb6816863985488` | 4 | `eval/tier2-expansion/campfire/packets/task*.json` |
| Lobsters | `430d864b0d7bf1b30913ee42e6cca3d9fbddcaa4` | 4 | `eval/tier2-expansion/lobsters/packets/task*.json` |
| Publify Core | `80ede867d802949e218fdf0bb4f3c31f68f8a56a` | 4 | `eval/tier2-expansion/publify/packets/task*.json` |

The repository URLs and checkout locations come from `eval/tier2/apps/*.rb`.
Before candidate generation, the runner MUST fail closed unless every checkout
exists at its pinned SHA. Prepared or task-seeded files do not change the
documentation corpus; the pinned base tree is the documentation source for all
tasks.

For expansion tasks, the focus set is the stable, de-duplicated `files[].path`
sequence in the committed packet manifest. For Redmine, it is the stable,
de-duplicated sequence of `### \`PATH\`` headings under `## Files to inspect
first` in the committed packet Markdown. Candidate generation may use only the
app SHA, task ID, and focus paths. Task prose, acceptance artifacts, reference
diffs, and labels MUST NOT generate or rank candidates.

The runner records its own ctxpack commit and the SHA-256 of every prompt,
focus artifact, and reference diff used for scoring.

## Documentation corpus

Only Git-tracked regular files at the pinned app SHA are eligible. Documentary
files are:

- files ending in `.md`, `.markdown`, `.mdown`, `.rdoc`, `.rst`, `.adoc`, or
  `.txt`; or
- extensionless files whose basename is `README`, `ARCHITECTURE`, `DESIGN`,
  `DEVELOPMENT`, or `CONTRIBUTING`, matched case-insensitively.

Paths with a segment equal to `.git`, `vendor`, `node_modules`, `tmp`, `log`,
`coverage`, `_site`, or `site` are excluded. Symlinks, submodules, binary files,
invalid UTF-8, and files larger than 256 KiB are typed omissions, not crashes.

Agent-governing instructions are control-plane input and MUST NOT become
documentary candidates. The fixed exclusion set is case-insensitive basenames
`AGENTS.md`, `CLAUDE.md`, `CODEX.md`, and `GEMINI.md`, plus exact paths
`.github/copilot-instructions.md`, `.cursorrules`, and
`.github/instructions/**`. The runner inventories their presence and exclusion
counts separately. It does not read their contents into candidate artifacts.

## Retrieval recipes

Recipes operate independently and are also combined in the fixed order below.
Paths use `/`, bytewise lexical sorting, and repository-root-relative identity.
No task keywords, full-text search, embeddings, RAG, LLM selection, Git history,
or wall-clock input is permitted.

1. **Forward exact reference.** In `.rb` focus files, inspect only lines whose
   first non-whitespace character is `#`. Extract whitespace-, quote-, or
   backtick-delimited tokens that end in an eligible documentary extension or
   conventional basename, optionally followed by `#FRAGMENT`. Resolve a token
   relative to the focus file first, then repository root, without escaping the
   repository. Emit the referenced section, or the document introduction when
   no fragment is present. Other source formats do not participate.
2. **Reverse exact link.** In Markdown documents, parse inline link destinations
   in `[text](target)` forms (images and reference-style links are excluded).
   Select only targets whose normalized path exactly equals a focus file or one
   of its ancestor directories below the repository root. Emit the smallest
   containing section. External URLs and fragment-only links do not qualify.
3. **Mirrored path.** For each focus file, remove its extension and try the
   exact same relative stem beneath `doc/` and `docs/`, with each eligible
   documentary extension. Also try an eligible documentary sibling with the
   same stem. Emit the document introduction.
4. **Ancestor conventional document.** From each focus file's directory toward
   the repository root, try the fixed conventional basenames `README`,
   `ARCHITECTURE`, `DESIGN`, and `DEVELOPMENT` with eligible extensions.
   Nearer ancestors rank first; repository-root documents rank last. Emit the
   document introduction.

Markdown sections start at an ATX heading and end before the next heading of
equal or higher level. A fragment uses GitHub-style lowercased ASCII heading
slugs with punctuation removed and whitespace collapsed to `-`; duplicate
slugs gain `-1`, `-2`, and so on in document order. Non-Markdown documents and
documents without an applicable heading are one unit.

A document introduction begins at byte zero and ends before the second ATX
heading of level 1 or 2; non-Markdown documents use the whole file. Every
candidate is truncated on a valid UTF-8 and whole-line boundary to 1,024 bytes.
The combined result de-duplicates by `(document path, start line, end line)`,
then retains at most three candidates and at most 2,048 excerpt bytes per task.
Later candidates are truncated or omitted when the byte budget is exhausted.

Fixed combined ranking is recipe order, then focus-path order, ancestor
distance where applicable, document path, and start line. Explicit seed focus
paths remain a separate unchanged primary list; supplemental candidates never
participate in the packet's file budget and cannot evict or outrank a primary.

## Negative controls

Each task has a rotated-focus control: use the next task's focus set within the
same app, wrapping from the final task to the first, while retaining the
original task's relevance oracle. This uses no observed documentation and
detects generic repository prose that appears useful regardless of focus.

The runner also owns committed synthetic fixtures for:

- a focus file with no documentation (`no_candidates`);
- a broken exact link (`broken_reference`, no emitted candidate);
- an oversized and an invalid-UTF-8 document (typed omissions);
- an `AGENTS.md` and `CLAUDE.md` that exactly link to the focus
  (`governing_instruction_excluded`, no emitted candidate);
- duplicate links and sections that cross the per-task candidate and byte caps.

Synthetic fixtures verify mechanics and failure handling; they are not part of
the 15-task relevance denominator.

## Ground truth and labeling

Candidate generation is frozen before any label is assigned. The label sheet
uses opaque candidate IDs and hides recipe, rank, and whether the row came from
the real or rotated focus. The labeler sees the task prompt, seed focus and its
pinned source content, excerpt with provenance, acceptance/seed artifacts, and
one fixed successful implementation diff: the lowest-run-index treatment record
whose committed `runs.jsonl` row is complete and task-successful. If no such row
exists, the task is ineligible and the corpus check fails before candidates are
generated. These oracle inputs may score a candidate but may not generate,
filter, or rank one.

Every emitted candidate receives exactly one label:

| Label | Definition |
|---|---|
| `relevant_unique` | Correct information that would materially guide this task and is not already present in the seed focus artifacts. |
| `relevant_redundant` | Correct and task-relevant, but already available from the seed focus artifacts. |
| `repository_background` | Correct repository context, but it does not change a task decision. |
| `unrelated` | Not useful for the task. |
| `stale_or_conflicting` | Contradicted by the pinned source/task or points to a removed/renamed fact as current. |
| `governing_instruction` | Agent-control material escaped the fixed exclusion boundary. |

The labeler also records a one-sentence rationale and whether truncation hid
context needed to classify the excerpt. Ambiguous rows are conservatively
`repository_background`; the RESULTS document reports their count. One author
defines the oracle and labels the candidates, so author bias remains an
explicit limitation even with opaque ordering.

## Metrics

Metrics are reported for each recipe, each app, the fixed combined result, and
the rotated-focus controls. Empty denominators remain empty and never count as
passes.

- **Precision:** (`relevant_unique` + `relevant_redundant`) / emitted
  candidates.
- **Incremental precision:** `relevant_unique` / emitted candidates.
- **Task hit rate:** tasks with at least one relevant candidate / 15.
- **Incremental task hit rate:** tasks with at least one `relevant_unique`
  candidate / 15.
- **Rotated-focus lift:** real incremental task hit rate minus rotated-focus
  incremental task hit rate, in percentage points.
- **Distraction rate:** (`repository_background` + `unrelated`) / emitted
  candidates, plus the same ratio weighted by excerpt bytes.
- **Safety counts:** `stale_or_conflicting`, `governing_instruction`, broken
  references emitted, and primary-list changes.
- **Budget:** selected candidates and excerpt bytes per task; report median,
  p95, maximum, truncations, and omissions.
- **Latency:** monotonic elapsed milliseconds for corpus inventory and each
  task retrieval; report median, p95, and maximum. Checkout verification and
  human labeling are excluded.
- **Determinism:** SHA-256 of canonical candidate JSON from three clean replays.
- **Provenance completeness:** fraction of candidates with app/revision, task,
  recipe, focus paths, document path, line range, excerpt SHA-256, and resolved
  reference when applicable.
- **Availability/failure taxonomy:** counts and samples for every typed omission
  and synthetic control outcome.

Canonical JSON uses sorted object keys, recipe-ranked arrays, UTF-8, and a
single trailing newline. It contains no timestamps or absolute paths.

## Frozen gates and decision rule

| Gate | Threshold | Consequence if failed |
|---|---:|---|
| Combined precision | at least 0.70 overall and at least 0.50 in every app with emitted candidates | Value failure |
| Incremental task hit rate | at least 5 of 15 tasks (0.333) | Value failure |
| Rotated-focus lift | at least 20 percentage points | Value failure |
| Byte-weighted distraction | at most 0.25 | Value failure |
| Safety | zero `stale_or_conflicting`, `governing_instruction`, or broken-reference candidates emitted; zero primary-list changes | Safety failure |
| Budget | no task exceeds 3 candidates or 2,048 excerpt bytes | Safety failure |
| Latency | p95 task retrieval at most 500 ms and maximum at most 1,000 ms on the pinned local checkouts | Operational failure |
| Determinism | all three canonical candidate JSON files byte-identical | Safety failure |
| Provenance | 100% complete | Safety failure |
| Synthetic controls | every predeclared outcome matches exactly; zero crashes | Safety failure |

The verdict is:

- **Proceed** only if every gate passes. This authorizes a separate packet/API
  design issue, not implementation or an agent-benefit claim.
- **Drop** if combined precision is below 0.50 or the real combined result has
  zero `relevant_unique` candidates.
- **Defer** for every other gate failure, including safety or operational
  failures. A retry requires a new preregistration with a materially different
  deterministic recipe; thresholds are not amended after measurement.

Per-recipe results explain the combined verdict but cannot be selected
post-measurement to turn a failing combined result into a pass.

## Replay and measurement sequence

1. Approve and commit this pre-registration before inspecting subject docs.
2. Implement the stdlib-only runner and synthetic fixtures without generating
   subject candidates. Update `eval/README.md`; run the runner self-check and
   `bundle exec rake test`; review and commit the runner before measurement.
3. Verify all pinned checkouts, then generate the real and rotated-focus
   candidate bundle once. Record the runner commit and artifact hashes.
4. Freeze the opaque label sheet before labeling. Complete every label before
   computing aggregate metrics.
5. Re-run candidate generation under `LC_ALL=C, TZ=UTC`, the available UTF-8
   locale with `TZ=America/Los_Angeles`, and a third clean process using the
   first environment. Compare canonical bytes.
6. Score with the frozen rules; write raw per-candidate/per-task JSON and
   `RESULTS.md`. Do not edit this file or prior recorded evidence.

If a checkout is unavailable or at the wrong SHA, candidate generation stops
before producing partial results. A runner defect found before the first
candidate bundle may be repaired and re-reviewed. A defect found after
candidate generation invalidates all generated candidates and labels; fix it,
record the restart in RESULTS, and regenerate from zero.

## Provenance and planned artifacts

- `eval/documentation-spike/run_documentation_spike.rb` — frozen retrieval and
  scoring runner.
- `eval/documentation-spike/fixtures/` — synthetic negative controls.
- `eval/documentation-spike/candidates.json` — canonical real/control candidate
  records with opaque IDs and provenance.
- `eval/documentation-spike/labels.json` — completed labels keyed by opaque ID.
- `eval/documentation-spike/results/` — raw per-app and summary JSON.
- `eval/documentation-spike/RESULTS.md` — gate table, verdict, taxonomy,
  limitations, and the separate future-source-family inventory.

No raw absolute checkout path, author identity, external content, network
response, secret, or subject agent transcript is recorded.

## Explicit non-goals

- No compiler, resolver, packet, renderer, manifest, CLI, format, normative
  spec, dependency, CI, or existing frozen-evidence change.
- No product documentation discovery or excerpting implementation.
- No broad keyword search, embeddings, generic RAG, or LLM retrieval/judging.
- No claim about agent success, code quality, or exploration cost. A Proceed
  verdict requires a later separately approved behavioral A/B.
- No Git-history, repository-contract/configuration, build/ownership metadata,
  external issues/PRs, CI, telemetry, or runtime-trace measurement. RESULTS may
  list these families only as unmeasured follow-ups.
- No GitHub issue mutation or evalkit change without separate authorization.

## Amendments and sign-off

Mechanical pre-measurement corrections must be dated here and approved before
the freeze commit. After candidate generation, no amendment is allowed.

- **2026-07-17 — pre-measurement corpus-count correction:** The pinned corpus
  contains 15 tasks: Redmine 3, Campfire 4, Lobsters 4, and Publify 4. All
  13-task references are corrected to 15, and the intended ≥30% incremental
  task-hit gate becomes 5/15 (0.333). No subject documentation, candidates,
  labels, or measurements existed when corrected.

- [x] User approved this exact pre-registration on 2026-07-17.
- [x] Frozen in a dedicated commit before subject-document inspection.
