# ctxpack by example

**Task + seed(s) → deterministic context packet** for AI coding agents.

A hands-on tour of ctxpack, a local **context engineering CLI** for Rails
codebases and a deterministic context compiler. Here, context engineering
means deterministically selecting, ordering, bounding, and explaining evidence
around user-supplied seeds for an agent's task. By the end you can generate a
context packet from the seed evidence you already have (test, error, diff,
files, method, or controller#action), read every section, feed it to an AI
coding agent, and know when ctxpack will (correctly) refuse.

Packet excerpts below were **generated** from the bundled fixture app
`test/fixtures/apps/minitest_basic` (Format 4). Explicit ellipses mark
abridgement. The same seeds, task, and tree produce byte-identical packet
*content*; `Generated from:` is the target app's Git state (or the enclosing
repo when the fixture is compiled in place), not a marketing fiction.

To reproduce the excerpts yourself: copy the fixture somewhere, add an empty
`config/application.rb` (the fixture ships without one, and root discovery
walks up to it), and for the git-range diff example run `git init` and make
a commit first. Your `Generated from:` SHA will differ; everything else
matches.

## What ctxpack does, and when to reach for it

A **seed** is evidence plus a deterministic expansion recipe. You supply
evidence you already have; ctxpack expands it under fixed rules and records a
reason code on every included file.

