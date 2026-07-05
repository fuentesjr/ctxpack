# Spec: Packet compilation

Status: Draft. Source: `design.md` — "Settled v0 direction", "Parsing and
static analysis strategy", "Test candidate rules", "v0 packet limits".

Compilation is the pipeline from anchor to internal packet object:

```text
anchor → controller file → action + applicable callbacks → referenced
constants → constant files → test candidates → limits applied → packet object
```

Rendering the packet object is specified in `packet-format.md`.

## Anchor resolution

**ANCH-1.** Accepted anchor format is `controller#action`, optionally
namespaced with `/`:

```text
accounts#upgrade
admin/accounts#upgrade
```

Tokens are snake_case, matching the shape shown by `bin/rails routes`.

**ANCH-2.** The anchor maps to a controller file purely by convention:

```text
accounts#upgrade       → app/controllers/accounts_controller.rb
admin/accounts#upgrade → app/controllers/admin/accounts_controller.rb
```

No route table is consulted; Rails is never booted.

**ANCH-3.** The action MUST be directly defined as `def <action>` in the
resolved controller file. Inherited actions, concern-defined actions, and
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
arrays (or their absence). A `before_action` with dynamic filter arguments
(computed symbols, `if:`/`unless:` procs deciding inclusion, splats, etc.)
MUST NOT be guessed at; it becomes an uncertainty note instead.

**CB-2a.** `skip_before_action` declarations in the same controller class are
honored under the same literalness rule: a callback skipped for the action via
a literal `skip_before_action` (unconditional, or with literal `only:` /
`except:` arrays covering the action) is excluded from the packet. A
`skip_before_action` with dynamic filter arguments MUST NOT be guessed at; the
affected callback stays in the packet and the skip becomes an uncertainty
note.

**CB-3.** For applicable callbacks whose methods are defined in the same
controller file, ctxpack extracts a snippet of the method (see FMT-5). These
snippets are additional ranges on the controller file entry and share the
per-file snippet-line limit (LIM-1); they do not get a separate budget.

**CB-4.** Callbacks declared outside the controller file — in a superclass or
an included concern — are NOT resolved in v0 (consistent with ANCH-5). The
packet MUST list their names as unresolved rather than omitting them.

## Constants

**CONST-1.** ctxpack collects obvious constants referenced inside the action
body and inside the bodies of applicable same-file callbacks. "Obvious" means
syntactically present constant references (e.g. `Billing::Subscriptions`,
`SyncBillingAccountJob`) — no receiver-type inference, no call-graph
construction.

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
reference: action body top-to-bottom, then applicable callbacks in declaration
order. This ordering decides both which files survive the max-constant-files
limit (LIM-1) and their display order in the packet. Constants dropped by the
limit are named in the omitted-candidates note (LIM-2).

## Test candidates

Rationale (from design): test discovery must be as rule-bound as controller
resolution, or the determinism claim is hollow for exactly the fuzziest part
of the packet.

**TEST-1.** Discovery applies exactly two rules, in order:

1. **Conventional controller test** —
   `test/controllers/<controller_path>_controller_test.rb`, included only if
   the file exists.
2. **Integration matches** — files matching `test/integration/*_test.rb`
   whose basename contains both the controller token (final path segment,
   e.g. `accounts`) and the action name, as underscore-delimited tokens.
   Matching rule **[fixed by spec]**: split the basename on underscores; the
   controller token must be present, and the action's tokens must appear as a
   contiguous in-order subsequence (`bulk_update` matches
   `accounts_bulk_update_flow_test.rb`, not `bulk_accounts_update_test.rb`).
   Multiple matches are sorted lexicographically.

**TEST-2.** The combined list is truncated at the max-test-files limit
(LIM-1); truncation MUST be reported in the omitted-candidates note.

**TEST-3.** Both rules use the `minitest_candidate` reason code. The packet's
"Why" line states which rule matched. Rule 2 matches MUST always carry the
`test_inferred_by_path` uncertainty note.

**TEST-4.** No content matching in v0: path rules only, no grepping test
bodies for routes or controller names.

**TEST-5.** If neither rule matches, the packet says so explicitly rather
than guessing.

**TEST-6.** Each included test file yields a suggested command in the
packet's "Tests to run" section, of the form
`bin/rails test <path>`.

## Limits

**LIM-1.** v0 limits, as internal constants (not CLI flags — CLI-18):

```text
max total files:            8
max constant files:         4
max test files:             2
max snippet lines per file: 120
```

Max total files is an outer safety invariant over the whole packet, not an
allocation target. With v0's categories (1 controller + 4 constant files +
2 test files) it is unreachable by construction; it exists so future reason
codes (views, mailers, …) cannot grow packets past 8 without a deliberate
spec change.

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
