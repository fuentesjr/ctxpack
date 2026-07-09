# Tier 3 offline probe — prerequisite gate result

**Date:** 2026-07-08. Resolves step 1 of the PROJECT_TRACKER "OFFLINE
Rubydex-recall probe" work order (the hard prerequisite/blocking unknown).

## Question

Is Rubydex installed and able to index the three pinned expansion apps
**offline** (no app boot, no DB) — the same no-boot constraint that shaped
Tier 0?

## Result: feasibility PASSES for all three apps

Rubydex **0.2.8** is installed as a gem (native Rust extension, ABI-built for
Ruby 4.0.x under mise). It is a **static** analyzer — it parses Ruby source via
Prism/Rust and does **not** boot the app or touch a database. The Tier 0 no-boot
problem is a non-issue here.

Indexed each pinned template checkout offline (`Rubydex::Graph#index_workspace`
+ `#resolve`, run under the 4.0.1 gem pointed at each app's source tree):

| App | SHA | index+resolve | documents | declarations | constant_refs |
|---|---|---|---|---|---|
| Campfire | `71ffeeea` | 0.90 s | 6,793 | 117,042 | 125,396 |
| Lobsters | `430d864b` | 0.85 s | 6,933 | 117,489 | 127,927 |
| Publify (`publify_core` engine) | `80ede867` | ~0.97 s | 5,686 | 101,147 | 102,699 |

No boot, no DB, sub-second. **Gate cleared on feasibility.**

## But: a structural reframe the proposal did not anticipate

Rubydex indexes **only Ruby-family files** — observed document extensions are
`.rb`, `.rbs`, `.rake`, `.ru`. It does **not** index `.erb` view templates or
`.yml` locale files (they are not Ruby source; a Ruby semantic graph has no node
for them).

Cross-referenced against what the convention resolver actually **missed** on
feature tasks (control arm, production-only, from
`../tier2-expansion/coverage/coverage_by_session.json`):

| Case | Missed file | Reachable by which mechanism? |
|---|---|---|
| campfire t1 (`autocompletable/users#index`) | `app/models/user.rb` | **Rubydex** — pre-existing sibling model, reached via call graph |
| lobsters t2 (`users#standing`) | `app/models/user_standing.rb` | **NOTHING** — `new file mode 100644`, the agent *created* it; no resolver can pack a file absent at the base SHA |
| campfire t2 (`accounts#edit`) | `app/views/accounts/edit.html.erb` | view path convention (file pre-exists); NOT Rubydex |
| campfire t2 | `config/locales/en.yml` | note/pointer only — the miss is a *newly-added* key (see below) |
| publify t1 (`setup#index`) | `app/views/setup/index.html.erb` | view path convention (file pre-exists); NOT Rubydex |
| publify t1 | `config/locales/en.yml` | note/pointer only — newly-added key `nickname` |

**Corrected count (was overstated in the first draft of this file): Rubydex's
*demonstrated* reach on this corpus is ONE pre-existing file
(campfire t1 `user.rb`), on a task that already meets the exploration bar
without it.** `lobsters user_standing.rb` was miscounted — it is an
agent-created file (verified: `new file mode 100644` in
`t2-2-control-2.patch`), unreachable by any resolver. The remaining misses are
views (closable by a Rails path-convention layer — the files pre-exist) and
locales (the specific misses are *new keys* the agents add, e.g. publify's
`nickname: Nickname`, so a base-tree `t(".key")` scan fires on none of them;
locale belongs as a standing pointer, not a packet file — including a giant
truncated `en.yml` to move a file-level recall number is metric-gaming).

**Note — the task also creates files that no resolver can ever recall**
(`user_standing.rb`, sibling `user_standing_summary.rb` in other rounds), so
feature recall < 1.0 is a permanent structural floor, not a resolver defect.

**Measured harm from the view omission (not hypothetical):** the only two
treatment-arm quality dings in the entire 72-session grid are P06
(`t2-1-treatment-1`) and P20 (`t2-1-treatment-3`), both publify t1, each docked
`-1 correct` for a backend-only fix that omitted the setup-form field/locale —
"an operator can't actually choose the nickname through the UI"
(`../tier2-expansion/judging/scores.json`). The view-convention layer targets
exactly this failure.

The proposal (and the `design.md` "Rubydex-backed semantic resolver" note)
lumped "view templates, locale files, and sibling models" together as Rubydex's
surface. On this actual corpus that is two-thirds wrong: **Rubydex's unique
reach is the call-graph-connected Ruby files (sibling models via
associations/helpers), not views or locales.** The views/locales gap is closable
only by a **Rails path-convention layer** (action → `app/views/<controller>/
<action>.*`; `t(".key")` → locale file) — a different mechanism, and one that
would extend the *existing* convention resolver rather than swap in Rubydex.

### Concretely verified reachability

campfire `autocompletable/users#index` references `User` only inside the private
`users_scope` helper (`... : User.all`), not in the `index` action body — which
is exactly why ctxpack v0 (action-body-scoped `referenced_constant`) missed it.
Rubydex's resolved graph follows the intra-file call/reference edges and resolves
that `User` reference to `app/models/user.rb` (also surfaces `Current` →
`app/models/current.rb`). This is the class of file Rubydex adds over convention.

## Implication for the probe (revised after the Fable advisory + verification)

- The offline probe is **feasible and cheap** — everything needed is on disk.
- **Rubydex's recall ceiling on this corpus is already known: one pre-existing
  file**, on a task that already meets the exploration bar. No probe output can
  change that. So the probe's real deliverable is not a recall number but the
  **precision/noise cost** of budget-limited graph resolution — the number
  needed to write a documented "defer Rubydex" verdict rather than a vibes one.
  Rubydex's honest case (concerns/services/POROs reached via call graph) needs a
  corpus whose misses are Ruby-shaped; this corpus's are view/locale/new-file.
- The higher-leverage, dependency-free build is a **Rails view path-convention
  layer** (action → `app/views/<controller>/<action>.*` when it exists). It
  closes the pre-existing view misses and targets the one *measured* harm
  (P06/P20). Locale stays a pointer, not a file.
- **Cheapest next experiment (symmetric):** augment each task's packet file-set
  with the conventional view path (and, separately, the Rubydex-resolved Ruby
  set) and re-run `../tier2-expansion/packet_coverage.rb` over the same
  committed diffs — one writeup, four columns: convention / +view / +Rubydex /
  +both. Near-zero cost; also quantifies each mechanism's precision dip on
  bug/behavior tasks (whose actions have views too, but whose diffs don't touch
  them — the view layer's one real cost).
- **These are two mechanisms, not one** — the proposal and `design.md` lump
  "views, locales, and sibling models" under "Rubydex," which is what produced
  the confusion. Only the sibling-model slice is Rubydex's; views/locales need
  convention.
