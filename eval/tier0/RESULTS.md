# Tier 0 anchor viability spike — results

Executed 2026-07-05 against the pre-registered definition in
[`eval-plan.md`](../../eval-plan.md) ("Tier 0 — anchor viability spike").
Gates and taxonomy were fixed before any data was collected and were not
adjusted.

## Verdict

**Average engine-excluded resolution rate: 91.0% → ≥ 70% gate passes.**
Per the pre-registered decision rule: build the vertical slice as designed;
stand up Tier 1 in CI. No anchor-rule rework is required before pass 2.

| App | SHA | Pairs | Resolved | Rate |
|---|---|---|---|---|
| Mastodon | `163f96cee4dea23365bff9b433871e68d20d9ee7` | 616 | 568 | 92.2% |
| Discourse | `28b003a38d82c354ffc49bac23b655de9664e478` | 755 | 727 | 96.3% |
| Zammad | `50384f4c390e8abed07694897956c2f8e176208d` | 596 | 503 | 84.4% |
| **Average (pre-registered metric)** | | | | **91.0%** |
| Pooled (all 1,967 pairs) | | 1,967 | 1,798 | 91.4% |

Success = `Ctxpack.compile` returned a packet. **Zero post-anchor compiler
crashes across all 1,967 real-app pairs** — incidental but strong stress-test
signal for the pass 1 compiler.

## Method

- Apps: the eval plan's example trio (Mastodon, Discourse, Zammad); all three
  extracted cleanly, no swaps needed.
- Route tables were extracted via the plan's documented fallback, since
  booting three large apps was impractical: each app's `config/routes.rb`
  (plus split route files) was evaluated against a real
  `ActionDispatch::Routing::RouteSet` from the app's own pinned actionpack
  version (Mastodon 8.1.3; Discourse and Zammad 8.0.5), with a fake `Rails`
  module and a permissive constant stub standing in for app constants,
  constraints, and mounted engines (`extract_routes.rb`). Real Rails code
  performs all `resources`/`namespace`/`scope`/`concern` expansion.
- Every unique `controller#action` pair was fed to the real
  `Ctxpack.compile`; failures were classified per the pre-registered taxonomy
  (`classify_anchors.rb`). `inherited_action` vs `concern_action` was decided
  by a driver-side static chase (superclass chain and `include`d concerns via
  conventional paths, depth ≤ 5) that is deliberately *more* lenient than
  ctxpack itself.
- Raw inputs and per-anchor outputs are committed under
  [`routes/`](routes/) and [`results/`](results/).

### Extraction limitations (documented per plan)

- Mounted engines are stubbed: their internal routes never enter the
  denominator. Mount calls recorded: Mastodon 2 (`/sidekiq`, `/pghero`),
  Discourse 2, Zammad 0. Consequently the raw rate *equals* the
  engine-excluded rate by construction — `engine_route` is structurally zero
  rather than measured, which slightly flatters nothing: engines are an
  explicit v0 non-goal and the plan's headline metric already excludes them.
- Gem route-generating DSL calls could not be expanded without the gems and
  were skipped after recording: `devise_for users` + `use_doorkeeper`
  (Mastodon), `use_doorkeeper` (Zammad). Mastodon's Devise-generated routes
  point at app-overridden `auth/*` controllers, so a real `bin/rails routes`
  table would add roughly a dozen pairs not measured here.
- Routes were drawn as `Rails.env.production?`; dev-only routes (e.g.
  letter_opener) are excluded.
- Redirect/inline-rack routes carry no `controller#action` and were excluded
  from the denominator (Mastodon 16, Discourse 6).

## Failure taxonomy (169 failures total)

| Class | Mastodon | Discourse | Zammad | Total |
|---|---|---|---|---|
| `inherited_action` | 26 | 3 | 17 | 46 |
| `concern_action` | 0 | 0 | 24 | 24 |
| `file_not_found` | 0 | 1 | 0 | 1 |
| `engine_route` | 0 | 0 | 0 | 0 (structural, see above) |
| `other` | 22 | 24 | 52 | 98 |

`other` decomposes into three sharp sub-categories:

1. **Class-name inflection mismatches — 59** (Mastodon 15, Zammad 44). The
   conventional file exists, but ctxpack's `camelize` derives the wrong class
   name for acronym-styled classes: Mastodon's `ActivityPub::*` (custom
   inflection, expected `Activitypub::*`) and Zammad's `AITextTools`,
   `SMIME`, `PGP`, `SSL`, `GitHub`, etc. **51 of the 59 have a literal
   `def <action>` sitting in the correctly-resolved file** — the strict
   `def` constraint holds; only the class-name match fails.
