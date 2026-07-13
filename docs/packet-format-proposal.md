# Proposal: packet format v2 — merged

Status: **accepted and implemented locally, uncommitted.** The normative
contract now lives in [`specs/packet-format.md`](../specs/packet-format.md);
this document remains the decision record for the four-slice design.
Written 2026-07-12. Merges two independent drafts: an evidence-first
improvement proposal and a developer-happiness redesign; where they conflicted,
the resolution and its reason are stated inline.

## Final resolution (2026-07-13)

- All four slices landed atomically by explicit user choice: the user is the
  only current ctxpack consumer, so preserving a v1 manifest mode would add
  migration machinery without protecting a real compatibility need.
- The Slice 3 statement that manifest arrays were untouched applies only to
  that Markdown slice; Slice 4 deliberately replaces the manifest schema with
  the lossless v2 fact representation.
- Tier 1 fixture YAML has no Markdown-prose expectation field. EVAL-5 prefers
  stable packet/manifest assertions over Markdown parsing; public renderer
  tests own exact Markdown structure, while `expect.manifest` covers selected
  top-level stable facts.
- The release-boundary three-app harness rerun remains pending explicit user
  sign-off because it changes every treatment prompt and costs approximately
  50M subject tokens. It has not been run as part of implementation.

Evidence base: [`eval/tier2/RESULTS.md`](../eval/tier2/RESULTS.md),
[`eval/tier2-expansion/RESULTS.md`](../eval/tier2-expansion/RESULTS.md)
(exploration A/B, blind diff quality, packet-vs-diff coverage), and
[`eval/tier3-rubydex/RESULTS.md`](../eval/tier3-rubydex/RESULTS.md).

## Summary

Keep the packet's information model — deterministic provenance, bounded
evidence, explicit uncertainty, runnable commands — and redesign its Markdown
surface around three jobs: establish the task and anchor, show the smallest
ordered map of files and evidence needed to start work, and end with runnable
tests and packet-specific follow-ups. The retrieval rules that produced the
Tier 2 wins do not change.

Four slices, in landing order:

| Slice | Contents | Character |
|---|---|---|
| 1 | Task blockquote containment · visible line ranges · honest repo-stamp label · Markdown format-version line | Correctness + navigation; two verified defects |
| 2 | `## How to use this packet` · `## Inspect first` map · `## Evidence` for snippets only · `## Run` | Information hierarchy; targets the one measured net-negative |
| 3 | `## Follow-ups` (absorbs Uncertainty, Omitted candidates, Retrieve-more) · one-line `Scope:` for standing v0 boundaries | Tail compression |
| 4 | Manifest v2 (lossless fact representation) | Machine fidelity; landed atomically by user choice |

All slices are renderer/manifest-layer: no resolution, callback, constant,
test-candidate, or limit behavior changes, so Tier 0 is N/A throughout (state
it explicitly per change). Determinism (DET-1..DET-5) is preserved — every new
line is templated, no timestamps, no model prose, limit values read from
`Ctxpack::Compiler::LIMITS`.

## What the evidence says (baseline the redesign must not regress)

- **The win is exploration efficiency, and the entrypoint drives it.** The
  packet lands the first load-bearing read 50–89% sooner on feature/behavior
  tasks across three apps and both frameworks. Coverage shows the win is
  near-orthogonal to recall (bug tasks: 1.00 recall, no win; features: won at
  0.69) — value = landing the first file fast, not enumerating every file.
- **Code content is the driver, not the test pointer** (wins persist, even
  strengthen, with no test candidate in the packet).
- **The one remaining net-negative is task-shaped.** On all three expansion
  bug tasks, treatment agents read the packet's files before following the
  failing test that already localized the work. The packet cannot win there;
  the current "Files to inspect first" framing makes it pay a small toll.
- **File salience changes carry a known harm shape.** The only two quality
  dings in 72 sessions (pub t1) came from the packet under-cueing the view
  layer — since fixed by the view-resolution pass. Lesson applied below: the
  redesign keeps one flat, DET-2-ordered file map; it does not demote any
  file class into a lower tier.
- **The limits are fine.** The 8/4/2/2/120 caps never bit in the expansion
  grid; the recall gap was resolution scope, not budget. No limit changes.

## Two verified defects (independent of the redesign)

