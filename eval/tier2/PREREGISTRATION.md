# Tier 2 agent-in-the-loop A/B — pre-registration

**Status: FROZEN 2026-07-05 (user sign-off in session).** No thresholds,
task text, metric definitions, or interpretation rules change from this
point; only the explicitly permitted amendment rules below apply, each
amendment recorded in this file. Registered against the definition in
[`eval-plan.md`](../../eval-plan.md) ("Tier 2 — agent-in-the-loop A/B").
Thresholds and rules below are fixed before any data is collected and are
not adjusted after seeing results. Amendments after freezing are allowed
only where an explicit amendment rule below permits them, and every
amendment is recorded in this file.

## Subject (pinned agent)

- **Agent:** Claude Code CLI, headless. Exact CLI version recorded verbatim
  in every run record; the CLI is not upgraded mid-grid (a version change
  invalidates and restarts the grid).
- **Model:** `claude-sonnet-5`, pinned via `--model` on every invocation.
  Rationale (decision log, PROJECT_TRACKER 2026-07-05): the current Sonnet
  tier is the honest strong control — same sticker price as older Sonnets,
  currently cheaper under intro pricing, and downgrading the subject would
  handicap the competitor and inflate ctxpack's measured benefit.
- **Invocation:**
  `claude -p --model claude-sonnet-5 --output-format stream-json --verbose --dangerously-skip-permissions`
  with the session's working directory set to the task workspace.
- **Config isolation:** all sessions run with a dedicated
  `CLAUDE_CONFIG_DIR` created for this experiment: logged in once, no user
  CLAUDE.md, no memory, no custom agents/skills, no MCP servers. A snapshot
  hash of its settings is recorded in each run record.
- **Billing:** the user's Claude subscription (5-hour usage windows). The
  execution rules below are designed around that constraint.

## App

**Redmine @ `3386d9595767b3d0c455ace9281e056e9f61bd56`** (shallow clone
recorded 2026-07-05), Rails 8.1.3, Minitest, SQLite test database.

Chosen because ctxpack's test-candidate rules and task shape 2 assume
Minitest, and Redmine is the only large, clonable, conventionally-structured
Minitest Rails app among the candidates considered (the Tier 0 trio are all
RSpec). Anchor-resolution scan at this SHA using the Tier 0 method
(`extract_routes.rb` fallback + `classify_anchors.rb`):
**330/336 pairs resolved (98.2%), zero compiler crashes** — raw data in
[`routes/redmine.json`](routes/redmine.json) and
[`results/redmine.json`](results/redmine.json).

**Known limitation (recorded, not fixable without abandoning Minitest):**
Redmine keeps controller tests in `test/functional/` (pre-Rails-5 layout),
so packet test-candidate rule 1 (`test/controllers/…`, TEST-1) never fires
and rule 2 fires rarely; packets will usually carry an explicit
"no test candidates" line (TEST-5). This experiment therefore measures the
value of the packet's file/constant/callback content, and the eval plan's
test-suggestion confound cannot be observed on this app.

## Anchor selection

Anchors were drawn **before any packet was generated or read**
(eval-plan.md, "Anchor selection"). Procedure, fully deterministic and
committed as [`draw_anchors.rb`](draw_anchors.rb):

1. All 336 unique `controller#action` pairs from the route table, ordered
   by `SHA256("<app_sha>:<pair>")` (seed = the pinned Redmine SHA).
2. Task shapes filled tightest-filter-first (2, then 3, then 1) walking
   that order once each, requiring distinct controllers across shapes.
   Per-anchor signals consulted: the classifier's resolution boolean (a
   packet must exist for the treatment arm to run) and the mechanical
   shape filters in the script header. Packet content was never read.
3. Every skip recorded: [`anchors.json`](anchors.json).

Result: **shape 1 `twofa#deactivate_init`, shape 2 `my#show_api_key`,
shape 3 `roles#create`** (one skip: `twofa#deactivate_init` rejected for
shape 3, not a write action).

*Feasibility amendment rule:* if harness setup proves a drawn anchor
infeasible (e.g. the seeded bug cannot be made to fail its test), the draw
advances to the next candidate in the shuffled order for that shape, with
the reason recorded here — permitted only before any grid session for that
task has run.

## Tasks (frozen text)

Task prompts given to the agent are the verbatim contents of
[`tasks/task1_prompt.md`](tasks/task1_prompt.md),
[`tasks/task2_prompt.md`](tasks/task2_prompt.md),
[`tasks/task3_prompt.md`](tasks/task3_prompt.md).

