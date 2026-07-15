# ctxpack

Status: Draft — product definition reconciled 2026-07-13 to the accepted
seed-based interface (`docs/seed-based-interface-proposal.md`). Specs in
`specs/` are normative; this file records rationale and tradeoffs.

`ctxpack` is a **deterministic context compiler for AI coding agents**: given a
task and one or more **seeds** of evidence, it expands a budgeted, provenanced
context packet. Rails conventions remain the research bet and the gold-standard
recipe for the **anchor** seed — not the identity of the tool.

The core question:

> Can structured evidence (Rails conventions first among them) produce better
> AI coding context than generic code search?

## Problem

AI coding agents often struggle less because they lack intelligence and more because they receive poor context.

Generic retrieval can find files that mention the right words, but real work
arrives as red tests, stack pastes, open files, diffs — and, for classic Rails
HTTP work, as `controller#action` anchors. Rails applications also have stronger
signals than keywords:

- routes point to controller actions
- controller actions reference services, models, jobs, mailers, and views
- Minitest controller/integration tests and RSpec controller/request specs describe behavior at the application boundary
- models expose validations, associations, callbacks, and schema constraints
- package systems such as Packwerk define ownership and boundary rules

Most agents do not need the whole app. They need a small, high-signal slice of the app with clear reasons for why each file matters.

## Core idea

```text
task + seed(s) → deterministic, provenanced, budgeted context packet
```

A **seed** is evidence the caller already has, plus a deterministic **recipe**
for what else to pull. An **anchor** (`accounts#upgrade`) is one seed kind: a
Rails-flavored way to name a controller action and expand the conventional
vertical slice (callbacks, views, controller/request tests, referenced
constants). Other P0 kinds: `test`, `files`, and gated `error`. See
`specs/seeds.md`.

Example workflows:

```bash
# Classic Rails endpoint (anchor seed — still the golden path for HTTP work)
bin/rails routes -g upgrade
ctxpack accounts#upgrade -t "Implement billing upgrade"

# Red test (test seed — Phase 2+)
ctxpack --from-test test/services/billing_upgrade_test.rb:42 -t "Fix annual upgrade after 3DS"

# Explicit files (files seed — Phase 2+)
ctxpack --from-files app/services/billing/upgrade.rb -t "…"
```

`ctxpack` should not replace Rails' existing route discovery tools. Rails already
answers "what routes exist?" The **anchor seed** starts after the developer has
chosen a Rails-native anchor and answers:

> Given this controller action, what compact, evidenced Rails context should an agent receive?

The **product** answers the broader question:

> Given this task and this evidence I already have, what compact, evidenced
> context should an agent receive?

Instead of broad semantic search for `billing`, `upgrade`, and `account`, the
anchor recipe follows Rails structure:

```text
AccountsController#upgrade
→ controller action snippet
→ conventional view template, when one exists on disk
→ referenced constants/services/models/jobs
→ likely test candidates
→ package/boundary notes when cheaply detectable
```

Other recipes start thinner and deepen with evidence (per-kind viability
spikes). Spike scripts share plumbing, not scoring: each spike's scoring is
frozen in its own pre-registration, which also records why no existing eval
runner covered the question (SEED-5; inventory in `eval/README.md`) — the
guard against accreting ad-hoc eval frameworks.

The output is not an answer and not an autonomous agent. It is a prepared context artifact that another coding agent can use more effectively.

## Settled direction (seed compiler)

The compiler is intentionally small and deterministic:

```text
task + seed(s)
  → resolve each seed → candidates
  → merge + budget → focus set
  → compact Markdown packet (+ optional JSON manifest)
```

The **anchor seed recipe** remains the mature vertical slice:

```text
controller#action → action snippet + applicable before_action callbacks → conventional view template(s) → referenced constants → nearby test candidate → compact markdown packet
```

Implementation is a small Ruby CLI/gem. Ruby is the default because ctxpack is
Rails-native for the anchor recipe and can lean on Prism, Rails naming
conventions, and familiar gem/bundle workflows. Go's single-binary distribution
may be valuable later, but it should wait until the packet algorithm proves useful.

