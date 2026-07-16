# ctxpack 🧳

**Task + seed(s) → deterministic context packet** for AI coding agents.

`ctxpack` is a local **context engineering CLI** for Rails codebases: a
deterministic context compiler. Here, context engineering means deterministically
selecting, ordering, bounding, and explaining evidence around user-supplied
seeds for an agent's task. ctxpack turns evidence you already have into a
compact, provenanced Markdown packet:

```text
task + seed(s) → provenanced, budgeted packet
```

A **seed** is evidence plus a deterministic expansion recipe. You point at a
failing test, a stack frame, a diff, open files, a service method, or a Rails
`controller#action` — ctxpack expands that evidence under fixed rules and
records why every file was included.

## Status

v0 is **implemented and evaluated**. Compiler, Markdown/manifest renderers,
CLI, fixture evals, seed kinds through Phase 5, and the Rails view-convention
layer are shipped and tested. Live pass status:
[`PROJECT_TRACKER.md`](PROJECT_TRACKER.md). Offline experiment results under
[`eval/`](eval/).

Hands-on walkthrough and FAQ:

- [`docs/examples.md`](docs/examples.md) — install, seed recipes, packet anatomy
- [`docs/faq.md`](docs/faq.md) — limits, refusals, when packets help, determinism

## Quick start (seed kinds)

ctxpack is **pre-release** (not on RubyGems). From a Rails app:

```ruby
# Gemfile
gem "ctxpack", github: "fuentesjr/ctxpack"
```

```bash
bundle install
bundle binstubs ctxpack   # optional: bin/ctxpack next to bin/rails
```

