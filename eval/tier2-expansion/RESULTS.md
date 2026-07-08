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
carries the verdict; the blind diff-quality pass (below) is now **complete** and
confirms **no quality regression** (control 7.94 / treatment 7.94 of 8), closing
the frozen rule's one remaining gate.

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

## Diff quality (blind, 0–8)

Ran the pre-registered blind four-dimension rubric (0–2 each:
correct-beyond-acceptance-test, minimal, follows-conventions,
no-unrelated-changes; sum 0–8) over **all 72 grid diffs**. Arm labels stripped;
each app's 24 diffs shuffled into opaque codes by a PRNG seeded on its app SHA;
**byte-identical diffs forced to identical scores** (47 unique byte-contents
across the 72). Judge-of-record: the orchestrator, scoring **blind to arm** — the
opaque-code → session/arm map was sealed and unread until scoring was finalized.
Reproducible via `build_blind_judging.rb` + `tabulate_quality.rb`; per-code
scores, comments, mapping, and aggregate under
[`judging/`](judging/) (see [`judging/README.md`](judging/README.md)).

| app · task | kind | control (runs → mean) | treatment (runs → mean) |
|---|---|---|---|
| camp t1 | feature | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| camp t2 | feature | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| camp t3 | bug | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| camp t4 | behavior | 7,8,8 → **7.67** | 8,8,8 → **8.00** |
| lob t1 | feature | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| lob t2 | feature | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| lob t3 | bug | 7,8,8 → **7.67** | 8,8,8 → **8.00** |
| lob t4 | behavior | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| pub t1 | feature | 8,8,8 → **8.00** | 7,7,8 → **7.33** |
| pub t2 | feature | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| pub t3 | bug | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| pub t4 | behavior | 8,8,8 → **8.00** | 8,8,8 → **8.00** |
| **overall** | | **7.94** (n=36) | **7.94** (n=36) |

**No diff-quality regression — the gate closes.** Overall means are identical
(7.944 vs 7.944 of 8). Diff quality is at ceiling, exactly as in Tier 2: Sonnet 5
produces correct, minimal, conventional diffs with or without the packet, so this
dimension is non-discriminating and the exploration metric carries the support
verdict. What the pass had to show — that treatment does **not** regress quality —
holds.

The four sub-8 diffs (each 7/8) are genuine, describable gaps, and they **split
evenly by arm** (2 control, 2 treatment), so the parity is insensitive to any
single scoring call:

- **control** — `camp t4` (behavior): a `rescue ArgumentError` used for expected
  invalid-input control flow (vs the explicit guard the others use), which also
  lets a nil/missing param through; `lob t3` (bug): fixes the failing test by
  changing the `after_action` from `only: [:unread]` to `only: [:all]`, silently
  dropping read-marking from the `:unread` action (the intended fix keeps both).
- **treatment** — **both** on `pub t1` (setup-nickname feature): 2 of 3 treatment
  runs implemented the `nickname` param handling in the controller but **omitted
  the setup-form field**, so an operator can't actually choose the nickname
  through the setup UI the task is about (it still passes a param-posting test).
  Hypothesis (weak, n=2, one task): the anchor-centered packet points hard at the
  controller and may under-cue the view layer, whereas a control agent exploring
  to localize tends to stumble onto the setup view. Worth watching if the packet
  ever grows view-awareness; not a general pattern at this n.

## Packet-vs-diff coverage (LIM-1 north-star)

Offline recall/precision of each task's **packet file-set** (the ≤8 files
`ctxpack` resolves — `files[].path` in the packet manifest) against the files
each subject diff actually touched — the designated post-v0 evidence source for
the LIM-1 limits (decision log 2026-07-05). `recall = |packet ∩ diff| / |diff|`
(of what the task touched, how much the packet had), `precision = |packet ∩
diff| / |packet|`. **Production-only** (top-level `test/`/`spec/` removed from
both sets) is the headline variant; self-authored tests are noise. The packet is
per-task and identical across arms, so **control diffs give the unbiased read**
(the agent never saw the packet) while treatment is a steering read. Computed by
`packet_coverage.rb` over all 72 grid sessions; per-session + aggregate JSON
under [`coverage/`](coverage/).

| slice | arm | prod-only recall | prod-only precision |
|---|---|---|---|
| overall | control (unbiased) | **0.80** | **0.63** |
| overall | treatment | 0.85 | 0.65 |
| feature | control | **0.69** | 0.65 |
| bug | control | **1.00** | 0.61 |
| behavior | control | **0.83** | 0.61 |

Readings:

- **The ≤8-file packet recalls ~80% of the production files a completed task
  touches, sight unseen** (control), and ~37% of its production files go
  untouched (precision 0.63 — over-inclusion, mostly the resolved constant files
  like `user.rb`/`Article` and the odd sibling). No sign the LIM-1 budget starves
  recall (no limit-hit truncation drove the misses) or grossly over-includes; the
  8/4/2/120 guesses look defensible, not validated-tight.
- **The recall gap is a feature-task, resolution-scope gap, not a limit gap.**
  Bug tasks recall 1.00 (the fix is a one-liner in the very controller the packet
  points at); behavior 0.83; **features only 0.69** — the missed files are
  **views, locale files, and sibling models** the anchor-centered convention
  resolver structurally cannot reach (it resolves constants by Zeitwerk path, not
  view/locale/graph edges). That is exactly the surface a semantic resolver
  (Rubydex, probe #3) would target.
- **Coverage recall does *not* track the exploration wins — they are near
  orthogonal.** Recall is *highest* on bug tasks (1.00), where the packet gave
  *no* exploration benefit (control already localizes from the failing test); and
  *lowest* on features (0.69), where the packet's exploration wins are
  *strongest*. So the packet's measured value comes from **landing the first
  load-bearing file fast (the entrypoint), not from enumerating every file the
  task will touch**. A complete file-set is neither necessary (features win with
  0.69 recall) nor sufficient (bugs have 1.00 recall and no win) for the
  exploration benefit. This tempers the #3 case: the coverage gap is real but the
  current packet already wins on features *without* closing it.
- **Caveat — treatment recall (0.85) overstates coverage.** Part of the
  control→treatment recall bump is an *under-touch* artifact: on `pub t1` the two
  treatment runs that omitted the setup view (the same runs docked in Diff
  Quality) score recall 1.0 only because their diff denominator shrank to the one
  controller file. High recall is not always good; the honest coverage read is the
  control arm.

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
  metric is a proxy for effort, not outcome quality. Diff quality is now judged
  and at ceiling in both arms (7.94/7.94), so it too is non-discriminating — it
  rules out a quality regression but adds no positive signal. Blind but
  single-judge (the orchestrator), and the 0–8 rubric compresses a lot into four
  coarse dimensions.
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
find-the-code tasks, the sharpest next probes are: (1) ~~the blind diff-quality
pass~~ **done** (above) — no regression, gate closed; (2) ~~packet-vs-diff
coverage~~ **done** (above) — control-arm prod recall 0.80 / precision 0.63; the
recall gap is a feature-task view/locale/sibling-model *resolution-scope* gap,
and it is **near-orthogonal to the exploration wins** (highest recall on bug
tasks, which show no win); and (3) Rubydex-backed resolution against this same
three-app harness — now with a concrete target (the feature-task recall gap) and
a concrete caution (the packet already wins on features without closing it). See
[`../tier3-rubydex/PROPOSAL.md`](../tier3-rubydex/PROPOSAL.md).