1. **Task Markdown escapes the Task section.**
   `markdown_renderer.rb:34` appends `packet.task` verbatim. `--task-file`
   deliberately accepts multiline issue bodies, so a task containing
   `## Notes`, a thematic break, or a fenced block restructures the packet
   document itself. Fix: render every task line as a Markdown blockquote,
   which safely contains headings, lists, fences, and blank lines, and
   visually separates user-supplied input from ctxpack's deterministic
   output. The raw task string stays unmodified on the packet object and in
   the manifest.

2. **The unknown repo-stamp label claims a cause it cannot know.**
   `markdown_renderer.rb:49` renders `unknown (not a git repository)` for any
   nil commit — but since the FMT-11 Git-unavailable fallback, a nil commit
   also means "Git executable missing," where that diagnosis is false. Fix:
   one honest label for the observable state, `unknown (Git state
   unavailable)`, with no new packet field required. Manifest v1 keeps
   `commit: null`; v2 adds an `available` boolean (Slice 4).

Both ship in Slice 1 regardless of the rest of this proposal's fate.

## Proposed Markdown shape

Deliberate departure from the developer-happiness draft: the `## Task` and
`## Anchor` headings are **kept**. Collapsing them into an unlabeled header
block was the largest FMT-2 rewrite for the smallest gain (five bullets →
three lines) and removed the two stable headings informal parsers most
plausibly key on. Everything else in that draft's shape survives with the
headings intact.

````markdown
# ctxpack context packet

## Task

> Implement billing upgrade.
>
> ## Acceptance criteria
>
> - Prorate the existing subscription.

## How to use this packet

- If the task already names a failing test, an error, or an exact location,
  start there and use this packet to verify coverage — not as a reading list.
- Otherwise, start with `app/controllers/accounts_controller.rb` and open the
  other listed files only as the task touches them.

## Anchor

- Anchor: `accounts#upgrade`
- Controller: `AccountsController`
- Action: `upgrade`
- File: `app/controllers/accounts_controller.rb`
- Generated from: 1b55cce (clean)
- Format: 2
- Scope: routes, superclass/concern callbacks, and locale files are not
  scanned by ctxpack v0; use `bin/rails routes -g upgrade` for endpoints, and
  check `config/locales/` if the task touches user-facing copy.

## Inspect first

1. `app/controllers/accounts_controller.rb` — `controller_action`: action and
   applicable callbacks
2. `app/views/accounts/upgrade.html.erb` — `view_candidate`: conventional
   template for `accounts#upgrade`
3. `app/services/billing/subscriptions.rb` — `referenced_constant`:
   `Billing::Subscriptions`
4. `app/jobs/sync_billing_account_job.rb` — `referenced_constant`:
   `SyncBillingAccountJob`
5. `test/controllers/accounts_controller_test.rb` — `minitest_candidate`:
   conventional controller test path
6. `test/integration/accounts_upgrade_test.rb` — `minitest_candidate`:
   path-inferred; verify coverage

## Evidence

### `app/controllers/accounts_controller.rb`

`controller_action` — action `upgrade` · lines 8–13

```ruby
def upgrade
  subscription = Billing::Subscriptions.new(@account)
  subscription.upgrade!(plan: params[:plan])
  SyncBillingAccountJob.perform_later(@account.id)
  redirect_to account_path(@account)
end
```

`before_action_callback` — callback `set_account` applies · lines 21–23

```ruby
def set_account
  @account = Account.find(params[:id])
end
```

## Run

- `bin/rails test test/controllers/accounts_controller_test.rb`
- `bin/rails test test/integration/accounts_upgrade_test.rb` — path-inferred;
  verify coverage

## Follow-ups

- Inspect `around_action` callback `with_billing_audit`; it applies but is
  not snippeted in v0.
- Inspect the inline `before_action` block; it applies but has no method
  snippet.
- Inspect `test/integration/accounts_upgrade_test.rb` to confirm the
  path-inferred candidate covers the task.
- Verify convention-only constant match `Billing::Subscriptions` →
  `app/services/billing/subscriptions.rb` if the task depends on it.
````

Normative section order: title · Task (blockquoted) · How to use this packet ·
Anchor (with Format and Scope lines) · Inspect first · Evidence (omitted when
no snippets exist) · Run (or the explicit no-candidate statement, TEST-5) ·
Follow-ups (omitted when empty). File order inside Inspect first and Evidence
is the existing DET-2 order, unchanged.

## Rationale per change

### `## How to use this packet` (Slice 2)

