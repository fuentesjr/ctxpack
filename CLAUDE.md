# CLAUDE.md — Claude Code adapter

**Read and follow [`AGENTS.md`](AGENTS.md).** It is the canonical operating
manual for this repo (project map, commands, conventions, failure modes,
quality bars, caution list, escalation). This file adds only what is
Claude-specific; if anything here seems to conflict with `AGENTS.md`,
`AGENTS.md` wins.

## Session bootstrap

- Fresh working sessions resume from `PROJECT_TRACKER.md` ("Resuming a
  session"): its "Next step: execution plan" is the work order.
- Tier 2 harness runs need a session started with
  `claude --dangerously-skip-permissions` (the harness spawns unsandboxed
  subject sessions) — see `eval/tier2/RUNBOOK.md`. Never start the grid from
  a normal session; it will be refused by the permission classifier.

## Repo skills (in `.claude/skills/`, symlinked to canonical `.agents/skills/`)

| Skill | Use when |
|---|---|
| `codex-spec-pass` | Landing a spec pass via the Codex delegation loop (dispatch → background poll → session-side verify → `--resume` fix rounds) |
| `tier0-corpus-rescan` | Any compiler-behavior change, at the pass boundary — mandatory gate |
| `add-fixture-eval` | Any packet bug found — turn it into a Tier 1 YAML regression case, red-then-green |
| `extract-approach` | After **every** non-trivial solved problem, before moving on. A solution without its learning note in `docs/agent-learnings/` is unfinished work |

Edit skills only at their canonical `.agents/skills/<name>/SKILL.md` path —
the `.claude/skills/` entries are symlinks, and the rest of `.agents/skills/`
is a gitignored synced mirror you must not edit.

## Codex delegation notes (Claude-side mechanics)

The `codex:codex-rescue` agent is a one-shot forwarder. Poll from the main
session via the companion script (newest version dir under
`~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`),
and always have the forwarder launch with the companion's own `--background`
flag — details and the wedged-run recovery playbook are in the
`codex-spec-pass` skill and `PROJECT_TRACKER.md` "Working process".

## Proof before claiming success

Do not say "done", "fixed", or "passing" without, in this session:

1. `bundle exec rake test` output pasted (must show `0 failures, 0 errors`).
2. The diff reviewed against the spec codes in scope, each named.
3. For packet bugs: the new eval case shown failing pre-fix.
4. For compiler-behavior changes: corpus re-scan result stated, or an explicit
   deferral note.
5. Anything unverified named as unverified.
