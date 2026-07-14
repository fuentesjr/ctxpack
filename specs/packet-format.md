# Spec: Packet format and determinism

Status: Draft. Source: `design.md` — "What is a context packet?",
"Determinism", "v0 packet contents", "Machine-readable manifest", "Example
packet shape"; amended 2026-07-13 for format v3 / seed ontology
(`docs/seed-based-interface-proposal.md` §6.2, §14.4).

## Version policy

**FMT-0.** Format version 3 **replaces** version 2 as the only emitted version
at Phase 2 (first non-anchor seed). There is no compatibility fork and no
emission flag. Both version carriers bump together: the Markdown `Format:`
line and the manifest `version` field. Phase 1 (behavior-compatible wrap)
still emits format v2 byte-identical to pre-seed goldens; Phase 2 re-baselines
every golden. Consumers MUST inspect `version` and reject unsupported versions.

## Markdown packet

**FMT-1.** The packet is a Markdown document. Humans and agents are the
primary readers; JSON is never the primary artifact (see MAN-1).

**FMT-2.** Required sections, in order:

Every `##` section heading is followed by one blank line before its content.

1. `# ctxpack context packet` — title.
2. `## Task` — the requested task text, with every input line contained in a
   Markdown blockquote. Blank input lines render as `>` lines so headings,
   lists, thematic breaks, and fences in task text cannot create peer packet
   sections. CRLF, bare-CR, and LF separators normalize to LF for Markdown
   display only; the packet object and manifest preserve the raw task string.
   When no `--task` was given, the blockquote states that no task was provided.
   **[fixed by spec]**
3. `## How to use this packet` — two fixed bullets: tasks that already name a
   failing test, error, or exact location start there and use the packet to
   verify coverage; otherwise start with the entrypoint (or focus list when no
   anchor seed is present) and open other files only as the task touches them.
4. **Locus section (version-dependent):**
   - **Format v2 (Phase 1 only):** `## Anchor` — the exact anchor, resolved
     controller class and action, controller path, repo stamp, `Format: 2`,
     and the FMT-8 `Scope:` line.
   - **Format v3:** always include `## Seeds` — one inventory line per seed
     (`kind: identity`). When an anchor seed is present, also include
     `## Anchor` with the same heading-shape fields as v2 (exact anchor,
     controller class/action, controller path, repo stamp, `Format: 3`,
     FMT-8 `Scope:`). When no anchor seed is present, omit `## Anchor` and
     put repo stamp + `Format: 3` + a seed-appropriate `Scope:` line under
     `## Seeds` (or a following `## Focus` header line — exact placement fixed
     at Phase 2 implementation and locked by goldens). Non-anchor packets use
     `## Focus` as the human label for the inspect inventory when that
     improves clarity; the machine inventory remains DET-2-ordered file lines
     (FMT-3). **[v3 fixed by seed proposal §6.2]**
5. `## Inspect first` — one flat DET-2-ordered inventory line per included
   file, carrying its literal reason code and templated provenance (FMT-3).
   (May be titled `## Focus` in non-anchor v3 packets if goldens so decide;
   content contract is unchanged.)
6. `## Evidence` — one `###` subsection per file that has at least one
   snippet, in DET-2 order (FMT-4). Omitted when no snippets exist.
7. `## Run` — suggested test commands (TEST-6), or the explicit TEST-5
   no-candidate statement; for non-anchor seeds, Run may list the seed’s
   primary test path command when applicable.

Conditional sections:

8. **Withdrawn.** `## Retrieve more only if needed` was replaced by FMT-2 §9;
   the code remains reserved and is not reused.
9. `## Follow-ups` — one deduplicated imperative bullet per packet-specific
   uncertainty, convention-only constant match, omitted candidate, or explicit
   no-test-candidate state. Omitted when none exist. **[trigger rule fixed by
   spec]**

**FMT-3.** The defining property of a packet is provenance: every included
file MUST carry a human-readable templated phrase and a literal
machine-readable reason code on its `## Inspect first` inventory line.
"Contains billing" is not a reason; `controller_action` is.

**FMT-4.** `## Evidence` contains subsections only for files with snippets.
Each evidence item renders one provenance line containing the reason code,
subject, and FMT-5 ranges, followed by a fenced Ruby snippet. A single file
may carry multiple evidence blocks (e.g. the action and each applicable
callback). Pointer-only constant, view, and test files have no Evidence
subsection.

**FMT-4a.** The `view_candidate` inventory phrase is templated as
`conventional template for <controller#action>` — filled in with the resolved
anchor (the same form used in `## Anchor`). No snippet follows (VIEW-3).

**FMT-5.** Snippets are extracted with stable 1-based inclusive ranges (the
enclosing method definition), displayed on the evidence provenance line as
`lines <start>–<end>` (multiple ranges comma-separated in stored order), and
subject to the per-file line limit (LIM-1) and allocation policy in LIM-4. A
head-truncated action snippet ends with an explicit templated truncation marker
inside the fence (e.g. `# … truncated by ctxpack at 120 lines`).

