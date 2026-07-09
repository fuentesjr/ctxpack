# Tier 3 offline probe — results & verdict

**Date:** 2026-07-08. Completes the PROJECT_TRACKER "OFFLINE Rubydex-recall
probe" work order (steps 1–4). Orchestrator/judge = Claude; script authored by
Codex, run + verified + judged session-side; independent advisory pass by Fable
(caught a factual error in the first `GATE.md` draft — see that file).

## Question

Does richer resolution of the frozen anchor's dependencies recall the
**production files the convention/Zeitwerk resolver structurally misses** on the
Tier 2 expansion feature tasks — computed **offline** over the same committed
diffs, at near-zero agent cost? And specifically: is a **Rubydex** semantic
resolver worth a native-dependency swap, or does a dependency-free **Rails view
path-convention** layer do the job?

## Method

`four_column_coverage.rb` builds four packet file-set variants per app×task and
recomputes recall/precision over the same 72 committed expansion diffs, reusing
`../tier2-expansion/packet_coverage.rb`'s metric definitions verbatim:

- **convention** — today's packet `files[].path`.
- **+view** — convention ∪ existing `app/views/<controller>/<action>.*`.
- **+rubydex** — convention ∪ Rubydex-resolved `app/`|`lib/` Ruby files whose
  constant is referenced anywhere in the controller file (reaches refs in
  private helpers the action-body-scoped convention resolver misses).
- **+both** — the union.

All budget-capped at LIM `max_total_files` = 8 (cap never bit; convention sets
are 2–4 files). **Self-check:** the `convention` column reproduces the committed
`../tier2-expansion/coverage/coverage_by_session.json` recall/precision **exactly**
(the script aborts otherwise) — so the harness is proven faithful before the new
columns are trusted.

Two verification catches worth recording:
- **Convention parity self-check passed** → the baseline is faithfully reproduced.
- **A real bug in the first Codex draft, caught session-side** (the self-check
  could not — it only guards `convention`): Rubydex's constant resolution depends
  on the **process working directory**, not just `workspace_path`. Run from the
  ctxpack root with only `workspace_path` set, sibling-model refs (`User`,
  `Current`, …) stay **unresolved** — only superclasses resolve. Fix: `chdir`
  into the app root before indexing. Pre-fix, campfire t1 `+rubydex` recalled
  0.500 (missed `user.rb`); post-fix 1.000. This is exactly why Codex summaries
  are never trusted.

## Results (control arm = unbiased read, production-only)

Control agents never saw the packet, so packet-vs-control-diffs is the honest
test of whether a resolver's file-set captures what the task needs.

**Feature tasks** (where the recall gap and the exploration wins both live):

| variant | recall | precision | ΔR vs conv | −ΔP | ΔR per precision lost |
|---|---|---|---|---|---|
| convention | 0.685 | 0.653 | — | — | — |
| **+view** | **0.815** | 0.556 | **+0.130** | 0.097 | **1.33** |
| +rubydex | 0.769 | 0.341 | +0.083 | 0.312 | 0.27 |
| +both | 0.898 | 0.342 | +0.213 | 0.311 | 0.68 |

**Overall (all tasks):** convention R 0.801 / P 0.632 · +view R 0.866 / P 0.542
· +rubydex R 0.843 / P 0.297 · +both R 0.907 / P 0.290.

## Findings

1. **The view layer is the efficient recall gain.** +0.130 feature recall for a
   0.097 precision cost (ratio 1.33) — it adds ~one mostly-relevant view file
   per task. It lifts recall on the two view-primary feature tasks (campfire t2
   `accounts#edit` 0.444→0.889; publify t1 `setup#index` 0.333→0.667) — and
   publify t1 is precisely the task where the packet caused *measured* harm (the
   only two treatment-arm quality dings in the whole grid, P06/P20, were the
   backend-only fix that omitted the setup form/locale). Dependency-free.

2. **Rubydex's entire measured recall gain is ONE file.** Across all 12 tasks,
   Rubydex raises recall on exactly one: campfire t1 `autocompletable/users#index`
   (0.500→1.000), by reaching `app/models/user.rb`. And `User` is a **literal
   `User.all` constant in the controller file** — just inside a private helper
   the convention resolver's action-body scan skips. So this recall is
   recoverable by **widening the existing convention constant-scan to the whole
   controller file** — a one-heuristic, dependency-free change — with no Rubydex.

3. **Rubydex's precision cost is severe and mostly pure noise.** It **halves**
   feature precision (0.653→0.341) and craters bug/behavior precision
   (0.611→0.270 / 0.236) for **zero** recall gain there (those tasks already sit
   at ceiling recall). It floods the packet with every constant the controller
   references — superclasses (`ApplicationController` on *every* controller),
   concerns, jobs, POROs — almost none of which the diffs touch (e.g. lobsters t1
   adds 5 files for zero recall). For a tool whose value is a *small, high-signal*
   packet (LIM-1: "small by construction"), that is the wrong direction.
   *Caveat (honest):* this precision figure is a lower bound for a naive
   whole-controller-file scope; a surgical action-call-graph Rubydex resolver
   would score better on precision — but it would be *more* engineering, for a
   native Rust dependency, to match a recall gain a one-line convention widening
   already delivers.

4. **Views and locales remain the bulk of the residual gap, and Rubydex can't
   touch them** — it indexes only Ruby (see `GATE.md`). The remaining feature
   recall gap after +view is dominated by locale keys and **files the task
   creates** (`user_standing.rb` et al.), which no resolver can recall — a
   permanent structural floor, not a defect.

## Verdict

- **Build the Rails view path-convention layer** (action → existing
  `app/views/<controller>/<action>.*`). It is the efficient, dependency-free
  recall gain and it targets the one place the packet caused measured harm.
- **Widen the convention constant-scan to the whole controller file** (cheap,
  dependency-free) to capture the sibling-model recall — this subsumes Rubydex's
  entire measured benefit on this corpus.
- **Locale = a standing pointer**, not a packet file (the misses are newly-added
  keys; a truncated giant `en.yml` would be metric-gaming).
- **Defer Rubydex.** On this corpus it buys one file of recall — already reachable
  by a convention widening — at a precision cost that halves packet precision,
  plus a native Rust runtime dependency `design.md` deliberately excludes. Its
  honest case (files reached via cross-file call edges, not literal in-file
  constants) needs a corpus whose misses are that shape; these misses are
  view/locale/new-file/in-file-constant shaped. Revisit only if such a corpus
  appears.
- **No new agent grid** from this probe. The view layer is a compiler-behavior
  change governed by the pre-registered coverage north-star; validate it via a
  real spec pass (new reason code + fixture-eval cases + mandatory Tier 0 corpus
  re-scan) and a release-boundary re-run of the existing harness (watch: no
  bug-task exploration regression from the added view surface; whether the
  publify-t1 treatment view omission disappears).

## Artifacts

- `four_column_coverage.rb` — the recompute (chdir-fixed; self-check gates it).
- `coverage/four_column_summary.json`, `coverage/four_column_by_session.json`.