Application root discovery is unchanged: walk upward from the current directory
to the nearest ancestor containing `config/application.rb`, matching `bin/rails`
and Rake ergonomics. If no ancestor is a Rails application root, fail clearly.

### Anchor seed (unchanged semantics)

Accepted anchor format:

```text
accounts#upgrade
admin/accounts#upgrade
```

Mapping rules:

```text
accounts#upgrade       → app/controllers/accounts_controller.rb
admin/accounts#upgrade → app/controllers/admin/accounts_controller.rb
```

Anchor tokens are snake_case as printed by `bin/rails routes`, with one tolerance learned from the Tier 0 spike: real route tables contain actions like `merged?` and `_show_secure_deprecated`, so the action token admits a trailing `?`/`!` and a leading `_`.

The controller class is identified *within* the conventionally resolved file, not by camelizing the anchor: the spike showed the dominant failure mode was acronym-styled class names (`AITextTools`, `ActivityPub`) whose inflections live in per-app initializers that v0 never loads. Since the file was already found by exact convention, ctxpack accepts the class defined there whose name matches the anchor path underscore-insensitively, instead of guessing the name and missing.

The action must be directly defined as `def upgrade` in that controller class. If the controller file, a matching controller class, or the direct action method cannot be found, fail clearly and explain the unsupported case instead of guessing.

Out of scope for anchor resolution:

- inherited controller actions
- controller concerns that define actions
- Rails engines and mounted apps
- custom route-string parsing
- route constraints
- metaprogrammed actions
- booting Rails to inspect routes

### What stays from the pre-seed design (do not throw away)

- Deterministic compile; prism-only runtime dependency policy
- Provenance / reason codes / uncertainty codes as registries
- Budgets (limits as constants until evidence says otherwise)
- No embeddings/RAG required for core
- No Rails boot for static recipes (anchor, files, method, test path rules, diff)
- Tiered eval mindset: fixture cases per seed kind; real-app spikes where needed
- OptionParser CLI, injectable streams, composable stdout

### Primary commands

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
# Phase 2+ equivalents:
ctxpack --from-anchor accounts#upgrade -t "…"
ctxpack --from-test test/controllers/accounts_controller_test.rb:10 -t "…"
ctxpack --from-files app/models/account.rb -t "…"
# Phase 5a:
ctxpack --from-method Billing::Subscriptions#upgrade! -t "…"
ctxpack Billing::Subscriptions#upgrade! -t "…"   # positional sugar (SEED-10 rule 4)
# Phase 5b:
ctxpack --from-diff main...HEAD -t "…"
ctxpack --from-diff path/to/change.patch -t "…"  # explicit flag only (not positional)
```

The original `ctxpack packet accounts#upgrade --task "…"` form remains a
compatibility path. Positional sugar classifies argv by SEED-10 (specs/seeds.md);
`*Controller#action` stays suggest-only rewrite to the underscore anchor, never
the method seed. Method-shaped tokens (`Billing::Upgrade#call`) dispatch to the
method seed (Phase 5a): exact CONST-2b path resolution with no segment trimming,
instance-def FQN match, same-file callee BFS + constant scan under existing
budgets, **no test-candidate leg** (spike test-leg precision failed — see
`eval/seed-spikes/method/RESULTS.md` and SEED-25). Diff seeds (Phase 5b) take a
git range or patch path via `--from-diff` only (existing `.patch` paths stay
files seeds under SEED-10 rule 6): changed files that exist in the working tree
as primaries, def-anchored or windowed snippets for `.rb` hunks, and
**paired-test mirror candidates** only (no basename token matching — 5a lesson;
spike agreement 0.810 PASS — see `eval/seed-spikes/diff/RESULTS.md` and
SEED-26).

Long task descriptions can come from `--task-file PATH`, or from injected
stdin with `--task-file -`; this keeps issue bodies and agent pipelines out of
shell quoting while preserving the same packet contract and filename
derivation. `--stdout` is the complementary pipeline mode: it emits only the
fully rendered Markdown by default, while `--stdout=json` emits the same
manifest facts available from the public manifest renderer. Neither form
creates an artifact. Artifact options conflict with that mode instead of
acquiring hidden precedence.

By default, the command should save a migration-style context artifact and print its path:

```text
.ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md
```

The anchor is an exact Rails controller action, using the same shape shown by `bin/rails routes`.

Possible later extension, only if it stays simple:

```bash
ctxpack packet --helper upgrade_account --task "Implement billing upgrade"
```

But route helper support is not required for v0. The first version should avoid route-string input such as `POST /accounts/:id/upgrade` as the happy path because it creates shell quoting issues and invites route typos. The CLI can still recognize common Rails-shaped mistakes syntactically and point back to `bin/rails routes`; guidance is not resolution and never boots or browses the app.

## What ctxpack should not duplicate

Do not build a custom route browser in v0.

Use Rails for route discovery:

```bash
bin/rails routes -g upgrade
bin/rails routes -c AccountsController
```

Then use `ctxpack` for context compilation:

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
```

This writes a durable point-in-time context artifact under `.ctxpack/` and prints the saved path.

This keeps the responsibility split clear:

```text
Rails:
  discover routes, helpers, and controller actions

ctxpack:
  compile a small, evidenced context packet from a known Rails anchor
```

## What is a context packet?

A context packet is a small, explicit bundle of task-relevant information:

- the task being worked on
- the exact Rails anchor
- the likely entry point
- the files to inspect first
- short code snippets from those files
- why each file was included
- tests likely worth running
- assumptions and uncertainty
- optional follow-up retrieval if more context is needed

The important property is not just inclusion. It is **provenance**: every file should have a reason.

## Determinism

`ctxpack` should make packet construction deterministic by default:

```text
same repo state + same packet inputs = same normalized packet content
```

That means:

- deterministic file ordering
- stable snippet ranges
- templated reason codes and reason text
- no model-generated summaries
- no fuzzy autonomous retrieval
- no hidden agent judgment in packet construction
- no generated timestamps inside packet content

The default artifact filename is the exception: it should use a Rails-migration-style timestamp for chronological ordering and collision resistance. The path is a storage concern, not part of the packet's semantic content. Evals can use `--out` or normalize the output path when checking determinism.

One repo-state stamp is allowed inside packet content: the git commit SHA at generation time, with a `dirty` marker when the working tree has uncommitted changes. Unlike a timestamp, the SHA is a function of repo state, so it preserves `same repo state + same inputs = same content` — and it makes staleness mechanically detectable whenever an old packet is read later. The dirty marker is honest rather than precise: the SHA cannot capture uncommitted changes, so a packet built from a dirty tree must say so.

Stamp resolution uses normal git discovery from the application root (`git -C <app_root> rev-parse HEAD`), so an app living in a monorepo subdirectory stamps the enclosing repository's SHA. When Git state is unavailable — whether outside a work tree or because the Git executable is missing — the stamp is the fixed honest string `unknown (Git state unavailable)`. One consequence for Tier 1 evals: the fixture trees live inside ctxpack's own repository, so their packets stamp whatever ctxpack's current SHA happens to be. Double-run determinism checks are unaffected (same repo state, same stamp), but golden-content assertions must normalize the stamp line, exactly as they normalize output paths.

Skills or sub-agents may consume the packet later, but they should not be responsible for constructing the canonical packet.

## Why Rails is a good target

Rails has conventions that make shallow, exact retrieval unusually powerful:

- HTTP routes map to controller actions.
- Controller actions often reveal orchestration.
- Zeitwerk maps constants to file paths.
- Request specs often map to user-visible behavior.
- Active Job, Action Mailer, and views leave recognizable call sites.
- Active Record models expose useful domain constraints through familiar DSLs.
- Packwerk, when present, adds package ownership and boundary information.

This means a useful first version does not need embeddings, a graph database, or a full Ruby call graph.

## Parsing and static analysis strategy

Use Prism for v0 parsing.

v0 only needs to:

- find the direct controller action method
- collect `before_action` declarations in the same controller class and keep the ones that apply to the action (literal `only:`/`except:` filters only — arrays or single symbol/string literals; dynamic filter arguments become a packet-specific uncertainty fact and Follow-up instead of a guess)
- extract stable snippets for the action and for applicable callback methods defined in the same file
- collect obvious constants referenced inside the action body, applicable callback bodies, and same-file methods transitively called from the action through literal implicit-`self` or explicit-`self` method calls
- map those constants to likely files using Rails/Zeitwerk naming conventions

The intra-file call expansion is deliberately narrow: it follows only direct
methods in the same controller class, only from the action body, and only via
literal calls with no receiver or an explicit `self` receiver. It does not
infer receiver types, cross file boundaries, dynamic dispatch (`send`,
`public_send`, aliases), or constants in method parameter defaults. Callback
calls are not expanded; callbacks contribute their own constants, and a
callback that is also called by the action is traversed only because the
action reaches it.

Callbacks matter because in real controllers most of an action's preconditions — auth, scoping, record loading — live in `before_action`, not the action body. A packet that shows `def upgrade` using `@account` without showing `set_account` omits the actual entry behavior. Callback methods not defined in the controller file are out of v0 scope (consistent with anchor resolution): when an in-file declaration names such a method, the packet lists that name as unresolved rather than pretending it doesn't exist; declarations made entirely in superclasses or concerns are invisible to v0 and are covered by the standing `Scope:` line.

Rubydex is promising, but it should not be a required v0 dependency. It is a semantic indexer/graph and earns its keep later if deterministic evals show that convention-based constant resolution misses important context.

Structure the implementation so a future resolver can be swapped in:

```text
Parser: Prism
Default resolver: convention/path-based constant resolver
Future resolver: Rubydex-backed semantic resolver
```

## View resolution

For view-primary feature tasks — a form field, changed rendered UI — the
load-bearing file is the view, not the controller. None of the resolution
above reaches it: the constant resolver only walks Ruby via Zeitwerk
convention. The Tier 3 offline probe
([`eval/tier3-rubydex/RESULTS.md`](eval/tier3-rubydex/RESULTS.md)) measured
this directly: adding the action's conventional view template(s) to the
packet lifted feature-task recall from 0.685 to 0.815 (control arm,
production-only diffs) for a precision cost of 0.097 — a favorable 1.33
recall-gained-per-precision-lost ratio, and dependency-free. It also targeted
the only two treatment-arm diff-quality dings measured across the whole
72-session expansion grid (publify's `setup#index`, sessions P06/P20): a
backend-only fix that omitted the setup form the packet never pointed at.

