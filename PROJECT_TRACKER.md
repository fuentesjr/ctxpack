# ctxpack project tracker

This is the compact current work-order checkpoint. Fresh sessions need only:
**“Continue from PROJECT_TRACKER.md.”** Specs own requirements, `design.md`
owns rationale, eval artifacts own measured evidence, and Git history owns
completed chronology together with the explicitly historical snapshots under
`docs/history/`.

## Current state

- Upstream ctxpack is verified through `21912b5`; the Markdown-context work is
  local-only. Local commits `2f58649`, `2bf1c86`, and `e40e9e1` contain the
  decision map, audit, and frozen ablation protocol; the cleanup closure is the
  commit containing this checkpoint. **Do not push.** The matching local
  evalkit ledger entry is commit `b3f7eb4` and is also unpushed.
- v0 ships anchor, test, files, error, method, and diff seeds. Method ships
  without its failed test-candidate leg (SEED-25). Route did not ship
  (`0.243 < 0.70`) and remains CLI-17c coaching-only; reopening it requires a
  new frozen spike. `specs/README.md` routes the current normative surface.
- The files-seed history tracer and optimized `git-recon facts` companion are
  complete and published (`3e7cf79`/`05f293e` in ctxpack, `7682b2c` in
  git-recon). The representative provider-seam recheck passed in 6.020 seconds
  with 5 facts, 10 truncated, and no error; the exact recipe remains in
  `implementation-notes.md`.
- Context-source issue planning is complete. GitHub issues #6 (seed-driven
  git-recon signals) and #7 (repository-documentation enrichment) remain open
  and paused behind this cleanup. No issue/PR mutation is authorized.
- The reusable cleanup workflow now lives in the installed local
  `~/Projects/skills/audit-markdown-context` skill. Its read-only script
  reproduces this repository's tracked Markdown inventory and also passes
  against an unrelated skill repository. The canonical Agent README and this
  project now use a three-attempt stop/report rule.

## Markdown context cleanup

Baseline `21912b5` has 103 regular Markdown documents (807,759 bytes / 15,104
lines) plus four Claude skill symlinks, for 107 tracked `.md` paths. The
evidence and dispositions live in:

- [`docs/markdown-context-audit.md`](docs/markdown-context-audit.md)
- [`eval/markdown-context/RESULTS.md`](eval/markdown-context/RESULTS.md)

Inventory and transcript-forensics tickets #1/#2 are resolved. Ticket #3's
Codex ablation stopped under its frozen 900k-token cap after five pilot runs,
so its category gate is inconclusive. The completed T1 pair still caught a
direct wrong turn: the full tracker restarted resolved ticket #1; the compact
tracker selected ticket #3 but also invented a prohibition on authorized local
commits/deletions. No unique/protected material is deleted on that incomplete
causal result.

The implemented static lane:

- removes the fully superseded packet-format proposal and stale agent backlog;
- compacts `AGENTS.md`, `CLAUDE.md`, this tracker, and cumulative pass notes,
  while retaining their unique chronology as explicitly historical documents;
- keeps current authority, safety gates, the benchmark recipe, and Git recovery
  pointers;
- corrects stale shipped/pending statements in specs and `design.md`;
- updates routed skill instructions and stops mandatory note accumulation when
  a better authoritative home already exists;
- retains normative specs, `design.md` rationale, the seed/acquisition
  proposals, learning notes, and all frozen/recorded eval evidence.

## Working process

- Implement spec-governed behavior in dependency order from
  `specs/README.md`; verify delegate work session-side and reconcile any spec
  amendment with `design.md`.
- Run the whole Minitest suite before success. Compiler-behavior changes also
  run the `tier0-corpus-rescan` skill against the pinned three-app corpus;
  predicted changes must be named and every other per-anchor change is a
  defect.
- Keep only current authority in the tracker and current pass notes. Historical
  snapshots are explicitly nonauthoritative; Git remains the full recovery
  path.

## Current work order

The Markdown cleanup work order is complete in the local closure commit. The
whole suite, diff/provenance/link/accounting gates, and two independent reviews
passed. The post-cleanup skill extraction and canonical retry-rule update are
complete, including the local ctxpack instruction alignment. Do not push
ctxpack, evalkit, or any other repository.

The only optional evidence follow-up is funding a newly pre-registered causal
confirmation grid above the exhausted 900k-token cap.

Otherwise return to issue #6 disposition and #7 scheduling; neither starts
implicitly.

## Standing follow-ups

- Multi-seed CLI determinism in fixture evals uses primary-seed cases for some
  error/multi scenarios; full merge behavior is covered through packet-object
  expectations.
- `TestClass#method` sugar still coaches `--from-test PATH`.
- Method test-leg and route resolver re-spikes need new frozen
  pre-registrations and explicit work orders.
- `Ctxpack::Compiler` is 1,805 lines and remains the highest-pressure design
  refactor. Schedule a behavior-preserving split only at an explicit pass
  boundary, with unchanged tests, whole-suite/Tier-0 proof, and before/after
  advisory Metz evidence.
- Nested eval subject workspaces can inherit ctxpack's root instructions. The
  rules now scope ctxpack gates explicitly, but workspace/instruction isolation
  remains the structural follow-up.
- Tier 3 Rubydex remains deferred. Real-usage LIM-1 dogfooding is
  discretionary. The release-boundary three-app rerun remains separately
  gated; do not spend its large subject budget implicitly.

## Recovery

Completed pass/status chronology remains available without occupying every
fresh session:

```sh
less docs/history/project-tracker-through-2bf1c86.md
less docs/history/implementation-notes-through-2bf1c86.md
git log -- PROJECT_TRACKER.md implementation-notes.md
git show 2bf1c86:PROJECT_TRACKER.md
git show 2bf1c86:implementation-notes.md
```
