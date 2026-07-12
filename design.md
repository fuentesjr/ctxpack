# ctxpack

Status: Draft v0 proposal.

`ctxpack` is a deterministic Rails-aware context packet compiler for AI coding agents.

The core question:

> Can Rails conventions produce better AI coding context than generic code search?

## Problem

AI coding agents often struggle less because they lack intelligence and more because they receive poor context.

Generic retrieval can find files that mention the right words, but Rails applications have stronger signals than keywords:

- routes point to controller actions
- controller actions reference services, models, jobs, mailers, and views
- Minitest controller/integration tests and RSpec controller/request specs describe behavior at the application boundary
- models expose validations, associations, callbacks, and schema constraints
- package systems such as Packwerk define ownership and boundary rules

Most agents do not need the whole app. They need a small, high-signal slice of the app with clear reasons for why each file matters.

## Core idea

Build a CLI that turns an exact Rails anchor into a compact **context packet** for an AI coding agent.

Example workflow:

```bash
bin/rails routes -g upgrade
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
```

`ctxpack` should not replace Rails' existing route discovery tools. Rails already answers "what routes exist?" `ctxpack` starts after the developer has chosen a Rails-native anchor and answers:

> Given this controller action, what compact, evidenced Rails context should an agent receive?

Instead of doing broad semantic search for `billing`, `upgrade`, and `account`, `ctxpack` follows Rails structure:

```text
AccountsController#upgrade
→ controller action snippet
→ conventional view template, when one exists on disk
→ referenced constants/services/models/jobs
→ likely test candidates
→ package/boundary notes when cheaply detectable
```

The output is not an answer and not an autonomous agent. It is a prepared context artifact that another coding agent can use more effectively.

## Settled v0 direction

The first version should be intentionally small and deterministic:

```text
controller#action → action snippet + applicable before_action callbacks → conventional view template(s) → referenced constants → nearby test candidate → compact markdown packet
```

v0 should be built as a small Ruby CLI/gem. Ruby is the default implementation choice because `ctxpack` is Rails-native: it can lean on Ruby parsing, Rails naming conventions, and familiar gem/bundle workflows without reimplementing Ruby semantics in another language. Go's single-binary distribution may be valuable later, but it should wait until the packet algorithm proves useful.

v0 discovers the Rails application root the way Rails tooling does: it walks
upward from the current directory to the nearest ancestor containing
`config/application.rb`, so it works from anywhere inside the app — matching
`bin/rails` and Rake ergonomics. If no ancestor is a Rails application root,
it fails clearly.

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

The action must be directly defined as `def upgrade` in that controller class. If the controller file, a matching controller class, or the direct action method cannot be found, v0 should fail clearly and explain the unsupported case instead of guessing.

Out of scope for v0 anchor resolution:

- inherited controller actions
- controller concerns that define actions
- Rails engines and mounted apps
- custom route-string parsing
- route constraints
- metaprogrammed actions
- booting Rails to inspect routes

Primary command:

```bash
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
```

By default, the command should save a migration-style context artifact and print its path:

```text
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.md
```

The anchor is an exact Rails controller action, using the same shape shown by `bin/rails routes`.

Possible later extension, only if it stays simple:

```bash
ctxpack packet --helper upgrade_account --task "Implement billing upgrade"
```

But route helper support is not required for v0. The first version should avoid route-string input such as `POST /accounts/:id/upgrade` as the happy path because it creates shell quoting issues and invites route typos.

## What ctxpack should not duplicate

Do not build a custom route browser in v0.

Use Rails for route discovery:

```bash
bin/rails routes -g upgrade
bin/rails routes -c AccountsController
```

Then use `ctxpack` for context compilation:

```bash
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
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

Stamp resolution uses normal git discovery from the application root (`git -C <app_root> rev-parse HEAD`), so an app living in a monorepo subdirectory stamps the enclosing repository's SHA. When the application root is not inside any git work tree, the stamp is the fixed string `unknown (not a git repository)` — still deterministic. One consequence for Tier 1 evals: the fixture trees live inside ctxpack's own repository, so their packets stamp whatever ctxpack's current SHA happens to be. Double-run determinism checks are unaffected (same repo state, same stamp), but golden-content assertions must normalize the stamp line, exactly as they normalize output paths.

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
- collect `before_action` declarations in the same controller class and keep the ones that apply to the action (literal `only:`/`except:` filters only — arrays or single symbol/string literals; dynamic filter arguments become an uncertainty note instead of a guess)
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

Callbacks matter because in real controllers most of an action's preconditions — auth, scoping, record loading — live in `before_action`, not the action body. A packet that shows `def upgrade` using `@account` without showing `set_account` omits the actual entry behavior. Callback methods not defined in the controller file are out of v0 scope (consistent with anchor resolution): when an in-file declaration names such a method, the packet lists that name as unresolved rather than pretending it doesn't exist; declarations made entirely in superclasses or concerns are invisible to v0 and are covered by a standing uncertainty note.

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
- tests to run
- uncertainty notes
- follow-up retrieval suggestions only when more context is needed

Callback snippets are additional snippet ranges on the controller file, so they share the existing per-file snippet limit rather than needing a new one.

The packet should be Markdown because humans and agents are the primary readers.

## Test candidate rules

Likely test candidates must be as rule-bound as controller resolution, or the determinism claim is hollow for exactly the fuzziest part of the packet. Controller test/spec paths are real Rails conventions; integration/request filenames are not — they are guesses, and the rules for guessing must be explicit.

v0 first selects one test family. RSpec is selected when the app has `spec/`
plus `spec/rails_helper.rb` or an `rspec-rails` dependency; otherwise Minitest
is selected. The selected family then applies two rules in order:

1. Conventional controller test/spec: `test/controllers/<controller_path>_controller_test.rb` for Minitest, or `spec/controllers/<controller_path>_controller_spec.rb` for RSpec, included only if the file exists.
2. Boundary-test path matches: Minitest checks `test/integration/*_test.rb`; RSpec checks `spec/requests/*_spec.rb`. The basename must contain the controller token and the action tokens as underscore-delimited tokens. Multiple matches are sorted lexicographically. `spec/system/` is intentionally out of v0 scope.

The combined list is truncated at the max-test-files limit, with truncation reported in the omitted-candidates note. Minitest rules use `minitest_candidate`; RSpec rules use `rspec_candidate`; the packet's "Why" line states which rule matched. Rule 2 matches always carry the `test_inferred_by_path` uncertainty note.

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

If a limit is hit, the packet should not silently omit context. It should include an explicit omitted-candidates or uncertainty note, for example:

```markdown
## Omitted candidates
- More constants were referenced than v0 includes.
- Inspect manually if the task requires deeper behavior:
  - Billing::Subscriptions
  - SyncBillingAccountJob
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

When ctxpack creates `.ctxpack/` for the first time, it should print a one-line reminder to stderr to add the directory to `.gitignore`. No interactive prompt, no automatic `.gitignore` edits. Success stdout is a composable, line-oriented result: one saved artifact path per line, relative to the directory where the command was invoked. This keeps paths directly usable even when ctxpack finds the Rails root by walking upward from a nested directory.

Default filename shape:

```text
YYYYMMDDHHMMSS_<context_name>.md
```

The timestamp should match the familiar Rails migration style: chronological, sortable, and collision-resistant. The name should describe the feature, bug, or context, using snake case.

Example:

```bash
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade"
```

writes:

```text
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.md
```

If `--name` is omitted, derive a snake_case name from the task and anchor:

```bash
ctxpack packet accounts#upgrade --task "Implement billing upgrade"
```

writes something like:

```text
.ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md
```

Rules:

- prefer an explicit `--name` for clear feature/bug/context naming
- use snake_case names to resemble Rails migration filenames
- include enough context in the name to avoid vague artifacts like `upgrade.md`
- when a derived name exceeds 80 characters, truncate the task prefix before the anchor; if the anchor itself exceeds the cap, retain its trailing 80 characters so the action remains visible
- include a timestamp in the default filename for ordering and collision resistance
- do not include generated timestamps inside packet content
- do not silently overwrite an existing artifact; require `--force` or an explicit `--out`
- allow `--dir` or `--out` for callers that want a different location
- reject `--out` + `--manifest` before compilation when the Markdown and JSON paths would collide, including extension-case-only differences
- treat committing a packet as opt-in, never the default; when opting in, `docs/ctxpack/` is the standard committed location (`--dir docs/ctxpack`)

Both top-level and `packet`-subcommand `--help` / `-h` forms should work without a Rails application root and return through the CLI's injected streams. Compilation failures should render the supplied controller/action in the Rails-native route hint only when both tokens are safe to paste into a shell; otherwise the hint uses generic placeholders.

## Machine-readable manifest

Markdown should be the main artifact. A structured manifest only earns its keep if it keeps evals simple.

If needed, generate a small manifest from the same internal packet object and save it next to the Markdown packet:

```bash
ctxpack packet accounts#upgrade \
  --name billing_upgrade_accounts_upgrade \
  --task "Implement billing upgrade" \
  --manifest
```

writes:

```text
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.md
.ctxpack/20260527143015_billing_upgrade_accounts_upgrade.json
```

The manifest is not a second product surface in v0. It exists so evals can assert stable fields without parsing Markdown prose.

Example manifest fields:

```json
{
  "version": 1,
  "anchor": "accounts#upgrade",
  "repo": {
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
      "reason_code": "controller_action",
      "snippet_ranges": [[24, 39]]
    }
  ],
  "tests": [
    {
      "command": "bin/rails test test/integration/accounts_upgrade_test.rb",
      "reason_code": "minitest_candidate"
    }
  ],
  "uncertainty": [
    {
      "code": "test_inferred_by_path"
    }
  ]
}
```

If evals can use the internal packet object directly, the public `--manifest` flag can wait.

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
- running the same command twice with a fixed `--out`, or with output paths normalized, produces the same content hash

Do not use an LLM judge in v0. Every packet bug should become a small deterministic eval case.

The runner itself should be re-runnable at any commit with no one-shot setup — re-runnability is a design property that is hard to retrofit. The Tier 2 harness follows the same principle, so usefulness can be re-measured at release boundaries rather than tested once ([`eval-plan.md`](eval-plan.md)).

## Non-goals for v0

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
   If a test file was guessed, a constant was matched by convention only, or multiple routes map to the action, the packet should say so.

## Example packet shape

````markdown
# ctxpack context packet

## Task
Implement billing upgrade.

## Anchor
- Action: `accounts#upgrade`
- Controller: `AccountsController#upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: `0f4b21c` (clean)

## Files to inspect first

### `app/controllers/accounts_controller.rb`
Why: controller action for the requested anchor.
Reason code: `controller_action`

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

Why: `before_action :set_account` applies to `upgrade` and loads `@account`.
Reason code: `before_action_callback`

```ruby
def set_account
  @account = current_user.accounts.find(params[:id])
end
```

### `test/integration/accounts_upgrade_test.rb`
Why: likely Minitest integration test for `accounts#upgrade`.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/integration/accounts_upgrade_test.rb`

## Uncertainty
- The Minitest file was inferred by path and should be verified.
- Callbacks declared outside this controller file (superclass or concerns) were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g upgrade` if the exact endpoint matters.
- Locale files are not scanned; user-facing strings conventionally live in `config/locales/`. If the task adds or changes user-visible copy, add or update the matching locale key(s).
- Billing package boundaries were not inspected in v0.

## Retrieve more only if needed
- Billing public API files if the controller delegates to `Billing::*`.
- Job implementation if the side effect behavior is part of the task.
````

## Relationship to skills and sub-agents

A skill or sub-agent can be useful as a wrapper around `ctxpack`, for example:

1. run `ctxpack packet accounts#upgrade`
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

If the Tier 0 gate passes, build the smallest possible `ctxpack packet <controller#action>` prototype against one static Rails-shaped fixture tree.

Success would mean the Rails-aware packet:

- includes fewer irrelevant files
- surfaces the true entry point faster
- gives the coding agent better tests to run
- reduces unnecessary exploration
- makes uncertainty clearer to the human operator
- produces stable output that can be regression-tested with simple eval cases

Whether the first four hold is judged against a real coding agent's own exploration — not keyword search — via the Tier 2 A/B in the eval plan.