v0 includes the action's conventional view template(s) — files on disk
matching `app/views/<controller_path>/<action>.*`, every existing format
variant, sorted lexicographically — existence-gated: no matching template is
not an error, since many actions render nothing (redirect, `head`, an
implicit JSON render). Included views are list-only (no ERB snippet; ERB is
not Ruby and is not parsed) and carry the `view_candidate` reason code.

v0 deliberately does not confirm the conventional view against the action's
actual render target: it does not parse the action body for `render` /
`redirect_to` / `head`. That would be render-target inference across possible
execution paths, outside the shallow scan ctxpack performs, so a view entry
can be a false positive when the action renders something else. This is
disclosed as uncertainty, not hidden, and it does not change the "no Rubydex
dependency" non-goal below: the probe's entire measured Rubydex recall gain
was one file, reached via a literal in-file helper constant that the narrow
same-file action call graph can reach without a native dependency, and the
view layer captures the bulk of the remaining gap on its own — see
`RESULTS.md`'s verdict for the full four-column comparison.

## v0 packet contents

A v0 packet should include:

- the requested task
- the exact `controller#action` anchor
- the git commit SHA the packet was generated from, with a dirty marker when the working tree has uncommitted changes
- the controller/action file and snippet
- `before_action` callbacks that apply to the action, with snippets when defined in the same file
- obvious constants referenced by the action body, applicable callbacks, and same-file methods transitively called from the action
- files resolved from those constants when Zeitwerk naming makes that cheap and exact
- the action's conventional view template(s), when they exist on disk (list-only, no snippet)
- likely Minitest or RSpec test candidates
- runnable test commands
- one standing Scope statement for v0 boundaries
- specific imperative Follow-ups only when packet facts need verification or
  a limit omitted something

Callback snippets are additional snippet ranges on the controller file, so they share the existing per-file snippet limit rather than needing a new one.

The packet should be Markdown because humans and agents are the primary readers.

## Test candidate rules

