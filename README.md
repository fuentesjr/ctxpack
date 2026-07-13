# ctxpack 🧳

**Deterministic Rails-aware context packets for AI coding agents.**

`ctxpack` asks a small question with a practical answer:

> Can Rails conventions produce better AI coding context than generic code search?

The idea is to turn an exact Rails anchor like `accounts#upgrade` into a compact, evidenced Markdown packet that another coding agent can use as starting context.

```bash
bin/rails routes -g upgrade
ctxpack accounts#upgrade -t "Implement billing upgrade"
```

Example output:

```text
.ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md
```

## ✨ Status

`ctxpack` v0 is **implemented and evaluated**. The compiler, Markdown/manifest
renderers, CLI, fixture evals, and the Rails view-convention resolution layer
are all shipped and tested. See
[`PROJECT_TRACKER.md`](PROJECT_TRACKER.md) for live pass status and the
`RESULTS.md` files under [`eval/`](eval/) for the Tier 0 / Tier 2 evaluation
results.

Hands-on walkthrough and FAQ:

- [`docs/examples.md`](docs/examples.md) — install, first packet, anatomy of the Markdown output
- [`docs/faq.md`](docs/faq.md) — limits, refusals, when packets help, determinism

The repo contains:

- [`lib/`](lib/) + [`exe/ctxpack`](exe/ctxpack) — the v0 gem and CLI
- [`test/`](test/) — unit tests and YAML fixture evals
- [`specs/`](specs/README.md) — normative v0 specifications derived from the design: compilation (anchors, callbacks, constants, views, tests, limits), packet format/determinism, CLI, fixture evals
- [`design.md`](design.md) — the v0 product and implementation design
- [`eval-plan.md`](eval-plan.md) — the three-tier evaluation plan: anchor viability, determinism regression, agent A/B
- [`PROJECT_TRACKER.md`](PROJECT_TRACKER.md) — live implementation status and next steps

## 🧭 Why Rails?

Rails apps already contain strong structural signals:

- routes point to controller actions
- controller actions reference services, models, jobs, mailers, and views
- Minitest controller/integration tests and RSpec controller/request specs describe app behavior
- Zeitwerk maps constants to file paths
- Rails conventions reveal useful context without broad semantic search

`ctxpack` uses those conventions before reaching for heavier tools like embeddings, graph databases, or full Ruby call graphs.

## 🎯 v0 goal

v0 stays intentionally small:

```text
controller#action
→ action snippet + applicable before_action callbacks
→ conventional action view templates when present
→ obvious referenced constants from the action, applicable callbacks, and same-file called helpers
→ likely test candidates
→ compact Markdown packet
```

Example anchor mapping:

```text
accounts#upgrade       → app/controllers/accounts_controller.rb
admin/accounts#upgrade → app/controllers/admin/accounts_controller.rb
```

v0 fails clearly when it cannot resolve a direct controller action instead of pretending to understand every Rails edge case.

## 📦 What is a context packet?

A context packet is a small, point-in-time artifact for a specific coding task. It includes:

- the requested task
- the exact Rails anchor
- the git commit it was generated from, so staleness is detectable
- the likely entry point
- files to inspect first
- short snippets from those files
- why each file was included
- tests likely worth running
- assumptions, uncertainty, and follow-up retrieval suggestions

The key property is **provenance**: every file needs a reason.

## 🛤️ CLI

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
```

ctxpack is **pre-release** (not on RubyGems yet). From a Rails app:

```ruby
# Gemfile
gem "ctxpack", github: "fuentesjr/ctxpack"
```

```bash
bundle install
bundle binstubs ctxpack   # optional: bin/ctxpack next to bin/rails
bundle exec ctxpack accounts#upgrade -t "Implement billing upgrade"
```

It works from any subdirectory of the app: like `bin/rails`, it walks upward to
find the application root (`config/application.rb`). Saved paths are printed
relative to the directory where the command was invoked, so they can be opened
or piped directly from there.

By default, `ctxpack` writes a durable Markdown artifact under:

```text
.ctxpack/
```

The directory is meant to be gitignored — committed packets go stale and become misleading context for future agents. When ctxpack creates the default directory, it asks Git whether `.ctxpack/` is already ignored and reminds only when needed. Committing a specific packet (e.g. to link from a PR) is opt-in, with `docs/ctxpack/` as the standard committed location: `--dir docs/ctxpack`.

Long or multiline tasks can come from a file or pipeline without shell quoting:

```bash
ctxpack accounts#upgrade --task-file issue.md
gh issue view 123 --json body --jq .body |
  ctxpack accounts#upgrade --task-file -