## Reason codes

**FMT-6.** Reason-code registry (anchor codes retained; seed codes added at
the phase that ships the kind):

| Code | Meaning | Since |
|---|---|---|
| `controller_action` | The controller action file for the requested anchor | v0 |
| `before_action_callback` | Snippet of a `before_action` method applying to the action | v0 |
| `referenced_constant` | File resolved by convention from a constant referenced in the action, an applicable callback, or a same-file method transitively called from the action **[name fixed by spec]** | v0 |
| `view_candidate` | Conventional view template for the resolved action (VIEW-1..VIEW-3) | v0 |
| `minitest_candidate` | Test file matched by TEST-1 rule 1 or rule 2 | v0 |
| `rspec_candidate` | Spec file matched by TEST-1 RSpec rule 1 or rule 2 | v0 |
| `test_seed_primary` | User-named test/spec file from a `test` seed | Phase 2 |
| `files_seed_primary` | User-named file from a `files` seed | Phase 2 |
| `files_seed_neighbor` | Neighbor inferred by the files recipe | Phase 2 |
| `error_seed_frame` | Application frame file from an `error` seed | Phase 3 |
| `method_seed_primary` | User-named method def file from a `method` seed | Phase 5a |

New codes require a spec update; freeform reason codes are prohibited.

## Uncertainty

**FMT-7.** Uncertainty codes (machine-readable, used in the manifest):

| Code | Emitted when |
|---|---|
| `test_inferred_by_path` | A test candidate matched selected-family TEST-1 rule 2 (always — TEST-3) |
| `dynamic_callback_args` | A `before_action` or `skip_before_action` had non-literal filter arguments (CB-2, CB-2a) **[name fixed by spec]** |
| `unresolved_external_callbacks` | An applicable in-file callback declaration names a method with no direct definition in the controller file (CB-4) **[name fixed by spec]** |
| `around_callback_present` | An `around_action` applies to the action; named, not snippeted (CB-1a) **[name fixed by spec]** |
| `block_callback_present` | An applicable callback was declared with an inline block, so there is no method to snippet (CB-1a) **[name fixed by spec]** |
| `view_inferred_by_convention` | An included view file was matched by action→template convention, not confirmed against the action's actual render target; emitted once per included view with that view path as subject (VIEW-4, VIEW-6) |
| `test_seed_surface_uncertain` | A `test` seed could not deterministically resolve a production surface, or resolved only by weak path-token heuristics (Phase 2) |

**FMT-8.** Standing v0 boundaries appear exactly once in the templated
`Scope:` line under `## Anchor`: routes, superclass/concern callbacks, and
locale files are not scanned; the same line embeds the action-specific
`bin/rails routes -g <action>` command and `config/locales/` pointer.
Packet-specific uncertainty appears exactly once as an imperative FMT-2 §9
follow-up: path-inferred tests, coded callback uncertainty, convention-only
constant matches, and convention-inferred view templates are named
specifically; each included convention-inferred view gets its own path-named
Follow-up. If a guess was made anywhere, it is named — no false precision.

**FMT-9.** `## Follow-ups` names every candidate excluded by a limit (constant
files, test files, view files, and truncated snippets) in an imperative bullet
that includes the current applicable value from `Compiler::LIMITS`. Truncation
facts carry the semantic limit key that selected that value; renderers MUST NOT
infer it from category or reason prose. Truncation without such a bullet is a
bug (LIM-2).

## Repo stamp

**FMT-10.** Exactly one repo-state stamp is allowed inside packet content:
the git commit SHA at generation time, with a `dirty` marker when the working
tree has uncommitted changes. The dirty marker is honest rather than precise:
the SHA cannot capture uncommitted changes, so a dirty-tree packet must say
so.

**FMT-11.** Stamp resolution uses normal git discovery from the application
root (`git -C <app_root> rev-parse HEAD`), so an app in a monorepo
subdirectory stamps the enclosing repository's SHA. When Git state is
unavailable — whether outside a work tree or because the Git executable is
missing — the stamp is the fixed honest string `unknown (Git state
unavailable)` rather than claiming an unobserved cause.

**FMT-12.** Dirty means any non-empty `git status --porcelain` output from
the application root — staged, unstaged, or untracked (gitignored files
excluded). Untracked files count because a new untracked file can be
snippeted into the packet while being invisible to the SHA — exactly the
irreproducibility the marker exists to flag. **[fixed by spec]**

## Determinism

**DET-1.** Core guarantee:

```text
same repo state + same task + same normalized seeds = same normalized packet content
```

"Normalized" means: output path ignored, repo-stamp line normalized when
comparing across repo states (see EVAL-7); seeds normalized per SEED-8 /
SEED-20.

**DET-2.** File ordering within the packet is deterministic:

- **Anchor-only packets (historic):** the entrypoint controller file first,
  then the action's conventional view file(s) in lexicographic order
  (VIEW-2, VIEW-5, VIEW-7), then constant files in first-reference order
  (CONST-4), then test candidates in TEST-1 rule order.
