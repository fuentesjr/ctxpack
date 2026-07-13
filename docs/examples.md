# ctxpack by example

A hands-on tour for Rails developers. By the end you can generate a context
packet for any `controller#action`, read every section, feed it to an AI coding
agent, and know when ctxpack will (correctly) refuse.

All packet output shown here is **real**, produced by the ctxpack CLI (tool
commit `bcfed2f`) against a throwaway copy of the bundled fixture app. Output is
byte-for-byte deterministic, so the same anchor + same tree always produces the
same packet. (The `Generated from:` line inside a packet is the *target app's*
git SHA, so the sample below shows a different short SHA than the tool commit.)

## What ctxpack does, and when to reach for it

Given a Rails anchor like `accounts#upgrade`, ctxpack **statically** (it never
boots your app) compiles a short, ordered list of the files worth reading first:
the controller action, its applicable callbacks, the constants it references,
the conventional view template, and the test files that cover it — plus an
honest **Uncertainty** section naming anything it guessed.

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
Requires Ruby ≥ 3.2; its only runtime dependency is
[`prism`](https://github.com/ruby/prism), Ruby's own parser.

## Anatomy of a packet

Here is the full packet for `accounts#upgrade`. Read it top to bottom, then see
the section-by-section notes below.

````markdown
# ctxpack context packet

## Task
Add annual billing option to the upgrade flow

## Anchor
- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: 49a4ea9 (clean)

## Files to inspect first

### `app/controllers/accounts_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def upgrade
    subscription = Billing::Subscriptions.new(@account)
    subscription.upgrade!(plan: params[:plan])
    SyncBillingAccountJob.perform_later(@account.id)
    redirect_to account_path(@account)
  end
```

Why: callback `set_account` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def set_account
    @account = Account.find(params[:id])
  end
```

… (the other applicable callbacks follow) …

### `app/services/billing/subscriptions.rb`

Why: constant `Billing::Subscriptions` was referenced by the action, an applicable callback, or a same-file method transitively called from the action.
Reason code: `referenced_constant`

### `app/jobs/sync_billing_account_job.rb`

Why: constant `SyncBillingAccountJob` was referenced by the action, an applicable callback, or a same-file method transitively called from the action.
Reason code: `referenced_constant`

### `test/controllers/accounts_controller_test.rb`

Why: test file matched the conventional controller test path.
Reason code: `minitest_candidate`

### `test/integration/accounts_upgrade_test.rb`

Why: test file matched integration path tokens for the anchor.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/controllers/accounts_controller_test.rb`
- `bin/rails test test/integration/accounts_upgrade_test.rb`

## Uncertainty
- `around_action` callback `with_billing_audit` applies and is not snippeted in v0.
- Inline `before_action` callback block applies and has no method snippet.
- Test file `test/integration/accounts_upgrade_test.rb` was inferred by path and should be verified.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g upgrade` if the exact endpoint matters.
- Locale files are not scanned; user-facing strings conventionally live in `config/locales/`. If the task adds or changes user-visible copy, add or update the matching locale key(s).
- Convention-only constant match `Billing::Subscriptions` resolved to `app/services/billing/subscriptions.rb`; verify it if the task depends on that behavior.
- Convention-only constant match `SyncBillingAccountJob` resolved to `app/jobs/sync_billing_account_job.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect applicable `around_action` behavior for `with_billing_audit` if it affects the task.
- Inspect inline callback block behavior for `before_action` if it affects the task.
- Inspect test file `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred Minitest candidate covers the task.
````

Section by section:

- **`## Task`** — the string you passed as `--task`, echoed so the packet is
  self-describing when an agent reads it.
- **`## Anchor`** — the resolved controller, action, and file. `Generated from:
  49a4ea9 (clean)` is a **repo stamp**: the short git SHA of the tree the packet
  was compiled against, plus `(clean)` or `(dirty)`. A `(dirty)` stamp means you
  generated from uncommitted changes — the packet reflects your working tree,
  not a commit. Outside a git repo the line reads `unknown (not a git
  repository)`.
- **`## Files to inspect first`** — the ordered file list, by priority:
  controller action → applicable callbacks → referenced constants → view
  template → test candidates. Each entry has a plain-language **Why** and a
  machine-readable **Reason code** (full table [below](#what-gets-included-and-why)).
  Ruby files that were parsed carry a snippet; view and test files are listed
  by path only (they point you at the file without quoting it).
- **`## Tests to run`** — copy-pasteable commands for the test candidates, so the
  first thing an agent does can be run the covering test.
- **`## Uncertainty`** — everything ctxpack *guessed* or deliberately did not
  resolve: path-inferred tests, convention-only constant matches, out-of-file
  callbacks, the standing locale pointer, and route discovery. This section is
  the point: ctxpack tells you where to double-check instead of pretending to
  certainty.
- **`## Retrieve more only if needed`** — a short, mechanical follow-up list
  derived from the uncertainty/omission codes: the next files or checks to pull
  in *only if* the task touches them.
- **`## Omitted candidates`** — not shown above because nothing was omitted here.
  When a limit truncates the file set (see [limits](#limits)), this section names
  exactly which constants, tests, views, or snippets were dropped, so nothing
  disappears silently.

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
   the **Uncertainty** notes as things to verify rather than assume.

For programmatic wiring, add `--manifest` to also emit a sibling JSON file with
the same information in a stable, machine-readable shape:

```console
$ bundle exec ctxpack accounts#upgrade -t "..." --manifest
.ctxpack/…_accounts_upgrade.md
.ctxpack/…_accounts_upgrade.json
```

```json
{
  "version": 1,
  "anchor": "accounts#upgrade",
  "entrypoint": { "file": "app/controllers/accounts_controller.rb", "controller": "AccountsController", "action": "upgrade" },
  "files": [
    { "path": "app/controllers/accounts_controller.rb", "reason_code": "controller_action", "snippet_ranges": [[10, 15]] },
    { "path": "app/services/billing/subscriptions.rb", "reason_code": "referenced_constant", "snippet_ranges": [] }
  ],
  "tests": [
    { "command": "bin/rails test test/controllers/accounts_controller_test.rb", "reason_code": "minitest_candidate" }
  ],
  "uncertainty": [ { "code": "around_callback_present" }, { "code": "test_inferred_by_path" } ]
}
```

(Trimmed for brevity — the real manifest lists every file and code.)

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

**Reason codes** (every file in `## Files to inspect first` carries one):

| Reason code | Meaning |
|---|---|
| `controller_action` | The controller action file for the anchor |
| `before_action_callback` | A `before_action` method that applies to the action (with snippet) |
| `referenced_constant` | A file resolved by convention from a constant referenced in the action, an applicable callback, or a same-file method transitively called from the action |
| `view_candidate` | The conventional view template for the action (listed by path) |
| `minitest_candidate` | A Minitest file matched by the conventional/path rules |
| `rspec_candidate` | A spec file matched by the conventional/path rules |

**Uncertainty codes** (machine-readable, in the manifest; prose in
`## Uncertainty`):

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

When a cap truncates something, it is named in `## Omitted candidates` and, if a
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
`## Tests to run` switch to specs and `bundle exec rspec` automatically:

```markdown
## Tests to run
- `bundle exec rspec spec/controllers/accounts_controller_spec.rb`
- `bundle exec rspec spec/requests/accounts_upgrade_spec.rb`
```

**Actions with several view formats.** Every format variant that exists at the
conventional path is included (up to the 2-view limit), each as its own
`view_candidate`:

```markdown
### `app/views/view_budgets/index.html.erb`

Why: Conventional view template for `view_budgets#index`.
Reason code: `view_candidate`

### `app/views/view_budgets/index.json.jbuilder`

Why: Conventional view template for `view_budgets#index`.
Reason code: `view_candidate`
```

**API-only actions with no view.** No view entry is added and resolution does
*not* fail — a missing conventional template is normal, not an error.
