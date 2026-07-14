# ctxpack 🧳

**Deterministic context packets for AI coding agents** — task + seeds → provenanced packet.

`ctxpack` asks a small question with a practical answer:

> Can structured evidence (Rails conventions first among them) produce better AI coding context than generic code search?

A **seed** is evidence you already have (a Rails `controller#action` anchor, a test path, open files, …) plus a deterministic expansion recipe. The classic Rails workflow remains first-class:

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
- [`specs/`](specs/README.md) — normative specifications: seeds, compilation (anchors, callbacks, constants, views, tests, limits), packet format/determinism, CLI, fixture evals
- [`design.md`](design.md) — product and implementation design (seed compiler; anchor is one seed kind)
- [`docs/seed-based-interface-proposal.md`](docs/seed-based-interface-proposal.md) — accepted north-star product definition
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

## 🎯 Goal

```text
task + seed(s) → compact, provenanced Markdown packet
```

The **anchor seed** recipe (mature, evaluated) stays small:

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

ctxpack fails clearly when it cannot resolve seed evidence instead of pretending to understand every Rails edge case. Additional seed kinds (`test`, `files`, `error`, `method` without its test-candidate leg) ship behind per-kind viability spikes — see `specs/seeds.md` and `PROJECT_TRACKER.md`.

## 📦 What is a context packet?

A context packet is a small, point-in-time artifact for a specific coding task. It includes:

- the requested task
- the exact Rails anchor
- the Git commit and dirty state when Git is available, so staleness is detectable
- the likely entry point
- files to inspect first
- short, line-addressable snippets from the entry point
- why every file and snippet was included
- tests likely worth running
- specific follow-ups for assumptions, uncertainty, and omitted candidates

The key property is **provenance**: every file needs a reason.

## 🚀 Install and run

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

