# Tier 3 (proposal): Rubydex-backed semantic resolution

**Status: PROPOSAL — NOT frozen.** Every prior pre-registration in this project
was frozen only after explicit user sign-off; this one additionally has a hard
prerequisite gate (is Rubydex runnable on the pinned apps?) and a genuine
go/no-go on the evidence below. Do not start a grid from this document as-is.

## The decision-rule branch this sits on

`eval-plan.md`: *"Tier 2 support → expand to more tasks and a second app; only
then consider Rubydex-backed resolution, judged by the same harness."* Expansion
is done and returned **SUPPORT / generalizes**
([`../tier2-expansion/RESULTS.md`](../tier2-expansion/RESULTS.md)), so this is
formally the next branch.

## What Rubydex would change

v0 resolves constants by **Zeitwerk path convention only** (`design.md`:
*"Default resolver: convention/path-based constant resolver; Future resolver:
Rubydex-backed semantic resolver"*). Rubydex is a semantic indexer/graph. Swapped
in behind the resolver seam, it could surface files that path-convention
structurally cannot reach: **view templates, locale files, and sibling models**
reached via associations / call edges rather than a literal constant reference in
the action body.

## What the evidence already says (this reshapes the probe)

From the just-completed passes in the expansion RESULTS:

- **Coverage found the packet's recall gap is a feature-task, resolution-scope
  gap** — control (unbiased) prod-only recall is 1.00 on bug tasks, 0.83 on
  behavior, but **0.69 on features**, and the missed files are exactly
  views/locales/sibling models. That is precisely Rubydex's surface. *So there is
  a real gap for Rubydex to close.*
- **But the exploration wins are already strongest on features** (features 5/6
  task-instances meet the bar) *despite* that recall gap, and **coverage recall
  is near-orthogonal to the exploration wins** (highest recall on bug tasks,
  which show no win). The packet's measured value is *landing the first
  load-bearing file fast*, not enumerating every file the task touches.

**The tension for #3:** Rubydex would close a real coverage gap, but nothing yet
shows that closing it moves the metrics that actually moved (exploration, quality).
Rubydex must be judged on whether richer resolution *converts* to an
exploration/quality gain — coverage improvement alone is not the win.

## Proposed design (to finalize only on sign-off)

- **Harness:** reuse the exact three-app expansion harness (Campfire / Lobsters /
  Publify; same frozen anchors, same 4 tasks/app, same metric code). No
  re-drawing anchors, no new tasks.
- **Arm axis:** the value question is *incremental* resolution quality, so the
  sharp comparison is **convention-packet vs rubydex-packet** (both arms
  packeted), with the existing `control` (no-packet) and convention-`treatment`
  numbers from the expansion grid as the standing baseline.
- **Metrics:** the frozen exploration metric (LBR, distraction) + the diff-quality
  gate + packet-vs-diff coverage — coverage is now the *sharp instrument*
  (Rubydex should raise feature recall; the real test is whether that recall gain
  **co-moves** with an exploration/quality gain).
- **Focus on features.** That is where both the recall gap and the wins live;
  bug/behavior tasks already sit at ceiling coverage and/or no win.

## Open decisions / prerequisites (need user input before any freeze)

1. **Hard gate — is Rubydex runnable on these pinned apps offline?** Indexing
   generally needs to boot/index the app; several of these apps are hard to boot
   (Publify is an *engine* + dummy app; Campfire is rails-edge). This is the same
   no-boot constraint that already shaped Tier 0 anchor resolution. If Rubydex
   can't index them offline, the probe is blocked or needs a different app set.
2. **Arm design:** 2-arm (conv vs rubydex) head-to-head, or 3-arm (control / conv
   / rubydex)?
3. **Scope/cost:** full ~72-session grid, or a pre-registered **feature-tasks-only
   subset** (where the hypothesis lives) to cut cost?
4. **The success bar** (frozen before any run): e.g. Rubydex shows ≥ N% additional
   median LBR reduction over the convention packet *on feature tasks*, with no
   quality regression and a meaningful feature prod-recall gain.
5. **Build dependency:** is the `design.md` swappable-resolver seam built out
   enough to drop Rubydex in, or is that a build pass first?

## Recommendation (DRA)

**Cheaper probe before the grid.** Given the orthogonality finding, the ~72-session
Rubydex grid is not obviously worth it yet — the coverage gap is real but there's
no evidence it's what produces value. Before spending a grid, run the **offline**
question first, for near-zero agent cost: recompute packet-vs-diff coverage with a
**Rubydex-resolved packet** over the *same committed expansion diffs* (does Rubydex
resolution actually recall the missed feature files — the views/locales/siblings?).
That single offline step answers prerequisite (1) *and* the coverage-gain question
before we spend any agent budget on whether a coverage gain converts to an
exploration/quality gain. Only if Rubydex demonstrably closes the feature recall
gap offline does the head-to-head grid earn its cost.
