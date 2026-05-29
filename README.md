# ctxpack 🧳

**Deterministic Rails-aware context packets for AI coding agents.**

`ctxpack` asks a small question with a practical answer:

> Can Rails conventions produce better AI coding context than generic code search?

The idea is to turn an exact Rails anchor like `accounts#upgrade` into a compact, evidenced Markdown packet that another coding agent can use as starting context.

```bash
bin/rails routes -g upgrade
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
```

Planned output:

```text
docs/ctxpack/20260527143015_billing_upgrade_accounts_upgrade.md
```

## ✨ Status

`ctxpack` is currently in **v0 design/prototype planning**.

The repo contains:

- [`design.md`](design.md) — the v0 product and implementation design
- [`eval-plan.md`](eval-plan.md) — the lightweight evaluation plan
- [GitHub issues](https://github.com/fuentesjr/ctxpack/issues) — mini-epics and tasks for the first implementation slice

## 🧭 Why Rails?

Rails apps already contain strong structural signals:

- routes point to controller actions
- controller actions reference services, models, jobs, mailers, and views
- Minitest controller/integration tests describe app behavior
- Zeitwerk maps constants to file paths
- Rails conventions reveal useful context without broad semantic search

`ctxpack` tries to use those conventions before reaching for heavier tools like embeddings, graph databases, or full Ruby call graphs.

## 🎯 v0 goal

The first version should stay intentionally small:

```text
controller#action
→ controller action snippet
→ obvious referenced constants
→ likely Minitest candidates
→ compact Markdown packet
```

Example anchor mapping:

```text
accounts#upgrade       → app/controllers/accounts_controller.rb
admin/accounts#upgrade → app/controllers/admin/accounts_controller.rb
```

v0 will fail clearly when it cannot resolve a direct controller action instead of pretending to understand every Rails edge case.

## 📦 What is a context packet?

A context packet is a small, point-in-time artifact for a specific coding task. It should include:

- the requested task
- the exact Rails anchor
- the likely entry point
- files to inspect first
- short snippets from those files
- why each file was included
- tests likely worth running
- assumptions, uncertainty, and follow-up retrieval suggestions

The key property is **provenance**: every file needs a reason.

## 🛤️ Planned v0 CLI

```bash
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
```

By default, `ctxpack` should write a durable Markdown artifact under:

```text
docs/ctxpack/
```

Use Rails for route discovery:

```bash
bin/rails routes -g upgrade
bin/rails routes -c AccountsController
```

Use `ctxpack` after choosing the exact Rails anchor.

## 🧪 Evaluation philosophy

v0 evals should be boring and deterministic:

- static Rails-shaped fixtures
- no generated Rails app
- no Rails boot required
- no LLM judge
- no external corpus
- every packet bug becomes a small regression case

Success means `ctxpack` helps agents start with fewer irrelevant files, clearer tests, and less exploratory wandering.

## 🚫 Non-goals for v0

`ctxpack` should not start with:

- embeddings or generic RAG
- a custom route browser
- route-string parsing as the primary UX
- Rails engines or mounted apps
- inherited or metaprogrammed action discovery
- full dependency graphs
- Rubydex-backed indexing as a required dependency
- RSpec support before the Minitest path proves out
- autonomous agent behavior

## 🧰 Implementation direction

The planned v0 implementation is a small Ruby CLI/gem:

- Ruby for low Rails impedance
- Prism for direct Ruby parsing
- convention-based constant-to-file resolution
- Minitest first
- Rubydex later only if evals show a concrete need

## 🗺️ Project workflow

This repo starts with two issue primitives:

- **Mini-epics** — focused outcomes spanning a small batch of tasks
- **Tasks** — one concrete implementation, documentation, or review unit

See the issue templates in [`.github/ISSUE_TEMPLATE`](.github/ISSUE_TEMPLATE).

## 🐣 Current next step

Build the smallest vertical slice:

1. scaffold the Ruby gem/CLI
2. add the static Rails-shaped fixture
3. implement `ctxpack packet accounts#upgrade`
4. prove deterministic output with fixture evals

See:

- [Mini-epic #1: Build the v0 packet compiler vertical slice](https://github.com/fuentesjr/ctxpack/issues/1)
- [Mini-epic #2: Add v0 fixture evals and deterministic regression checks](https://github.com/fuentesjr/ctxpack/issues/2)
