# Markdown context decision map

Status: tickets #1 and #2 resolved; frontier is #3. Baseline: ctxpack
`21912b5`. Detailed evidence: [`markdown-context-audit.md`](markdown-context-audit.md).

Goal: reduce the Markdown that coding agents are likely to load, and remove
documents that measurably worsen their work, without losing current authority
or irrecoverable evidence.

## Resolved decisions

- **Active documentation surface** means Markdown in the default checkout that
  is automatically loaded, explicitly routed to, or likely to appear in normal
  search/navigation. Bytes on disk are not context cost until a document is
  read.
- **Context cost** is Markdown read volume plus the tool calls, tokens, and time
  it induces. **Context harm** is a causal degradation in correctness, spec
  compliance, diff quality, or exploration caused by a document's presence.
- Codex is the causal subject. Existing Claude transcripts may provide
  observational evidence; cross-agent causal confirmation is deferred unless
  the Codex result needs it.
- Two removal lanes apply:
  1. A document may leave the active tree without live runs when it is provably
     superseded or duplicated, an authoritative replacement exists, and it has
     no unique required evidence.
  2. Unique but suspect material requires a pre-registered Codex worktree
     ablation before removal.
- A causal removal candidate must reduce median Markdown/exploration cost by at
  least 30% on the pre-registered task majority, or eliminate a repeated
  document-caused wrong turn, with no regression in task success, spec
  compliance, or blind diff quality. Small pilots locate signal; confirmation
  requires at least three task shapes and three runs per arm.
- Removal means leaving the default working tree. Moving a file to an in-tree
  archive does not count because broad search can still surface it. Git history
  is the default recovery mechanism.
- Normative specs and `design.md` retain their reconciliation rules. Frozen
  pre-registrations and recorded eval evidence require a separately approved
  provenance migration before they may leave the default branch.
- Live subject sessions require a visible spend approval after the
  pre-registration states task count and expected cost. No deletion happens
  during evidence collection.
- Worktrees isolate causal arms and any later independent implementation or
  review streams; they are unnecessary for the read-only frontier ticket.

## #1: What is the active documentation surface?

Blocked by: none
Type: Research

### Question

At baseline `21912b5`, which Markdown files are automatically loaded, routed
to, linked from common entry points, or likely to surface in broad search, and
what unique authority does each carry?

### Answer

Resolved. The baseline has 107 tracked Markdown paths but 103 regular
documents; four `.claude` paths are symlink adapters to four canonical
`.agents` skill files. The regular documents total 807,759 bytes / 15,104
lines. The explicit continuation path makes the 103 KB tracker the highest
known load, while skill bodies are routed on trigger and the 63-file eval tree
has low ordinary inbound exposure. No regular files are byte-identical.

The active discovery chain is `AGENTS.md` -> `PROJECT_TRACKER.md` -> cumulative
history and authority documents. The tracker routes to 32 Markdown targets and
its completed decision log is two thirds of its bytes. See the audit for the
complete category accounting, link/path graph, authority classes, and limits.

## #2: Which documents are actually consumed or implicated in wrong turns?

Blocked by: #1
Type: Research

### Question

Across existing agent transcripts, which Markdown files are read, how much
pre-code context do they consume, which references trigger further reads, and
which observed mistakes can be traced to stale or conflicting documentation?

### Answer

Resolved observationally. Across 98 Claude transcripts and 1,535 parsed tool
calls, no tool explicitly read a ctxpack Markdown file and no manual reference
cascade occurred. Root `CLAUDE.md` instructions were still injected into
nested subject workspaces: one agent had to reject ctxpack's rake rule while
working on Lobsters and another emitted an irrelevant Tier 0 disclaimer while
working on Campfire. Both tasks succeeded, so this proves contamination and
avoidable reasoning, not correctness harm. The corpus does not measure Codex
working in ctxpack; ticket #3 remains required.

## #3: Which document categories causally help or harm Codex?

Blocked by: #1, #2
Type: Prototype

### Question

Using held-out tasks and isolated worktrees, how do full-doc, lean-history, and
other evidence-selected repository surfaces change Codex cost and outcomes?

### Answer

Pending. Check `eval/README.md` before authoring: extend the Tier 2 harness if
its arm model fits; otherwise pre-register why a new runner is necessary. Run
a cheap pilot before any confirmation grid.

## #4: Which individual files should change disposition?

Blocked by: #3
Type: Research

### Question

Within categories that show harm, which files should remain active, be
compressed, become explicitly routed-on-demand, or leave the default tree?

### Answer

Pending. Use narrower ablations only where category evidence cannot isolate the
cause; apply the proof-of-supersession lane where it can.

## #5: What cleanup preserves authority and provenance?

Blocked by: #4
Type: Grilling

### Question

What exact cleanup set discharges the measured harm while keeping one current
source of truth, required experiment provenance, and recoverability?

### Answer

Pending. Present the evidence and exact delete/compress/route set before
implementation; keep unrelated documentation cleanup out of the change.
