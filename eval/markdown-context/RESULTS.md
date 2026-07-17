# Markdown context ablation results

Pre-registration: [`PREREGISTRATION.md`](PREREGISTRATION.md). Subject base:
`2bf1c86`. Compact arm: `860c9d2`. Run date: 2026-07-17.

## Verdict

**Inconclusive for the pre-registered category gate; stopped at the frozen
token cap.** Five of six pilot sessions completed. They consumed 803,913
reported input-plus-output tokens, leaving 96,087 tokens under the 900,000 cap.
The paired full-arm T3 run was expected to exceed the remainder after compact
T3 alone used 360,040, so it was not started. Confirmation runs were not run.

The category therefore does not receive causal authorization to remove unique
history or rationale. The observed T1 pair is still direct evidence of one
document-caused wrong turn: the full arm restarted resolved ticket #1 after
following stale duplicated tracker sections. The compact arm selected ticket
#3, but its final answer also invented an approval stop for local commits and
deletions that the lean tracker explicitly authorized. The pair supports
reconciling the tracker while also showing that the compact authority surface
needs correction; it does not replace the uncompleted three-task/three-
replicate gate.

## Runs

| Run | Task | Arm | Score | Input | Cached input | Output | Tool calls | Result |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | T1 resume | compact | 4/5 | 110,955 | 80,384 | 1,459 | 5 | Correct next action; omitted an explicit “#1/#2 resolved” sentence; false local commit/deletion prohibition found in review |
| 2 | T1 resume | full | 3/5 | 70,504 | 47,360 | 974 | 2 | **Wrong turn:** restarted ticket #1 from stale tracker sections |
| 3 | T2 seed status | full | 7/7 | 139,325 | 85,760 | 1,188 | 4 | Correct |
| 4 | T2 seed status | compact | 7/7 | 118,013 | 89,856 | 1,455 | 4 | Correct |
| 5 | T3 files flow | compact | 8/8 | 357,975 | 295,936 | 2,065 | 7 | Correct; paired full run not started |

Totals: 796,772 input tokens, 599,296 cached input tokens, 7,141 output
tokens, and 1,407 reasoning-output tokens. `runs.jsonl` contains the final
answers, usage, arm commits, manual scores, anomalies, CLI/model provenance,
and SHA-256 digests of the scratch event streams.

## Direct context reduction

The compact payload reduced the tested bootstrap/history files from 274,750
bytes to 7,482 bytes (97.3%). Codex's automatically loaded project
`AGENTS.md` fell from 16,487 to 4,138 bytes (74.9%). Those arm properties are
deterministic, but the pre-registered median explicit-Markdown metric was not
scored after the pilot stopped. Several tasks used broad recursive `rg`
searches, so reliable per-path byte attribution needs capture instrumentation
rather than post-hoc command-string parsing.

Token totals are secondary by pre-registration and were noisy: compact T1 used
more reported tokens than full T1 even though it chose the correct work order;
compact T2 used fewer. No task-wide token claim is made.

## Applied gates

1. **Answer quality:** not evaluable across the full grid. The completed T2
   pair tied at 7/7. Compact T1 beat full T1 by one point and avoided the wrong
   work order. T3 is unpaired.
2. **Markdown reduction on at least two tasks:** not evaluated. Automatic
   instruction bytes fell 74.9% in every compact run, but the frozen gate also
   called for explicit-read accounting and task medians.
3. **No new repeated wrong turn:** not satisfied/evaluable. Compact T1 added
   an authority error and approval stop; the required replication did not
   occur, so the frozen repeated-wrong-turn test cannot be completed.

Pre-registered consequence: do not use this study to delete protected or
unique material. Continue only with the independent static lane: remove fully
superseded documents, reconcile objectively false/current-looking statements,
and compress duplicated bootstrap/history material without discarding unique
authority.

The later file-level disposition applied that lane: it preserved current
authority, rationale, normative requirements, measured results, open work, and
the standing provider benchmark recipe in their owning files. Completed
tracker/pass chronology was separated from current authority into explicitly
historical documents rather than deleted. The causal pilot is not cited as
permission to discard unique history.

## Post-record review addendum (2026-07-17)

The immutable run-1 row preserves the anomaly recorded during initial manual
scoring. A later review of its recorded final answer found an additional
authority error: it said local commits and deletions were unauthorized even
though the compact tracker authorized both. The 4/5 score remains unchanged
because answer-key item 5 tested only the prohibition on upstream and GitHub
mutation. The result narrative and gate 3 above include the correction; the
recorded row is not rewritten.

## Protocol notes

- The first command was rejected before execution by the approval reviewer as
  a possible private-data disclosure. GitHub API verification established that
  ctxpack is public; the retried frozen command used only the public base plus
  synthetic compact docs and was approved. No rejected-attempt data left the
  machine and it is not counted as a subject run.
- Codex CLI was `0.144.5`; model `gpt-5.6-luna`, reasoning effort `low`; every
  completed run was ephemeral and read-only.
- The CLI JSONL has usage but no event timestamps. The preregistered wall-time
  field is therefore null in `runs.jsonl`; no timing claim is made.
- Raw verbose event streams remain gitignored scratch by design. Their hashes
  are recorded in `runs.jsonl`; the compact per-run records are committed.
- No prior pre-registration, runner, result, packet, prompt, or transcript was
  changed.
