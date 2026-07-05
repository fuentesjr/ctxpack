# Spec: Packet format and determinism

Status: Draft. Source: `design.md` — "What is a context packet?",
"Determinism", "v0 packet contents", "Machine-readable manifest", "Example
packet shape".

## Markdown packet

**FMT-1.** The packet is a Markdown document. Humans and agents are the
primary readers; JSON is never the primary artifact (see MAN-1).

**FMT-2.** Required sections, in order:

1. `# ctxpack context packet` — title.
2. `## Task` — the requested task text. When no `--task` was given, this
   section states that no task was provided. **[fixed by spec]**
3. `## Anchor` — the exact anchor, resolved controller class and action, the
   controller file path, and the repo stamp line
   (`Generated from: <short-sha> (clean|dirty)`).
4. `## Files to inspect first` — one `###` subsection per included file
   (FMT-4).
5. `## Tests to run` — suggested test commands (TEST-6), or an explicit
   statement that no candidates were found (TEST-5).
6. `## Uncertainty` — see FMT-8.

Conditional sections:

7. `## Omitted candidates` — required whenever any limit truncated candidates
   (FMT-9); omitted otherwise.
8. `## Retrieve more only if needed` — follow-up retrieval suggestions,
   emitted as a pure function of the packet's uncertainty and omission state:
   each uncertainty/omission code maps to one templated suggestion (e.g.
   `unresolved_external_callbacks` → inspect the superclass/concerns; omitted
   constants → inspect the named constants manually; no test candidates →
   search `test/` by hand). When no codes are present, the section is
   omitted. **[trigger rule fixed by spec]**

**FMT-3.** The defining property of a packet is provenance: every included
file MUST carry a human-readable "Why" line and a machine-readable reason
code. "Contains billing" is not a reason; `controller_action` is.

**FMT-4.** Each file subsection contains, per included evidence item: a
`Why:` line (templated text, not freeform — DET-3), a `Reason code:` line,
and a fenced Ruby snippet when a snippet applies. A single file may carry
multiple Why/reason/snippet blocks (e.g. the controller file carries the
action snippet and each applicable callback snippet).

**FMT-5.** Snippets are extracted with stable ranges (the enclosing method
definition), subject to the per-file line limit (LIM-1) and the allocation
policy in LIM-4. A head-truncated action snippet ends with an explicit
templated truncation marker line inside the fence (e.g.
`# … truncated by ctxpack at 120 lines`).

## Reason codes

**FMT-6.** v0 reason-code registry:

| Code | Meaning |
|---|---|
| `controller_action` | The controller action file for the requested anchor |
| `before_action_callback` | Snippet of a `before_action` method applying to the action |
| `referenced_constant` | File resolved by convention from a constant referenced in the action or an applicable callback **[name fixed by spec]** |
| `minitest_candidate` | Test file matched by TEST-1 rule 1 or rule 2 |

New codes require a spec update; freeform reason codes are prohibited.

## Uncertainty

**FMT-7.** Uncertainty codes (machine-readable, used in the manifest):

| Code | Emitted when |
|---|---|
| `test_inferred_by_path` | A test candidate matched TEST-1 rule 2 (always — TEST-3) |
| `dynamic_callback_args` | A `before_action` or `skip_before_action` had non-literal filter arguments (CB-2, CB-2a) **[name fixed by spec]** |
| `unresolved_external_callbacks` | Applicable callbacks are declared outside the controller file (CB-4) **[name fixed by spec]** |
| `around_callback_present` | An `around_action` applies to the action; named, not snippeted (CB-1a) **[name fixed by spec]** |
| `block_callback_present` | An applicable callback was declared with an inline block, so there is no method to snippet (CB-1a) **[name fixed by spec]** |

**FMT-8.** The `## Uncertainty` section MUST state, in templated prose, at
minimum: which test files were inferred by path; that callbacks outside the
controller file were not resolved; that route discovery is delegated to Rails;
and any convention-only constant matches worth verifying. If a guess was
made anywhere, it is named here — no false precision.

**FMT-9.** The `## Omitted candidates` section names the specific candidates
each limit excluded (constants, test files), so the reader can inspect
manually. Truncation without this section is a bug (LIM-2).

## Repo stamp

**FMT-10.** Exactly one repo-state stamp is allowed inside packet content:
the git commit SHA at generation time, with a `dirty` marker when the working
tree has uncommitted changes. The dirty marker is honest rather than precise:
the SHA cannot capture uncommitted changes, so a dirty-tree packet must say
so.

**FMT-11.** Stamp resolution uses normal git discovery from the application
root (`git -C <app_root> rev-parse HEAD`), so an app in a monorepo
subdirectory stamps the enclosing repository's SHA. Outside any git work
tree, the stamp is the fixed string `unknown (not a git repository)` — still
deterministic.

**FMT-12.** Dirty means any non-empty `git status --porcelain` output from
the application root — staged, unstaged, or untracked (gitignored files
excluded). Untracked files count because a new untracked file can be
snippeted into the packet while being invisible to the SHA — exactly the
irreproducibility the marker exists to flag. **[fixed by spec]**

## Determinism

**DET-1.** Core guarantee:

```text
same repo state + same packet inputs = same normalized packet content
```

"Normalized" means: output path ignored, repo-stamp line normalized when
comparing across repo states (see EVAL-7).

**DET-2.** File ordering within the packet is deterministic: the entrypoint
controller file first, then constant files in first-reference order
(CONST-4), then test candidates in TEST-1 rule order. **[fixed by spec]**

**DET-3.** All prose in the packet is templated: reason text, Why lines,
uncertainty notes. No model-generated summaries anywhere.

**DET-4.** No fuzzy or autonomous retrieval, and no hidden agent judgment, in
packet construction. Skills or sub-agents may consume packets; they MUST NOT
be the canonical packet builder.

**DET-5.** No generated timestamps inside packet content. The
migration-style timestamp in the default filename is the only timestamp, and
it is a storage concern (CLI-12). The repo stamp (FMT-10) is the only
permitted repo-state marker, allowed because it is a function of repo state.

## JSON manifest

**MAN-1.** The manifest is optional (`--manifest`, CLI-10), generated from
the same internal packet object as the Markdown, and written as a sibling
`.json` file. It exists so evals can assert stable fields without parsing
Markdown prose. It is not a second product surface in v0; if evals can use
the internal packet object directly, the public flag can wait.

**MAN-2.** Manifest shape (`version: 1`):

```json
{
  "version": 1,
  "anchor": "accounts#upgrade",
  "repo": {
    "commit": "0f4b21c9e8d3a17650b2c44aa91d7e5f8c03d6ab",
    "dirty": false
  },
  "entrypoint": {
    "file": "app/controllers/accounts_controller.rb",
    "controller": "AccountsController",
    "action": "upgrade"
  },
  "files": [
    {
      "path": "app/controllers/accounts_controller.rb",
      "reason_code": "controller_action",
      "snippet_ranges": [[24, 39]]
    }
  ],
  "tests": [
    {
      "command": "bin/rails test test/integration/accounts_upgrade_test.rb",
      "reason_code": "minitest_candidate"
    }
  ],
  "uncertainty": [
    { "code": "test_inferred_by_path" }
  ]
}
```

Field notes: `repo.commit` is the full SHA or `null` outside a git work tree
**[null-outside-git fixed by spec]**; `snippet_ranges` are 1-based inclusive
line ranges; `reason_code` and `uncertainty[].code` values come from the
FMT-6 / FMT-7 registries.

**MAN-3.** Manifest content follows the same determinism rules as the
Markdown (DET-1..DET-5), including stable key order.
