# CLAUDE.md — Claude Code adapter

Read and follow [`AGENTS.md`](AGENTS.md); it is the canonical project operating
manual.

- Fresh sessions resume from `PROJECT_TRACKER.md`.
- Tier 2 harness grids require a session started with
  `claude --dangerously-skip-permissions`; see `eval/tier2/RUNBOOK.md`.
- Repo skills under `.claude/skills/` are symlinks to the canonical four
  `.agents/skills/` bodies. Edit the canonical paths only.
- Claude-specific delegation profiles and companion mechanics belong in local
  Claude configuration/skills, not this repository adapter.
- The main session remains the DRA and verifies every delegate's diff and
  repository gate itself.
