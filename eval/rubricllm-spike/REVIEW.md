# RubricLLM source/API review (issue #5)

**Pinned:** [dpaluy/rubric_llm](https://github.com/dpaluy/rubric_llm) commit
`02ceec3c2b3172adde5ee620e6643ba598389c00` (v0.4.0 + 1 commit; includes the
#7 error-visibility and #8 batch-validation fixes). Reviewed 2026-07-14 by
reading every `lib/` file (~1,360 lines) and the relevant tests — claims
below are source-verified, not README-derived. Line references are against
the pinned commit.

## Summary

rubric_llm is small and clean but LLM-judge-centric: 6 RAG-flavored judge
metrics on a 0.0–1.0 scale, a pure-Ruby paired t-test, and a tiny offline
retrieval-metrics class. The genuinely reusable pieces for ctxpack are
narrow: the dependency-free p-value machinery (~80 lines,
`comparison.rb:73–153`) and, if rank-aware packet metrics are ever wanted,
`RetrievalResult`'s NDCG/MRR. The judge stack is a structural mismatch with
ctxpack's blind 0–8 judging: hard-wired to ruby_llm, no offline/dry-run
mode, no caching, no seed control, no blinding support, and a JSON schema
that requires scores in [0,1].

## Judge contract

- Sole provider touchpoint: `RubyLLM.chat(model:, provider:)` at
  `judge.rb:38` (+ temperature/max_tokens/schema/instructions, :39–44).
  The gem never configures credentials — that's the host app's problem.
- Defaults from ENV: `RUBRIC_JUDGE_MODEL` → `gpt-4o`, provider `:openai`,
  temperature 0.0, max_retries 2 (`config.rb:10–17`).
- **No dry-run/offline/stub mode anywhere.** The gem's own tests stub by
  removing the `RubyLLM` constant (`test/test_helper.rb:94–95`).
- Missing API key does **not** fail fast: every error retries with backoff
  (~3s per metric before surfacing as a nil-score error entry); a 6-metric
  run sleeps ~18s per sample before reporting failure. No upfront
  credential check.

## Retrieval metrics (pure, offline)

`retrieval_result.rb` (68 lines): `precision_at_k`, `recall_at_k`, `mrr`
(single-query), binary-gain `ndcg`, `hit_rate`. Inputs: ordered `retrieved`
array + `relevant` set, exact equality only. **No F1, no cross-query
aggregation.** Fully offline (no requires, no config).

## A/B statistics

`comparison.rb`: positional pairing (`zip`, nil pairs dropped, size
mismatch only warns), paired t-test with exact Student-t p via regularized
incomplete beta (Lentz continued fraction, :93–153 — formulation checked,
matches Numerical Recipes; fixture spot-check reproduces). Hazards:

- **se = 0 → p = 1.0** (:82): a perfectly uniform improvement across all
  pairs reports "not significant" — a real landmine at ctxpack's n=3
  (demonstrated empirically in `RESULTS.md`).
- Significance stars printed with **no n/df/small-sample caveat, no effect
  size, no CI** (:25–42, :155–161); numeric failures silently return p=1.0.
- Nil scores silently shrink per-metric n.

## Determinism / blinding

No seed parameter, no response caching, no record/replay, no arm-label or
blind-evaluation concept. ctxpack's sealed-mapping blind judging would live
entirely outside the gem.

## Error semantics (post-#7)

Judge failures never fabricate scores and never abort the batch: per-metric
`nil` + error detail, `Result#pass?` fails closed, reports count errors.
Caveats: `Result#overall` averages only non-nil scores (silent denominator
change), and error-nils silently drop comparison pairs.

## Batch / reporting / Minitest

Thread-pool batch (default sequential), upfront sample validation (#8),
plain-text summary, CSV (`csv` runtime dep) and JSON export. Minitest
integration = four assertions that each make a **live LLM call**
(`minitest.rb:41–45`) — unusable for ctxpack's deterministic Tier 1.

## Dependency surface

`csv` + `ruby_llm ~> 1.16`; ruby_llm 1.16 pulls `base64`,
`event_stream_parser`, `faraday` (+multipart/net_http/retry), `marcel`,
`ruby_llm-schema`, `zeitwerk`. Ruby `>= 3.4.0` (matches ctxpack's floor;
not a blocker). Adopting means adopting the faraday HTTP stack.

## Offline compatibility matrix

| Component | Zero network/credentials? |
|---|---|
| `RetrievalResult` (all metrics) | Yes |
| `Comparison` (t-test/summary) | Yes |
| `Report` (stats/CSV/JSON) | Yes |
| `Result`/`Config`/batch validation | Yes |
| `evaluate`/`evaluate_batch`/all judge metrics | **No** (no offline mode) |
| Minitest/RSpec assertions | **No** (live call per assertion) |
| `require "rubric_llm"` | Yes (loads, makes no calls) |