Requires Ruby ≥ 3.4. The only runtime dependency is
[`prism`](https://github.com/ruby/prism).

At least one seed is required. Task text is optional but recommended.
Examples below all work against a Rails-shaped tree (see
[`docs/examples.md`](docs/examples.md) for full packets from
`test/fixtures/apps/minitest_basic`):

```bash
# Failing or focused test → production surface + run command
ctxpack --from-test test/controllers/accounts_controller_test.rb \
  -t "Fix failing upgrade controller test"

# Stack / log paste (stdin); only filtered app frames are stored (PII-safe)
cat log/error.txt | ctxpack --from-error - -t "Debug upgrade stack"

# Continue or review from a git range or a patch file
ctxpack --from-diff HEAD~1 -t "Continue from last commit"
ctxpack --from-diff patches/upgrade_accounts.patch -t "Review upgrade patch"

# Open files you already care about (+ budgeted neighbors when they exist)
ctxpack --from-files app/services/billing/subscriptions.rb \
  -t "Inspect billing subscriptions service"

# Non-controller method: resolve the def, same-file constants — no test leg
ctxpack --from-method "Billing::UpgradeService#call" \
  -t "Inspect upgrade service"

# Rails controller#action — the most mature recipe (anchor seed)
ctxpack accounts#upgrade -t "Implement billing upgrade"
# explicit form:
ctxpack --from-anchor accounts#upgrade -t "Implement billing upgrade"
```

The compatibility form also works:

```bash
ctxpack packet accounts#upgrade --task "Implement billing upgrade"
```

Like `bin/rails`, ctxpack walks upward to `config/application.rb`. Saved paths
are relative to the invocation directory; seed paths and output destinations
are relative to the discovered app root.

**Task-only is refused.** Prose without seed evidence fails with a missing-seed
message; turning a bug report into a seed lives in skills, not in the gem.

**Routes / URLs are coaching-only.** Paste a route-shaped string and ctxpack
points you at `bin/rails routes` — it never resolves routes (the route-seed
spike did not ship; see [`eval/seed-spikes/route/RESULTS.md`](eval/seed-spikes/route/RESULTS.md)).

## What seeds exist

| Kind | How you pass it | What the recipe does (not an agent-benefit claim) |
|---|---|---|
| `test` | `--from-test path[:line]` or a `test/`/`spec/` path | Primary test file; infer production surface by path/constant heuristics; suggest a run command |
| `error` | `--from-error paste\|-` | Normalize to application `path:line` frames only; snippet around each frame |
| `diff` | `--from-diff range\|patch` (flag only) | Changed files still present in the tree; optional conventional paired tests for `app/**/*.rb` |
| `files` | `--from-files path…` or an existing non-test path | Named files as primaries; budgeted neighbors when conventions hit |
| `method` | `--from-method Const#method` or positional `Foo::Bar#baz` | Exact constant + instance method; same-file constant expansion; **no test-candidate leg** |
| `anchor` | `controller#action` or `--from-anchor` | Full ANCH recipe: action, callbacks, views, constants, test candidates |

Multi-seed is supported (`--from-test … --from-anchor …`). Catalog and gates:
[`specs/seeds.md`](specs/seeds.md) (SEED-4).

The **anchor** seed is the most mature recipe (Tier 0 viability + Tier 2
exploration studies on controller#action packets). Other kinds shipped behind
per-kind existence/convention viability spikes — they describe deterministic
expansion, not proven agent speedups.

## Why Rails conventions?

Rails apps already carry structural signals (controllers, Zeitwerk paths,
Minitest/RSpec layout, view path conventions). ctxpack uses those before
embeddings, graph DBs, or full call graphs — and fails clearly when a seed
cannot resolve rather than guessing every edge case.

## What is a context packet?

A point-in-time artifact for one coding task:

- the task text (if provided)
- which seed(s) produced the packet (Format 3)
- Git commit + dirty state when Git is available
- ordered files to inspect first, each with a reason code
- short, line-addressable snippets where the recipe produces them
- test commands under `Run` when candidates exist
- follow-ups for uncertainty and omissions

**Provenance is the product:** every file needs a reason.

## Output modes

Default: timestamped Markdown under `.ctxpack/` (meant to be gitignored).

| Goal | Command |
|---|---|
| Timestamped Markdown in `.ctxpack/` | `ctxpack --from-test path -t "..."` |
| Other directory | `… --dir docs/ctxpack` |
| Exact Markdown path | `… --out tmp/packet.md` |
| Markdown + sibling JSON manifest | `… --manifest` |
| Markdown on stdout, no files | `… --stdout` |
| Manifest JSON on stdout | `… --stdout=json` |

```bash
ctxpack --from-test test/controllers/accounts_controller_test.rb \
  --task-file issue.md --stdout | your-agent
```

Bare `--stdout` conflicts with `--out`, `--dir`, `--name`, `--force`, and
`--manifest`. Exact `--out` cannot combine with `--dir` or `--name`. Existing
output is never replaced without `--force`.

### Task input

```bash
ctxpack accounts#upgrade --task-file issue.md
gh issue view 123 --json body --jq .body |
  ctxpack accounts#upgrade --task-file -
```

`--task` and `--task-file` are mutually exclusive. `--from-error -` conflicts
with `--task-file -` (single stdin occupancy).

### CLI reference

| Option | Purpose |
|---|---|
| `-t`, `--task TASK` | Record the task; used in the derived filename |
| `--task-file PATH` | Task from file, or stdin with `-` |
| `--from-anchor ANCHOR` | Explicit anchor seed |
| `--from-test PATH[:LINE]` | Test/spec seed |
| `--from-files PATH…` | One or more file paths |
| `--from-error PASTE\|-` | Stack/log paste (or stdin) |
| `--from-method CONST#METHOD` | Non-controller method seed |
| `--from-diff RANGE\|PATCH` | Git range or patch path (flag only) |
| `--name NAME` | Timestamped artifact name stem |
| `-d`, `--dir DIR` | Timestamped output directory (default `.ctxpack/`) |
| `-o`, `--out PATH` | Exact Markdown path |
| `-f`, `--force` | Permit replacing existing output |
| `--manifest` | Also write sibling Format 3 JSON |
| `--stdout[=FORMAT]` | Markdown (default) or `json`; no artifacts |
| `-h`, `--help` | Help (no Rails app required) |
| `-v`, `--version` | Version (top-level only) |

## Packet Format 3

Markdown is for agents to orient quickly. Shape (abridged; generated from
fixture `test/fixtures/apps/minitest_basic`, anchor `accounts#upgrade`):

````markdown
# ctxpack context packet

## Task

> Implement billing upgrade

## How to use this packet

- Otherwise, start with `app/controllers/accounts_controller.rb` and open the
  other listed files only as the task touches them.

## Seeds

- anchor: `accounts#upgrade`

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- Generated from: … (clean)
- Format: 3
- Scope: routes, superclass/concern callbacks, and locale files are not scanned…

## Inspect first

1. `app/controllers/accounts_controller.rb` — `controller_action`: …
2. `app/services/billing/subscriptions.rb` — `referenced_constant`: …
3. `test/controllers/accounts_controller_test.rb` — `minitest_candidate`: …

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

- Verify convention-only constant match …
````

Non-anchor seeds omit the `## Anchor` block and list seed identity under
`## Seeds` (for example `test: …`, `method: Billing::UpgradeService#call`,
`diff: HEAD~1`). Full worked examples:
[`docs/examples.md`](docs/examples.md).

`--manifest` / `--stdout=json` emit the same facts as JSON (`version: 3`,
`seeds: [...]`, optional `anchor`). Manifest consumers should reject unknown
`version` values.

## Evaluation philosophy

See [`eval-plan.md`](eval-plan.md).

**CI regression (Tier 1):** static fixtures, no Rails boot, no LLM judge.
Every packet bug becomes a YAML case. Tier 1 does **not** prove agent value.

**Offline experiments (Tiers 0 and 2):** pre-registered gates before data.

What we can claim from agent A/B work (directional, offline — not field data):

- On three apps (Campfire, Lobsters, Publify), packets met the pre-registered
  bar — a **≥ 30% median reduction in exploration** (calls to first
  load-bearing file read) **on at least half the tasks per app** — on all
  three apps of the Tier 2 expansion grid. Details:
  [`eval/tier2-expansion/RESULTS.md`](eval/tier2-expansion/RESULTS.md),
  earlier single-app run [`eval/tier2/RESULTS.md`](eval/tier2/RESULTS.md).
- Diff quality was at ceiling in both arms — **no code-quality claim**.
- Those studies used **anchor-seed** packets. Newer seed kinds shipped on
  viability gates (can the recipe resolve real evidence?), not on a second
  agent A/B.

The bar is beating the agent's first minutes of exploration on focused tasks,
not replacing judgment.

## Non-goals for v0

- embeddings / generic RAG
- resolving routes inside the gem (coaching only)
- Rails engines as first-class resolution
- inherited / metaprogrammed action discovery
- full cross-file dependency graphs
- Rubydex as a required dependency (probed offline; deferred)
- system/browser spec discovery
- task-only compilation (skill territory)
- autonomous agent behavior
- network calls or telemetry

## Implementation

- Ruby CLI/gem; Prism only at runtime
- Convention-based resolution (no app boot)
- Deterministic Minitest and RSpec controller/request pointers (where the recipe includes a test leg)
- Spec-driven: [`specs/`](specs/README.md), rationale in [`design.md`](design.md)

## Project workflow

Mini-epics and tasks via [`.github/ISSUE_TEMPLATE`](.github/ISSUE_TEMPLATE).
Resume work from [`PROJECT_TRACKER.md`](PROJECT_TRACKER.md).

Product north star (accepted):
[`docs/seed-based-interface-proposal.md`](docs/seed-based-interface-proposal.md).
