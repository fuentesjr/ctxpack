# Tier 2 harness runbook

Operational notes for running the frozen Tier 2 A/B (see
[`PREREGISTRATION.md`](PREREGISTRATION.md) for the science, which is fixed;
this file is just how to drive [`harness.rb`](harness.rb)).

The harness accepts an optional app selector:

```bash
ruby eval/tier2/harness.rb [app] setup
ruby eval/tier2/harness.rb [app] run [N]
ruby eval/tier2/harness.rb [app] status
ruby eval/tier2/harness.rb [app] verify
```

If `[app]` is omitted, it defaults to `redmine`, so the original Tier 2
commands below remain valid. `verify` is offline: it compares Redmine's
schedule, run ids, prompt bytes, prompt determinism, and packet SHA-256s
against `eval/tier2/golden/*`. Skeleton expansion apps with no tasks print
`<app>: not yet authored (0 tasks)` and exit successfully.

## Why a dedicated session / flags

The harness spawns the subject agent as
`claude -p --model claude-sonnet-5 --dangerously-skip-permissions …` (frozen
invocation). Claude Code's **auto-mode permission classifier refuses to let an
agent spawn those unsandboxed sub-sessions**, so the orchestrating session
must start with the classifier off.

**Start the new session from the project root with:**

```bash
cd /Users/sal/Projects/ctxpack
claude --dangerously-skip-permissions
```

That is the single flag that matters — it turns off the auto-mode classifier
for the orchestrating session so it can launch the harness. (`--model` for
*your* orchestrating session is irrelevant to the experiment; the harness
always pins the subject to `claude-sonnet-5` regardless of your default.)

Safety context for granting this: every subject session runs in a disposable
`git clone` under `tmp/tier2/workspaces/<run_id>/`, isolated from the repo and
deleted after scoring. Nothing the subject does touches the ctxpack working
tree.

### First message in the new session

> Continue the Tier 2 pilot from eval/tier2/RUNBOOK.md.

## Preconditions (already satisfied, verify if unsure)

- `ruby eval/tier2/harness.rb verify` prints `OK`.
- `ruby eval/tier2/harness.rb status` runs and lists the 20-tuple schedule.
- `tmp/tier2/template` is Redmine @ `3386d959`, bundled, test DB migrated.
- `tmp/tier2/claude-config/` is an authenticated sterile `CLAUDE_CONFIG_DIR`
  (settings.json is `{}`). Auth check:
  `CLAUDE_CONFIG_DIR=$PWD/tmp/tier2/claude-config claude -p "Reply with exactly: OK" --model claude-haiku-4-5`
  → prints `OK`. If it prints "Not logged in", re-login interactively:
  `CLAUDE_CONFIG_DIR=$PWD/tmp/tier2/claude-config claude` then `/login`.
- `eval/tier2/packets/packets.json` exists (packets generated, SHAs recorded).
- If any precondition is missing: `ruby eval/tier2/harness.rb setup` is
  idempotent and rebuilds everything except the interactive login.

## Run the pilot

```bash
ruby eval/tier2/harness.rb run 2
```

Runs the first 2 pending tuples = the pilot (task 2, control then treatment,
`pilot: true`). Serial; up to 30 min/session. Appends one JSONL line per
session to `eval/tier2/runs.jsonl`; writes `transcripts/<run_id>.jsonl`,
`diffs/<run_id>.patch`, and `tmp/tier2/scoring-logs/<run_id>.log`.

Prints per session: `-> complete success=true|false` (or `aborted`/`timeout`).
On `aborted` the loop stops (usage window likely gone) — just re-run the same
command to resume; complete tuples are skipped.

## After the pilot — what to check

1. `runs.jsonl` last 2 lines: `status`, `metrics.task_success`,
   `usage.*` (for batch sizing), `metrics.wall_time_s`.
2. Sanity: control and treatment diffs both fix the `@current_user`/`@user`
   rename; neither touches `test/`.
3. Calibration: sum tokens + wall-time per session → size grid batches to fit
   the 5-hour usage window with headroom.
4. Apply any *mechanical* acceptance-test fixes surfaced (allowed pre-grid
   only; record in PREREGISTRATION.md amendments). Never weaken an assertion.

## Run the grid

```bash
ruby eval/tier2/harness.rb run          # all remaining pending tuples
ruby eval/tier2/harness.rb run 6        # or a window-sized batch
```

18 sessions: rounds 1–3 × tasks 1,2,3 × {control,treatment}, arms
back-to-back, arm order alternating by round (odd control-first, even
treatment-first). Resume across usage windows by re-running; `runs.jsonl` is
the resume key.

`ruby eval/tier2/harness.rb status` shows done/pending at any time.

## Then

Blind-judge the 18 diffs (author, seeded shuffle, arm labels stripped, 0–2 on
four dimensions), analyze per the pre-registered interpretation, write
`eval/tier2/RESULTS.md`, and run the PROJECT_TRACKER end-of-session ritual.
Ask before committing.