1. **Feature** at `twofa#deactivate_init`: send a security-notification
   email when 2FA deactivation is initiated. Acceptance:
   [`tasks/task1_acceptance_test.rb`](tasks/task1_acceptance_test.rb).
2. **Bug fix** at `my#show_api_key`: the workspace branch carries
   [`tasks/task2_seed.patch`](tasks/task2_seed.patch) (a one-line
   ivar-rename drift bug that 500s the view); the agent receives the
   failing-test command plus verbatim runner output. Acceptance: the
   existing `test_show_api_key` passes and the full
   `test/functional/my_controller_test.rb` file is green; the scorer also
   verifies no file under `test/` was modified.
3. **Behavior change** at `roles#create`: warn when `copy_workflow_from`
   references a missing role. Acceptance:
   [`tasks/task3_acceptance_test.rb`](tasks/task3_acceptance_test.rb).

Acceptance tests are hidden from the agent: they live only in this
directory, are never present in a session workspace, and are copied into
`test/functional/` of a separate scoring checkout after each session.

*Acceptance-test amendment rule:* the pilot may surface mechanical setup
bugs in the acceptance tests (fixture names, API drift). Such repairs are
allowed **only before any grid session runs**, must never weaken an
assertion after any agent output exists, and are recorded here.

## Arms

Identical wrapper prompt; the only difference is `{context_block}`.

```text
You are working in a Redmine checkout at the current working directory.

Task anchor (controller#action): {anchor}

{task_description}

{context_block}

Rules:
- Make the smallest correct change consistent with this codebase's
  conventions.
- Leave your final changes uncommitted in the working tree.
- Work autonomously; do not ask questions.
```

- **Control:** `{context_block}` is empty.
- **Treatment:** `{context_block}` is:

```text
## Context packet

The following context packet was generated for this task's anchor by a
static analysis tool. It may help you locate relevant code.

{packet_markdown}
```

Packets are generated once per task at grid setup by `ctxpack packet` from
the ctxpack commit recorded in the run records; the SHA-256 of each packet
markdown is recorded and the identical bytes are used in every treatment
session for that task.

## Harness and execution (subscription-aware)

- **Workspace per session:** fresh checkout of Redmine at the pinned SHA
  (task 2 additionally has the seed patch committed on top), with bundle
  and SQLite test DB prepared once and copied in. No eval artifacts or
  acceptance tests are ever inside a workspace.
- **Run records:** one JSONL line per session appended to
  `eval/tier2/runs.jsonl` (schema below) — the harness's public contract
  (decision log 2026-07-05) and the resume key.
- **Serial execution, pre-registered order.** Pilot first: task 2, control
  then treatment, one run each, marked `pilot: true`, excluded from
  analysis. Grid: rounds r = 1..3; within a round tasks 1, 2, 3; the two
  arms of a task run back-to-back, arm order alternating by round (odd
  rounds control-first, even rounds treatment-first) so usage-window
  boundaries and any drift hit both arms symmetrically.
- **Resumability across usage windows:** a `(task, arm, run_index)` tuple
  with a `status: "complete"` record is skipped on harness restart; the
  grid may be executed in batches across 5-hour windows without affecting
  validity (model and versions are pinned; sessions are independent).
- **Abort rule:** a session interrupted by the subscription usage limit, a
  crash, or a network failure is recorded with `status: "aborted"`, its
  metrics are discarded, and the tuple is re-run in a later window.
  Aborted records are retained in `runs.jsonl`.
- **Timeout rule:** a session exceeding 30 minutes wall-clock is terminated
  and recorded `status: "timeout"`; it counts as `task_success: false`
  with its metrics kept (unlike aborts, timeouts are agent behavior, not
  harness/window failures).
- **Calibration:** the pilot's per-session token/window consumption is
  recorded and used to size grid batches, leaving headroom in each window
  (guideline, not a gate).

## Metrics

Mechanical, computed from the `stream-json` transcript and the final
`git diff` of the workspace (definitions fixed here; applied identically to
both arms):

| Metric | Definition |
|---|---|
| `task_success` | Acceptance suite exits 0 in the scoring checkout (plus task-specific checks above) |
| `calls_to_first_load_bearing_read` | 1-based index, over all tool_use events, of the first Read whose file appears in the final diff; null if none |
| `distraction_reads` | Count of distinct files Read but neither edited nor present in the final diff |
| `discarded_edits` | Count of distinct files edited (Edit/Write) but absent from the final diff |
| `total_tool_calls` | Count of tool_use events |
| `total_tokens` | input + output + cache-read + cache-creation from the session result event |
| `wall_time_s` | Session start to session end |

Recorded limitation: file reads made via Bash (`cat`, `sed`) are not counted
as reads in either arm; only the Read tool counts.

