# Spec: Packet compilation

Status: Draft. Source: `design.md` — "Settled v0 direction", "Parsing and
static analysis strategy", "Test candidate rules", "v0 packet limits".

Compilation is the pipeline from anchor to internal packet object:

```text
anchor → controller file → action + applicable callbacks → views →
referenced constants → constant files → test candidates → limits applied →
packet object
```

Rendering the packet object is specified in `packet-format.md`.

## Anchor resolution

**ANCH-1.** Accepted anchor format is `controller#action`, optionally
namespaced with `/`:

```text
accounts#upgrade
admin/accounts#upgrade
```

Tokens are snake_case, matching the shape shown by `bin/rails routes`. The
action token additionally tolerates a trailing `?` or `!` and a leading `_`
(`tickets#merged?`, `pages#_show_secure_deprecated`) — Ruby method-name
shapes that occur in real route tables. **[amended: originally strict
snake_case for both tokens; the Tier 0 spike found real routed actions
rejected only by the grammar]**

**ANCH-2.** The anchor maps to a controller file purely by convention:

```text
accounts#upgrade       → app/controllers/accounts_controller.rb
admin/accounts#upgrade → app/controllers/admin/accounts_controller.rb
```

No route table is consulted; Rails is never booted. Within the resolved
file, the controller class is the first class (in source order) whose
fully-qualified name matches the anchor's controller path
segment-by-segment — case- and underscore-insensitively, after dropping the
final segment's `Controller` suffix — so `ai_text_tools#index` accepts
`AITextToolsController`. If no class in the file matches, resolution fails
with a message naming the file. **[amended: originally the class was looked
up by exact camelization of the anchor (`ai_text_tools` →
`AiTextToolsController`), which fails for acronym-styled classes — their
inflections live in per-app initializers v0 never loads. The file was
already resolved by convention, so the class it defines is trusted
instead.]**

**ANCH-3.** The action MUST be directly defined as `def <action>` in the
resolved controller class (ANCH-2) in the resolved controller file.
**[amended: "file" narrowed to "class" when ANCH-2 gained class-by-file
matching; unchanged in effect for conventionally named classes]**
Inherited actions, concern-defined actions, and
metaprogrammed actions are unresolvable in v0. Method visibility is ignored:
any direct `def <action>` matches, whether or not it follows a `private` or
`protected` marker. (The anchor comes from `bin/rails routes`, so a routable
action exists; visibility tracking is parser complexity v0 skips — revisit if
the Tier 0 spike surfaces private same-named helpers shadowing inherited
actions.) **[visibility rule fixed by spec]**

**ANCH-4.** Resolution MUST be exact. ctxpack MUST NOT fuzzy-match controller
names, search for the action elsewhere, or guess an alternative file.

**ANCH-5.** Out of scope for v0 resolution (MUST fail, not degrade):
inherited controller actions; actions defined in concerns; Rails engines and
mounted apps; custom route-string parsing; route constraints; metaprogrammed
actions; booting Rails to inspect routes.

**ANCH-6.** If the conventional controller file does not exist, resolution
fails with a message naming the expected path.

**ANCH-7.** If the file exists but contains no direct `def <action>`,
resolution fails with a message saying the action was not directly defined
and that inherited/concern/metaprogrammed actions are unsupported in v0.

## Parsing

**PARSE-1.** v0 parses Ruby with Prism. No other parser, index, or semantic
engine is a v0 dependency; in particular Rubydex MUST NOT be required.

**PARSE-2.** The implementation MUST keep constant resolution behind a
swappable interface:

```text
Parser: Prism
Default resolver: convention/path-based constant resolver
Future resolver: Rubydex-backed semantic resolver (not v0)
```

## Callbacks

Rationale (from design): most of an action's preconditions — auth, scoping,
record loading — live in `before_action`, not the action body. A packet that
shows `def upgrade` using `@account` without showing `set_account` omits the
actual entry behavior.

**CB-1.** ctxpack collects `before_action`, `prepend_before_action`, and
`append_before_action` declarations in the same controller class as the action
and keeps those that apply to the action. All three are parsed identically for
applicability; declaration order in the packet follows source order, with no
attempt to model prepend reordering.

**CB-1a.** `around_action` declarations applying to the action are NOT
snippeted; their names are listed under Uncertainty. Inline block callbacks
(`before_action { ... }`) yield a "block callback present" uncertainty note
and no snippet. `after_action` is ignored (it cannot be a precondition).

