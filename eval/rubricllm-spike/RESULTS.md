# RubricLLM spike — offline side-by-side + verdict (issue #5)

**Run:** 2026-07-14. Script: `side_by_side.rb` (takes the path to a
rubric_llm clone pinned at `02ceec3`; reads ONLY the committed
`eval/tier2-expansion/coverage/coverage_by_session.json`; zero network,
zero credentials, zero LLM calls; no recorded evidence modified).
Companion source review: [`REVIEW.md`](REVIEW.md).

## Side-by-side: retrieval metrics vs committed coverage

`RubricLLM::RetrievalResult` fed each session's `packet_files` (retrieved)
and `diff_files` (relevant):

> **72 sessions compared, 0 mismatches** — `recall_at_k`/`precision_at_k`
> at k = packet size reproduce ctxpack's recorded all-files recall and
> precision exactly (< 1e-9).

Read both ways: rubric_llm's math is correct, AND it replaces only ~30
lines of `packet_coverage.rb`'s arithmetic — the bulk of that script
(artifact extraction, prod-only filtering, per-category tabulation,
provenance) would remain custom either way. No material custom-code
reduction.

## Paired t-test exercised on committed data + hazards demonstrated

- Real data (36 control/treatment recall pairs by app×task×round):
  control 0.8102 vs treatment 0.8241, delta +0.0139, **p = 0.710** —
  mechanically sensible.
- **se = 0 landmine (n=3):** uniform +0.1 improvement across all pairs →
  **p = 1.0** ("not significant"). A perfectly consistent effect — the
  best possible n=3 outcome — is reported as the least significant. This
  confirms the issue's risk note: statistical packaging is not statistical
  validity at ctxpack's n = 3/arm/task.
- n=3 noisy +0.2 improvement → p = 0.023 with significance stars and no
  n/df caveat anywhere in the report output.

## Verdict against the issue's explicit value criteria

- **Materially less custom eval code/operations?** No (see above; and the
  judge stack would *add* operations: credentials, cost caps, and all
  blinding built by us around it).
- **A discriminating capability the current stack lacks?** No. Judging:
  ctxpack's sealed-arm blind 0–8 pipeline is strictly stronger than the
  gem's unblinded, uncached, [0,1]-schema judge. Statistics: the frozen
  directional rules were chosen deliberately for n=3; the gem's t-test
  would have reported the campaign's headline uniform effects as p=1.0.

## Recommendation: **DEFER** (borrow-on-demand)

Do not adopt (no gemspec/Gemfile/CI change — none was made). Do not vendor
speculatively either: no current ctxpack analysis needs p-values, and the
project rule is no code without a demonstrated need. Instead this spike
records the borrow map so borrowing is cheap the day a need appears:

- p-values for a future larger-n comparison: `comparison.rb:73–153`
  (paired t + regularized incomplete beta, dependency-free, MIT). Must fix
  the se=0 → p=1.0 case and attach explicit n/df/caveats before use.
- Rank-aware packet metrics: `retrieval_result.rb:29–51` (MRR, NDCG).

**No live judge pilot proposed** — with adoption deferred there is nothing
a paid pilot would decide; accordingly no sample/model/budget
pre-registration is needed and no paid calls were made.

**Smallest justified next step:** none (close the issue with this verdict;
re-open only when a concrete need for p-values or rank-aware metrics
appears).
