# Using a Rails engine as a Tier 2 benchmark app

## Problem

The third Tier 2 expansion app, Publify, turned out to keep its whole domain in
the `publify_core` **engine** gem: the `publify/publify` deploy app at v10 has a
single app controller (`application_controller.rb`). ctxpack resolves
controllers from `app_root/app/controllers/`, so anchors against the deploy app
would not resolve and no packet could be generated — the exact engine +
dummy-app shape the pre-registration rejected for Solidus.

## Context

Discovered at template prep while authoring `eval/tier2-expansion/publify/`. The
user chose (over dropping to two apps or ancient monolithic Publify v8) to pin
the **engine repo** `publify/publify_core` v10.0.3 (`80ede867`) — a
self-contained single engine with a committed `spec/dummy` app, SQLite, and
RSpec.

## Failed approaches / dead ends

- Pointing ctxpack at the engine root failed: ctxpack's app-root discovery
  (`CLI#discover_app_root`) searches upward for `config/application.rb`, and an
  engine has none at its root (only `config/routes.rb`); the dummy app's
  `application.rb` lives under `spec/dummy/`, a different directory from the
  engine's `app/controllers/`.
- `bin/rails routes` from the engine root crashed (`Rails.application` is nil —
  the engine commands don't boot a host app), and from `spec/dummy` it failed
  until `BUNDLE_GEMFILE` was pointed at the engine's Gemfile (the dummy's
  `bin/rails` looks for a nonexistent `spec/dummy/Gemfile`).
- First `bundle exec rspec` failed with
  `uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger` — the
  `concurrent-ruby >= 1.3.5` / Rails 6.1 logger-autoload breakage, unrelated to
  the engine.

## Key insight

ctxpack's discovery only checks that `config/application.rb` **exists**
(`File.file?`) — it never boots or parses it. So a **stub `config/application.rb`**
at the engine root is enough to make ctxpack treat the engine as the app root and
resolve its real `app/controllers/` + `spec/`. Because RSpec loads
`spec/dummy/config/environment` (not the engine-root file), the stub is inert for
the test run. Treating it (plus the patched Gemfile) as a **prepared file** baked
into the workspace **baseline commit** keeps it out of every subject diff, so it
is invisible to the metric that matters.

## Final approach

- Pin the engine repo; ctxpack `app_root` = engine root (the harness `chdir`s
  the template there for packet gen and clones it for workspaces).
- Prepared files (copied post-clone, baked into the baseline so they never leak
  into a subject diff): stub `config/application.rb` (discovery marker),
  patched `Gemfile` (pins `concurrent-ruby 1.3.4`), plus gitignored
  `Gemfile.lock` and dummy-app `spec/dummy/db/test.sqlite3`.
- Build the route table with `bin/rails routes --expanded` run from `spec/dummy`
  with `BUNDLE_GEMFILE` at the engine Gemfile (the non-isolated engine draws its
  routes into the dummy host app); draw anchors blind from that table.
- Result: engine controllers (incl. namespaced `Admin::`) resolve, RSpec test
  candidates fire, `bundle exec rspec` runs in each clone, the post-baseline tree
  is clean (scoring `git apply` safe), and all four tasks validated red-green.

## When this applies

Any Rails **engine** you want to use as a ctxpack fixture or Tier 2 benchmark:
the code-under-test is in the engine's `app/`, but the bootable app + DB config
live in a `spec/dummy` (or `test/dummy`) app. Bridge ctxpack's monolithic-app
assumption with a stub `config/application.rb` prepared file; run routes/specs
through the dummy app with `BUNDLE_GEMFILE` at the engine Gemfile. This stays
milder than a multi-gem monorepo (Solidus) only when it is a *single* engine
with a *committed* dummy app.