The only change here aimed at a *measured* cost. Two fixed templated bullets;
the second interpolates the entrypoint path. The agent — not ctxpack — decides
which branch applies, so the packet stays a pure function of its inputs. This
deliberately rejects task-shape *detection* (classifying freeform `--task`
text inside a deterministic tool is a brittle heuristic); the agent knows
whether it holds a failing test, and has strictly more information than the
compiler does. Directly testable: bug-task treatment overhead in a harness
re-run.

### `## Inspect first` + `## Evidence` (Slice 2)

Today every included file gets a `###` subsection even when it carries only
provenance text, and test files then reappear as commands — structure without
evidence, and ~37% of packet files (control-arm precision 0.63, mostly
constants) go untouched by the eventual diff while being framed as "inspect
first" at entrypoint priority.

The split makes the packet a map plus embedded source: one flat ordered
inventory line per file (path — reason code — templated phrase), and expanded
subsections only where a snippet exists. Repeating a snippet-bearing path once
in the map and once above its source is deliberate summary/detail structure;
pointer-only files stop generating empty-looking sections.

Two constraints the inventory must honor:

- **FMT-3 survives per-file**: each inventory line carries both the literal
  reason code and a templated human phrase. (The developer-happiness draft's
  example dropped visible codes from pointer-only files, contradicting its own
  design rules — fixed here.)
- **No tiering.** An earlier draft split constants into a demoted
  "consult as needed" section. Rejected: it re-creates the pub-t1 harm shape
  (under-cueing a file class), and the precision drag it targeted was never
  shown to hurt outcomes. The flat DET-2 map gets the dedup benefit without
  the salience risk; the How-to-use section carries the "don't read
  everything" signal instead.

### Visible line ranges (Slice 1)

`snippet_ranges` already exist on the packet object and in the manifest; the
primary artifact hides them. Rails developers and agents navigate by
`path:line`. Render each evidence item's range on its provenance line
(`· lines 8–13`; multiple ranges as a stable comma-separated list). No
synthetic line numbers inside fences — snippets stay literal, copyable source.

### `## Run` (Slice 2)

The command is the test candidate's primary interface; confidence-changing
provenance (`— path-inferred; verify coverage`) belongs beside the command,
not in a distant file subsection. Replaces `## Tests to run`; keeps the
explicit TEST-5 no-candidate statement.

### `## Follow-ups` + `Scope:` line (Slice 3)

Today the tail is three sections (`## Uncertainty`, `## Omitted candidates`,
`## Retrieve more only if needed`) where the third is by construction a
restatement of the first (FMT-2 §8 maps each code to one templated
suggestion), and standing v0 boundaries (routes, external callbacks, locales)
are re-announced in every packet as if discovered about this one — alert
fatigue that buries the packet-specific guesses.

- Standing boundaries compress to the single templated `Scope:` line under
  `## Anchor`, retaining both embedded actions (routes command, locales
  pointer). Precedent: the locale-pointer pass already chose
  action-embedded-in-note over a separate retrieve-more bullet (decision log
  2026-07-09); this generalizes it.
