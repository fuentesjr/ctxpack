# Tier 2 agent-in-the-loop A/B — results

Executes the frozen [`PREREGISTRATION.md`](PREREGISTRATION.md). All
thresholds, metric definitions, and the interpretation rule below were fixed
before any data was collected; nothing here adjusts them.

## Verdict

**SUPPORT (directional).** In 2 of 3 tasks (bug-fix and behavior-change) the
treatment arm reached its first load-bearing read with a ≥ 30% lower median,
with no regression in success rate (100% both arms) and no meaningful
regression in blind diff quality (control 8.00 vs treatment 7.89 / 8). This
clears the pre-registered support bar. At 3 runs/arm this is directional
evidence, not statistics.

The result is **task-shape dependent**: the packet helps the small-surface
tasks (2, 3) and *slightly hurts* the multi-file feature (task 1), where the
extra context added exploration and tokens without changing the (already
correct) outcome. That nuance is the most useful finding here.

## Provenance

| | |
|---|---|
| App | Redmine @ `3386d9595767b3d0c455ace9281e056e9f61bd56` |
| Subject | Claude Code `2.1.201`, model `claude-sonnet-5` |
| Config snapshot | `settings_sha256` `ca3d163bab055381…` (sterile `CLAUDE_CONFIG_DIR`) |
| ctxpack (packet gen) | `6e68c71` |
| Packet SHA-256s | task1 `3efccba1…`, task2 `e0fc8a6d…`, task3 `15dd1941…` ([`packets/packets.json`](packets/packets.json)) |
| Grid window | 2026-07-06 22:50:43Z → 23:34:20Z (rounds 1–3, two batches same day) |
| Sessions | 18 grid + 2 pilot; **all `complete`, zero aborts/timeouts** |
| Grid cost | ≈ 10.64M tokens total (input+output+cache) |

Per-session run records: [`runs.jsonl`](runs.jsonl). Transcripts under
`transcripts/`, final diffs under `diffs/`.

## Exploration & cost metrics (grid, per task × arm)

Mechanical, from the `stream-json` transcript and final `git diff` (definitions
frozen in PREREGISTRATION "Metrics"). `LBR` = `calls_to_first_load_bearing_read`.

| Task | Arm | LBR (runs) | median LBR | distraction (runs) | total tool calls (med) | tokens (med) |
|---|---|---|---|---|---|---|
| 1 twofa (feature) | control | 2, 6, 5 | **5** | 1, 2, 1 | 24 | 1.04M |
| 1 twofa (feature) | treatment | 6, 7, 12 | **7** | 0, 1, 2 | 26 | 1.09M |
| 2 my (bug fix) | control | 5, —, 3 | **4** | 0, 0, 1 | 6 | 0.23M |
| 2 my (bug fix) | treatment | 2, 2, 1 | **2** | 1, 1, 1 | 4 | 0.14M |
| 3 roles (behavior) | control | 2, 2, 2 | **2** | 0, 1, 0 | 12 | 0.46M |
| 3 roles (behavior) | treatment | 1, 1, 1 | **1** | 0, 0, 0 | 13 | 0.52M |

(`—` = null: one task-2 control run never issued a `Read` of a file that
appeared in its diff; median taken over the two defined values.)

## Pre-registered interpretation applied

Rule (verbatim): *Support if, in ≥ 2 of 3 tasks, treatment shows a ≥ 30%
median reduction in calls-to-first-load-bearing-read or distraction reads,
with no regression in success rate or diff quality.*

| Task | median LBR reduction | ≥ 30%? |
|---|---|---|
| 1 | 5 → 7 (**−40%**, worse) | ✗ |
| 2 | 4 → 2 (**50%**) | ✓ |
| 3 | 2 → 1 (**50%**) | ✓ |

→ **2 of 3 tasks** clear the LBR bar. (Distraction-read medians are ~0 in
both arms on all tasks, so LBR is the operative metric.)

- **Success rate:** `task_success` is `true` for all 18 grid sessions in both
  arms — 100%, no regression. Note this also means outcome success is
  **saturated at ceiling** and cannot itself discriminate the arms; the signal
  is entirely in exploration efficiency and diff quality.
- **Diff quality:** no regression (below).

Both conditions on the support rule hold → **SUPPORT**.

## Diff quality (blind, 0–8)

Each final diff scored 0–2 on four dimensions (correct-beyond-acceptance-test,
minimal, follows-conventions, no-unrelated-changes). Presented by opaque code,
arm labels stripped, in a seeded shuffle (seed = app SHA
`3386d959…`; order and per-code scores in `tmp/tier2/judging/`). Byte-identical
diffs were forced to identical scores.

| Task | control (runs) | treatment (runs) |
|---|---|---|
| 1 | 8, 8, 8 → **8.00** | 8, 7, 8 → **7.67** |
| 2 | 8, 8, 8 → **8.00** | 8, 8, 8 → **8.00** |
| 3 | 8, 8, 8 → **8.00** | 8, 8, 8 → **8.00** |
| **overall** | **8.00** | **7.89** |

The single sub-8 (a task-1 treatment diff) inserted the new locale key away
from its `twofa_mail_body_security_notification_*` siblings — a minor
convention miss. Treatment does not regress quality.

**Caveat on the judging (important):** diff quality is at ceiling — Sonnet 5
produces correct, minimal, conventional diffs on all three tasks with or
without the packet — so this dimension has almost no discriminating power here.
And these scores are an **agent first-pass for author review**, not the
pre-registered author judgment; residual author bias plus the ceiling effect
both argue against reading anything into the 0.11-point gap. Treatment showing
no regression is the load-bearing claim, and it holds under any reasonable
re-scoring.

## Reading of the result

- The packet's value is **exploration efficiency**, not output quality: on the
  bug-fix and behavior-change tasks it roughly halved the calls to the first
  load-bearing read and cut tokens (~40% on task 2), while every arm still
  produced a correct, ceiling-quality diff.
- On the **multi-file feature (task 1)** the packet did not help and mildly
  hurt: median LBR rose 5 → 7 and tokens were flat-to-higher. Hypothesis: the
  feature's real work is spread across a controller, a mailer/library method,
  and a locale file, and the anchor-centered packet points at the entry point
  without collapsing that multi-file search — so it adds reading surface
  without shortcutting the hunt. Worth probing if Tier 2 is expanded.
- **Redmine caveat (pre-registered):** the `test/functional/` layout makes the
  packet's test-candidate pointer structurally empty (TEST-5), so this
  experiment measured only the file/constant/callback content of the packet.
  A null test-pointer result here says nothing about modern-layout apps.

## Threats to validity

Inherited from `eval-plan.md` (author bias, agent nondeterminism, model drift,
single-app generalization) plus, for this instance: outcome-success and
diff-quality ceilings limit discrimination to exploration metrics; read-tool
-only counting may undercount Bash-based exploration (applied identically to
both arms); 3 runs/arm is directional. The diff-quality scores await author
confirmation.

## Pre-registered next action

`eval-plan.md`'s decision rule: **Tier 2 support → expand to more tasks and a
second app.** The task-1 regression makes the sharpest follow-up question
concrete: does the packet help or hurt *multi-file* feature work, and does the
test-candidate pointer add value on a modern (`test/controllers/`) layout that
Redmine could not exercise?