Likely test candidates must be as rule-bound as controller resolution, or the determinism claim is hollow for exactly the fuzziest part of the packet. Controller test/spec paths are real Rails conventions; integration/request filenames are not — they are guesses, and the rules for guessing must be explicit.

v0 first selects one test family. RSpec is selected when the app has `spec/`
plus `spec/rails_helper.rb` or an `rspec-rails` dependency; otherwise Minitest
is selected. The selected family then applies two rules in order:

1. Conventional controller test/spec: `test/controllers/<controller_path>_controller_test.rb` for Minitest, or `spec/controllers/<controller_path>_controller_spec.rb` for RSpec, included only if the file exists.
2. Boundary-test path matches: Minitest checks `test/integration/*_test.rb`; RSpec checks `spec/requests/*_spec.rb`. The basename must contain the controller token and the action tokens as underscore-delimited tokens. Multiple matches are sorted lexicographically. `spec/system/` is intentionally out of v0 scope.

The combined list is truncated at the max-test-files limit, with truncation
reported as an imperative Follow-up. Minitest rules use `minitest_candidate`;
RSpec rules use `rspec_candidate`; the `Inspect first` inventory phrase states
which rule matched. Rule 2 matches always carry the
`test_inferred_by_path` uncertainty fact, shown beside the command and as a
specific Follow-up.

No test-content matching in v0 — path rules only, no grepping test bodies for routes or controller names. If the selected family matches nothing, the packet says so rather than guessing across another framework.

## v0 packet limits

Small by construction requires explicit guardrails.

Initial internal v0 limits:

```text
max total files: 8
max constant files: 4
max view files: 2
max test files: 2
max snippet lines per file: 120
```

These should start as internal constants, not public CLI flags. Expose flags later only if fixture evals or real usage show the defaults are wrong.

The designated real-usage evidence is packet-vs-diff coverage: compare the packet's file list against the diff of the completed task. Files the task touched but the packet omitted are recall misses; packet files the task never touched are precision misses. This is the post-v0 north-star metric for the limits (and for the reason-code heuristics generally); no telemetry gets built until real usage exists to measure.

If a limit is hit, the packet should not silently omit context. It should
include a specific imperative Follow-up whose numeric value comes from the
compiler limit registry, for example:

```markdown
## Follow-ups

- Inspect omitted constant `SyncBillingAccountJob`; the 4-constant limit was reached.
```

The point of the limits is not to claim completeness. It is to prevent context dumping and preserve deterministic, reviewable packet size.

## Artifact location and naming

Context packets should be saved as named artifacts instead of written to a generic `context.md` file.

They are not disposable scratch files, but they are also not evergreen documentation that should be manually maintained forever. Treat them as durable point-in-time task records: reviewable, linkable from PRs/issues when deliberately committed, and superseded by newer packets when the code or task context changes.

Default output directory:

```text
.ctxpack/
```

The default is a hidden directory that projects should gitignore, not `docs/`:

- Committed packets rot the moment the code changes, and stale snippets presented as authoritative context are exactly the failure mode ctxpack exists to prevent. A future agent grepping the repo would find an old packet and trust its outdated snippets.
- Search tools like `rg` skip hidden directories by default, so even local packets stay out of routine code searches.
- Committing a packet should be a deliberate act, not a side effect. When a packet is worth committing — to link from a PR or issue — `docs/ctxpack/` is the default committed location: `--dir docs/ctxpack`. Arbitrary locations via `--dir`/`--out` remain possible, but one canonical committed path keeps shared packets discoverable and easy to sweep for staleness against their embedded commit SHA.

When an invocation creates the implicit/default `.ctxpack/`, ctxpack should
ask Git itself whether that path is ignored and remind on stderr only when Git
reports it unignored. This honors repository, info/exclude, and configured
global rules without reimplementing Git semantics; non-Git and operational
failures stay quiet. Explicit destinations supplied with `--dir` or `--out`
never remind; `--name` and `--manifest` still use the implicit/default
directory and remain eligible. No interactive prompt, no automatic ignore-file
edits. Saved-artifact stdout remains a composable, line-oriented result: one
invocation-relative path per line.
`--stdout` is deliberately different: exactly rendered Markdown by default or
manifest JSON with `--stdout=json`, with no path or reminder.

