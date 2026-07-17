# Markdown context ablation pre-registration

Status: frozen before the first subject run. Frozen 2026-07-17.

Existing runner considered: `tier2/harness.rb`; not used because it varies
injected packet content in external application workspaces, while this study
varies ctxpack's own repository Markdown surface for Codex. No reusable runner
is added: the protocol uses official ephemeral `codex exec` invocations and
records one aggregate JSONL row per run.

## Question

Does compacting the always-loaded project instructions and the explicit
resume/history chain reduce Codex context/exploration cost without reducing
answer correctness on representative ctxpack work?

This study does not test whether frozen eval evidence, normative specs, or
unique rationale should be deleted. Those surfaces are identical in both arms.

## Subject and base

- Subject: Codex CLI `0.144.5`, model `gpt-5.6-luna`, reasoning effort `low`.
- Base commit for both arms:
  `2bf1c86` (`Document active Markdown context audit`).
- Invocation: `codex exec --ephemeral --ignore-user-config --ignore-rules
  --sandbox read-only --json -m gpt-5.6-luna -c
  model_reasoning_effort="low" -C <worktree> <prompt>`.
- Each run starts in a fresh detached worktree. Network is unnecessary and the
  sandbox is read-only. Global Codex guidance and tool definitions are held
  constant; only project-repository content varies.
- The four `lean-surface/*.txt` payloads and `removed-paths.txt` define the
  compact arm byte-for-byte. Worktree preparation replaces the corresponding
  Markdown files and removes the two listed documents, then commits that arm
  state before subject execution. Code, tests, specs, design, user docs,
  skills, learning notes, and eval evidence remain byte-identical.

## Arms

1. **Full** — base commit unchanged.
2. **Compact bootstrap/history** — replace `AGENTS.md`, `CLAUDE.md`,
   `PROJECT_TRACKER.md`, and `implementation-notes.md` with the frozen payloads;
   remove the provably stale `docs/agent-backlog.md` and superseded
   `docs/packet-format-proposal.md`.

The two deletions are included because they are already eligible for the
static supersession lane. This experiment's causal claim is category-level;
it will not attribute any effect to either low-inbound file individually.

## Tasks and answer keys

Prompts are frozen in `tasks/*.txt`. Every task is read-only, so code-diff
quality is not applicable; final-answer quality is the outcome gate.

### T1 — resume/current work

Required facts, one point each:

1. Decision-map ticket #3 is next.
2. Tickets #1 and #2 are resolved.
3. The next action is the bounded Codex worktree ablation, not issue #6/#7 or
   another compiler pass.
4. `docs/markdown-context-decision-map.md` and the audit are named as current
   evidence/work-order inputs.
5. No upstream push or GitHub mutation is authorized.

### T2 — seed status and authority

Required facts, one point each:

1. Method seed shipped in Phase 5a.
2. Its test-candidate leg did not ship.
3. SEED-25 is cited.
4. Route seed did not ship and remains coaching-only.
5. The route resolution gate result `0.243 < 0.70` is reported.
6. Reopening route requires a new pre-registered spike.
7. `specs/seeds.md` is treated as normative; proposal/plan chronology is not.

### T3 — files-seed flow

Required facts, one point each:

1. Public API/CLI accept explicit seeds and `--from-files`.
2. Paths are app-root-relative normalized identities.
3. Files seeds enter compilation as primary evidence/focus-set inputs.
4. Existing packet merge/limit/determinism rules still apply.
5. Optional Git history enrichment is bounded and typed.
6. Markdown and manifest render from the completed packet object.
7. Tier 1 YAML cases exercise the whole packet shape.
8. Correct normative codes are cited from `specs/seeds.md` and related specs.

## Run count, order, and stopping

The pilot is replicate 1: six runs, one per task/arm. Frozen pilot order:

1. T1 compact, 2. T1 full, 3. T2 full, 4. T2 compact,
5. T3 compact, 6. T3 full.

If the pilot has no task-success regression and the compact arm reduces
combined automatic-plus-explicit Markdown bytes by at least 30% on at least
two tasks, continue unchanged for replicates 2 and 3. The frozen remaining
order is:

7. T3 full, 8. T2 compact, 9. T1 full, 10. T3 compact,
11. T1 compact, 12. T2 full,
13. T2 full, 14. T1 compact, 15. T3 compact, 16. T2 compact,
17. T3 full, 18. T1 full.

Stop before confirmation if a pilot task loses two or more answer-key points
in the compact arm versus full, any run cannot execute after four protocol
attempts, or the token cap would be exceeded. Pilot plus confirmation is
capped at 18 sessions and 900,000 total reported input plus output tokens.

## Metrics

Per run record:

- exit/result status and exact CLI/model versions;
- reported input, cached-input, output, and reasoning-output tokens;
- wall time and tool-call count;
- project Markdown paths explicitly opened or searched;
- automatic project instruction bytes (`AGENTS.md`, which Codex reads before
  work per the official discovery contract) plus bytes of explicitly opened
  project Markdown;
- answer-key score and missing/incorrect facts;
- any stale-document detour, irrelevant gate, approval stop, or conflict.

Deduplicate a Markdown path within a run when counting bytes. Do not add
global instructions or tool-schema tokens to the Markdown-byte metric because
they are constant but not observable as separate usage fields.

## Decision rule

The compact category passes only if all are true across the 18-run grid:

1. Median answer-key score is not lower on any task and no compact run loses
   two or more points versus its task's full-arm median.
2. At least two of three tasks reduce median automatic-plus-explicit project
   Markdown bytes by 30% or more.
3. The compact arm does not add a repeated wrong turn, irrelevant gate,
   approval stop, or authority error.

Reported token deltas are secondary because system/tool/global context is
aggregated with project instructions. A token improvement is welcome but is
not required when the directly attributable project-Markdown metric passes.

Passing justifies compacting the tested bootstrap/history category. It does
not justify deleting protected eval evidence, normative specs, `design.md`,
the accepted seed proposal, the re-scoped anchor proposal, or learning notes.
Failing keeps unique history active while still permitting the two static
deletions and corrections of objectively false statements.

## Provenance and artifacts

- Raw event streams live only in gitignored scratch during execution because
  committing 18 verbose transcripts would recreate the discovery problem.
- `runs.jsonl` records immutable per-run metrics, final answers, arm commit,
  event-stream SHA-256, scoring, and anomalies.
- `RESULTS.md` reports the frozen gates without rewriting this file.
- No existing pre-registration, result, packet, prompt, transcript, or frozen
  runner is modified.
