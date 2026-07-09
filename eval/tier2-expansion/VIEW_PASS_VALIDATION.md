# Release-boundary validation — view pass + CONST-1 + locale pointer

Date: 2026-07-09. ctxpack SHA at validation: `c7a4ae3` (view pass `6688ff9`,
CONST-1 widening `ab72137`, locale pointer `c7a4ae3`).

This is a **usefulness check at the release boundary, not a correctness gate**
(correctness is covered by each pass's Tier 1 fixtures + the Tier 0 rescan). It
asks the two questions the execution plan named for the packet-coverage layer:

1. Does publify t1 (`setup#index`) now surface what the P06/P20 quality dings
   showed the packet omitting — the setup-form **view** and a **locale** pointer
   (the two-part cause: nickname changed backend-only, no form field, no locale
   key)?
2. Does the added view surface introduce a **bug-task exploration regression**
   (extra distraction files) on the bug task, publify t3 (`articles#preview`)?

## Method

Regenerate the publify t1 and t3 packets against the current committed `lib/`
(`ctxpack packet <anchor>` run from the pinned publify template — parse-only, no
app boot), and diff coverage against the frozen-grid committed packets
(`eval/tier2-expansion/publify/packets/task{1,3}.md`, generated at the old lib
`80ede86`). No subject sessions were run: the frozen 72-session grid already
established that treatment agents act on packet files (SUPPORT / generalizes,
`RESULTS.md`), so "the view is now in the packet" is the load-bearing coverage
fact, and the behavioral value follows from the established prior. The frozen
grid `runs.jsonl` / `packets/` provenance was left untouched (regeneration went
to scratch).

## Result — coverage confirmed on both watch-items

**t1 `setup#index` (feature, the P06/P20 target):**

| file / note | OLD packet (`80ede86`) | NEW packet (`c7a4ae3`) |
|---|---|---|
| `app/controllers/setup_controller.rb` (action + `check_config`) | present | present |
| `app/views/setup/index.html.erb` (`view_candidate`) | **absent** | **present** |
| locale standing note (`config/locales/`) | **absent** | **present** |
| `app/models/user.rb` (`referenced_constant` `User`) | present | present |
| `spec/controllers/setup_controller_spec.rb` | present | present |

The packet now surfaces **both** things the P06/P20 treatment diffs omitted: the
setup **view** (the form-field surface) and the **locale** pointer. CONST-1 adds
nothing here — `User` was already referenced in the action body (`@user =
User.new`); CONST-1's target was campfire t1, not publify.

**t3 `articles#preview` (bug, the regression check):** OLD and NEW packets are
**identical** — `articles#preview` has no conventional view template, so the
existence-gated view glob adds nothing, and no new constant is reachable. The
only universal addition anywhere is the one-line locale *uncertainty note* (not
a file). So the added view surface **does not touch the bug task**: the
mechanism for an exploration regression (extra distraction files to read) is
absent by construction.

## Verdict

Both coverage watch-items pass. The three passes close the P06/P20 packet-level
omission (view + locale) without adding any distraction surface to the bug task.
Per the user decision at the release boundary, the packet-coverage confirmation
is accepted as sufficient; the optional subject-session behavioral re-run was
not spent (predictable result given the established grid, and it would require
isolating regenerated packets from the frozen-grid provenance).

Reproduce: from `tmp/tier2-expansion/publify/template`, run
`ruby -I <repo>/lib <repo>/exe/ctxpack packet setup#index --manifest --force`
(and `articles#preview`) and compare against `packets/task1.md` / `task3.md`.
