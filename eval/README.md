# Eval tooling inventory

One table, every runner. **Authoring rule (binding):** before writing any
new eval/measurement script, find your question below; if a runner already
answers a question of that shape, extend it. A new runner's pre-registration
MUST carry one line — *"Existing runner considered: `<name>`; not used
because `<reason>`"* — so reuse is a recorded decision, not a vibe. Shared
plumbing for new viability spikes lives in
[`lib/spike_harness.rb`](lib/spike_harness.rb) (pinned apps, exclusions,
percentile, taxonomy, gate summaries); per-spike scoring stays in the
spike's own frozen script. Already-measured spike scripts are historical
artifacts — do not retrofit them.

This inventory unifies **plumbing and discoverability only**. Tier 0/1/2
answer categorically different questions; do not merge them into one
framework (see the RubricLLM verdict, `rubricllm-spike/RESULTS.md`, for the
adoption discipline this repo applies to eval tooling — including its own).

| Runner | Question it answers | Inputs | Baselines / recorded output |
|---|---|---|---|
| `tier0/classify_anchors.rb` | Does the compiler resolve real-app anchors? (+ mandatory pass-boundary rescan, `tier0-corpus-rescan` skill) | Pinned checkouts + committed `tier0/routes/*.json` | `tier0/results/post_amendment/` (byte-compare), addenda in `tier0/RESULTS.md` |
| `tier0/extract_routes.rb` | Build pair-count route tables without booting Rails | App checkout + actionpack version | Committed `tier0/routes/*.json` — do not re-extract for rescans |
| Tier 1 fixture evals (`test/fixtures/evals/*.yml` via `FixtureEvalsTest`) | Regression: does a packet keep its exact shape? (`add-fixture-eval` skill) | Fixture apps | CI, red-then-green per packet bug |
| `tier2/harness.rb` (+ `tier2-expansion/` per-app configs) | Do packets change real agent behavior? (A/B grid) | Subject apps, tasks, `--dangerously-skip-permissions` session | `runs.jsonl`, packets, transcripts — **frozen provenance** |
| `tier2-expansion/build_blind_judging.rb` + `tabulate_quality.rb` | Blind 0–8 diff-quality judging, sealed arm mapping | Grid diffs | `tier2-expansion/judging/` |
| `tier2-expansion/packet_coverage.rb` | Packet-vs-diff recall/precision (LIM-1 north star) | Grid packets + diffs | `tier2-expansion/coverage/` |
| `tier3-rubydex/four_column_coverage.rb` | Candidate-expansion comparison vs committed diffs | Grid artifacts | `tier3-rubydex/RESULTS.md` (Rubydex deferred) |
| `seed-spikes/run_{test,files,error,method,diff,route}_spike.rb` | SEED-5 viability gates, one frozen script per kind | Pinned checkouts (+ history for diff; `extract_route_rows.rb` tables for route) | `seed-spikes/<kind>/PREREGISTRATION.md` + `RESULTS.md` + `results/` |
| `seed-spikes/work-start-corpus.md` | Scenario → correct seed kind + packet (SEED-24, re-scored at phase gates) | Fixture-backed | Scoring blocks in the file |
| `rubricllm-spike/side_by_side.rb` | Issue #5 side-by-side (decided: DEFER) | Committed coverage artifacts + rubric_llm clone | `rubricllm-spike/RESULTS.md` |
| `lib/spike_harness.rb` | Shared spike plumbing (future spikes) | — | Self-check: `ruby eval/lib/spike_harness_check.rb` |

Decision rules and tier definitions: [`../eval-plan.md`](../eval-plan.md).
Nothing here is CI-wired except Tier 1 (EVAL-10).
