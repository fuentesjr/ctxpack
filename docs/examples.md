# ctxpack by example

A hands-on tour for Rails developers. By the end you can generate a context
packet for any `controller#action`, read every section, feed it to an AI coding
agent, and know when ctxpack will (correctly) refuse.

Packet excerpts shown here follow the real deterministic Format 2 output from
the bundled fixture app; explicit ellipses mark abridgement. The same anchor,
task, and tree produce byte-identical packet content. The `Generated from:`
line is the target app's Git state, not ctxpack's own revision.

## What ctxpack does, and when to reach for it

Given a Rails anchor like `accounts#upgrade`, ctxpack **statically** (it never
boots your app) compiles a short, ordered list of the files worth reading first:
the controller action, its applicable callbacks, the constants it references,
the conventional view template, and the test files that cover it — plus
deduplicated **Follow-ups** naming anything it guessed.

Reach for it when you're about to hand a *focused* task (a bug fix, a
behavior tweak, a small feature) to an AI coding agent and want it to land on
the right files immediately instead of exploring blindly. On sprawling,
many-file features the packet helps less and can even add reading surface — see
[the FAQ](faq.md#does-it-actually-help) for the nuance.

## Install and first run

ctxpack is **pre-release** — it is not on RubyGems yet. Add it from source:

```ruby
# Gemfile
gem "ctxpack", github: "fuentesjr/ctxpack"
```

```console
$ bundle install
$ bundle binstubs ctxpack     # optional: gives you bin/ctxpack
```

Then, from anywhere inside your Rails app, generate your first packet:

```console
$ bundle exec ctxpack accounts#upgrade \
    -t "Add annual billing option to the upgrade flow"
ctxpack: .ctxpack/ is not ignored; add `.ctxpack/` to .gitignore
.ctxpack/20260709223029_add_annual_billing_option_to_the_upgrade_flow_accounts_upgrade.md
```

ctxpack finds your app root by walking up to the first `config/application.rb`,
writes the packet to `.ctxpack/<utc-timestamp>_<name>.md`, and prints the path.
When the new default directory is not ignored according to Git, the reminder is written to stderr; success stdout contains only artifact paths,
one per line. Paths are relative to the directory where you invoked ctxpack, so
they remain directly usable when you run from a nested app directory.
Requires Ruby ≥ 3.4; its only runtime dependency is
[`prism`](https://github.com/ruby/prism), Ruby's own parser.

## Anatomy of a packet

Here is an abridged packet for `accounts#upgrade`. Read it top to bottom, then see
the section-by-section notes below.

````markdown
# ctxpack context packet

## Task

> Add annual billing option to the upgrade flow

## How to use this packet

- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list.
- Otherwise, start with `app/controllers/accounts_controller.rb` and open the other listed files only as the task touches them.

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: 49a4ea9 (clean)
- Format: 2
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

… (the other applicable callback evidence follows) …

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
- `bin/rails test test/integration/accounts_upgrade_test.rb` — path-inferred; verify coverage

## Follow-ups

- Inspect `around_action` callback `with_billing_audit`; it applies but is not snippeted in v0.
- Inspect the inline `before_action` block; it applies but has no method snippet.
- Inspect `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred candidate covers the task.
- Verify convention-only constant match `Billing::Subscriptions` → `app/services/billing/subscriptions.rb` if the task depends on it.
````

Section by section:

- **`## Task`** — the string you passed as `--task`, contained in a blockquote
  so issue-body Markdown cannot restructure the packet.
- **`## How to use this packet`** — fixed guidance for starting from an exact
  failing location when one exists, or from the entrypoint otherwise.
- **`## Anchor`** — the resolved controller, action, and file. `Generated from:
  49a4ea9 (clean)` is a **repo stamp**: the short git SHA of the tree the packet
  was compiled against, plus `(clean)` or `(dirty)`. A `(dirty)` stamp means you
  generated from uncommitted changes — the packet reflects your working tree,
  not a commit. When Git state cannot be read, the line says `unknown (Git
  state unavailable)`. `Format: 2` versions the Markdown shape; `Scope:` holds
  standing v0 boundaries once.
- **`## Inspect first`** — the flat DET-2-ordered file map. Every entry carries
  a literal reason code and templated provenance.
- **`## Evidence`** — snippet-bearing files only, with exact visible source
  ranges. Pointer-only constant, view, and test files stay in the map.
- **`## Run`** — copy-pasteable commands for the test candidates, so the
  first thing an agent does can be run the covering test.
- **`## Follow-ups`** — packet-specific uncertainty and omissions, each once
  as an imperative action. It is omitted when there is nothing to follow up.

## Choosing an anchor

An anchor is always `controller#action` in snake_case — never a URL, route
helper, or HTTP verb.

```console
$ bundle exec ctxpack articles#preview -t "Fix preview for drafts"

# Namespaced controllers use a path-style prefix:
$ bundle exec ctxpack admin/users#destroy -t "Soft-delete instead of destroy"
```

ctxpack does not read `config/routes.rb` — you bring the anchor. If you have a
route or URL and need its `controller#action`, ask Rails:

```console
$ bin/rails routes -g upgrade      # grep by action/path fragment
$ bin/rails routes -c accounts     # all routes for a controller
```

The `controller#action` shown in that output is your anchor.

## Feeding a packet to an AI coding agent

The Markdown packet is written to be dropped straight into
an agent prompt (Claude Code, Cursor, a custom harness — anything that reads
text):

1. Generate the packet for the anchor you're about to work on.
2. Paste its contents (or attach the file) at the top of your task prompt.
3. The agent opens the listed files first, runs the suggested test, and treats
   **Follow-ups** as things to verify rather than assume.

For programmatic wiring, add `--manifest` to also emit a sibling JSON file with
the same information in a stable, machine-readable shape:

```console
$ bundle exec ctxpack accounts#upgrade -t "..." --manifest
.ctxpack/…_accounts_upgrade.md
.ctxpack/…_accounts_upgrade.json
```

```json
{
  "version": 2,
  "task": "...",
  "anchor": "accounts#upgrade",
  "repo": { "available": true, "commit": "49a4ea9…", "dirty": false },
  "entrypoint": { "file": "app/controllers/accounts_controller.rb", "controller": "AccountsController", "action": "upgrade" },
  "files": [
    { "path": "app/controllers/accounts_controller.rb", "evidence": [
      { "reason_code": "controller_action", "subject": "upgrade", "snippet_ranges": [[10, 15]], "truncated": false }
    ] }
  ],
  "tests": [
    { "path": "test/controllers/accounts_controller_test.rb", "command": "bin/rails test test/controllers/accounts_controller_test.rb", "reason_code": "minitest_candidate", "rule": "conventional_controller_test" }
  ],
  "follow_ups": [ { "code": "around_callback_present", "subject": "with_billing_audit" } ],
  "omitted_candidates": [],
  "no_test_candidates": false
}
```

(Trimmed for brevity — the real manifest lists every file and code.)
When a limit omits a candidate, both its `follow_ups` fact and full
`omitted_candidates` record carry a semantic `limit_key` such as
`max_constant_files`; consumers do not need to interpret prose to identify the
limit.

Why this beats letting the agent grep or `@`-mention files itself is covered in
the [FAQ](faq.md#why-not-just-let-the-agent-grep).

## Flags and output

```
ctxpack <anchor> [options]
ctxpack packet <anchor> [options] # compatibility form
```

| Flag | Effect |
|---|---|
| `-t`, `--task TASK` | Records the task string in the packet; also seeds the default filename. Optional but recommended. |
| `--task-file PATH` | Read a multiline task from an invocation-relative file, or from stdin with `-`. Conflicts with `--task`. |
| `--name NAME` | Override the derived filename stem (letters, numbers, underscores only). |
| `-d`, `--dir DIR` | Output directory for the timestamped file. Default `.ctxpack/`. |
| `-o`, `--out PATH` | Write to an exact path instead of a timestamped name. |
| `-f`, `--force` | Allow overwriting existing Markdown or manifest output. |
| `--manifest` | Also write the sibling `.json` manifest. |
| `--stdout` | Emit raw Markdown without creating files; conflicts with artifact-output options. |
| `-h`, `--help` | Print descriptions, defaults, both forms, and examples; works in either form/position before Rails-root discovery. |
| `-v`, `--version` | Print the installed version when used alone; no Rails app required. |

Notes you'll hit in practice:

- **Default location.** Packets land in `.ctxpack/` with a UTC-timestamped
  filename, so repeated runs never clobber each other. The first time ctxpack
  creates `.ctxpack/`, it asks Git about repository, info/exclude, and configured
  global rules, then reminds on stderr only when the directory is unignored.
- **Scripting.** Success stdout contains only saved paths, one per line,
  relative to your invocation directory. With `--manifest`, Markdown is first
  and JSON second.
- **Issue bodies and pipelines.** `--task-file issue.md` avoids shell quoting;
  `--task-file - --stdout` reads standard input and emits only Markdown.
- **Regenerating.** Because the filename is timestamped, back-to-back runs just
  make new files. If either the Markdown path or sibling manifest already
  exists, ctxpack refuses unless you pass `--force`; `--out` never implies
  overwrite permission.
- **Exact paths are unambiguous.** `--out` cannot be combined with an explicit
  `--dir` or `--name`; use `--out PATH --force` when intentionally replacing an
  exact file. `--force` does not replace directories; if either Markdown or
  manifest destination is not a regular file, ctxpack fails before writing.
- **Exact JSON output paths.** `--out packet.json --manifest` is rejected
  before compilation because the manifest would replace the Markdown artifact;
  choose a Markdown path such as `--out packet.md`.
- **Committing packets.** Want them in the repo instead of ignored? Point them
  at a tracked directory: `--dir docs/ctxpack`. Keep in mind the repo stamp — a
  committed packet is a snapshot of one tree state and goes stale as the code
  moves.

## What gets included, and why

**Reason codes** (every file in `## Inspect first` carries one):

| Reason code | Meaning |
|---|---|
| `controller_action` | The controller action file for the anchor |
| `before_action_callback` | A `before_action` method that applies to the action (with snippet) |
| `referenced_constant` | A file resolved by convention from a constant referenced in the action, an applicable callback, or a same-file method transitively called from the action |
| `view_candidate` | The conventional view template for the action (listed by path) |
| `minitest_candidate` | A Minitest file matched by the conventional/path rules |
| `rspec_candidate` | A spec file matched by the conventional/path rules |

**Uncertainty codes** (machine-readable in manifest `follow_ups`; imperative
prose in `## Follow-ups`):

| Uncertainty code | Emitted when |
|---|---|
| `test_inferred_by_path` | A test candidate matched by path tokens, not the conventional path |
| `dynamic_callback_args` | A callback's `only:`/`except:` filter had non-literal (computed) arguments |
| `unresolved_external_callbacks` | An applicable callback names a method not defined in this controller file |
| `around_callback_present` | An `around_action` applies (named, not snippeted in v0) |
| `block_callback_present` | An applicable callback is an inline block (no method to snippet) |
| `view_inferred_by_convention` | A view was matched by action→template convention, not confirmed against the real render target |

### Limits

ctxpack caps the packet so it stays small enough to actually read:

| Limit | Value |
|---|---|
| Total files | 8 |
| Referenced constants | 4 |
| View templates | 2 |
| Test candidates | 2 |
| Snippet lines per file | 120 |

When a cap truncates something, it is named in `## Follow-ups` and, if a
snippet is head-truncated, the fence ends with an explicit
`# … truncated by ctxpack at 120 lines` marker. There is no flag to raise the
limits — see [the FAQ](faq.md#can-i-raise-the-limits).

## When ctxpack refuses

ctxpack fails loudly and specifically rather than guessing. The most common
first-run outcome on a real app is a refusal — that's a feature.

An action that isn't literally defined in the controller file (inherited from a
base class, mixed in from a concern, or metaprogrammed):

```console
$ bundle exec ctxpack accounts#teleport -t "..."
ctxpack: action teleport was not directly defined in app/controllers/accounts_controller.rb; inherited, concern-defined, and metaprogrammed actions are unsupported in v0
Use Rails-native route discovery, for example `bin/rails routes -g teleport` or `bin/rails routes -c accounts`.
```

A malformed anchor (a URL, verb, or route helper instead of `controller#action`):

```console
$ bundle exec ctxpack packet POST /accounts/:id/upgrade
ctxpack: Rails route strings are not supported; pass a controller#action anchor
Try `bin/rails routes -g upgrade` to find it.
```

In both cases the fix is to find the real `controller#action` (via
`bin/rails routes`) and anchor on that.

## Other setups

**RSpec projects.** When ctxpack detects an RSpec suite (a `spec/` directory
with `spec/rails_helper.rb` or `rspec-rails`), the test candidates and
`## Run` switches to specs and `bundle exec rspec` automatically:

```markdown
## Run

- `bundle exec rspec spec/controllers/accounts_controller_spec.rb`
- `bundle exec rspec spec/requests/accounts_upgrade_spec.rb`
```

**Actions with several view formats.** Every format variant that exists at the
conventional path is included (up to the 2-view limit), each as its own
`view_candidate`:

```markdown
## Inspect first

1. `app/controllers/view_budgets_controller.rb` — `controller_action`: action and applicable callbacks
2. `app/views/view_budgets/index.html.erb` — `view_candidate`: conventional template for `view_budgets#index`
3. `app/views/view_budgets/index.json.jbuilder` — `view_candidate`: conventional template for `view_budgets#index`

## Follow-ups

- Confirm the action renders `app/views/view_budgets/index.html.erb`; it was matched by convention.
- Confirm the action renders `app/views/view_budgets/index.json.jbuilder`; it was matched by convention.
```

**API-only actions with no view.** No view entry is added and resolution does
*not* fail — a missing conventional template is normal, not an error.