**CB-2.** Applicability is decided only from literal `only:` / `except:`
filters (or their absence). A literal filter is an array of symbol or string
literals, or a single symbol or string literal — Rails treats `only: :upgrade`
and `only: [:upgrade]` identically, and the single-literal form is the more
common style in real controllers. A `before_action` with dynamic filter
arguments (computed symbols, `if:`/`unless:` procs deciding inclusion, splats,
etc.) MUST NOT be guessed at; it becomes an uncertainty note instead.
**[amended: originally arrays only; single literals admitted after
implementation review showed the array-only rule would push the dominant
Rails style into uncertainty notes]**

**CB-2a.** `skip_before_action` declarations in the same controller class are
honored under the same literalness rule: a callback skipped for the action via
a literal `skip_before_action` (unconditional, or with literal `only:` /
`except:` filters — per CB-2, arrays or single literals — covering the
action) is excluded from the packet. A
`skip_before_action` with dynamic filter arguments MUST NOT be guessed at; the
affected callback stays in the packet and the skip becomes an uncertainty
note.

**CB-3.** For applicable callbacks whose methods are defined in the same
controller file, ctxpack extracts a snippet of the method (see FMT-5). These
snippets are additional ranges on the controller file entry and share the
per-file snippet-line limit (LIM-1); they do not get a separate budget.

**CB-4.** Callback methods not defined in the controller file are NOT
resolved in v0 (consistent with ANCH-5): when an applicable in-file
declaration names a method with no direct definition in the same file, the
packet MUST list that name as unresolved rather than omitting it.
Declarations living entirely outside the controller file (superclass or
concern `before_action`s) are invisible to v0 and cannot be named; they are
covered by the Uncertainty section's standing note that callbacks outside the
controller file were not resolved (FMT-8). **[amended: originally said
"callbacks declared outside the controller file must be listed by name",
which is unimplementable — v0 never reads the superclass or concerns, so
those names cannot be known]**

## Constants

**CONST-1.** ctxpack collects obvious constants referenced inside the action
body and inside the bodies of applicable same-file callbacks. "Obvious" means
syntactically present constant references (e.g. `Billing::Subscriptions`,
`SyncBillingAccountJob`) — no receiver-type inference, no cross-file
call-graph construction.

**CONST-1a.** The constant scan set is the action body, the bodies of
applicable same-file callbacks, and the bodies of same-file methods
transitively called from the action body. A call counts as an intra-file
method call only when it is a `Prism::CallNode` whose receiver is absent
(implicit `self`) or is a `Prism::SelfNode` (explicit `self.foo`), and whose
method name matches a direct method of the controller class. Calls with any
other receiver are ignored. Only literal identifier calls are followed:
`send`, `public_send`, `method`, `alias_method`, aliases, and other dynamic
dispatch are out of scope.

Transitivity uses a FIFO work-list seeded with qualifying same-file calls
found in the action body in source order. The visited set is seeded with the
action's own method name only. For each popped method name, ctxpack marks it
visited, scans that method body for constants, and appends further qualifying
same-file calls in source order, skipping already-visited or already-queued
names. The traversal terminates because the direct-method set is finite.

Callback bodies are scanned for constants but their calls are not followed.
Only the action's call graph expands. If a method is both an applicable
callback and reachable from the action, its constants are emitted at its
callback position (path-level deduplication makes a later callee emission a
no-op), but the BFS still traverses through that method to discover its own
callees; callback names are therefore not seeded into the visited set. As with
actions and callbacks, constants in method parameter defaults
(`def helper(x = MAX)`) are not scanned because ctxpack scans method bodies
only.

**CONST-2.** Collected constants are mapped to files using Rails/Zeitwerk
naming conventions only, and only when the mapping is cheap and exact — i.e.
the conventionally derived path exists. A constant whose conventional file
does not exist yields no file entry (it may still surface in the
omitted-candidates or uncertainty notes).

**CONST-2a.** Namespace-relative references resolve lexically: candidate
constant names are built from the innermost enclosing namespace outward (e.g.
bare `Subscriptions` inside `Admin::AccountsController` tries
`Admin::Subscriptions`, then `::Subscriptions`), each candidate is mapped to
its conventional paths, and the first candidate whose file exists wins. One
file per constant reference. References already qualified from root
(`::Billing::Subscriptions`) skip the lexical walk.

**CONST-2b.** Conventional paths are searched under every direct subdirectory
of `app/` except `assets`, `views`, and `javascript`:
`app/<subdir>/<zeitwerk_path>.rb`, subdirectories checked in lexicographic
order, first existing file wins. `lib/` is not searched in v0 — it is not
autoloaded by default in modern Rails and would require reading app
configuration. (Post-v0: add opt-in `lib/` support for apps using
`config.autoload_lib`.)

**CONST-3.** Constant-to-file matches by convention are shallow evidence, not
proof; the packet's uncertainty section reflects this (FMT-8).

