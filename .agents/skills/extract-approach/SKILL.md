---
name: extract-approach
description: Place durable learning from a non-trivial solved problem in its smallest authoritative home; create a docs/agent-learnings note only when no better code, test, spec, eval, tracker, or current-pass home exists.
---

# extract-approach

Run this placement decision after every non-trivial solved problem, before
moving on. "Non-trivial" means any of: more than one approach was attempted,
the root cause was not the first hypothesis, the fix required knowledge not
written down anywhere in the repo, or a future agent would plausibly burn >15
minutes rediscovering it. The output is a durable canonical home, not
necessarily a new Markdown file.

## When to use

- A debugging session where the first hypothesis was wrong.
- A workflow/tooling failure with a non-obvious fix that is not already
  captured in the owning skill or current eval result.
- An experiment/harness pitfall that cost a re-run.
- Any solved problem where you consulted more than the obvious file.

## When NOT to use

- Routine work that succeeded first try using documented conventions.
- Facts already encoded in code/tests or recorded in a spec, eval result,
  current tracker, current pass notes, or an existing learning — improve or
  link that source instead of duplicating it.
- Generic language/runtime facts whose regression is permanently captured by
  a focused test and whose explanation adds no project-specific decision.

## Workflow

1. Search code/tests, specs, eval results, `PROJECT_TRACKER.md`,
   `implementation-notes.md`, and existing learnings. Choose the smallest
   authoritative home that will be encountered when the problem recurs.
2. If one exists, update it or record that the learning is already captured;
   do not create another file.
3. Only when no better home exists, write
   `docs/agent-learnings/YYYY-MM-DD-short-title.md` (today's date,
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

4. If the reusable rule contradicts or extends `AGENTS.md`, propose the
   `AGENTS.md` edit in the same change (don't let the manual and the
   learnings drift apart).

## Verification requirements

- [ ] The lesson has one named authoritative home and is not duplicated.
- [ ] If a new learning file was necessary, all eight sections are non-empty
      and "Reusable rule" is one checkable imperative sentence.
- [ ] Existing notes were searched; extend rather than create a near-duplicate.

## Expected output

One named durable home, which may be an existing test/spec/eval/tracker/pass
note. A new or extended learning note is the fallback, not the default.

## Escalation

- The learning implies a spec or pre-registration problem → surface to the
  user; those documents change only by their own amendment rules.
- Unsure between two Markdown homes → prefer the one already authoritative for
  the behavior; do not create a third source while uncertain.