- Everything packet-specific becomes one imperative bullet in
  `## Follow-ups`: what to do and why in one deterministic sentence. Coded
  uncertainties, convention-only constant matches, and FMT-9 omissions
  ("Inspect omitted constant `EpsilonFive`; the 4-constant limit was
  reached" — value read from `LIMITS`) all land here, each named specifically.
- Plain bullets, not `- [ ]` task-list syntax (an open question in the
  developer-happiness draft, decided here): checkboxes imply persistent
  state a static artifact doesn't have, and render inconsistently in
  terminals. The imperative verb carries the operational emphasis.

Within Slice 3, nothing is lost: FMT-7 codes and the then-current manifest
arrays are untouched; only the second registry-to-prose mapping and the
boilerplate repetition go. Slice 4 replaces those arrays as described below.

### `Format:` line (Slice 1)

The manifest is versioned; the Markdown is not, and this proposal is itself a
breaking Markdown change. One line in `## Anchor` (`- Format: 2`), bumped by
any change visible to a heading- or label-parsing consumer. Three tokens of
insurance against exactly this migration recurring unbadged.

### Manifest v2 (Slice 4)

The v1 manifest omits facts central to the Markdown and packet object: task
text, evidence subjects and truncation state, test paths/rules, uncertainty
subjects, omitted candidates, the no-candidate state, repo availability.
Acceptable for a Tier 1 assertion aid; not for a public `--manifest` flag.
Decide which it is before the gem's contract hardens. If public, ship v2 as a
lossless fact representation (per-file `evidence[]` with subject +
`snippet_ranges` + `truncated`; `tests[]` with path + rule; `follow_ups[]`
with code + subject; `omitted_candidates`; `repo.available`) — serialized
facts, never rendered prose. Separate pass unless a real consumer needs it
atomically with the Markdown change; keep v1 emission only if an actual
consumer exists.

## Explicitly not proposed

- **JSON- or XML-primary packets.** MAN-1's rationale stands, and the Tier 2
  wins were measured on the Markdown. The manifest serves machines.
- **Raising or adding limits.** The caps never bit; omissions surface as
  Follow-ups bullets.
- **LLM-generated summaries or descriptions.** Violates DET-3/DET-4;
  determinism is the tool's identity.
- **Task-shape-adaptive packet contents.** The How-to-use section hands the
  decision to the agent instead of embedding a heuristic classifier.
- **Role-tiered file sections.** Rejected above (pub-t1 harm shape; precision
  drag not shown to hurt).
- **Rubydex-enriched content.** Deferred with data: +0.083 feature recall
  (one file, convention-reachable) for a precision halving. Revisit only with
  a corpus whose misses are cross-file-call-edge shaped.
- **Snippets for constant/view files.** Nothing says the listed paths are
  under-consumed for lack of quoted code, and the precision profile already
  says over-inclusion. Reopen only if dogfooding surfaces the need.

## Spec impact

FMT-2 (section list — the largest amendment, with §8 withdrawn in place),
FMT-4/FMT-4a (evidence line shape, inventory lines), FMT-5 (range display),
FMT-8 (Follow-ups template + Scope split), FMT-9 (omissions as Follow-ups),
FMT-11 (stamp label). FMT-3, FMT-6, FMT-7, FMT-10, FMT-12, and DET-1..DET-5
are preserved as written; DET-2 order is unchanged, only where files render
moves. MAN-2 → v2 in Slice 4. Every amendment lands with `design.md`
reconciled in the same commit; no code is renumbered or reused. README,
`docs/examples.md`, and `docs/faq.md` re-verified against real output in the
same passes.

## Migration and evidence gates

1. **Before any rendering change:** search the repo and known workflows for
   consumers parsing current headings. Tier 1 fixture evals and the recorded
   Tier 2 prompt templates are known consumers — recorded evidence
   (`eval/*/packets/`, transcripts, golden prompts) is never regenerated;
   frozen packets are historical format-1 artifacts.
2. **Slice 1** (blockquote, ranges, stamp label, Format line): the
   task-heading escape gets a red renderer test *before* the fix — a task
   body containing `## Injected` must not produce a peer section. Then
   fixture evals red-then-green, full suite green, Tier 0 N/A stated.
3. **Slice 2, then Slice 3:** same gates; public renderer expectations are
   updated and reviewed by hand, while fixture YAML continues to assert stable
   packet/manifest facts per EVAL-5. The diff is the review surface. Slices
   stay independently reviewable; no compiler-retrieval change rides along
   with any of them.
4. **Slice 4** (manifest v2): compatibility tests + a documented versioning
   policy; landed atomically with Slices 1–3 per the final resolution above.
5. **Behavioral validation:** one release-boundary re-run of the existing
   three-app harness (~50M subject tokens, ≈$20 — user sign-off required),
   justified more strongly here than for an incremental change because every
   prompt a treatment agent sees changes shape. Watch items, pre-stated:
   (a) bug-task treatment overhead shrinks (the How-to-use hypothesis);
   (b) feature/behavior LBR wins do not regress (the restructuring risk);
   (c) diff quality stays at ceiling. Any usefulness claim comes from this
   new pre-registered run — never from reinterpreting the frozen Tier 2
   evidence.

## Acceptance criteria

- A task containing headings, lists, blank lines, and fenced code cannot
  alter the packet's top-level section structure.
- A reader can identify the anchor, entrypoint, repo state, first files,
  tests, and actionable gaps without reading duplicated prose.
- Every included file retains deterministic human and machine provenance on
  one line; pointer-only files create no empty-looking subsections.
- Every rendered snippet exposes its exact 1-based inclusive source range.
- Standing v0 boundaries appear exactly once; packet-specific findings appear
  exactly once, each as one imperative follow-up.
- Test candidates are explained and operationalized in the same place.
- Unknown repo state claims no cause ctxpack cannot distinguish.
- The Markdown declares its format version.
- Full suite green, recorded experiment data untouched, no new dependency,
  Ruby 3.4 compatible.

If only one slice ships, ship Slice 1: two verified defects and two lines of
navigation/versioning value, with no structural risk.