Default filename shape:

```text
YYYYMMDDHHMMSS_<context_name>.md
```

The timestamp should match the familiar Rails migration style: chronological, sortable, and collision-resistant. The name should describe the feature, bug, or context, using snake case.

Example without an explicit `--name`:

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
```

writes:

```text
.ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md
```

Rules:

- derive a useful name by default; reserve explicit `--name` for callers that
  need a stable, curated artifact stem
- use snake_case names to resemble Rails migration filenames
- include enough context in the name to avoid vague artifacts like `upgrade.md`
- when a derived name exceeds 80 characters, truncate the task prefix before the anchor; if the anchor itself exceeds the cap, retain its trailing 80 characters so the action remains visible
- include a timestamp in the default filename for ordering and collision resistance
- do not include generated timestamps inside packet content
- do not silently overwrite an existing Markdown artifact or manifest; every
  overwrite requires `--force`, including an explicit `--out`
- allow `--dir` or `--out` for callers that want a different location, but
  reject `--out` with explicitly supplied `--dir` or `--name` instead of hiding
  precedence rules; `--out --force` remains valid
- reject `--out` + `--manifest` before compilation when the Markdown and JSON paths would collide, including extension-case-only differences
- accept multiline task input through `--task-file PATH` / `--task-file -`,
  conflicting explicitly with `--task` before either input is read
- make `--stdout` a mutation-free rendered-content mode: Markdown by default,
  MAN-2 JSON for `--stdout=json`, and reject every explicit artifact option
  before discovery, reads, or compilation
- treat committing a packet as opt-in, never the default; when opting in, `docs/ctxpack/` is the standard committed location (`--dir docs/ctxpack`)

No arguments and `--help` / `-h` in either command form or position should
print self-sufficient help (including both forms, defaults, pipeline examples,
path bases, output modes, and conflicts) without a Rails application root and
return through the CLI's injected streams. Sole
top-level `--version` / `-v` should behave the same way. Common options have
conservative aliases (`-t`, `-d`, `-o`, `-f`); `--task-file`, `--stdout`,
`--name`, and `--manifest` stay
long-only so the short-option surface remains memorable. Compilation failures
should render the supplied controller/action in the Rails-native route hint
only when both tokens are safe to paste into a shell; otherwise the hint uses
generic placeholders. Filesystem failures should be concise `ctxpack:` errors,
not Ruby backtraces, and user-facing paths should be invocation-relative. The
common typo `ctxpack packets` may suggest the compatibility command, while
unrelated unknown commands should fail without speculative suggestions. Before
compilation or writes, every existing destination should be verified as a
regular file even under `--force`, so a directory-valued sibling manifest
cannot leave behind a partial Markdown artifact.
Common route helpers, controller-class references, HTTP route strings, and a
final slash used in place of `#` receive tailored Rails-native diagnostics
before root discovery. The recognizers stay deliberately narrow and
shell-safe so unrelated commands and hostile-looking input retain generic
handling.

## Machine-readable manifest

Markdown remains the primary artifact. The optional structured manifest is its
public machine-fact sibling: evals and other consumers can inspect the same
packet without parsing headings or templated prose.

For pipelines that do not need artifacts, `--stdout=json` emits that same
manifest directly and exclusively to stdout.

Generate the manifest from the same internal packet object and save it next to
the Markdown packet:

```bash
ctxpack accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade" \
  --manifest
```

writes:

```text
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.md
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.json
```

The manifest is a lossless machine-fact representation of the same packet
object, not rendered Markdown prose. It exists so evals and other consumers
can inspect stable fields without parsing headings or templated sentences.

Example manifest fields:

```json
{
  "version": 2,
  "task": "Implement billing upgrade",
  "anchor": "accounts#upgrade",
  "repo": {
    "available": true,
    "commit": "0f4b21c9e8d3a17650b2c44aa91d7e5f8c03d6ab",
    "dirty": false
  },
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
          "snippet_ranges": [[24, 39]],
          "truncated": false
        }
      ]
    }
  ],
  "tests": [
    {
      "path": "test/integration/accounts_upgrade_test.rb",
      "command": "bin/rails test test/integration/accounts_upgrade_test.rb",
      "reason_code": "minitest_candidate",
      "rule": "integration_path_match"
    }
  ],
  "follow_ups": [
    {
      "code": "test_inferred_by_path",
      "subject": "test/integration/accounts_upgrade_test.rb"
    }
  ],
  "omitted_candidates": [],
  "no_test_candidates": false
}
```