**Diff quality (human-judged, blind):** each final diff scored 0–2 on four
dimensions — correct beyond the acceptance test, minimal, follows app
conventions, no unrelated changes — sum 0–8. All 18 diffs are judged in one
sitting after the last session, stripped of arm labels and presented in a
seeded shuffled order. Judge is the author; residual bias acknowledged per
eval-plan "Threats to validity".

## Runs

**3 runs per arm per task (18 sessions) + 2 pilot sessions.**

*Extension rule:* the grid may be extended to 5 runs per arm using the
identical harness and pinned versions, but only as a decision taken for all
tasks at once **before any per-arm analysis has been computed**. No
per-task, post-peek extensions.

## Pre-registered interpretation (verbatim from eval-plan.md)

- **Support:** in at least 2 of 3 tasks, treatment shows a ≥ 30% median
  reduction in calls-to-first-load-bearing-read or distraction reads, with
  no regression in success rate or diff quality.
- **Fail:** neither exploration nor outcomes improve meaningfully on at
  least 2 of 3 tasks.

At this sample size the result is directional evidence, not statistics.

## JSONL run-record schema

One object per line in `eval/tier2/runs.jsonl`:

```json
{
  "run_id": "t2-<task>-<arm>-<run_index>[-pilot]",
  "pilot": false,
  "task": 1,
  "arm": "control | treatment",
  "run_index": 1,
  "status": "complete | aborted | timeout",
  "started_at": "ISO 8601",
  "ended_at": "ISO 8601",
  "app_sha": "3386d9595767b3d0c455ace9281e056e9f61bd56",
  "ctxpack_sha": "<git SHA of ctxpack used to generate packets>",
  "packet_sha256": "<sha256 of packet markdown, null for control>",
  "agent": {
    "cli_version": "<claude --version verbatim>",
    "model": "claude-sonnet-5",
    "settings_sha256": "<hash of CLAUDE_CONFIG_DIR settings snapshot>"
  },
  "usage": {
    "input_tokens": 0,
    "output_tokens": 0,
    "cache_read_tokens": 0,
    "cache_creation_tokens": 0
  },
  "metrics": {
    "task_success": true,
    "calls_to_first_load_bearing_read": 0,
    "distraction_reads": 0,
    "discarded_edits": 0,
    "total_tool_calls": 0,
    "wall_time_s": 0
  },
  "transcript_path": "transcripts/<run_id>.jsonl",
  "workspace_diff_path": "diffs/<run_id>.patch",
  "notes": ""
}
```

## Threats to validity (this instance)

Inherited from eval-plan.md (author bias, agent nondeterminism, model
drift, single-app generalization), plus instance-specific:

- **Test-candidate emptiness on Redmine** (above): the packet's test
  pointer is structurally absent, so a null result here does not rule out
  test-pointer-driven value on modern-layout apps.
- **Read-tool-only read counting** may undercount exploration done via
  Bash; applied identically to both arms, so the A/B difference remains
  meaningful.
- **Subscription-window batching** spreads sessions over days; mitigated by
  pinned versions and the alternating arm order.

## Amendments

- **2026-07-05 (pre-pilot, mechanical setup fix):** `tasks/task2_seed.patch`
  as originally committed was not an applicable unified diff — the
  redirection that wrote it captured rtk-hook-filtered `git diff` output
  instead of the raw diff. Regenerated via `git diff --output=…` from the
  pinned checkout with the identical frozen semantic (the one-line
  `@user` → `@current_user` rename inside `MyController#show_api_key`);
  verified with `git apply --check`. No task text, assertion, or threshold
  changed; no agent output existed at the time.

- **2026-07-05 (pre-pilot, mechanical setup clarification):** the frozen text
  did not say which tree state task 2's packet is generated from. Generating
  it from the pristine pinned tree would inline the pre-bug line
  (`@user = User.current`) into the packet — leaking the fix to the
  treatment arm. The harness therefore generates task 2's packet from the
  seeded tree (pinned SHA + seed commit), the realistic input for a bug-fix
  task; tasks 1 and 3 generate from the pinned tree directly. Recorded
  packet SHA-256s in `packets/packets.json` reflect this. No agent output
  existed at the time.

## Sign-off

- [x] User approved this pre-registration (FROZEN 2026-07-05)
- [x] Pilot run (2 sessions) complete; no acceptance/harness fixes needed
      (2026-07-06)
- [x] Grid run per the execution rules — 18/18 `complete`, zero aborts
      (2026-07-06)
- [x] Analysis + `RESULTS.md` per the interpretation rules — **SUPPORT**
      (diff-quality scores pending author confirmation)
