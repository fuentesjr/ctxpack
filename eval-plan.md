# ctxpack evaluation plan

Status: v1. Replaces the original plan, which compared packets against raw `rg`/`find` search. That baseline was a strawman: no one's real alternative to ctxpack is grep.

## Purpose

Decide, with criteria written down before any data is collected, whether Rails-aware context packets are worth building beyond v0.

## The honest competitor

Modern coding agents already know Rails conventions. Given "implement billing upgrade in `accounts#upgrade`", an agent will read the controller, follow `Billing::Subscriptions` by Zeitwerk naming, and look for a matching test — unprompted, within its first few tool calls.

So the hypothesis is **not** "packets beat keyword search." It is:

> Seeding a coding agent with a ctxpack packet measurably reduces exploration and/or improves task outcomes, compared with the same agent starting from only the task description and anchor.

If the packet cannot beat the agent's own first two minutes, the tool is not useful, no matter how deterministic it is.

## Structure: three tiers

Ordered by cost. Each tier has pre-registered pass/kill criteria — thresholds are chosen before running, and are not adjusted after seeing results.

```text
Tier 0  anchor viability spike     hours    run BEFORE building the packet renderer
Tier 1  determinism regression     CI       designed in design.md; runs continuously
Tier 2  agent-in-the-loop A/B      days     the hypothesis test; gated on Tier 0
```

Tier 1 is the only tier that runs in CI. Tiers 0 and 2 are offline experiments against real apps and real agents; they are evidence-gathering, not regression tests.

## Tier 0 — anchor viability spike

> **Executed 2026-07-05.** 91.0% engine-excluded average across
> Mastodon/Discourse/Zammad → the ≥ 70% gate passed; proceed as designed.
> Method, failure taxonomy, and raw data: [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md).
> The classifier has since been adopted as a standing pass-boundary corpus
> re-scan for compiler-behavior changes (mechanics in `PROJECT_TRACKER.md`,
> "Working process"); its first re-run, after the ANCH amendments, is the
> 93.9% addendum in RESULTS.md.

The strictest v0 constraint — the action must be a literal `def <action>` in the conventionally-named controller file — is also the most likely to fail on real apps (concerns, inherited CRUD, engines). This is answerable in an afternoon and should be answered before any packet rendering exists.

Method:

1. Pick 2–3 real open-source Rails apps of different styles (e.g. Mastodon, Discourse, Zammad — final list chosen by which boot cleanly, recorded with commit SHAs).
2. Extract the full route table with `bin/rails routes`. If booting an app is impractical, a static parse of `config/routes.rb` is an acceptable documented fallback, with its limitations noted in the results.
3. For every `controller#action` pair, attempt v0 anchor resolution.
4. Classify every failure:

```text
file_not_found      conventional controller path does not exist
inherited_action    action defined in a superclass
concern_action      action defined in an included concern
engine_route        route belongs to a mounted engine
other               metaprogramming, unconventional layout, etc.
```

Report the raw resolution rate and the rate excluding engine routes (engines are an explicit v0 non-goal and would unfairly inflate the denominator).

Pre-registered gates (on the engine-excluded rate, averaged across apps):

- **≥ 70%** — proceed to the vertical slice as designed.
- **50–69%** — rework anchor rules (e.g. one-level superclass lookup) before writing the renderer.
- **< 50%** — the exact-anchor concept is too brittle; stop and rethink before building anything.

The failure taxonomy is as valuable as the rate: it says exactly which v0 non-goal to promote first if the gate fails.

## Tier 1 — determinism regression (reference)

Fully specified in `design.md` ("Simple v0 evals"): static Rails-shaped fixture trees, YAML expectation cases, include/exclude/reason-code/limit assertions, and a double-run content-hash check with normalized output paths. Every packet bug becomes a new case. No LLM judge.

Stated limitation, so it is never misread: **Tier 1 proves the tool agrees with itself on fixtures authored to match its own assumptions.** It is circular by design and says nothing about usefulness. Tier 1 results must never be cited as evidence for the hypothesis — that is Tier 2's job.

## Tier 2 — agent-in-the-loop A/B

The actual hypothesis test. Run only after Tier 0 passes and the vertical slice exists.

The harness is built to re-run — pinned agent setup, scripted arms, recorded SHAs — not as one-shot scripts. A "support" result converts it from a gate into a usefulness-regression check re-run at release boundaries; the decision rules below already assume this ("judged by the same harness").