Manifest schema versions are breaking versions. v0 emits only the current
schema; consumers inspect `version` and reject versions they do not support.
Version 2 replaces version 1 without a compatibility flag because there are
no external consumers to preserve yet. Omitted-candidate facts carry a
semantic `limit_key` naming `Compiler::LIMITS`; neither the renderer nor a
machine consumer needs to interpret category or reason prose to identify the
limit that was reached.

## Simple v0 evals

Evals should be part of v0, but they should stay boring and deterministic.

These fixture evals are Tier 1 of [`eval-plan.md`](eval-plan.md): regression checks that the tool agrees with itself. They are circular by design — the fixtures are authored to match ctxpack's own assumptions — so they are never evidence that packets are useful. Usefulness is tested separately by the Tier 0 anchor viability spike and the Tier 2 agent A/B in the eval plan.

Use static Rails-shaped fixture trees for v0 rather than generated Rails apps. The first fixture can be intentionally small:

```text
test/fixtures/apps/minitest_basic/
  app/controllers/accounts_controller.rb
  app/services/billing/subscriptions.rb
  app/jobs/sync_billing_account_job.rb
  test/controllers/accounts_controller_test.rb
  test/integration/accounts_upgrade_test.rb
```

The fixture does not need to boot Rails. It only needs enough Rails-shaped structure to test deterministic packet construction.

A fixture case can be a small YAML file:

```yaml
name: accounts_upgrade
command:
  anchor: accounts#upgrade
  task: Implement billing upgrade

expect:
  entrypoint:
    file: app/controllers/accounts_controller.rb
    action: upgrade

  include:
    - path: app/controllers/accounts_controller.rb
      reason_code: controller_action
    - path: test/integration/accounts_upgrade_test.rb
      reason_code: minitest_candidate

  exclude:
    - app/controllers/admin/accounts_controller.rb

  tests:
    - bin/rails test test/integration/accounts_upgrade_test.rb

  max_files: 8
```

The eval runner should check:

- correct entry point
- required files included
- forbidden files excluded
- expected reason codes present
- expected test commands suggested
- packet stays under file/snippet limits
- running the same command twice with fixed `--out ... --force`, or with output paths normalized, produces the same content hash

Do not use an LLM judge in v0. Every packet bug should become a small deterministic eval case.

The runner itself should be re-runnable at any commit with no one-shot setup — re-runnability is a design property that is hard to retrofit. The Tier 2 harness follows the same principle, so usefulness can be re-measured at release boundaries rather than tested once ([`eval-plan.md`](eval-plan.md)).

## Non-goals for v0

- Task-only compilation inside the gem (prose → seed is skill-only)
- Interactive seed pickers; LLM-inside-gem seed choice
- Silent dual-emission of packet format versions (v3 replaces v2 at Phase 2)

Do not start with:

- embeddings
- generic RAG
- custom `ctxpack routes` command
- interactive route pickers
- freeform route-string parsing as the primary UX
- generic root-level outputs such as `context.md`
- treating packets as disposable `tmp/` scratch files by default
- full dependency graphs
- autonomous agent behavior
- production trace integrations
- PR history mining
- profiler ingestion
- full Packwerk enforcement
- perfect static analysis of Ruby
- Go implementation or single-binary packaging before packet usefulness is proven
- Rubydex-backed global indexing as a required dependency
- system/browser spec discovery
- inherited or metaprogrammed controller action resolution
- Rails engines and mounted app resolution

The goal is to test whether Rails-aware structural context beats generic retrieval for common coding-agent tasks.

## Design principles

1. **Artifact first**  
   Design the packet the agent receives before designing the index.

2. **Exact Rails anchors beat fuzzy recall**  
   A controller action, route helper, test file, or stack frame is often more valuable than many keyword matches. v0 should start with exact `controller#action` anchors.

