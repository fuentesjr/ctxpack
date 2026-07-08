# Tier 2 expansion — results

Extends the Tier 2 A/B ([`../tier2/RESULTS.md`](../tier2/RESULTS.md)) to three
apps across two test frameworks, per the frozen
[`PREREGISTRATION.md`](PREREGISTRATION.md). Answers the two questions Tier 2
raised but could not settle (multi-file features; the test-candidate pointer)
and tests cross-framework generalization.

## Verdict

**SUPPORT — and it generalizes.** The per-app rule (treatment shows ≥ 30% median
reduction in calls-to-first-load-bearing-read *or* distraction-reads on ≥ 2 of 4
tasks, with no success/quality regression) is met on **all three apps, across
both frameworks** (Minitest + RSpec):

| app | framework | tasks meeting bar | success (control / treatment) |
|---|---|---|---|
| Campfire | Minitest | **2/4** | 12/12 · 12/12 |
| Lobsters | RSpec | **3/4** | 12/12 · 12/12 |
| Publify | RSpec (engine) | **3/4** | 11/12 · 12/12 |

The two open questions resolve cleanly: **the packet helps multi-file features
(it does not hurt them — the Tier 2 scare was noise)**, and **the wins do not
depend on the test-candidate pointer** (they persist, even strengthen, when the
packet carries no test candidate — so the packet's code content is the driver).
As in Tier 2, `task_success` is saturated (71/72), so the exploration metric
carries the verdict; the blind diff-quality pass is a pending follow-up (below).

## Provenance

- **72 grid sessions** (3 apps × 4 tasks × 2 arms × 3 rounds) + 6 pilots, all
  `status:"complete"`, serial, arm order alternating by round, resumable via each
  app's `runs.jsonl`. Committed under `eval/tier2-expansion/<app>/`.
- Subject: Claude Code + `claude-sonnet-5`, `--dangerously-skip-permissions`,
  sterile authenticated `CLAUDE_CONFIG_DIR`. Packets generated once per task by
  `ctxpack packet` (framework-aware via P1 `21505b0`), SHA-256 pinned, identical
  bytes across a task's treatment runs.
- Apps: **Campfire** `71ffeeea` (Minitest/SQLite), **Lobsters** `430d864b`
  (RSpec/MariaDB), **Publify** = `publify_core` engine `80ede867` (RSpec/SQLite).
  Anchors drawn blind (seed = each app SHA) before any packet; `anchors.json` per
  app. Task-id map: 1,2 = feature · 3 = bug · 4 = behavior.
- Run hygiene: throttle-induced `timeout`/`aborted` records (subject process hung
  on a usage-window cap, 0 tokens) were re-run to completion and kept only as
  provenance; the one degraded 4 s `complete` (`publify t2-1-control-3`) was
  deleted and re-run. Every tuple has exactly one `complete` record.
- Cost: **51.4M subject tokens** total (Campfire 19.8M / Lobsters 20.2M / Publify
  11.4M), ≈ $20 Sonnet-equivalent; median wall 74–128 s/session.

## Exploration metrics (grid, per app × task × arm)

Median across 3 rounds. LBR = calls-to-first-load-bearing-read (nil = the agent
edited a load-bearing file with no preceding Read of it; excluded from the
median). DIS = distraction-reads. `tc` = packet carried a test candidate.
`meets` = ≥ 30% reduction on the better of LBR/DIS.

| app · task | kind | tc | LBR c→t | LBR %↓ | DIS c→t | DIS %↓ | meets |
|---|---|---|---|---|---|---|---|
| camp t1 | feature | ✓ | 3→1 | **67%** | 0→0 | — | ✅ |
| camp t2 | feature | ✓ | 2→3 | −50% | 5→4 | 20% | ✗ |
| camp t3 | bug | ✓ | nil→2 | — | 0→1 | — | ✗ |
| camp t4 | behavior | ✓ | 2→1 | **50%** | 0→0 | — | ✅ |
| lob t1 | feature | ✓ | 9→1 | **89%** | 2→2 | 0% | ✅ |
| lob t2 | feature | ✗ | 2→14 | −600% | 5→3 | **40%** | ✅ |
| lob t3 | bug | ✓ | 2→2 | 0% | 0→1 | — | ✗ |
| lob t4 | behavior | ✗ | 3→1 | **67%** | 0→0 | — | ✅ |
| pub t1 | feature | ✓ | 2→1 | **50%** | 0→1 | — | ✅ |
| pub t2 | feature | ✓ | 2→1 | **50%** | 2→0 | **100%** | ✅ |
| pub t3 | bug | ✓ | nil→5 | — | 0→0 | — | ✗ |
| pub t4 | behavior | ✓ | 2→1 | **50%** | 0→0 | — | ✅ |

## Pre-registered interpretation applied

- **Generalizes.** 3/3 apps meet the per-app support bar (≥ 2/4 tasks), across
  both frameworks; no treatment success regression on any app (Publify treatment
  12/12 ≥ control 11/12).
- **Feature caveat refuted.** Pooled across apps: **features 5/6 tasks meet the
  bar, median 58.5% reduction** — the *strongest* category, not the weakest. The
  Tier 2 "packet hurts multi-file features" pattern (n=1) does not survive 6
  instances. The consistent non-meeter is instead the **bug task in all three
  apps** (0/3): control agents localize straight from the failing-test output
  (LBR often nil = zero exploration), leaving nothing for the packet to save,
  while treatment agents also read the packet's files first. Behavior tasks meet
  in all three apps (3/3).
- **Test-pointer contribution — not the driver.** Split by
  `packet_had_test_candidate`: **true → 6/10 meet, median 50%**; **false → 2/2
  meet, median 53.5%** (both Lobsters). Wins persist and are marginally larger
  without a test candidate, so the packet's value is its file/constant/callback
  **content**, not the suggested test command. This addresses the `eval-plan.md`
  confound in the "whole packet" direction (caveat: only n=2 false instances —
  Lobsters' within-app 2/2 split).

## Diff quality (blind, 0–8) — PENDING follow-up

Not yet run. As in Tier 2, the verdict rests on the exploration metric with
`task_success` saturated; the blind four-dimension 0–8 rubric (arm labels
stripped, seeded shuffle, author-judged) over the 72 diffs is a confirmatory
follow-up. The `diffs/` are committed per app; nothing in the support verdict
depends on quality *improving* — only on it not regressing, which the saturated
success rate is consistent with.

## Reading of the result

The packet reliably lands the first load-bearing read a step or two sooner
whenever the task does **not** already ship with a localizing signal — features
and behavior changes, where the agent must first find the relevant
controller/model/callback. It adds nothing (and a little exploration overhead) on
the **bug** task, whose failing test already points at the code. That is a
coherent, useful boundary: ctxpack's value concentrates on
find-the-code-from-a-description work, not fix-the-failing-test work. The
cross-framework consistency (Minitest and RSpec, three unrelated codebases,
including an engine + dummy-app) makes the effect look structural rather than
app-specific.

## Threats to validity

- **Directional, not statistical.** n = 3/arm/task; medians over 3 points, with
  real noise (LBR nils on bug tasks; treatment outliers like `lob t2` [2,16,14]).
- **Saturated success** makes `task_success` non-discriminating; the exploration
  metric is a proxy for effort, not outcome quality — and **diff quality is not
  yet judged**.
- **Author-authored tasks across 3 apps** amplify selection bias; mitigated by
  pre-packet blind anchor draws and hidden acceptance tests, not eliminated.
- **Read-tool-only counting**; work done via Grep/Bash/other tools is invisible
  to LBR (part of why control bug-task LBR is often nil).
- **Publify is an engine benchmark** (stub `config/application.rb`, dummy-app
  scoring); representative of engine-shaped apps, one step removed from a
  deployed monolith.

## Pre-registered next action

Per `eval-plan.md`'s decision rule, Tier 2 SUPPORT → expand (done here) → *"only
then consider Rubydex-backed resolution, judged by the same harness."* With
generalization now shown across two frameworks and the value localized to
find-the-code tasks, the sharpest next probes are: (1) the pending blind
diff-quality pass to close the quality gate; (2) whether packet-vs-diff coverage
(recall/precision of packet files against files the completed task touched — the
designated post-v0 north-star) tracks the exploration wins; and (3) Rubydex-backed
resolution against this same three-app harness.
