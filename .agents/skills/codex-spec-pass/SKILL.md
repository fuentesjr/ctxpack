---
name: codex-spec-pass
description: Run a ctxpack spec implementation pass via the Codex delegation loop — dispatch the brief to Codex, poll in the background, verify session-side requirement-by-requirement, route defects back via --resume, gate on the corpus re-scan, and close with the tracker ritual. Use when PROJECT_TRACKER.md's execution plan calls for implementing a spec pass or a comparable multi-file lib/ change.
---

# codex-spec-pass

The repo's standing workflow for landing a spec pass (see `PROJECT_TRACKER.md`,
"Working process"). Implementation is delegated to Codex; review, verification,
and acceptance are always session-side.

## When to use

- The execution plan in `PROJECT_TRACKER.md` names a spec pass (a file in
  `specs/` with a requirement prefix like `ANCH`, `FMT`, `CLI`, `EVAL`).
- A multi-file change to `lib/` that has a written spec or precise brief.

## When NOT to use

- Small in-session mini-passes (e.g. the ANCH amendment mini-pass) — the
  tracker reserves the Codex loop for full spec passes; do focused TDD directly.
- Eval harness or docs-only work (no spec codes to verify against).
- Anything touching a frozen `PREREGISTRATION.md` — stop and ask the user.

## Workflow

1. **Write the brief.** Name the spec file and every requirement code in
   scope, the test command (`bundle exec rake test`), and the rule that Codex
   owns the pass notes in `implementation-notes.md`.
2. **Dispatch** via the `codex:codex-rescue` agent. It is a one-shot
   forwarder: it returns a task ID without waiting. **Always instruct the
   forwarder to launch via the companion's own `--background` flag** — a
   foreground companion inside a harness background shell gets reaped at
   subagent exit and the job wedges at "running" forever (upstream
   codex-plugin-cc#432).
3. **Poll from the main session** with the plugin companion script at
   `$(jq -r '.plugins["codex@openai-codex"][0].installPath' ~/.claude/plugins/installed_plugins.json)/scripts/codex-companion.mjs`
   (resolve via `installed_plugins.json`, not by picking a cache version
   dir — stale versions linger there): `status <task-id>` /
   `result <task-id>`, backgrounding a polling loop for long runs.
   - Wedged-run fingerprint: job JSON under the plugin's `state/<ws>/jobs/`
     has no `request` key. The Codex turn usually completed server-side —
     verify the working tree, then `cancel` the stale record.
4. **Verify session-side. Never trust Codex's own summary.**
   - `bundle exec rake test` — paste the summary line; it must show 0 failures.
   - `git status` / `git diff` — review the diff **requirement-by-requirement**
     against the pass's spec codes; record each code as verified or defective.
   - Confirm `implementation-notes.md` has current pass notes.
5. **Fix rounds:** route each confirmed defect back to the **same** Codex
   session by forwarding a `--resume` request, then re-verify (step 4) before
   acceptance.
6. **Corpus re-scan gate:** if the pass changed compiler behavior (anything
   under `lib/ctxpack/` affecting resolution, callbacks, constants, test
   candidates, or limits), run the `tier0-corpus-rescan` skill before
   acceptance. Passes that don't touch compiler behavior skip it — say so
   explicitly.
7. **Reconcile docs:** spec bugs found during implementation are amended in
   the spec *and* reconciled with `design.md` in the same change
   (`specs/README.md` rule). Never renumber requirement codes; mark retired
   ones *Withdrawn*.
8. **Close:** update `PROJECT_TRACKER.md` (Status table, decision log entry,
   rewrite "Next step: execution plan" per the end-of-session ritual). Ask
   before committing.

## Verification requirements

Before claiming the pass is done, all of:

- [ ] `bundle exec rake test` run in this session; summary line pasted; 0 failures.
- [ ] Every in-scope requirement code checked against the diff, individually.
- [ ] Corpus re-scan run or explicitly skipped with the reason "no compiler behavior touched".
- [ ] `implementation-notes.md` updated by Codex (confirmed current, not assumed).
- [ ] `PROJECT_TRACKER.md` Status + decision log + execution plan rewritten.

## Expected output

A working-tree diff implementing the spec pass, green suite, updated
`implementation-notes.md` and `PROJECT_TRACKER.md`, and a session report
listing: requirement codes verified, defects found and their fix rounds,
corpus re-scan result or skip reason.

## Escalation

- Two consecutive `--resume` fix rounds fail on the same defect → stop and
  report (what was tried, what happened, best hypothesis, recommended next move).
- Codex proposes a spec amendment → surface it to the user before adopting;
  spec and `design.md` must move together.
- Any need to change dependencies, `ctxpack.gemspec`, or CI → ask first.
