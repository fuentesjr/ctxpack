# Spec: View resolution (FROZEN)

**Status: FROZEN 2026-07-08 (user sign-off).** This is the view-layer spec
drafted after the Tier 3 offline probe
([`../eval/tier3-rubydex/RESULTS.md`](../eval/tier3-rubydex/RESULTS.md)). Its
four open design decisions were resolved by explicit user sign-off on
2026-07-08; the requirements below are final. Its requirements have been
folded into `packet-compilation.md` and `packet-format.md` (see "Folded into
the canonical specs" at the end for exactly where); this file stays as the
rationale record — VIEW-1..VIEW-7 numbering is stable.

Requirement prefix: `VIEW`. Numbering is stable.

## Why views (rationale)

The probe established that the packet's measured value is *landing the first
load-bearing file fast*, not completeness. For view-primary feature tasks
(adding a form field, changing rendered UI) the load-bearing file **is the
view** — and v0's resolver, which only reaches Ruby via Zeitwerk convention,
never includes it. The consequence was measured: the only two treatment-arm
diff-quality dings in the entire 72-session expansion grid (publify t1
`setup#index`, sessions P06/P20) were backend-only fixes that omitted the setup
form and its locale — "an operator can't actually choose the nickname through
the UI." The packet steered the agent to the controller but not the template.

The view is **convention-mappable from the action** far more cheaply and
precisely than a semantic resolver reaches it. The probe's four-column recompute
(feature tasks, control arm, production-only recall/precision):

| resolver | recall | precision | recall gained per precision lost |
|---|---|---|---|
| convention (today) | 0.685 | 0.653 | — |
| **+ view convention** | **0.815** | 0.556 | **1.33 (favorable)** |
| + Rubydex semantic | 0.769 | 0.341 | 0.27 (halves precision) |

The view layer is the efficient, dependency-free recall gain. (Rubydex is
deferred — see RESULTS.md; `design.md`'s "no Rubydex dependency" non-goal
stands.)

## Requirements

**VIEW-1 (convention mapping).** After the action resolves (ANCH-3), ctxpack
includes the conventional view template(s) for the action: files on disk
matching `app/views/<controller_path>/<action>.*`, where `<controller_path>` is
the anchor's controller path (namespaced, snake_case) and `<action>` is the
anchor's action token:

```text
setup#index          → app/views/setup/index.*
admin/users#destroy  → app/views/admin/users/destroy.*
```

The action token is taken with any trailing `?`/`!` stripped and a leading `_`'s
empty token dropped, consistent with ANCH-1 / TEST-1 rule 2 (view filenames
cannot carry `?`/`!`). Inclusion is existence-gated: if no matching template
exists, **no view entry is added and resolution does NOT fail** — many actions
render nothing (redirect, `head`, JSON-only via a controller that renders
implicitly, an action whose template lives elsewhere). A missing conventional
template is normal, not an error (contrast ANCH-6, where a missing *controller*
file is a hard failure).

**VIEW-2 (literal, existence-gated matching).** Matching is a single-segment
glob under the exact directory only:

- Glob `app/views/<controller_path>/<action>.<ext>` — one path segment
  `<action>`, a dot, then any extension. No recursion into subdirectories.
- Partials (basename beginning `_`) MUST NOT be included.
- Other actions' templates MUST NOT be included (no prefix/fuzzy match).
- **Frozen: all format variants.** Every format variant that exists matches
  and is included (`index.html.erb`, `index.json.jbuilder`,
  `index.turbo_stream.erb`), sorted lexicographically. Not restricted to
  `*.html.*` — simplest rule, existence-gated, and it matches the measured
  +view numbers above (the probe's one precision-hurting view addition,
  campfire t1 `index.json.jbuilder`, is already priced into that 0.556
  precision figure).

**VIEW-3 (reason code, no snippet).** Each included view file carries the
`view_candidate` reason code and an empty `snippet_ranges` — the template is not
Ruby, is not parsed, and is listed to point the agent at the file (the same
list-only shape `referenced_constant` already uses for files whose snippet set
is empty). **Frozen: list-only, no snippet.** v0 does not extract an ERB
snippet — no ERB truncation policy and no non-Ruby fence; less code, and the
list-only shape is sufficient to point the agent at the file.

**VIEW-4 (no render-target analysis — frozen).** v0 MUST NOT parse the action
body for `render` / `redirect_to` / `head` to confirm or suppress the
conventional view. That is render-target inference (call-graph-shaped, the
class of analysis v0 excludes, per PARSE-1 / ANCH-5). Consequence: a view
entry may be a false positive when the action renders a different template or
redirects. This is disclosed, not hidden (VIEW-6). v0 stays convention-only
and existence-gated; it does not scan for explicit render targets.

**VIEW-5 (budget & priority).** View files count against the LIM-1
`max_total_files` invariant (8). Today `1 controller + 4 constants + 2 tests = 7`
makes 8 unreachable "by construction" (LIM-1) — adding views changes that, which
is exactly the "deliberate spec change" LIM-1 anticipated for "future reason
codes (views, mailers, …)". Two sub-decisions, both frozen:
1. **`max_view_files` = 2.** An action rarely has more than one or two format
   templates worth surfacing.
2. **Priority within `max_total_files`: reorder, ceiling unchanged.** Because
   1+4+2 already = 7, views can collide with the 8-file ceiling. File ordering
   is **controller → action view(s) → constants → test candidates**, so the
   high-signal action view is not squeezed out by a 4th constant or a rule-2
   test match. `max_total_files` stays at 8 — it is NOT raised to
   `8 + max_view_files`.

Views truncated by either limit MUST be named in the LIM-2 omitted-candidates
note.

**VIEW-6 (uncertainty).** View inclusion is convention-only evidence (like
CONST-3, but the action→template default is stronger than constant guessing).
The packet's `## Uncertainty` section MUST disclose that included views were
matched by convention and not confirmed against the action's actual render
target (VIEW-4), via a new uncertainty code `view_inferred_by_convention`. The
`## Retrieve more only if needed` section (FMT-2 §8) maps that code to one
templated suggestion (e.g. "confirm the action renders this template; it may
redirect or render another").

**VIEW-7 (determinism & ordering).** View resolution is a pure function of the
on-disk view directory and the anchor — no clocks, no globher ordering
ambiguity (lexicographic sort, VIEW-2). DET-2 file ordering extends to place
views at the frozen position chosen in VIEW-5's priority rule.

## Folded into the canonical specs (2026-07-08)

The frozen decisions above were integrated as follows (per the cross-spec
contract in `specs/README.md`):

- **`packet-compilation.md`** — added a `## Views` section (VIEW-1..VIEW-7);
  updated the pipeline diagram to place views ahead of constants
  (`… → action + applicable callbacks → views → referenced constants →
  constant files → test candidates → limits`), matching the VIEW-5 priority /
  DET-2 display order (views have no data dependency on constants); amended
  **LIM-1** to add `max_view_files = 2` and the priority rule, and revised
  LIM-1's "unreachable by construction" paragraph.
- **`packet-format.md`** — added `view_candidate` to the FMT-6 reason-code
  registry; added `view_inferred_by_convention` to the FMT-7 uncertainty
  registry; extended FMT-8's required uncertainty prose; extended DET-2 with
  the view position; added a "Why" template line for `view_candidate`
  (FMT-4a).
- **`specs/README.md`** — added `VIEW` to the `packet-compilation.md`
  requirement-prefix row. (Views were never named in the `design.md`
  non-goals list this file echoes, so there was nothing to drop there.)
- **`design.md`** — reconciled: v0 now includes conventional action views;
  recorded the probe evidence and the render-target-analysis boundary
  (VIEW-4); the "no Rubydex dependency" non-goal stands unchanged.

Still pending — out of scope for this spec-only pass, required before this
spec is implemented:

- **Fixture evals** (`add-fixture-eval`, red-then-green) — new YAML cases:
  namespaced action view, multi-format-variant action, action with no template
  (no entry, no failure), partial excluded, budget truncation. Author red first.
- **Tier 0 corpus re-scan** — this changes compiler behavior, so the re-scan at
  the spike SHAs is **mandatory** before acceptance (per PROJECT_TRACKER
  "Working process"). View inclusion is additive (new files), so per-anchor
  *resolution* of existing categories should not regress; confirm that.

## Companion work (related, deliberately NOT in this spec)

The probe's verdict also recommends two adjacent changes. They are kept out of
this spec to keep it small and independently reviewable (the constant widening
is a CONST amendment, not a view feature; the locale item is a note, not a
resolver). Sequence them as the user prefers:

1. **Widen the constant scan (CONST-1) from the action body to the whole
   controller class.** The probe's entire Rubydex recall win was one file
   (campfire t1 `app/models/user.rb`, referenced as `User.all` in a *private
   helper* the action-body scan skips). A full-controller-file constant scan
   captures it with no dependency. **Caveat to weigh:** on multi-action
   controllers this can pull constants from unrelated actions — a precision cost
   CONST-1's action-body narrowing deliberately avoids. Options: whole-class
   (simplest), or action body + same-file methods transitively called from the
   action (precise, needs intra-file call-graph). This wants its own
   red-then-green cases and its own freeze.
2. **Locale as a standing pointer, not a packet file.** The locale misses are
   *newly-added* keys (e.g. publify's `nickname`); a base-tree scan fires on
   none, and snippeting a truncated giant `en.yml` to move a file-level recall
   number would be metric-gaming a "small by construction" packet. Surface
   "user-facing strings live in `config/locales/`" as templated Uncertainty /
   "Retrieve more only if needed" prose instead.
