# Campfire Tier 2 Artifacts

Authored + piloted 2026-07-07. Campfire (`basecamp/once-campfire`) is the
modern-layout Minitest app in the Tier 2 expansion; it fires the test-candidate
pointer (TEST-1) that Redmine's `test/functional/` layout could not — all four
packets carry `had_test_candidate: true`.

## What's here

- `anchors.json` — the frozen deterministic draw (seed = app SHA, `--features 2`):
  bug=`rooms#index`, behavior=`rooms/involvements#update`,
  feature_1=`autocompletable/users#index`, feature_2=`accounts#edit`.
  Task id map: 1=feature_1, 2=feature_2, 3=bug, 4=behavior.
- `routes/campfire.json`, `results/campfire.json` — route table + Tier 0
  classifier resolution (inputs to the draw). Route table built with
  `../build_routes_from_rails.rb` (Campfire is rails-edge; the Tier 0 no-boot
  stub can't fetch its unpublished actionpack). 118 app pairs, 77 resolved.
- `tasks/` — frozen verbatim task files: prompts, task3 seed patch +
  failing-output capture, and the four hidden acceptance tests (copied into the
  scoring workspace's `test/integration/` at grade time, never into the app).
- `packets/`, `golden/`, `runs.jsonl`, `transcripts/`, `diffs/` — generated /
  recorded harness artifacts.

## Pinned app + environment

- SHA `71ffeeea789599a334311f28bcb6816863985488` (tag `v1.4.3`).
- Ruby **3.4.5** (Campfire's committed `Gemfile.lock` — rails 8.2.0.alpha —
  needs it; the machine's mise global 4.0.1 bumps the lock and breaks clones).
  `tmp/tier2-expansion/campfire/mise.toml` pins 3.4.5 for the whole tree.
- SQLite; test env uses the `test` cable adapter + null cache, so **no Redis**.
- Template checkout: `tmp/tier2-expansion/campfire/template` (bundled under mise
  3.4.5; `storage/db/test.sqlite3` prepared — the one `prepared_files` entry).
- Config reuses Redmine's authenticated `CLAUDE_CONFIG_DIR`
  (`tmp/tier2/claude-config`) via the `config_dir:` override — Claude binds
  OAuth to the literal config-dir path, so a copy is not authenticated.

## Running

Always launch under mise 3.4.5 so the harness + scoring resolve the right Ruby:

```bash
mise exec ruby@3.4.5 -- ruby eval/tier2/harness.rb campfire verify
mise exec ruby@3.4.5 -- ruby eval/tier2/harness.rb campfire status
mise exec ruby@3.4.5 -- ruby eval/tier2/harness.rb campfire setup   # idempotent
mise exec ruby@3.4.5 -- ruby eval/tier2/harness.rb campfire run [N]  # needs a
    # --dangerously-skip-permissions orchestrating session (see eval/tier2/RUNBOOK.md)
```

Golden was captured with `tmp/tier2-expansion/campfire/capture_golden.rb` after
`setup` (schedule + deterministic prompts; packet SHAs live in
`packets/packets.json`, which `verify` checks directly).

## Pilot (2026-07-07)

Pilot task = 3 (bug). Both `t2-3-{control,treatment}-1-pilot`: `complete`,
`task_success=true`; both diffs apply the minimal `rooms.first`→`rooms.last`
fix, neither touches `test/`; scoring ran the full `rooms_controller_test.rb`
green (5 runs, 0 failures). Treatment `packet_had_test_candidate=true`. No
acceptance-test or harness amendment needed. Calibration: ~74s / ~92s wall,
~0.56M / ~0.47M tokens per session.
