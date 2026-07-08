# Publify Tier 2 Artifacts

Authored 2026-07-08. Publify (`publify/publify_core`) is the SQLite-backed
RSpec engine in the Tier 2 expansion. The pinned checkout is used only as an
offline benchmark fixture; subject diffs are discarded and nothing is sent
upstream.

## What's here

- `anchors.json` - the frozen deterministic draw. Task id map:
  1=feature_1 (`setup#index`), 2=feature_2 (`tags#index`),
  3=bug (`articles#preview`), 4=behavior (`admin/users#destroy`).
- `routes/publify.json`, `results/publify.json` - route table and classifier
  resolution inputs to the draw.
- `tasks/` - frozen task prompts, hidden RSpec acceptance specs, and the task 3
  seed patch. The hidden specs are copied into `spec/requests/` only in scoring
  workspaces.
- `tmp/tier2-expansion/publify/reference-impls/` - uncommitted reference
  implementation patches for tasks 1, 2, and 4.

## Pinned app + environment

- SHA `80ede867d802949e218fdf0bb4f3c31f68f8a56a`
  (`publify/publify_core` v10.0.3).
- Ruby **3.1.7** via mise.
- SQLite through the engine's committed `spec/dummy` app.
- Template checkout: `tmp/tier2-expansion/publify/template`.
- The pinned unit is the `publify_core` engine, not the deploy app. The deploy
  app is a thin shell; the engine contains the real controllers, models, routes,
  factories, and specs.
- Routes are collected and specs are run through `spec/dummy`, with
  `BUNDLE_GEMFILE` pointing at the engine Gemfile.
- Each workspace copies prepared files after the local clone:
  `config/application.rb`, `Gemfile`, `Gemfile.lock`, and
  `spec/dummy/db/test.sqlite3`.
- `config/application.rb` is a stub used only as ctxpack's app-root discovery
  marker; it is never booted because RSpec loads `spec/dummy/config/environment`.
- The prepared `Gemfile` pins `concurrent-ruby` to 1.3.4 because 1.3.5 dropped
  an implicit `logger` require that Rails 6.1 needs in this app.
- `Gemfile.lock` and `spec/dummy/db/test.sqlite3` are gitignored upstream, so
  the harness copies them into each workspace for deterministic bundle and DB
  setup.
- Config reuses Redmine's authenticated `CLAUDE_CONFIG_DIR`
  (`tmp/tier2/claude-config`) via the `config_dir:` override.

## Task designs

### Task 1 - `setup#index` feature

Adds an optional admin nickname during initial setup. `POST /setup` with a
non-blank `user[nickname]` should create the admin user with that nickname.
When the nickname is absent or blank, the existing hard-coded `"Publify Admin"`
default remains unchanged. The hidden request spec starts from `Blog.create`
so the setup flow is active, then covers both custom and default nickname
paths.

The reference patch touches `SetupController#create` plus `user_params`, using
the submitted nickname with `.presence` and otherwise falling back to
`"Publify Admin"`.

### Task 2 - `tags#index` feature

Adds `GET /tags.json`, returning a JSON array of tag objects with `name` and
`articles_count`. The count is the number of published contents associated
with the tag via the existing `tag.contents.published` path used by the tag
show flow. Existing HTML behavior stays unchanged. The hidden request spec
creates a configured blog, one tag, two published articles, and one draft
article associated to the tag, then asserts the JSON entry counts only the two
published records.

The reference patch adds a small `Tag#published_articles_count` method and has
`TagsController#index` render the JSON representation.

### Task 3 - `articles#preview` seeded bug

The seed patch changes:

```ruby
@article = Article.last_draft(params[:id])
```

to:

```ruby
@article = Article.find(params[:id])
```

This prevents preview from walking to the last descendant draft and is intended
to break the existing controller example:
`assignes last article with id like parent_id`. Scoring forbids edits under
`spec/` and runs the whole `spec/controllers/articles_controller_spec.rb`.

### Task 4 - `admin/users#destroy` behavior

Changes user deletion so an admin cannot delete their own account, while the
existing last-admin guard still controls whether another admin can be deleted.
The hidden request spec creates three admins, signs in as the first, verifies a
self-delete redirects without deleting that user, and verifies deleting a
different admin still succeeds.

The reference patch adds the `@user != current_user` guard to
`Admin::UsersController#destroy`.

## Test-candidate pointer (pre-registered sub-analysis)

Publify gives a **within-app 4/4** on `packet_had_test_candidate`, like
Campfire. Every drawn controller has a matching controller spec:

| task | anchor | had_test_candidate | why |
|---|---|---|---|
| 1 | `setup#index` | **true** | `spec/controllers/setup_controller_spec.rb` exists |
| 2 | `tags#index` | **true** | `spec/controllers/tags_controller_spec.rb` exists |
| 3 | `articles#preview` | **true** | `spec/controllers/articles_controller_spec.rb` exists |
| 4 | `admin/users#destroy` | **true** | `spec/controllers/admin/users_controller_spec.rb` exists |

(Recorded post-draw in `anchors.json`; not consulted by the draw.)

## Validation status - DONE (session-side, 2026-07-08)

Codex authored the artifacts (its managed sandbox lacks Ruby 3.1.7/bundle/the
prepared SQLite DB, so it did not fabricate red/green output or
`task3_failing_output.txt`). All red-then-green validation was done session-side
against the local prepared template via the harness `setup`/`score` paths and
throwaway clones (same discipline as Lobsters):

- **task 1** (setup nickname): base + acceptance spec **2 ex / 1 failure** →
  reference impl **2 ex / 0 failures**; additive `setup_controller_spec.rb`
  **13 / 0**.
- **task 2** (tags JSON): base **1 / 1 failure** → reference impl **1 / 0**;
  additive `tags_controller_spec.rb` **15 / 0**.
- **task 3** (preview bug): `harness.rb publify setup` captured
  `tasks/task3_failing_output.txt` (seed → the existing example
  `assignes last article with id like parent_id` fails, 2870 bytes); the
  un-seeded base spec is green (54 ex / 0 failures / 1 pending), so the fix
  (restore `last_draft`) is green.
- **task 4** (self-delete): base **2 / 1 failure** → reference impl **2 / 0**;
  additive `admin/users_controller_spec.rb` **8 / 0**.
- `harness.rb publify verify` → **OK** (schedule + deterministic prompts +
  packet SHA-256s); `status` → 26 tuples (2 pilot + 24 grid); packets fire
  `had_test_candidate: true` for all four anchors.

**2-session pilot (task 3, both arms): green.** Both `complete` / `success=true`,
each a minimal single-file fix to `app/controllers/articles_controller.rb`,
neither touching `spec/` (control reimplemented the last-draft lookup inline;
treatment restored `Article.last_draft`). No amendment needed. Control 64s /
treatment 74s; treatment packet `had_test_candidate=true`.

No compiler behavior touched (the engine bridge lives in the app template, not
in `lib/`) → Tier 0 corpus re-scan skipped per its rule. ctxpack suite green
(55 runs, 362 assertions).

## Running

```bash
mise exec ruby@3.1.7 -- ruby eval/tier2/harness.rb publify verify
mise exec ruby@3.1.7 -- ruby eval/tier2/harness.rb publify setup
mise exec ruby@3.1.7 -- ruby eval/tier2/harness.rb publify run [N]
```