Reach for it when you're about to hand a *focused* task to an AI coding agent
and want a short, ordered starting set instead of open-ended exploration. On
the three-app Tier 2 expansion, feature tasks were the strongest measured
category: 5/6 met the pre-registered exploration bar, with a 58.5% median
reduction on the better exploration metric. Bug tasks were 0/3 because their
failing-test output already localized the code. These are small, offline,
directional results from **anchor-seed** packets, not production field data or
evidence about final code quality; see
[the FAQ](faq.md#does-it-actually-help).

**Measured agent benefit** so far applies to **anchor-seed** packets in offline
A/B studies (exploration reduction). Other seed kinds describe what the
compiler does after viability spikes; they are not a second agent-proof claim.

## Install and first run

ctxpack is **pre-release** — not on RubyGems. Add it from source:

```ruby
# Gemfile
gem "ctxpack", github: "fuentesjr/ctxpack"
```

```console
$ bundle install
$ bundle binstubs ctxpack     # optional: gives you bin/ctxpack
```

From anywhere inside your Rails app (walks up to `config/application.rb`):

```console
$ bundle exec ctxpack --from-test test/controllers/accounts_controller_test.rb \
    -t "Fix failing upgrade controller test"
ctxpack: .ctxpack/ is not ignored; add `.ctxpack/` to .gitignore
.ctxpack/20260715001542_fix_failing_upgrade_controller_test_accounts_controller_test.md
```

Packets land in `.ctxpack/<utc-timestamp>_<name>.md`. Success stdout is only
artifact paths (one per line). Requires Ruby ≥ 3.4; only runtime dependency is
[`prism`](https://github.com/ruby/prism).

For optional files-seed history, install the independent git-recon companion:

```console
$ git clone https://github.com/fuentesjr/git-recon.git
$ ln -s "$PWD/git-recon/bin/git-recon" ~/.local/bin/git-recon
```

ctxpack discovers a compatible executable on `PATH`; it does not co-install or
download it. The files example below shows the honest unavailable form. With
the companion installed, `## History` instead contains up to five bounded
coupled-path/commit facts. Profiling reduced the representative direct
git-recon query from 10.27–13.02 seconds to 4.838–5.192 seconds with identical
output. The pre-optimization end-to-end ctxpack path measured
18.623–19.021 seconds. A post-optimization recheck through ctxpack's
production provider seam took 6.020 seconds and returned 5 facts with 10
truncated and no error. The tracer remains limited to one retained files
primary under the unchanged 20-second deadline.

---

## Seed recipes (worked examples)

All excerpts: fixture `test/fixtures/apps/minitest_basic`.

### Test seed — failing or focused test

```console
$ bundle exec ctxpack --from-test test/controllers/accounts_controller_test.rb \
    -t "Fix failing upgrade controller test" --stdout
```

Positional sugar also works when the path exists under `test/` or `spec/`:

```console
$ bundle exec ctxpack test/controllers/accounts_controller_test.rb \
    -t "Fix failing upgrade controller test"
```

Generated packet (full for this small case):

````markdown
# ctxpack context packet

## Task

> Fix failing upgrade controller test

## How to use this packet

- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list.
- Otherwise, start with `test/controllers/accounts_controller_test.rb` and open the other listed files only as the task touches them.

## Seeds

- test: `test/controllers/accounts_controller_test.rb`
- Generated from: e01883c (clean)
- Format: 4
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack; expand from the listed seeds only.

## Inspect first

1. `test/controllers/accounts_controller_test.rb` — `test_seed_primary`: user-named test seed
2. `app/controllers/accounts_controller.rb` — `referenced_constant`: `accounts_controller`

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
````

What you get: the named test as primary, a convention/path-inferred production
file when one resolves, and a copy-pasteable run command. What you do not get
from this seed alone: full anchor-style callback and constant expansion of the
controller action (use an anchor seed or multi-seed for that).

### Error seed — stack / log paste

```console
$ printf '%s\n' \
    'app/controllers/accounts_controller.rb:12:in `upgrade`' \
    'app/services/billing/subscriptions.rb:8:in `upgrade!`' |
  bundle exec ctxpack --from-error - -t "Debug upgrade stack" --stdout
```

Abridged generated packet:

````markdown
## Seeds

- error: `app/controllers/accounts_controller.rb:12`
- Generated from: e01883c (clean)
- Format: 4

## Inspect first

1. `app/controllers/accounts_controller.rb` — `error_seed_frame`: application stack frame
2. `app/services/billing/subscriptions.rb` — `error_seed_frame`: application stack frame

## Evidence

### `app/controllers/accounts_controller.rb`

`error_seed_frame` — `app/controllers/accounts_controller.rb:12` · lines 1–27

```ruby
class AccountsController < ApplicationController
  …
  def upgrade
    subscription = Billing::Subscriptions.new(@account)
    subscription.upgrade!(plan: params[:plan])
    …
  end
```

### `app/services/billing/subscriptions.rb`

`error_seed_frame` — `app/services/billing/subscriptions.rb:8` · lines 1–11

```ruby
module Billing
  class Subscriptions
    …
    def upgrade!(plan:)
      @account.update!(plan: plan)
    end
  end
end
```
````

Only **filtered application frames** (`path:line` under the app) are stored —
never the raw paste (PII/secret rule). Framework/gem frames are dropped. This
fixture case has no test candidates under path rules, so `## Run` says so
explicitly.

### Diff seed — continue / review workflow

`--from-diff` is **explicit-flag-only** (no positional sugar; an existing
`.patch` path without the flag is a **files** seed).

**Git range** (continue from recent work — here a controller edit so the
paired-test mirror hits):

```console
$ bundle exec ctxpack --from-diff HEAD~1 -t "Continue from last commit" --stdout
```

Illustrative packet from a temp app built from the same fixture tree with one
committed controller change (paired-test mirror present):

````markdown
## Seeds

- diff: `HEAD~1`
- Generated from: 7d572d7 (clean)
- Format: 4
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack; expand from the listed seeds only.

## Inspect first

1. `app/controllers/accounts_controller.rb` — `diff_seed_primary`: changed file from diff seed
2. `test/controllers/accounts_controller_test.rb` — `diff_seed_paired_test`: conventional mirror test for diff primary

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
````

**Patch file** (review a saved diff) — generated from
`test/fixtures/apps/minitest_basic/patches/upgrade_accounts.patch`:

```console
$ bundle exec ctxpack --from-diff patches/upgrade_accounts.patch \
    -t "Review upgrade patch" --stdout
```

````markdown
## Seeds

- diff: `patches/upgrade_accounts.patch`
- Generated from: e01883c (clean)
- Format: 4
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack; expand from the listed seeds only.

## Inspect first

1. `app/controllers/accounts_controller.rb` — `diff_seed_primary`: changed file from diff seed
2. `test/controllers/accounts_controller_test.rb` — `diff_seed_paired_test`: conventional mirror test for diff primary

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
````

What you get: changed files that still exist in the working tree as primaries;
for production `app/**/*.rb` files, **conventional mirror** test paths when
they exist on disk (`diff_seed_paired_test`). What you do not get: basename
token search for tests, stdin diffs, or silent treatment of a bare `.patch`
path as a diff seed.

### Files seed — open files you already care about

```console
$ bundle exec ctxpack --from-files app/services/billing/subscriptions.rb \
    -t "Inspect billing subscriptions service" --stdout
```

Generated packet:

````markdown
## Seeds

- files: `app/services/billing/subscriptions.rb`
- Generated from: e01883c (clean)
- Format: 4
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack; expand from the listed seeds only.

## Inspect first

1. `app/services/billing/subscriptions.rb` — `files_seed_primary`: user-named files seed

## History

- Seed path: "app/services/billing/subscriptions.rb"
History context was unavailable (reason: executable_unavailable).

## Run

No Minitest candidates were found by ctxpack's path rules.

## Follow-ups

- Inspect history for "app/services/billing/subscriptions.rb" manually; bounded local history was unavailable (executable_unavailable).
- Search `test/` by hand if the task needs test coverage.
````

Named files are never dropped without a follow-up. Neighbors (conventional
tests, views, path-token constants) appear only when budgeted rules hit — this
service path has no neighbor hit in the fixture, which is honest output.
History is supplemental and separately budgeted: absence never removes the
named file or changes the Run section.

### Method seed — non-controller `Const#method`

Form: `Namespace::Class#method` (never `*Controller#action` — that is anchor
territory). Fixture class is `Billing::UpgradeService`:

```console
$ bundle exec ctxpack --from-method "Billing::UpgradeService#call" \
    -t "Inspect upgrade service" --stdout
```

Generated packet (abridged follow-ups):

````markdown
## Seeds

- method: `Billing::UpgradeService#call`
- Generated from: e01883c (clean)
- Format: 4

## Inspect first

1. `app/services/billing/upgrade_service.rb` — `method_seed_primary`: user-named method seed
2. `app/models/direct_alpha.rb` — `referenced_constant`: `DirectAlpha`
3. `app/models/direct_beta.rb` — `referenced_constant`: `DirectBeta`
4. `app/models/direct_gamma.rb` — `referenced_constant`: `DirectGamma`
5. `app/models/direct_delta.rb` — `referenced_constant`: `DirectDelta`

## Evidence

### `app/services/billing/upgrade_service.rb`

`method_seed_primary` — `call` · lines 3–7

```ruby
    def call
      DirectAlpha.prepare
      DirectBeta.prepare
      load_transitive
    end
```

## Run

No Minitest candidates were found by ctxpack's path rules.

## Follow-ups

- Verify convention-only constant match `DirectAlpha` → `app/models/direct_alpha.rb` if the task depends on it.
- …
- Inspect omitted constant `TransitiveEpsilon`; the 4-constant limit was reached.
- Search `test/` by hand if the task needs test coverage.
````

**What it contains:** exact constant resolution to a file, the instance method
snippet, same-file call-graph constant expansion under the usual caps.

**What it does not contain:** a **test-candidate leg**. The method-seed spike's
test-leg precision gate failed; re-promoting tests requires a new
pre-registration (see `eval/seed-spikes/method/RESULTS.md` and SEED-25).
`## Run` saying “no candidates” here is expected recipe design, not a missing
fixture file.

### Anchor seed — `controller#action` (most mature recipe)

Still first-class — the longest-evaluated recipe — but one seed kind among
several, not the product identity.

```console
$ bundle exec ctxpack accounts#upgrade \
    -t "Add annual billing option to the upgrade flow" --stdout
# or: ctxpack --from-anchor accounts#upgrade -t "..."
```

Abridged generated packet:

````markdown
# ctxpack context packet

## Task

> Add annual billing option to the upgrade flow

## How to use this packet

- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list.
- Otherwise, start with `app/controllers/accounts_controller.rb` and open the other listed files only as the task touches them.

## Seeds

- anchor: `accounts#upgrade`

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: e01883c (clean)
- Format: 4
- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack v0; use `bin/rails routes -g upgrade` for endpoints, and check `config/locales/` if the task touches user-facing copy.

## Inspect first

1. `app/controllers/accounts_controller.rb` — `controller_action`: action and applicable callbacks
2. `app/services/billing/subscriptions.rb` — `referenced_constant`: `Billing::Subscriptions`
3. `app/jobs/sync_billing_account_job.rb` — `referenced_constant`: `SyncBillingAccountJob`
4. `test/controllers/accounts_controller_test.rb` — `minitest_candidate`: conventional controller test path
5. `test/integration/accounts_upgrade_test.rb` — `minitest_candidate`: path-inferred; verify coverage

## Evidence

### `app/controllers/accounts_controller.rb`

`controller_action` — action `upgrade` · lines 10–15

```ruby
  def upgrade
    subscription = Billing::Subscriptions.new(@account)
    subscription.upgrade!(plan: params[:plan])
    SyncBillingAccountJob.perform_later(@account.id)
    redirect_to account_path(@account)
  end
```

`before_action_callback` — callback `set_account` applies · lines 23–25

```ruby
  def set_account
    @account = Account.find(params[:id])
  end
```

… (other applicable callback evidence follows) …

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
- `bin/rails test test/integration/accounts_upgrade_test.rb` — path-inferred; verify coverage

## Follow-ups

- Inspect `around_action` callback `with_billing_audit`; it applies but is not snippeted in v0.
- Inspect the inline `before_action` block; it applies but has no method snippet.
- Inspect `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred candidate covers the task.
- Verify convention-only constant match `Billing::Subscriptions` → `app/services/billing/subscriptions.rb` if the task depends on it.
- Verify convention-only constant match `SyncBillingAccountJob` → `app/jobs/sync_billing_account_job.rb` if the task depends on it.
````

Section by section:

- **`## Task`** — your `--task` / `--task-file` string, blockquoted so issue
  Markdown cannot restructure the packet.
- **`## How to use this packet`** — fixed guidance for exact failing locations
  vs entrypoint-first reading.
- **`## Seeds`** — every seed that contributed (kind + identity/evidence).
- **`## Anchor`** — only when an anchor seed is present: controller, action,
  file, repo stamp, format version, standing scope.
- **`## Inspect first`** — flat ordered file map; every entry has a reason code.
- **`## Evidence`** — snippet-bearing files only, with 1-based ranges.
- **`## History`** — conditional typed local-history facts or one honest
  omission for an applicable files primary.
- **`## Run`** — copy-pasteable test commands (or an explicit “no candidates”).
- **`## Follow-ups`** — packet-specific uncertainty and omissions once each.

Namespaced controllers use a path-style prefix: `admin/users#destroy`.

ctxpack does **not** read `config/routes.rb`. If you have a URL or helper and
need `controller#action`:

```console
$ bin/rails routes -g upgrade
$ bin/rails routes -c accounts
```

### Multi-seed

```console
$ bundle exec ctxpack \
    --from-test test/controllers/accounts_controller_test.rb \
    --from-anchor accounts#upgrade \
    -t "Fix upgrade with both seeds"
```

Seeds merge under MERGE rules (primaries kept, budgets applied once). Details:
[`specs/seeds.md`](../specs/seeds.md).

---

## Feeding a packet to an AI coding agent

1. Generate a packet from the seed you already have.
2. Paste or attach the Markdown at the top of the agent prompt.
3. The agent should open listed files first, run suggested tests when present,
   and treat **Follow-ups** as things to verify.

For tools:

```console
$ bundle exec ctxpack accounts#upgrade -t "..." --manifest
.ctxpack/…_accounts_upgrade.md
.ctxpack/…_accounts_upgrade.json
```

```console
$ bundle exec ctxpack accounts#upgrade -t "..." --stdout=json | jq .version
3
```

Manifest v3 carries `seeds: [...]` and optional `anchor`. When a limit omits a
candidate, `follow_ups` and `omitted_candidates` include a semantic
`limit_key` such as `max_constant_files`.

Why this can beat ad-hoc grepping (and when it does not): [FAQ](faq.md#why-not-just-let-the-agent-grep).

---

## Flags and output

```
ctxpack <seed-sugar> [options]
ctxpack --from-test PATH[:LINE] [options]
ctxpack --from-files PATH… [options]
ctxpack --from-error PASTE|- [options]
ctxpack --from-method CONST#METHOD [options]
ctxpack --from-diff RANGE|PATCH [options]
ctxpack --from-anchor ANCHOR [options]
ctxpack packet <anchor> [options]   # compatibility form
```

| Flag | Effect |
|---|---|
| `-t`, `--task TASK` | Task string; seeds default filename. Optional but recommended. |
| `--task-file PATH` | Multiline task from file or stdin (`-`). Conflicts with `--task`. |
| `--from-anchor` / `--from-test` / `--from-files` / `--from-error` / `--from-method` / `--from-diff` | Explicit seeds (multi-seed allowed). |
| `--name NAME` | Override derived filename stem. |
| `-d`, `--dir DIR` | Output directory (default `.ctxpack/`). |
| `-o`, `--out PATH` | Exact path instead of timestamped name. |
| `-f`, `--force` | Allow overwriting existing Markdown or manifest. |
| `--manifest` | Sibling `.json` manifest. |
| `--stdout[=FORMAT]` | Emit Markdown or manifest `json` without files. |
| `-h`, `--help` | Offline help. |
| `-v`, `--version` | Version; no Rails app required. |

Notes:

- **Default location.** Timestamped files under `.ctxpack/`; first create may
  remind on stderr if the directory is not gitignored.
- **Scripting.** Success stdout is paths only (or pure content with `--stdout`).
- **Regenerating.** Existing paths refuse without `--force`.
- **Committing packets.** Use `--dir docs/ctxpack` deliberately; stamps go
  stale as code moves.

---

## What gets included, and why

**Reason codes** (subset; full registry in `specs/packet-format.md` FMT-6):

| Reason code | Meaning |
|---|---|
| `controller_action` | Anchor controller action file |
| `before_action_callback` | Applicable `before_action` method (snippeted) |
| `referenced_constant` | Convention-resolved constant file |
| `view_candidate` | Conventional view template (list-only) |
| `minitest_candidate` / `rspec_candidate` | Test/spec from anchor (or selected-family) rules |
| `test_seed_primary` | User-named test/spec seed file |
| `files_seed_primary` / `files_seed_neighbor` | Files seed primary / neighbor |
| `error_seed_frame` | Application stack frame file |
| `method_seed_primary` | Method-seed def file |
| `diff_seed_primary` / `diff_seed_paired_test` | Diff changed file / mirror test |

**Uncertainty codes** (manifest `follow_ups`; prose in `## Follow-ups`):

| Uncertainty code | Emitted when |
|---|---|
| `test_inferred_by_path` | Test matched by path tokens, not the conventional path |
| `dynamic_callback_args` | Callback filter had non-literal arguments |
| `unresolved_external_callbacks` | Callback method not defined in this controller file |
| `around_callback_present` | `around_action` applies (named, not snippeted in v0) |
| `block_callback_present` | Inline block callback (no method to snippet) |
| `view_inferred_by_convention` | View matched by convention only |
| `test_seed_surface_uncertain` | Test seed production surface weak or empty |

### Limits

| Limit | Value |
|---|---|
| Total files | 8 |
| Referenced constants | 4 |
| View templates | 2 |
| Test candidates | 2 |
| Snippet lines per file | 120 |

Caps are fixed (no raise flag). Truncation is named in Follow-ups; long
snippets end with `# … truncated by ctxpack at 120 lines`.

---

## When ctxpack refuses

Refusals are specific. Common cases:

**Missing seed (task-only):**

```console
$ bundle exec ctxpack packet --task "Just prose, no seed"
ctxpack: missing seed; pass controller#action, a path, CONST#method, or a --from-* flag
…
```

(The `…` is the CLI's usage block, elided here.)

The gem does not invent a seed from prose. Skills may propose `ctxpack …`
lines; compile still needs evidence.

**Route-shaped input (coaching only — never resolved):**

```console
$ bundle exec ctxpack "GET /accounts"
ctxpack: Rails route strings are not supported; pass a controller#action anchor
Try `bin/rails routes -g accounts` to find it.
```

```console
$ bundle exec ctxpack upgrade_account
ctxpack: "upgrade_account" looks like a Rails route helper, not a controller#action anchor
Try `bin/rails routes -g upgrade_account`, then pass the controller#action anchor shown by Rails.
```

There is no `--from-route`. The Phase 5c route spike failed its resolution
gate (average 0.243 < 0.70); evidence stays coaching-only —
[`eval/seed-spikes/route/RESULTS.md`](../eval/seed-spikes/route/RESULTS.md).

**Action not directly defined in the controller file:**

```console
$ bundle exec ctxpack accounts#teleport -t "..."
ctxpack: action teleport was not directly defined in app/controllers/accounts_controller.rb; inherited, concern-defined, and metaprogrammed actions are unsupported in v0
Use Rails-native route discovery, for example `bin/rails routes -g teleport` or `bin/rails routes -c accounts`.
```

---

## Other setups

**RSpec projects.** When `spec/` plus `spec/rails_helper.rb` or `rspec-rails`
is present, candidates and `## Run` switch to `bundle exec rspec`.

**Actions with several view formats.** Conventional variants are included up
to the 2-view limit, each as `view_candidate`, with convention follow-ups.

**API-only actions with no view.** No view entry; missing template is normal,
not an error.
