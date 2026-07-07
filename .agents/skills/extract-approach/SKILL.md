---
name: extract-approach
description: Capture durable learning after every non-trivial solved problem — write a note to docs/agent-learnings/ recording the problem, failed approaches, key insight, and a reusable rule. A solution without its learning note is unfinished work.
---

# extract-approach

Run this after every non-trivial solved problem, before moving on. "Non-trivial"
means any of: more than one approach was attempted, the root cause was not the
first hypothesis, the fix required knowledge not written down anywhere in the
repo, or a future agent would plausibly burn >15 minutes rediscovering it.

## When to use

- A debugging session where the first hypothesis was wrong.
- A workflow/tooling failure with a non-obvious fix (e.g. the wedged Codex
  background-poll runs recorded in `PROJECT_TRACKER.md`).
- An experiment/harness pitfall that cost a re-run.
- Any solved problem where you consulted more than the obvious file.

## When NOT to use

- Routine work that succeeded first try using documented conventions.
- Facts already recorded in `PROJECT_TRACKER.md`'s decision log, the specs,
  or `implementation-notes.md` — link to them instead of duplicating. If the
  learning belongs in one of those (a project decision, a spec amendment, a
  pass note), put it there and skip the note.

## Workflow

1. Create `docs/agent-learnings/` if missing.
2. Write `docs/agent-learnings/YYYY-MM-DD-short-title.md` (today's date,
   kebab-case title) with exactly these sections:

   ```markdown
   # <Short title>

   ## Problem
   What was broken or needed, in one or two sentences.

   ## Context
   Where in the repo/workflow this arose; links to files, spec codes, tracker entries.

   ## Failed approaches
   Each attempt that didn't work and *why* it failed. "None" if the path was direct
   (then reconsider whether this note is needed).

   ## Key insight
   The single fact or mental-model correction that unlocked the solution.

   ## Final approach
   What actually worked, concretely enough to repeat.

   ## Verification
   How the solution was proven (commands + observed results).

   ## Reusable rule
   One imperative sentence a future agent can follow without reading the rest.

   ## When to apply again
   The trigger conditions that should make a future agent reach for this note.
   ```

3. If the reusable rule contradicts or extends `AGENTS.md`, propose the
   `AGENTS.md` edit in the same change (don't let the manual and the
   learnings drift apart).

## Verification requirements

- [ ] File exists at `docs/agent-learnings/YYYY-MM-DD-short-title.md` with all
      eight sections non-empty.
- [ ] "Reusable rule" is a single imperative sentence, checkable by a future
      agent.
- [ ] No duplication of an existing note — search `docs/agent-learnings/`
      first; extend an existing note rather than writing a near-duplicate.

## Expected output

One new (or extended) learning note; optionally a proposed `AGENTS.md`
amendment.

## Escalation

- The learning implies a spec or pre-registration problem → surface to the
  user; those documents change only by their own amendment rules.
- Unsure whether it's tracker-decision-log material vs a learning note →
  default to the learning note and mention the ambiguity in it.