Requires Ruby ≥ 3.4. The only runtime dependency is
[`prism`](https://github.com/ruby/prism).

The golden path is the anchor followed by options:

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
```

The compatibility form also works:

```bash
ctxpack packet accounts#upgrade --task "Implement billing upgrade"
```

Like `bin/rails`, ctxpack works from any subdirectory by walking upward to find
`config/application.rb`. Saved paths are printed relative to the directory
where the command was invoked. Task-file paths are also invocation-relative;
output destinations are relative to the discovered Rails application root.

Use Rails to choose the exact anchor before generating a packet:

```bash
bin/rails routes -g upgrade
bin/rails routes -c AccountsController
```

### Task input

Use `--task` / `-t` for a short task. Long or multiline tasks can come from a
file or standard input without shell quoting:

```bash
ctxpack accounts#upgrade --task-file issue.md
gh issue view 123 --json body --jq .body |
  ctxpack accounts#upgrade --task-file -
```

`--task` and `--task-file` are mutually exclusive.

### Output modes

By default, `ctxpack` writes a durable Markdown artifact under:

```text
.ctxpack/
```

The directory is meant to be gitignored — committed packets go stale and become misleading context for future agents. When ctxpack creates the default directory, it asks Git whether `.ctxpack/` is already ignored and reminds only when needed. Committing a specific packet (e.g. to link from a PR) is opt-in, with `docs/ctxpack/` as the standard committed location: `--dir docs/ctxpack`.

Choose one output shape:

| Goal | Command |
|---|---|
| Timestamped Markdown in `.ctxpack/` | `ctxpack accounts#upgrade -t "..."` |
| Timestamped Markdown in another directory | `ctxpack accounts#upgrade -t "..." --dir docs/ctxpack` |
| Exact Markdown path | `ctxpack accounts#upgrade -t "..." --out tmp/upgrade.md` |
| Markdown plus a sibling JSON manifest | `ctxpack accounts#upgrade -t "..." --manifest` |
| Raw Markdown on standard output, no files | `ctxpack accounts#upgrade -t "..." --stdout` |
| Manifest v2 JSON on standard output, no files | `ctxpack accounts#upgrade -t "..." --stdout=json` |

For a pipeline that does not need a durable artifact, emit rendered content
directly:

```bash
ctxpack accounts#upgrade --task-file issue.md --stdout | your-agent
ctxpack accounts#upgrade --task-file issue.md --stdout=json | jq .
```

Bare `--stdout` (or `--stdout=markdown`) emits Markdown; `--stdout=json` emits
the exact manifest v2 document. Every stdout form creates nothing and
intentionally conflicts with artifact options such as `--out`, `--dir`,
`--name`, `--force`, and `--manifest`.

An exact `--out` cannot be combined with `--dir` or `--name`. Existing output
is never replaced implicitly: pass `--force` to replace the Markdown artifact
or its sibling manifest.

### CLI reference

| Option | Purpose |
|---|---|
| `-t`, `--task TASK` | Record the task and use it in the derived filename |
| `--task-file PATH` | Read the task from a file, or from standard input with `-` |
| `--name NAME` | Set the timestamped artifact name |
| `-d`, `--dir DIR` | Set the timestamped output directory; default `.ctxpack/` |
| `-o`, `--out PATH` | Write Markdown to an exact path |
| `-f`, `--force` | Permit replacement of existing output |
| `--manifest` | Also write a sibling Format 2 JSON manifest |
| `--stdout[=FORMAT]` | Write Markdown (default) or `json` without creating artifacts |
| `-h`, `--help` | Show descriptions, defaults, and examples |
| `-v`, `--version` | Print the installed version; top-level only |

Running `ctxpack` with no arguments shows self-contained help without requiring
a Rails app. It includes both command forms, pipeline examples, path bases,
output modes, and option conflicts.

## 🧾 Packet Format 2

Markdown packets are optimized for an agent to orient quickly without treating
the packet as an exhaustive reading list. A generated packet has this shape:

````markdown
# ctxpack context packet

## Task

> Implement billing upgrade

## How to use this packet

- Otherwise, start with `app/controllers/accounts_controller.rb` and open the
  other listed files only as the task touches them.

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- Generated from: abc1234 (clean)
- Format: 2
- Scope: routes, superclass/concern callbacks, and locale files are not scanned…

## Inspect first

1. `app/controllers/accounts_controller.rb` — `controller_action`: action and applicable callbacks
2. `app/services/billing/subscriptions.rb` — `referenced_constant`: `Billing::Subscriptions`
3. `test/controllers/accounts_controller_test.rb` — `minitest_candidate`: conventional controller test path

## Evidence

### `app/controllers/accounts_controller.rb`

`controller_action` — action `upgrade` · lines 10–15

```ruby
def upgrade
  # …
end
```

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`

## Follow-ups

- Verify convention-only constant match `Billing::Subscriptions` →
  `app/services/billing/subscriptions.rb` if the task depends on it.
````

Important Format 2 properties:

- every task line is blockquoted, so task-supplied Markdown cannot escape its section
- each path appears once in the flat `Inspect first` map
- only snippet-bearing files expand under `Evidence`, with visible 1-based ranges
- test commands stay under `Run`, with inference labels beside the affected command
- `Follow-ups` contains packet-specific uncertainty and omissions as actions
- the repo stamp reports Git as unavailable when it cannot observe repository state

`--manifest` writes the same packet facts as sibling JSON for tools that should
not parse Markdown; `--stdout=json` streams those facts without creating either
artifact. Version 2 is the only emitted schema:

```json
{
  "version": 2,
  "task": "Implement billing upgrade",
  "anchor": "accounts#upgrade",
  "repo": { "available": true, "commit": "…", "dirty": false },
  "entrypoint": {
    "file": "app/controllers/accounts_controller.rb",
    "controller": "AccountsController",
    "action": "upgrade"
  },
  "files": [
    {
      "path": "app/controllers/accounts_controller.rb",
      "evidence": [
        {
          "reason_code": "controller_action",
          "subject": "upgrade",
          "snippet_ranges": [[10, 15]],
          "truncated": false
        }
      ]
    }
  ],
  "tests": [
    {
      "path": "test/controllers/accounts_controller_test.rb",
      "command": "bin/rails test test/controllers/accounts_controller_test.rb",
      "reason_code": "minitest_candidate",
      "rule": "conventional_controller_test"
    }
  ],
  "follow_ups": [],
  "omitted_candidates": [],
  "no_test_candidates": false
}
```

Manifest consumers should inspect `version` and reject schemas they do not
support. The manifest preserves the raw task even though Markdown rendering
normalizes and blockquotes its lines for safe display.

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