2. **Metaprogrammed/chase-exhausted — 37** (Discourse 23, e.g.
   `ListController`'s `Discourse.filters`-generated actions and
   `admin/backups` multipart actions from an included external-upload
   concern's `define_method`; Mastodon 6; Zammad 8).
3. **Anchor grammar rejections — 2**: real routed actions ctxpack's ANCH-1
   grammar cannot express — `api/v1/notifications/requests#merged?`
   (predicate method) and `uploads#_show_secure_deprecated` (leading
   underscore).

The single `file_not_found` (`message_bus#poll`) is a gem-provided controller
(message_bus), i.e. morally an engine route.

## Implications (recommendations, not gate actions)

The gate passed, so nothing below blocks pass 2. But the taxonomy says
exactly what to promote first, in order of value:

1. **Class matching, not name guessing (+~3 points, trivially cheap).** The
   top failure cause overall is not the strict-`def` bet but ANCH's exact
   camelized class-name lookup. Matching the class whose *file* was resolved
   (e.g. any class in the file whose name underscores back to the anchor
   path, or simply the def-search within the single Zeitwerk class per file)
   would convert 51 failures into resolutions and lift the average to ~94%.
   Worth a spec amendment discussion before pass 2 freezes FMT wording.
2. **ANCH-1 grammar**: allow trailing `?`/`!` and leading `_` in action
   tokens — they occur in real route tables.
3. **One-level superclass lookup** would address 46 `inherited_action`
   failures (the eval plan's own example rework), but at 2.3% of pairs it is
   not worth v0 complexity given the gate margin.

Per-app character matched expectations: Discourse is conventional at the
anchor layer (96.3%) with failures concentrated in deliberate
metaprogramming; Zammad is the stress case (84.4%) due to acronym
inflections and concern-defined CRUD; Mastodon sits between, with an
admin-settings inheritance family and the ActivityPub inflection.

## Reproduction

```sh
git clone --depth 1 <app> && git -C <app> rev-parse HEAD   # SHAs above
GEM_HOME=<isolated> ruby eval/tier0/extract_routes.rb <app_root> <actionpack_version> routes/<app>.json
ruby eval/tier0/classify_anchors.rb <app_root> routes/<app>.json results/<app>.json
```

## Post-amendment addendum (2026-07-05)

The two promoted amendments (class-by-file matching, ANCH-1 grammar
tolerance — see PROJECT_TRACKER decision log) were implemented the same day
and the classifier re-run against the same three apps at the same SHAs,
using the committed route tables (no re-extraction; apps shallow-fetched at
the recorded commits).

| App | Pairs | Resolved | Rate | Δ resolved |
|---|---|---|---|---|
| Mastodon | 616 | 584 | 94.8% | +16 |
| Discourse | 755 | 728 | 96.4% | +1 |
| Zammad | 596 | 539 | 90.4% | +36 |
| **Average** | | | **93.9%** | |

Exactly 53 pairs flipped to resolved — the 51 class-name inflection
mismatches plus the 2 grammar-rejected actions from the failure taxonomy
above. A per-anchor diff against the original results confirmed zero
regressions (no previously resolved pair now fails), and compiler crashes
remain zero. This matches the ~94% prediction in "Implications" item 1.
The remaining failures are the inherited/concern/metaprogrammed families
that the amendments deliberately did not touch. Per-anchor data:
[`results/post_amendment/`](results/post_amendment/).

## View-pass addendum (2026-07-08)

Mandatory pass-boundary re-scan for the view-resolution pass (VIEW-1..VIEW-7
+ the LIM-1 raise→truncate change — see PROJECT_TRACKER decision log). The
classifier was re-run against the same three apps at the same pinned SHAs,
using the committed route tables (no re-extraction; apps shallow-fetched at
the recorded commits and `git rev-parse HEAD` verified against the SHAs above).

| App | Pairs | Resolved | Rate | Δ vs post-amendment |
|---|---|---|---|---|
| Mastodon | 616 | 584 | 94.8% | 0 |
| Discourse | 755 | 728 | 96.4% | 0 |
| Zammad | 596 | 539 | 90.4% | 0 |
| **Average** | | | **93.9%** | |

**Zero per-anchor change.** A per-anchor diff against `results/post_amendment/`
found 0 regressions, 0 newly-resolved, 0 label-flips across all 1,967 pairs;
resolution rates and compiler-crash counts (0) are byte-identical to the
post-amendment baseline. This was the prediction: view inclusion is **additive
and post-resolution** — it appends `view_candidate` files to a packet after the
action has already resolved, and the total-file-limit change only truncates an
already-resolved packet, so neither can alter whether an anchor resolves. The
classifier exercises the full `Ctxpack.compile` path (including the new view
glob) against real app view trees with zero crashes. No new baseline is written
because the results are identical to `results/post_amendment/`. Gate passes; no
defect to route back.

### Re-verification (2026-07-09)

The view-pass rescan above was independently re-run to resolve a tracker
contradiction (a stale "Known debt" line claimed the rescan was still pending
because a GitHub fetch had failed on 2026-07-09). Fresh shallow checkouts of all
three apps at the pinned SHAs (`git rev-parse HEAD` verified against the table
above), classifier re-run against the committed route tables: the per-anchor and
per-app output JSONs are **byte-identical** to `results/post_amendment/` — 0
regressions / 0 newly-resolved / 0 label-flips / 0 crashes across all 1,967
pairs. The original addendum is genuine; the "pending/DNS-failed" debt note was a
transient fetch artifact and is removed from the tracker.

## Phase 1 seed-wrap rescan (2026-07-13)

Mandatory pass-boundary re-scan for the Phase 1 internal Seed/focus-set wrap
(no recipe change; `compiler.rb` internals moved to route through
`Seed.anchor` / `resolve_anchor_seed`). Classifier re-run against the three
apps at the pinned SHAs, committed route tables only.

| App | SHA verified | Pairs | Resolved | Rate | Δ vs post_amendment |
|---|---|---|---|---|---|
| Mastodon | `163f96cee4dea23365bff9b433871e68d20d9ee7` | 616 | 584 | 94.8% | 0 |
| Discourse | `28b003a38d82c354ffc49bac23b655de9664e478` | 755 | 728 | 96.4% | 0 |
| Zammad | `50384f4c390e8abed07694897956c2f8e176208d` | 596 | 539 | 90.4% | 0 |
| **Average** | | | | **93.9%** | |

**Zero per-anchor change.** Per-app result JSONs are **byte-identical** to
`results/post_amendment/` — 0 regressions / 0 newly-resolved / 0 label-flips /
0 compile crashes across all 1,967 pairs. Expected: Phase 1 is a wrap, not a
recipe change. Scratch outputs under `tmp/tier0-rescan/` (gitignored); no new
baseline written.

## Phase 2 seed implementation rescan (2026-07-13)

Mandatory re-scan after shipping `--from-test` / `--from-files` and format v3.
Anchor resolution path unchanged; new seeds are separate recipes.

| App | Rate | Δ vs post_amendment |
|---|---|---|
| Mastodon | 94.8% | 0 |
| Discourse | 96.4% | 0 |
| Zammad | 90.4% | 0 |

**Zero per-anchor change** — result JSONs byte-identical to `post_amendment/`;
0 crashes / 1,967 pairs.

## Phase 3–4 error + multi-seed rescan (2026-07-13)

Mandatory re-scan after `--from-error` and multi-seed merge. Anchor single-seed
path still byte-identical to `post_amendment/`; 0 crashes / 1,967 pairs.

## Phase 5a method-seed rescan (2026-07-14)

Mandatory re-scan after `--from-method` (SEED-25: exact CONST-2b resolution,
same-file BFS, no test leg). Anchor path is strictly additive-branch code;
classifier output byte-identical to `post_amendment/` on all three apps
(Mastodon 584/616, Discourse 728/755, Zammad 539/596); 0 crashes / 1,967
pairs. Checkouts verified clean at the pinned SHAs (history deepened for the
Phase 5b diff spike; worktrees untouched).

## Phase 5b diff-seed rescan (2026-07-14)

Mandatory re-scan after `--from-diff` (SEED-26: git-range/patch primaries,
def-anchored snippets, paired-test mirror leg). Classifier output
byte-identical to `post_amendment/` on all three apps; 0 crashes / 1,967
pairs. The two touched existing seams (shared snippet window helper, file
category union) are behavior-preserving; the rescan confirms the anchor
path byte-exactly.