Each session emits one JSONL run record as a stable artifact: task, arm, run index, app/ctxpack/packet SHAs, agent version and settings, the mechanical metrics below, and the transcript path. The record format is the harness's public contract — analysis scripts read it, and if experiment bookkeeping ever outgrows scripts (decision log: eval platforms deferred), adopting a platform becomes an import problem rather than a redesign.

### Setup

- **Subject:** one coding agent, pinned and recorded (CLI version, model ID, settings). Both arms use the agent's normal configuration and tooling — a deliberately strong control, because a handicapped agent is not the honest counterfactual.
- **App:** one real Rails application (not the Tier 1 fixtures), pinned to a commit SHA.
- **Arms:** identical wrapper prompt; the only difference is context.
  - *Control:* task description + anchor.
  - *Treatment:* task description + anchor + full packet content inline.
- **Tasks:** three shapes, one instance each:
  1. Feature work from a controller action.
  2. Bug fix from a failing Minitest integration/controller test.
  3. Small behavior change in a controller/service path (e.g. add a side effect).
- **Anchor selection:** anchors are drawn from the route table *before* any packets are generated, so tasks cannot be cherry-picked for anchors where ctxpack shines.
- **Acceptance test:** for each task, written before any runs, hidden from the agent, executed afterward to score success.
- **Runs:** minimum 3 per arm per task (5 if budget allows) to absorb agent nondeterminism. Report per-run values and medians — never a single anecdote. Full grid: 3 tasks × 2 arms × 3–5 runs = 18–30 agent sessions.
- **Pilot first:** run one task through the full harness before the grid, to shake out harness bugs cheaply.

### Metrics

Mechanical (computed from transcripts and diffs, no judgment required):

| Metric | Definition |
|---|---|
| Task success | Pre-written acceptance test passes |
| Calls to first load-bearing read | Tool calls before the agent first reads a file that appears in its final diff |
| Total tool calls / tokens / wall time | Whole-session cost |
| Distraction reads | Files read but neither edited nor present in the final diff |
| Discarded edits | Files edited but reverted or absent from the final diff |

Distraction reads is an imperfect proxy — some reads are legitimate context — but it is applied identically to both arms, and the A/B *difference* is meaningful even where the absolute number is not.

Human-judged: final diff quality against a rubric written before the runs (correct, minimal, follows app conventions, no unrelated changes). Diffs are judged blind to arm — a diff does not reveal whether a packet was used.

### Pre-registered interpretation

- **Support:** in at least 2 of 3 tasks, treatment shows a ≥ 30% median reduction in calls-to-first-load-bearing-read or distraction reads, with no regression in success rate or diff quality.
- **Fail:** neither exploration nor outcomes improve meaningfully on at least 2 of 3 tasks. This is the original kill condition, re-aimed at the real competitor: *the agent without the packet finds the right context just as fast.*

At this sample size the result is directional evidence, not statistics. The point of pre-registering thresholds is to prevent motivated reading of ambiguous results, not to claim significance.

## Threats to validity

- **Author bias.** The same person writes the tool, the tasks, and the rubric. Mitigations: pre-registered thresholds, anchor selection before packet generation, blind diff judging. Residual bias remains; say so in the writeup.
- **Agent nondeterminism.** Mitigated by repeated runs and medians, not eliminated.
- **Model drift.** Comparisons are only valid within one pinned agent/model setup. Record versions; rerun from scratch if the setup changes.
- **Test-suggestion confound.** Packets include suggested test commands, which may drive wins on their own. That is product value, not a confound to remove — but record whether wins concentrate there, because "agents mainly need the test pointer" and "agents need the whole packet" imply very different v1s.
- **Single-app generalization.** One app, three tasks. A pass here justifies a broader task set, not a general claim.

## Decision rules

| Result | Action |
|---|---|
| Tier 0 < 50% | Stop. Rethink the anchor concept before writing the renderer. |
| Tier 0 50–69% | Promote the top failure category (per taxonomy) into v0 scope, then re-run Tier 0. |
| Tier 0 ≥ 70% | Build the vertical slice; stand up Tier 1 in CI. |
| Tier 2 fail | Write up the negative result. Either stop, or pivot to a narrower bet (e.g. packets for smaller/cheaper models, or packets as PR-linkable review artifacts) — with a new eval plan. |
| Tier 2 support | Expand to more tasks and a second app; only then consider Rubydex-backed resolution, judged by the same harness. |
