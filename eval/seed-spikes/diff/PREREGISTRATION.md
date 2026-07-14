# Diff-seed viability spike — pre-registration

**Status:** Frozen before measurement (2026-07-14) after advisor review
(two corrections applied: mechanical `disagree_related_dir` rule; file
survival redefined over both diff sides. Plus report-only count of
attribution-ambiguous commits).
**Source:** `docs/seed-based-interface-proposal.md` §3 (diff row) + §11
Phase 5; `specs/seeds.md` SEED-5, SEED-7 (diff row), SEED-22; Phase 5 plan
in `PROJECT_TRACKER.md`.

## Question

The diff seed's evidence (changed files from a range/patch) is literal, like
the files seed — so per the SEED-22 files precedent, only the inferred leg
is gated: how often does the **paired-test** convention correctly identify
the test file that really accompanies a production change? Def-anchoring of
hunks (snippet quality) is measured report-only.

## Apps / SHAs (pinned; same as Tier 0)

Mastodon `163f96ce…`, Discourse `28b003a3…`, Zammad `50384f4c…` under
`tmp/tier0-rescan/`. The checkouts are shallow (depth 1); before measurement
each is deepened with `git fetch --deepen=600` — **worktree and HEAD are
untouched** (Tier 0 rescan state unaffected). The deepen depth is fixed here
before measurement. Environment note (mechanics, not scoring): Zammad's
in-place `--deepen` repeatedly failed on network resets, so its history
window comes from a fresh `--depth=601` fetch of the pinned SHA under
`tmp/seed-history/zammad` — the same 600-commits-above-pin window.

## Population

Per app, walking **first-parent** history from the pinned SHA within the
deepened window, **non-merge** commits only:

- **Def-anchoring population (report-only):** the most recent 200 commits
  touching ≥ 1 `app/**/*.rb` file (post-image side), excluding paths with
  `plugins/`, `engines/`, `vendor/`, `node_modules/`. If fewer than 200
  qualify in the window, use what exists and report N (no further
  deepening after measurement starts).
- **Paired-test population (gated):** within the same window, commits
  touching **exactly one** production `app/**/*.rb` file AND ≥ 1 test file
  (`test/**/*_test.rb` or `spec/**/*_spec.rb`), same exclusions. The
  single-production-file restriction makes the co-changed test attributable
  to that file. Cap: most recent 200 per app; report N as found.

## Heuristics under test (fixed before scoring)

**Paired-test prediction** for a production file `path` (post-image tree of
the commit, via `git show <sha>:<file>` existence — no checkout):

1. Controller mirror (TEST-1 shape): `app/controllers/<p>_controller.rb` →
   `test/controllers/<p>_controller_test.rb` /
   `spec/controllers/<p>_controller_spec.rb` and
   `spec/requests/<p>_spec.rb` / `spec/requests/<p>_controller_spec.rb`.
2. General mirror: `app/<dir>/<p>.rb` → `test/<dir>/<p>_test.rb` /
   `spec/<dir>/<p>_spec.rb` (e.g. `app/models/user.rb` →
   `spec/models/user_spec.rb`).
3. Lib mirror: `lib/<p>.rb` → `test/lib/<p>_test.rb` / `spec/lib/<p>_spec.rb`
   (population is app-scoped, so this fires only for completeness).

Prediction = the subset of those candidates existing in the commit's
post-image tree. **No basename token matching** (the 5a spike showed token
matching floods on generic names).

**Def-anchoring** (report-only): a changed hunk is def-anchored when any
post-image changed line falls inside a Prism instance/singleton def range in
the post-image file (parsed via `git show`, no checkout).

## Ground truth

For each (commit, production file) in the gated population: the commit's own
touched test files. **Agreement** = prediction ∩ touched tests ≠ ∅.
Co-change is the ground truth: the author of the commit told us which test
accompanies the change.

## Metrics and gates (pre-registered)

| Metric | Definition | Gate |
|---|---|---|
| Paired-test agreement | over gated-population pairs with **non-empty** prediction: fraction with agreement; per app, unweighted 3-app average over apps with ≥ 1 such pair. If no app yields ≥ 1 non-empty-prediction pair, the leg **fails** (unvalidated ≠ validated). | **≥ 70%** |
| Prediction coverage | fraction of gated-population pairs with non-empty prediction | report-only |
| Def-anchoring rate | fraction of changed hunks (def-anchoring population) that are def-anchored | report-only |
| File survival | over changed `app/**/*.rb` paths from **both diff sides** of def-anchoring-population commits: fraction existing in the post-image (measures the deletion/rename share the recipe must exclude from primaries) | report-only |
| Attribution-ambiguous commits | per app: count of window commits touching ≥ 2 production files AND ≥ 1 test (excluded from the gated population) — denominator context for the single-file restriction | report-only |

**Outcomes:**

- Agreement gate passes → ship `--from-diff` with the paired-test leg.
- Agreement gate fails → ship `--from-diff` **without** the paired-test leg
  (changed files + def-anchored snippets only); record the demotion.
- The primary leg (literal changed files) ships in either case — evidence is
  literal, per the SEED-22 files precedent for named-files-only.

## Failure taxonomy (pre-registered labels)

| Label | Meaning |
|---|---|
| `agree_mirror` | Prediction agreed via general/controller mirror |
| `disagree_related_dir` | Prediction non-empty, no overlap, but some touched test's first path segment under its test root (`test/` or `spec/`) equals the production file's first segment under `app/` — with controller primaries additionally treating `requests/` and `integration/` as related |
| `disagree_unrelated` | Prediction non-empty, no overlap, touched tests unrelated by path |
| `no_prediction` | No conventional candidate exists in the post-image tree |
| `crash` | Spike script raised on the pair |

## Explicit non-goals

- Not evidence packets help agents (Tier 1 circularity applies).
- Not a hunk-quality or snippet-line eval beyond the def-anchoring count.
- No Rails boot, no embeddings, no execution of sample-app code.
- Not CI-wired (EVAL-10).