```

For a pipeline that does not need a durable artifact, emit raw Markdown only:

```bash
ctxpack accounts#upgrade --task-file issue.md --stdout | your-agent
```

`--stdout` creates nothing and intentionally conflicts with artifact options
such as `--out`, `--dir`, `--name`, `--force`, and `--manifest`.

Markdown packets declare `Format: 2`: task bodies are blockquoted, files are
listed once under `Inspect first`, snippet-bearing files expand under
`Evidence` with source ranges, commands live under `Run`, and packet-specific
uncertainty/omissions are deduplicated under `Follow-ups`. The optional
manifest emits schema version 2 only; consumers should reject versions they do
not support.

Use Rails for route discovery:

```bash
bin/rails routes -g upgrade
bin/rails routes -c AccountsController
```

Use `ctxpack` after choosing the exact Rails anchor.

The compatibility form `ctxpack packet accounts#upgrade [options]` also works.
Common aliases are `-t`/`--task`, `-d`/`--dir`, `-o`/`--out`, and
`-f`/`--force`; `--task-file`, `--stdout`, `--name`, and `--manifest` stay long-only. An exact `--out`
cannot be combined with an explicit `--dir` or `--name`, and it never grants
overwrite permission—pass `--force` when replacing either Markdown or its
sibling manifest. Requires Ruby ≥ 3.4;
the only runtime dependency is [`prism`](https://github.com/ruby/prism).
Run `ctxpack` with no arguments, or use `--help` / `-h` in either command form,
for descriptions, defaults, and examples. `ctxpack --version` and `ctxpack -v`
print the installed version without requiring a Rails app.

## 🧪 Evaluation philosophy

Evaluation is split into two kinds of checks — see [`eval-plan.md`](eval-plan.md).

**CI regression evals** (Tier 1) stay boring and deterministic:

- static Rails-shaped fixtures
- no generated Rails app
- no Rails boot required
- no LLM judge
- every packet bug becomes a small regression case

**Offline hypothesis experiments** (Tiers 0 and 2) test whether packets are actually worth building, with pass/kill thresholds registered before any data is collected:

- Tier 0 measured how often v0 anchor rules resolve on real open-source Rails apps (Mastodon, Discourse, Zammad) — gate passed; see [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md)
- Tier 2 A/Bs the same coding agent on the same task with and without a packet — directional support on Redmine and a multi-app expansion; see [`eval/tier2/RESULTS.md`](eval/tier2/RESULTS.md) and [`eval/tier2-expansion/RESULTS.md`](eval/tier2-expansion/RESULTS.md)

The honest competitor is not keyword search — modern coding agents already follow Rails conventions on their own. Success means the packet beats the agent's own first two minutes of exploration: fewer irrelevant reads, clearer tests, less wandering.

## 🚫 Non-goals for v0

`ctxpack` does not include:

- embeddings or generic RAG
- a custom route browser
- route-string parsing as the primary UX
- Rails engines or mounted apps
- inherited or metaprogrammed action discovery
- full dependency graphs
- Rubydex-backed indexing as a required dependency (probed offline and deferred)
- system/browser spec discovery
- autonomous agent behavior

## 🧰 Implementation

v0 is a small Ruby CLI/gem:

- Ruby for low Rails impedance
- Prism for direct Ruby parsing
- convention-based action view resolution
- convention-based constant-to-file resolution (action body, applicable same-file callbacks, and same-file methods the action calls)
- deterministic Minitest and RSpec controller/request test pointers
- Rubydex only if a later corpus shows a concrete need the convention layer cannot cover

## 🗺️ Project workflow

This repo uses two issue primitives:

- **Mini-epics** — focused outcomes spanning a small batch of tasks
- **Tasks** — one concrete implementation, documentation, or review unit

See the issue templates in [`.github/ISSUE_TEMPLATE`](.github/ISSUE_TEMPLATE).

## 🐣 Current status & next step

v0 and the view/locale companion work are landed and gate-passed; the Tier 0
anchor spike and the Tier 2 agent A/B (with its multi-app expansion) are
complete. For live status and the current next step, see
[`PROJECT_TRACKER.md`](PROJECT_TRACKER.md) ("Resuming a session" and "Status"),
the source of truth over this snapshot.
