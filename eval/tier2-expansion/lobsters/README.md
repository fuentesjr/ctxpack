# Lobsters Tier 2 Artifacts

Authored 2026-07-07. Lobsters (`lobsters/lobsters`) is the MariaDB-backed
RSpec app in the Tier 2 expansion. The pinned checkout is used only as an
offline benchmark fixture; subject diffs are discarded and nothing is sent
upstream.

## What's here

- `anchors.json` - the frozen deterministic draw. Task id map:
  1=feature_1 (`comments#disown`), 2=feature_2 (`users#standing`),
  3=bug (`inbox#all`), 4=behavior (`stories#update`).
- `routes/lobsters.json`, `results/lobsters.json` - route table and classifier
  resolution inputs to the draw.
- `tasks/` - frozen task prompts, hidden RSpec acceptance specs, and the task 3
  seed patch. The hidden specs are copied into `spec/requests/` only in scoring
  workspaces.
- `tmp/tier2-expansion/lobsters/reference-impls/` - uncommitted reference
  implementation patches for tasks 1, 2, and 4.

## Pinned app + environment

- SHA `430d864b0d7bf1b30913ee42e6cca3d9fbddcaa4`.
- Ruby **4.0.0** via mise.
- MariaDB primary test DB `lobsters_test` at `127.0.0.1:3306` (credentials per
  the app's committed `config/database.yml.sample`); cache and queue databases
  use SQLite.
- Template checkout: `tmp/tier2-expansion/lobsters/template`.
- Each workspace copies the template's gitignored `config/database.yml` and
  patched `Gemfile.lock`.
- `remove_files: ["CLAUDE.md", "AGENTS.md"]` neutralizes Lobsters'
  upstream contribution instructions in sterile subject workspaces. Those files
  are aimed at upstream PRs, not at this offline benchmark.
- Config reuses Redmine's authenticated `CLAUDE_CONFIG_DIR`
  (`tmp/tier2/claude-config`) via the `config_dir:` override.

## Task designs

### Task 1 - `comments#disown` feature

Adds optional cascade disowning. `POST /comments/:id/disown` with a truthy
`cascade` parameter should disown the target comment and direct child replies
authored by the same original user. Without `cascade`, existing behavior is
unchanged. The hidden request spec verifies the same-author direct reply is
reassigned to `inactive-user`, a different-author direct reply is preserved,
and a same-author grandchild reply is preserved.

The reference patch touches `CommentsController#disown` plus
`InactiveUser.disown_with_direct_replies!`, keeping the feature multi-file and
using the existing inactive-user attribution path.

### Task 2 - `users#standing` feature

Adds `GET /~:username/standing.json`, returning a JSON summary with
`username`, `n_comments`, `n_flagged_comments`, and `n_flags`. Existing HTML
standing behavior and authorization stay intact. The hidden request spec signs
in as the target user, creates one flagged and one unflagged comment, and
asserts the JSON values.

The reference patch adds a small `User#standing_summary` method and has
`UsersController#standing` render it for JSON requests before the existing HTML
path.

### Task 3 - `inbox#all` seeded bug

The seed patch changes:

```ruby
after_action :update_read_at, only: [:all, :unread]
```

to:

```ruby
after_action :update_read_at, only: [:unread]
```

This prevents `GET /inbox/all` from marking unread notifications read and is
intended to break the existing controller example:
`marks the notification and associated message as read`. Scoring forbids edits
under `spec/` and runs the whole `spec/controllers/inbox_controller_spec.rb`.

### Task 4 - `stories#update` behavior

Changes story editing so an editable deleted story stays deleted after a normal
owner edit. The hidden request spec creates a recently-created deleted story,
signs in as its owner, patches the title, and asserts both that the title
changed and `is_deleted` stayed true.

The reference patch removes the unconditional `@story.is_deleted = false` from
`StoriesController#update`; `StoriesController#undelete` remains the explicit
restore path.

## Test-candidate pointer (pre-registered sub-analysis)

Unlike Campfire (4/4), Lobsters gives a **within-app 2/2 split** on
`packet_had_test_candidate` — ideal contrast for the pre-registered
test-pointer sub-analysis:

| task | anchor | had_test_candidate | why |
|---|---|---|---|
| 1 | `comments#disown` | **true** | `spec/controllers/comments_controller_spec.rb` exists |
| 2 | `users#standing` | false | no `users` controller spec; request specs lack the `standing` action token |
| 3 | `inbox#all` | **true** | `spec/controllers/inbox_controller_spec.rb` exists |
| 4 | `stories#update` | false | no `stories` controller spec; `stories_spec.rb` lacks the `update` token |

(The request-spec path match requires the filename to carry both the controller
*and* action tokens; `stories_spec.rb`/`users_controller_spec.rb` legitimately
don't. Recorded post-draw in `anchors.json`; not consulted by the draw.)

## Validation status — DONE (session-side, 2026-07-07)

Codex authored the artifacts but its managed sandbox blocks local MariaDB
(`trilogy_connect ... 127.0.0.1:3306` and `/tmp/mysql.sock`), so it correctly
did not fabricate `task3_failing_output.txt` or claim red/green
(see `docs/agent-learnings/2026-07-07-sandbox-blocked-db-validation.md`). All
red-then-green validation was done session-side against the local MariaDB, via
the harness's own `score`/`setup` paths and a warm throwaway clone:

- **task 1** (cascade disown): base **1 failure** → reference impl **0 failures**.
- **task 2** (standing JSON): reference impl **passes fast (0 failures)**. The
  *base* `standing` action infinite-loops on a `.json` request (missing-template
  / heinous inline-partial path; a Ruby-side `Array#each` loop, no DB query) —
  so an unimplemented subject diff would never terminate. Mitigated by the new
  scoring timeout (below); a non-implementing diff times out → scored `false`
  (the correct red outcome).
- **task 3** (inbox bug): seed → **2 failures**; fix (restore `:all`) → **0
  failures**. `harness.rb lobsters setup` captured `tasks/task3_failing_output.txt`
  (proves the seed fails the existing spec).
- **task 4** (deleted-story behavior): base **1 failure** → reference impl **0
  failures**.
- **Additive:** with each reference impl applied, the touched controllers'
  existing specs stay green (stories 27, comments 9, users 12 — all 0 failures).
- `harness.rb lobsters verify` → **OK** (schedule + deterministic prompts +
  packet SHA-256s); `status` → 26 tuples (2 pilot + 24 grid).

### Two additive harness changes landed this pass (P2-compatible)

Both leave the `runs.jsonl` schema, metric definitions, prompts, and
abort/timeout rules unchanged; Redmine + Campfire `verify` stay `OK`.

1. **`remove_files`** (`AppConfig`) + a guarded workspace-baseline commit in
   `make_workspace`: deletes listed tracked files from each clone and bakes that
   (plus any tracked prepared-file patch, e.g. the `Gemfile.lock` platform line)
   into a baseline commit, so neither leaks into the subject diff or breaks
   scoring's `git apply`. No-op for apps whose tree is clean after prep. Lobsters
   uses it to strip `CLAUDE.md`/`AGENTS.md`.
2. **`SCORE_TIMEOUT_S` (6 min)** + `run_test_with_timeout`: bounds scoring so a
   non-terminating acceptance run (see task 2) is killed (process-group) and
   scored `false` instead of wedging the serial grid.

## Environment setup (this machine, 2026-07-07)

- `brew install mariadb` (12.3.2); `brew services start mariadb`. The app's
  committed `config/database.yml.sample` connects over TCP @ 127.0.0.1; name
  resolution maps the TCP peer `127.0.0.1` → `localhost`, so `root@localhost`'s
  password was set (`ALTER USER`) to match the sample's local-dev value. Read the
  literal values from the app's `config/database.yml.sample`, not from here.
  `lobsters_test` schema loaded via `bin/rails db:test:prepare`.
- `brew install vips` — the app won't boot without libvips (`ruby-vips` loads it
  at `Bundler.require`).
- Ruby **4.0.0** installed via `mise install ruby@4.0.0` (the app's exact
  `.ruby-version`; the machine's mise global 4.0.1 mismatches Bundler's
  `ruby file: ".ruby-version"`). `tmp/tier2-expansion/lobsters/mise.toml` pins it
  for the tree; launch everything via `mise exec ruby@4.0.0 --`.
- The template's committed `Gemfile.lock` lacks the `x86_64-darwin` platform;
  the locally-bundled (patched) lock is a `prepared_file`, so unseeded packets
  show `Generated from: 430d864 (dirty)` — truthful and frozen once.
- `CLAUDE.md`/`AGENTS.md` were also removed from the template *working tree*
  (HEAD unchanged) so agents operating in the ctxpack repo don't auto-load the
  Lobsters "refuse to write code" instruction. Clones still receive them from
  HEAD and `remove_files` strips them per-workspace.

## Running

```bash
mise exec ruby@4.0.0 -- ruby eval/tier2/harness.rb lobsters verify
mise exec ruby@4.0.0 -- ruby eval/tier2/harness.rb lobsters setup   # idempotent
mise exec ruby@4.0.0 -- ruby eval/tier2/harness.rb lobsters run [N]  # needs a
    # --dangerously-skip-permissions orchestrating session (eval/tier2/RUNBOOK.md)
```