- **Non-anchor / multi-seed packets:** seed primaries in seed order (then
  path order within a multi-file seed), then neighbors/inferred files in
  recipe order, with global `max_total_files` applied per MERGE-4. When an
  anchor seed is present in a multi-seed packet, its controller remains the
  entrypoint and the historic anchor sub-order applies within the anchor
  contribution before merge with other seeds’ files.

**[fixed by spec; multi-seed order fixed by seeds.md MERGE-*]**

**DET-3.** All prose in the packet is templated: inventory provenance,
evidence provenance, Scope text, Run annotations, and Follow-ups. No
model-generated summaries anywhere.

**DET-4.** No fuzzy or autonomous retrieval, and no hidden agent judgment, in
packet construction. Skills or sub-agents may consume packets; they MUST NOT
be the canonical packet builder.

**DET-5.** No generated timestamps inside packet content. The
migration-style timestamp in the default filename is the only timestamp, and
it is a storage concern (CLI-12). The repo stamp (FMT-10) is the only
permitted repo-state marker, allowed because it is a function of repo state.

## JSON manifest

**MAN-1.** The manifest is an optional public machine-fact representation
(`--manifest`, CLI-10), generated from the same internal packet object as the
primary Markdown artifact and written as a sibling `.json` file. Evals and
other consumers use its stable facts without parsing Markdown prose; it never
replaces Markdown as the primary human/agent surface.

**MAN-2.** Manifest shape:

**Version 2** (Phase 1 only — byte-compatible with pre-seed goldens):

```json
{
  "version": 2,
  "task": "Implement billing upgrade.",
  "anchor": "accounts#upgrade",
  "repo": { "available": true, "commit": "…", "dirty": false },
  "entrypoint": {
    "file": "app/controllers/accounts_controller.rb",
    "controller": "AccountsController",
    "action": "upgrade"
  },
  "files": [],
  "tests": [],
  "follow_ups": [],
  "omitted_candidates": [],
  "no_test_candidates": false
}
```

**Version 3** (Phase 2 onward — the only emitted version after Phase 2):

```json
{
  "version": 3,
  "task": "Implement billing upgrade.",
  "seeds": [
    { "kind": "anchor", "identity": "accounts#upgrade", "evidence": "accounts#upgrade" }
  ],
  "anchor": "accounts#upgrade",
  "repo": { "available": true, "commit": "…", "dirty": false },
  "entrypoint": {
    "file": "app/controllers/accounts_controller.rb",
    "controller": "AccountsController",
    "action": "upgrade"
  },
  "files": [],
  "tests": [],
  "follow_ups": [],
  "omitted_candidates": [],
  "no_test_candidates": false
}
```

Field notes:

- `task` is the raw task string or `null`.
- **v3 `seeds`** is a non-empty array of `{kind, identity, evidence}` objects
  in seed order. Through Phase 3 it has length 1; Phase 4 allows length > 1.
  `identity` is the CLI-8a seed-identity string; `evidence` is the normalized
  evidence string (for `error`, a stable join of `path:line` frames — never
  the raw paste).
- **v3 `anchor`** is present when an anchor seed contributed; otherwise
  `null` or omitted consistently (implementation locks one form at Phase 2
  and goldens enforce it). v2 `anchor` remains required.
- **v3 `entrypoint`** is present for anchor seeds (same shape as v2); for
  non-anchor-only packets it is `null` or a focus primary descriptor locked
  at Phase 2.
- `repo.available` is false exactly when `repo.commit` is `null`;
  `repo.commit` is the full SHA or `null` when Git state is unavailable
  **[null-outside-git fixed by spec]**.
- Files are grouped in DET-2 order and preserve every evidence item's subject,
  1-based inclusive ranges, and truncation state. A file MAY list multiple
  `reason_code` values under multi-seed merge (MERGE-3); the evidence array
  carries one item per reason/subject pair.
- Tests preserve path, command, FMT-6 reason code, and TEST-1 rule.
  `no_test_candidates` distinguishes an explicit no-candidate result from an
  empty list caused by another state.
- `follow_ups` contains facts, never rendered prose. FMT-7 uncertainty uses
  its registry code and subject; `view_inferred_by_convention` subjects are
  always the specific included view path, never `null`. Code-less packet
  facts use the manifest-only codes `convention_constant_match` (plus
  `path`), `omitted_candidate` (plus `category` and `limit_key`), and
  `no_test_candidates` (subject `test/` or `spec/`). Full omission facts
  also appear under `omitted_candidates` as `category`, `subject`,
  `reason`, and `limit_key`. `limit_key` names a key in `Compiler::LIMITS`.

Manifest versions are breaking schema versions. ctxpack emits only the current
version; it does not retain compatibility modes before a real external
consumer requires them. Consumers MUST inspect `version` and reject versions
they do not support. Version 3 replaces version 2 at Phase 2 the same way
version 2 replaced version 1 — no dual-emission flag.

**MAN-3.** Manifest content follows the same determinism rules as the
Markdown (DET-1..DET-5), including stable key order.
