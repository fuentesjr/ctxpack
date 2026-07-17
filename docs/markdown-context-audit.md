# Markdown context audit

Baseline: `21912b57366dc91beedc51652501f246525f1d2c`.

This audit separates files stored in the repository from files that consume an
agent's context. A document is an active context risk only when an agent loads
it automatically, follows a route to it, or surfaces it during exploration.
Size alone is not a deletion reason.

The investigation used two lanes. Fully superseded material could leave the
active tree when a current authoritative replacement and Git recovery path
existed. Unique suspect material required a controlled Codex ablation with no
quality regression and either a 30% context-cost reduction on a task majority
or elimination of a repeated document-caused wrong turn. Normative specs and
frozen/recorded eval evidence kept their stricter reconciliation/provenance
rules.

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

Compacting the root rules reduces their cost but does not isolate nested
subject workspaces. The root instructions now explicitly scope ctxpack's test
and corpus gates to changes in this repository; a future harness/workspace
boundary remains the structural fix for inherited-instruction contamination.

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
  an authoritative replacement. Unique rationale or history requires a frozen
  causal gate before removal.
- Historical snapshots do not reduce broad-search exposure, but explicit
  nonauthority headers prevent them from competing with the current tracker
  and notes. The incomplete causal gate requires this residual cost; Git
  remains a second recovery mechanism.

## Final disposition

The causal pilot stopped under its frozen 900k-token cap after five runs, so it
does not authorize removing unique/protected material. It did expose one direct
stale-tracker wrong turn. The compact run selected the right ticket but also
invented an approval stop for authorized local commits/deletions; full results
are in
[`../eval/markdown-context/RESULTS.md`](../eval/markdown-context/RESULTS.md).

The independent static lane therefore:

- deletes the superseded packet-format proposal and stale agent backlog;
- compacts `AGENTS.md`, `CLAUDE.md`, `PROJECT_TRACKER.md`, and cumulative pass
  notes while keeping current authority, safety gates, and the provider
  benchmark recipe;
- separates their unique completed chronology into explicitly historical
  documents because the incomplete causal gate does not authorize deletion;
- corrects objectively stale status in specs and `design.md`;
- changes learning/pass workflow policy so completed chronology and generic
  lessons no longer accumulate automatically;
- retains normative specs, design rationale, both remaining proposals, all
  learning notes, and all frozen/recorded eval evidence.

The tracker/pass-note compaction is an authority separation, not a causal
deletion claim. Current work and approvals remain in the tracker, rationale in
`design.md`, requirements in `specs/`, measurements in frozen results, open
work in the tracker/issues/debt, and the standing operational recipe in
current pass notes. Unique completed chronology remains active but
nonauthoritative in `docs/history/project-tracker-through-2bf1c86.md` and
`docs/history/implementation-notes-through-2bf1c86.md`, with Git as a second
recovery path.

The completed decision map remains as explicitly historical investigation
evidence because the causal gate was incomplete.

Working-tree accounting after cleanup is 107 regular Markdown documents plus
four Claude skill symlinks (111 tracked paths), 807,364 regular-document bytes,
and 15,231 lines. The two retained historical snapshots total 220,742 bytes,
so the inconclusive gate deliberately prevents a large corpus-size win:

- total regular Markdown falls 395 bytes (<0.1%) while lines rise by 127
  (0.8%) because the audit/protocol/results and historical headers are new;
- root Markdown falls from 309,095 to 90,332 bytes (70.8%) because completed
  chronology moves out of the fresh-session authority surface;
- automatically/client-loaded `AGENTS.md` + `CLAUDE.md` fall from 22,468 to
  6,503 bytes (71.1%);
- the current tracker plus current pass notes are 11,274 bytes, down from
  215,116 bytes at baseline, with unique chronology retained separately.
- the tracker falls from 103,323 to 5,733 bytes (94.5%);
- implementation notes fall from 111,793 to 5,541 bytes (95.0%).

The retained increase lives under `docs/history/`, the completed decision map,
and routed eval/audit evidence—not the fresh-session bootstrap chain.

## Method and limits

The inventory used `git ls-tree`, `git cat-file`, `git show`, `git grep`, and
in-memory Ruby parsing against the baseline commit. The transcript audit parsed
all JSONL records read-only and correlated instruction phrases with each run's
pinned ctxpack SHA. No recorded evidence was modified.

Automatic instruction loading beyond the observed clients is environment
specific. Path mentions are a discovery heuristic, not proof of a read. Static
contradictions establish staleness; only controlled runs can establish their
effect on Codex task quality.