**CONST-2c.** When a candidate constant path has no file of its own, the
resolver retries with trailing segments trimmed (`Order::PENDING` → `Order` →
`app/models/order.rb`), because Zeitwerk defines value constants in their
parent's file. Trimming applies within each lexical candidate (CONST-2a)
before moving to the next candidate. The packet reports the file under the
trimmed constant name.

**CONST-4.** Resolved constant files are deduplicated and ordered by first
reference in three groups: action-body constants top-to-bottom, then
applicable same-file callback constants in declaration order, then transitive
same-file callee constants in BFS discovery order. Deduplication is by
resolved file path across all three groups; first occurrence wins. This
ordering decides both which files survive the max-constant-files limit
(LIM-1) and their display order in the packet. Constants dropped by the limit
are named in the omitted-candidates note (LIM-2). Because transitive callee
constants are appended last, they can add context under spare capacity but
cannot evict constants referenced directly by the action or callbacks.

## Views

Rationale (from the Tier 3 offline probe,
[`../eval/tier3-rubydex/RESULTS.md`](../eval/tier3-rubydex/RESULTS.md)): for
view-primary feature tasks (a form field, rendered UI) the load-bearing file
is the view, and none of the resolution above ever reaches it — the
constant resolver only walks Ruby via Zeitwerk convention. The view is
convention-mappable from the action far more cheaply and precisely than a
semantic resolver reaches it; the probe measured a feature-task recall gain
of +0.130 (0.685 → 0.815, control arm, production-only) for a precision cost
of −0.097, a favorable 1.33 recall-gained-per-precision-lost ratio.

**VIEW-1.** After the action resolves (ANCH-3), ctxpack includes the
conventional view template(s) for the action: files on disk matching
`app/views/<controller_path>/<action>.*`, where `<controller_path>` is the
anchor's controller path (namespaced, snake_case) and `<action>` is the
anchor's action token:

```text
setup#index          → app/views/setup/index.*
admin/users#destroy  → app/views/admin/users/destroy.*
```

The action token is taken with any trailing `?`/`!` stripped (view filenames
cannot carry `?`/`!`, consistent with ANCH-1 / TEST-1 rule 2); no other
normalization is applied to the token. Inclusion is existence-gated: if no matching
template exists, no view entry is added and resolution does NOT fail — many
actions render nothing (redirect, `head`, JSON-only via a controller that
renders implicitly, an action whose template lives elsewhere). A missing
conventional template is normal, not an error (contrast ANCH-6, where a
missing *controller* file is a hard failure).

**VIEW-2.** Matching is a single-segment glob under the exact directory only:

- Glob `app/views/<controller_path>/<action>.<ext>` — one path segment
  `<action>`, a dot, then any extension. No recursion into subdirectories.
- Partials (basename beginning `_`) MUST NOT be included. Consequence: an
  action whose name itself begins with `_` (tolerated by ANCH-1) can never
  have its own conventional view included, because the resulting filename is
  indistinguishable from a partial.
- Other actions' templates MUST NOT be included (no prefix/fuzzy match).
- Every format variant that exists matches and is included (e.g.
  `index.html.erb`, `index.json.jbuilder`, `index.turbo_stream.erb`), sorted
  lexicographically. Not restricted to `*.html.*`.

**VIEW-3.** Each included view file carries the `view_candidate` reason code
(FMT-6) and an empty `snippet_ranges` — the template is not Ruby, is not
parsed, and is listed to point the agent at the file, the same list-only
shape `referenced_constant` already uses for files whose snippet set is
empty. v0 does not extract an ERB snippet.

**VIEW-4.** v0 MUST NOT parse the action body for `render` / `redirect_to` /
`head` to confirm or suppress the conventional view. That is render-target
inference (call-graph-shaped, the class of analysis v0 excludes, per PARSE-1
/ ANCH-5). Consequence: a view entry may be a false positive when the action
renders a different template or redirects. This is disclosed, not hidden
(VIEW-6).

**VIEW-5.** View files count against the LIM-1 `max_total_files` invariant
(8) via a dedicated `max_view_files` sub-limit of 2. File ordering places the
action view(s) ahead of constant files and test candidates within
`max_total_files` — see LIM-1's priority rule. Views truncated by either
limit MUST be named in the LIM-2 omitted-candidates note.

