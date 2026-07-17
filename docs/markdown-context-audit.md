# Markdown context audit

Baseline: `21912b57366dc91beedc51652501f246525f1d2c`.

This audit separates files stored in the repository from files that consume an
agent's context. A document is an active context risk only when an agent loads
it automatically, follows a route to it, or surfaces it during exploration.
Size alone is not a deletion reason.

## Inventory

The baseline contains 107 tracked `.md` paths: 103 regular documents and four
Claude symlinks to repo-owned skills. The regular documents contain 807,759
bytes and 15,104 newline-terminated lines. Counting the symlink target blobs as
tracked content yields 807,957 bytes and 15,108 path-lines.

| Surface | Documents | Bytes | Lines | Context/provenance role |
|---|---:|---:|---:|---|
| `AGENTS.md`, `CLAUDE.md` | 2 | 22,468 | 347 | Root instruction adapters; automatic loading is client-dependent |
| `PROJECT_TRACKER.md` | 1 | 103,323 | 1,256 | Explicit fresh-session work-order entry point |
| Specs, `design.md`, `eval-plan.md` | 9 | 158,159 | 3,049 | Normative contract, rationale, and evaluation rules |
| User docs | 3 | 47,932 | 1,245 | `README.md`, examples, and FAQ |
| Operational/history ledgers | 4 | 130,890 | 2,157 | Pass history, debt, feedback, and backlog |
| Historical proposals | 3 | 89,895 | 1,633 | Decision provenance; not normative |
| Agent learnings | 14 | 34,449 | 681 | Trigger-routed reusable lessons |
| Eval tree | 63 | 204,526 | 4,398 | Frozen/recorded evidence mixed with runbooks and inventories |
| Repo-owned skill bodies | 4 | 16,117 | 338 | Loaded on skill trigger |

Default hidden-omitting `rg --files` discovery sees only 99 documents. It
misses the four canonical `.agents/skills/*/SKILL.md` files and four
`.claude/skills/` symlink paths, so tracked-document inventories must derive
from `git ls-tree` and inspect object modes.

No regular Markdown files are byte-identical. Semantic overlap and stale
authority—not duplicate blobs—are the cleanup opportunities.

## Exposure graph

The 103 regular documents contain 110 Markdown-link occurrences and 86 unique
directed edges. A broader resolvable `.md` path-mention scan identifies the
main routing surfaces:

| Source | Unique targets | Mentions |
|---|---:|---:|
| `PROJECT_TRACKER.md` | 32 | 131 |
| `implementation-notes.md` | 22 | 58 |
| `AGENTS.md` | 12 | 32 |
| `README.md` | 11 | 27 |
| `specs/seeds.md` | 11 | 15 |

Forty-nine regular documents have no incoming resolvable Markdown-path
mention. That includes 27 of 30 recorded packet/prompt files, 10 of 14 learning
documents, `docs/agent-backlog.md`, and `docs/packet-format-proposal.md`.
Low inbound exposure does not make recorded evidence disposable, but it does
show that the eval tree is not the primary bootstrap cost.

The tracker is the dominant avoidable load. Its 932-line decision log is 74.2%
of its lines and 66.2% of its bytes even though continuation loads the whole
file. `implementation-notes.md` is a second 1,851-line cumulative history whose
opening describes an obsolete compilation-only API.

## Observed consumption and harm

The recorded corpus contains 98 Claude sessions, 10.4 MB of transcripts, and
1,535 parsed tool calls. No tool explicitly read a ctxpack Markdown document.
One command searched for `CLAUDE.md`/`AGENTS.md` and returned no output; no
manual reference cascade followed.

Root instructions were nevertheless injected before exploration into nested
evaluation workspaces:

- A Lobsters agent explicitly rejected `rake test` because the requirement was
  from ctxpack's `CLAUDE.md`, then selected RSpec.
- A Campfire agent added an irrelevant statement that no ctxpack Tier 0 corpus
  rescan was required.

Both tasks succeeded. The evidence proves cross-workspace contamination and
avoidable reasoning, not a code defect or task failure. It also does not
measure normal Codex work inside ctxpack, so causal worktree ablation remains
necessary for unique historical material.

## Static information hazards

These findings do not depend on a live-agent cost experiment:

- `docs/packet-format-proposal.md` is unreferenced, says the implementation is
  uncommitted, and is superseded by the normative format spec, reconciled
  design, tests, and Git history.
- `docs/agent-backlog.md` presents completed multi-app, coverage, and README
  work as the current priority list. Its two still-relevant concerns can move
  to the active tracker/debt surface.
- `PROJECT_TRACKER.md` mixes the current work order with completed and mutually
  superseding status chronology.
- `implementation-notes.md` presents its first historical pass as current and
  states an obsolete public API.
- `AGENTS.md` describes an anchor-only product and repeats completion gates,
  while current behavior also accepts task plus explicit seeds.
- `specs/README.md`, `specs/views.md`, and the end of `design.md` retain shipped
  work as pending or as the next experiment.
- The documentation-writing skills require cumulative histories and generic
  learning notes, recreating the stock after cleanup.

## Disposition constraints

- Protect normative specs, `eval-plan.md`, frozen pre-registrations, recorded
  results, packets, prompts, and transcripts. They are evidence, not ordinary
  documentation; any later repository migration needs its own provenance plan.
- Keep skill bodies routed on demand. Fix stale triggered instructions, but do
  not delete them for raw size.
- Static proof is sufficient for documents that are fully superseded and have
  an authoritative replacement. Unique rationale or history requires the
  causal gate in the decision map before removal.
- An in-tree archive does not reduce broad-search exposure. Git history is the
  recovery mechanism for removed active-tree history.

## Method and limits

The inventory used `git ls-tree`, `git cat-file`, `git show`, `git grep`, and
in-memory Ruby parsing against the baseline commit. The transcript audit parsed
all JSONL records read-only and correlated instruction phrases with each run's
pinned ctxpack SHA. No recorded evidence was modified.

Automatic instruction loading beyond the observed clients is environment
specific. Path mentions are a discovery heuristic, not proof of a read. Static
contradictions establish staleness; only controlled runs can establish their
effect on Codex task quality.
