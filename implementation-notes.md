# Implementation notes — current pass and standing recipes

Completed pass notes are recoverable with:

```sh
git log -- implementation-notes.md
git show 2bf1c86:implementation-notes.md
```

## Markdown context cleanup (2026-07-17)

### Scope and evidence

- Baseline `21912b5`: 103 regular Markdown documents / 807,759 bytes / 15,104
  lines; four Claude skill symlinks make 107 tracked `.md` paths.
- `docs/markdown-context-audit.md` owns the consolidated investigation
  decisions, inventory/load-path evidence, transcript evidence, and final
  disposition. The completed planning map remains explicitly historical.
- `eval/markdown-context/PREREGISTRATION.md` froze a full-versus-compact Codex
  worktree ablation. It reused official ephemeral `codex exec`; no runner or
  dependency was added. The matching evalkit ledger entry is local commit
  `b3f7eb4`.
- Five pilot runs used 803,913 reported input-plus-output tokens. The frozen
  900k cap stopped the paired full T3 run and confirmation grid. Results are
  inconclusive for the category gate; no unique/protected deletion relies on
  them. The completed T1 pair exposed a stale full-tracker wrong turn and a
  compact-arm authority error about authorized local commits/deletions.

### Disposition

- Delete `docs/packet-format-proposal.md`: no inbound references, false
  “uncommitted” status, and full replacement by the normative format spec,
  reconciled design, tests, and Git history.
- Delete `docs/agent-backlog.md`: it presents completed Phase 2/coverage/README
  work as current. Preserve its live concerns in the compact tracker/follow-up
  surface.
- Compact the automatically loaded/root bootstrap chain (`AGENTS.md`,
  `CLAUDE.md`, `PROJECT_TRACKER.md`) and cumulative pass notes. Preserve
  current authority, safety gates, open work, and benchmark reproducibility;
  retain unique completed chronology in explicitly historical documents
  because the incomplete causal gate does not authorize deleting it.
- Correct objectively stale shipped/pending language in `specs/README.md`,
  `specs/views.md`, and the completed experiment tail of `design.md`; no
  behavior or requirement code changes.
- Update repo-owned skills so fixture-eval guidance admits current seed command
  shapes, spec-pass notes are current-pass-only, and learning notes are created
  only when no better authoritative home exists.
- Retain normative specs, design rationale, both remaining proposals, all
  learning notes, and frozen/recorded eval evidence. Their low ordinary
  exposure and unique provenance do not support deletion.

### Boundaries

- No production Ruby, dependency, lockfile, CI, compiler behavior, packet
  format, reason/uncertainty code, or existing recorded evidence changes.
- No Tier 0 rescan or packet-bug fixture is required for this docs/workflow
  cleanup.
- Local commits are authorized; no push or GitHub mutation is authorized.

### Verification

- First whole-suite run reached all 225 tests but hit the existing
  process-runner PID-file scheduling race (`1975 assertions`, one error). The
  focused test immediately passed (`1 run, 5 assertions`), and verification
  attempt 2 passed: `225 runs, 1976 assertions, 0 failures, 0 errors, 0 skips`.
- `git diff --check`, JSONL parsing, all local Markdown links, and all four
  Claude skill symlinks pass. Frozen pre-registration/lean payloads and prior
  recorded evidence are unchanged; no Ruby, dependency, lockfile, or CI path
  changed.
- Final accounting and percentages are recorded in the audit. Two independent
  review streams found no remaining actionable issue after corrections.
- This docs/workflow pass changes no runtime behavior. CLI-1/1e/2/4b and
  SEED-4/14/15/16/25/26/MERGE-1 wording now describes already-shipped behavior;
  requirement codes and semantics are unchanged and `design.md` is reconciled.
  TDD, a packet-bug YAML case, and the Tier 0 rescan are therefore not
  applicable.

## Standing provider-seam benchmark recipe

This recipe exercises the production history-provider seam directly; it does
not invoke CLI Rails-app discovery. Run it from the ctxpack root with the
repository bundle's Ruby. The Rails checkout must be clean at
`1d19b2a1f90eb64f7cda2209621eb21a43511be0`, and PATH-discovered `git-recon`
must resolve to optimized commit `7682b2c`.

```sh
bundle exec ruby -Ilib -rjson -rctxpack -e '
repo = "/Users/sal/Projects/rails"
revision = "1d19b2a1f90eb64f7cda2209621eb21a43511be0"
target_path = "activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb"
provider = Ctxpack::GitReconHistoryProvider.new(limits: Ctxpack::Compiler::LIMITS)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
history = provider.fetch(
  app_root: repo,
  repo_root: repo,
  path: target_path,
  revision: revision
)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
puts JSON.generate(
  ruby: RUBY_VERSION,
  revision: revision,
  path: target_path,
  deadline_seconds: Ctxpack::Compiler::LIMITS.fetch(:max_history_seconds),
  elapsed_seconds: elapsed.round(3),
  status: history.status,
  facts: history.facts.length,
  truncated: history.truncated_count,
  reason: history.reason
)
'
```

Healthy margin requires `status=included`, 5 facts, 10 truncated, no error
reason, and elapsed time below the existing 8-second representative-query
benchmark. This is a landing aid, not a normative timeout; production remains
20 seconds. The recorded run passed in 6.020 seconds on Ruby 4.0.1, leaving
13.98 seconds before the provider deadline.