**VIEW-6.** View inclusion is convention-only evidence (like CONST-3, but the
action→template default is stronger than constant guessing). The packet's
`## Uncertainty` section MUST disclose that included views were matched by
convention and not confirmed against the action's actual render target
(VIEW-4), via the uncertainty code `view_inferred_by_convention` (FMT-7). The
`## Retrieve more only if needed` section (FMT-2 §8) maps that code to one
templated suggestion (e.g. "confirm the action renders this template; it may
redirect or render another").

**VIEW-7.** View resolution is a pure function of the on-disk view directory
and the anchor — no clocks, no globbing-order ambiguity (lexicographic sort,
VIEW-2). DET-2 file ordering places views at the position fixed by VIEW-5's
priority rule.

## Test candidates

Rationale (from design): test discovery must be as rule-bound as controller
resolution, or the determinism claim is hollow for exactly the fuzziest part
of the packet.

**TEST-1.** Discovery first selects exactly one test family, then applies
exactly two path rules within that family, in order.

RSpec family is selected when the application root contains `spec/` and either
`spec/rails_helper.rb` exists or `Gemfile` / `Gemfile.lock` names
`rspec-rails`. Otherwise the Minitest family is selected.

Minitest rules:

1. **Conventional controller test** —
   `test/controllers/<controller_path>_controller_test.rb`, included only if
   the file exists.
2. **Integration matches** — files matching `test/integration/*_test.rb`
   whose basename contains both the controller token (final path segment,
   e.g. `accounts`) and the action name, as underscore-delimited tokens.

RSpec rules:

1. **Conventional controller spec** —
   `spec/controllers/<controller_path>_controller_spec.rb`, included only if
   the file exists.
2. **Request spec matches** — files matching `spec/requests/*_spec.rb` whose
   basename contains both the controller token and the action name, as
   underscore-delimited tokens. `spec/system/` is out of v0 scope and MUST NOT
   be searched.

For both families, rule 2 uses this matching rule **[fixed by spec]**: split
the basename on underscores; the controller token must be present, and the
action's tokens must appear as a contiguous in-order subsequence
(`bulk_update` matches `accounts_bulk_update_flow_test.rb`, not
`bulk_accounts_update_test.rb`). Action tokens are taken with any trailing
`?`/`!` stripped and the empty token from a leading `_` dropped (`merged?`
matches `oddities_merged_test.rb`). **[amended: consequence of the ANCH-1
action-grammar amendment — filenames cannot carry `?`/`!`]** Multiple rule 2
matches are sorted lexicographically.

**TEST-2.** The selected family's combined list is truncated at the
max-test-files limit (LIM-1); truncation MUST be reported in the
omitted-candidates note.

**TEST-3.** Minitest rules use the `minitest_candidate` reason code. RSpec
rules use the `rspec_candidate` reason code. The packet's "Why" line states
which family rule matched. Rule 2 matches in either family MUST always carry
the `test_inferred_by_path` uncertainty note.

**TEST-4.** No test-content matching in v0: path rules only, no grepping test
bodies for routes or controller names.

**TEST-5.** If neither rule in the selected family matches, the packet says so
explicitly rather than guessing from another framework or test directory.

**TEST-6.** Each included test file yields a suggested command in the
packet's "Tests to run" section: Minitest candidates use
`bin/rails test <path>`; RSpec candidates use `bundle exec rspec <path>`.

## Limits

**LIM-1.** v0 limits, as internal constants (not CLI flags — CLI-18):

```text
max total files:            8
max constant files:         4
max view files:             2
max test files:             2
max snippet lines per file: 120
```

Max total files is an outer safety invariant over the whole packet, not an
allocation target. Before views, v0's categories (1 controller + 4 constant
files + 2 test files = 7) made 8 unreachable by construction; that clause
anticipated exactly this outcome — adding the `view_candidate` reason code is
the "future reason codes (views, mailers, …)" case that needed a deliberate
spec change. With views, the categories now sum to 1 + 2 + 4 + 2 = 9, one over
the ceiling, so it is reachable: when a packet's candidates across categories
would exceed 8, files are included in priority order — controller → action
view(s) → constants → test candidates (VIEW-5) — so a high-signal action view
is not squeezed out by a fourth constant file or a rule-2 test match, and
whichever category is still filling when the ceiling is reached is truncated
there. `max_total_files` itself stays at 8; it is not raised to
`8 + max_view_files`.

**LIM-2.** When any limit truncates candidates, the packet MUST include an
explicit omitted-candidates note naming what was left out (FMT-9). Silent
omission is a bug.

**LIM-3.** The limits exist to prevent context dumping and to keep packets
deterministic and reviewable — not to claim completeness. Whether these
values hide essential context is an open question tracked in `design.md`;
changing them requires updating this spec and the fixture evals together.

**LIM-4.** When a file's snippets exceed the per-file line budget, allocation
is: the action snippet first — head-truncated at the budget, with an explicit
truncation marker, if the method alone exceeds it — then applicable callbacks
in declaration order, each included only if it fits whole in the remaining
budget. Callback snippets are never cut mid-method. Every dropped or
truncated snippet is named in the omitted-candidates note (LIM-2).