3. **Do not duplicate Rails**  
   Use `bin/rails routes` for route discovery. `ctxpack` should compile context, not become a parallel Rails route UI.

4. **Small by construction**  
   The packet should fit comfortably inside an agent prompt. If context is uncertain, suggest follow-up retrieval instead of dumping files.

5. **Every file needs a reason**  
   `Contains billing` is not enough. `Controller action`, `minitest_candidate`, `rspec_candidate`, or `constant referenced by action` is better.

6. **No false precision**  
   Static Ruby analysis cannot reliably produce a complete call graph for a real Rails app. The tool should present shallow evidence, not pretend to know the entire execution path.

7. **Uncertainty should be explicit**  
   Standing boundaries belong in one `Scope:` line; packet-specific guesses
   become deduplicated imperative Follow-ups.

## Example packet shape

````markdown
# ctxpack context packet

## Task

> Implement billing upgrade.

## How to use this packet

- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list.
- Otherwise, start with `app/controllers/accounts_controller.rb` and open the other listed files only as the task touches them.

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: 0f4b21c (clean)
- Format: 2
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack v0; use `bin/rails routes -g upgrade` for endpoints, and check `config/locales/` if the task touches user-facing copy.

## Inspect first

1. `app/controllers/accounts_controller.rb` — `controller_action`: action and applicable callbacks
2. `test/integration/accounts_upgrade_test.rb` — `minitest_candidate`: path-inferred; verify coverage

## Evidence

### `app/controllers/accounts_controller.rb`

`controller_action` — action `upgrade` · lines 24–32

```ruby
def upgrade
  Billing::Subscriptions.upgrade_account(
    account: @account,
    plan: params.require(:plan)
  )

  SyncBillingAccountJob.perform_later(@account.id)
  render json: { status: "upgraded" }
end
```

`before_action_callback` — callback `set_account` applies · lines 40–42

```ruby
def set_account
  @account = current_user.accounts.find(params[:id])
end
```

## Run

- `bin/rails test test/integration/accounts_upgrade_test.rb` — path-inferred; verify coverage

## Follow-ups

- Inspect `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred candidate covers the task.
````

## Relationship to skills and sub-agents

A skill or sub-agent can be useful as a wrapper around `ctxpack`, for example:

1. run `ctxpack accounts#upgrade`
2. read the generated packet
3. use the packet as the starting context for implementation or review

But the skill or sub-agent should not be the canonical packet builder. Keeping packet construction in a deterministic CLI makes the system easier to measure, diff, and improve.

## Open questions

- Is `controller#action` enough for v0, or is exact route-helper support needed early?
- What is the smallest packet that still changes agent behavior?
- Should v0 include snippets only, or also deterministic file-level metadata?
- How often do Rails conventions fail because of custom routing, metaprogramming, or unconventional service layout? (Measured directly by the Tier 0 spike in [`eval-plan.md`](eval-plan.md), with a failure taxonomy that says which non-goal to promote first.)
- Do the initial limits — 8 total files, 4 constant files, 2 view files, 2 test files, and 120 snippet lines per file — keep packets small without hiding essential context?
- When, if ever, do fixture evals justify adding a Rubydex-backed resolver?

## Next experiments

First, before any packet rendering exists, run the Tier 0 anchor viability spike from [`eval-plan.md`](eval-plan.md): attempt v0 anchor resolution against the route tables of 2–3 real open-source Rails apps and classify every failure. The strictest v0 constraint — a literal `def <action>` in the conventionally-named controller file — is also the most likely to fail on real apps, and it is cheaper to learn that in an afternoon of Prism scripting than after building the renderer.

If the Tier 0 gate passes, build the smallest possible `ctxpack
<controller#action>` prototype against one static Rails-shaped fixture tree.

Success would mean the Rails-aware packet:

- includes fewer irrelevant files
- surfaces the true entry point faster
- gives the coding agent better tests to run
- reduces unnecessary exploration
- makes uncertainty clearer to the human operator
- produces stable output that can be regression-tested with simple eval cases

Whether the first four hold is judged against a real coding agent's own exploration — not keyword search — via the Tier 2 A/B in the eval plan.
