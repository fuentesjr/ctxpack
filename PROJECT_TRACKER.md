# ctxpack project tracker

Tracks implementation progress against the normative specs in [`specs/`](specs/)
and the next steps. Update this file whenever a pass lands or a decision
changes scope. Per-pass technical decisions live in
[`implementation-notes.md`](implementation-notes.md); rationale lives in
[`design.md`](design.md).

## Working process

Each spec is implemented in its own pass, in the dependency order from
[`specs/README.md`](specs/README.md): implementation is delegated to Codex
(via the codex plugin), then reviewed requirement-by-requirement by Claude,
confirmed defects are routed back to the same Codex session, and the result is
re-verified before acceptance. Spec bugs discovered during implementation are
amended in the spec *and* reconciled with `design.md` in the same change.

Codex plugin mechanics (learned in pass 1): the `codex:codex-rescue` agent is
a one-shot forwarder — it hands the brief to Codex and returns a task ID
without waiting. Polling and result retrieval happen from the main session via
the plugin's companion script (`codex-companion.mjs status|result <task-id>`);
follow-up fix rounds resume the same Codex session by forwarding a `--resume`
request. Independent verification (running the suite, checking git state) is
always done session-side, never trusted from Codex's own summary.

End-of-session ritual: any session that changes the plan replaces the
"Next session prompt" section below before its final commit — one prompt,
covering only the immediate next step, pointing into this file rather than
duplicating it.

## Next session prompt

Written 2026-07-05, for Next steps item 1. If this prompt disagrees with
"Next steps", the tracker wins.

> Read PROJECT_TRACKER.md and do step 1 of Next steps: the ANCH amendment
> mini-pass (adopted — see the 2026-07-05 decision-log entry and the
> "Implications" section of eval/tier0/RESULTS.md for the evidence). Work
> in-session, red-green: first write failing tests for (a) a controller
> file whose class uses acronym naming (e.g. `AITextToolsController`
> reached via anchor `ai_text_tools#index`) and (b) actions named `merged?`
> and `_show_secure_deprecated`. Then amend ANCH-1/ANCH-2/ANCH-3 in
> specs/packet-compilation.md using the [amended] annotation style CB-2 and
> CB-4 already use, reconcile design.md in the same change, and make the
> smallest lib change that passes. Update implementation-notes.md and this
> tracker (status, decision log, and rewrite this prompt for pass 2), run
> `bundle exec rake test`, and ask before committing.
>
> Optional verification: re-clone the three spike apps at the SHAs in
> eval/tier0/RESULTS.md (route tables are already committed under
> eval/tier0/routes/ — skip extraction) and re-run
> `ruby eval/tier0/classify_anchors.rb <app_root> eval/tier0/routes/<app>.json <out>`
> to confirm the average rises to ~94% and the 51 inflection cases resolve;
> add a post-amendment addendum to RESULTS.md if so.

## Status

| Pass | Spec | Status | Notes |
|---|---|---|---|
| 1 | [`packet-compilation.md`](specs/packet-compilation.md) | **Done** (2026-07-05) | `Ctxpack.compile(app_root:, anchor:, task:)` → internal packet object. 20 tests / 87 assertions green. |
| 2 | [`packet-format.md`](specs/packet-format.md) | Not started | Markdown renderer + JSON manifest from the packet object. Repo stamp already computed in pass 1. |
| 3 | [`cli.md`](specs/cli.md) | Not started | Root discovery, flags, artifact naming/paths, exit codes. OptionParser vs Thor undecided (lean OptionParser). |
| 4 | [`fixture-evals.md`](specs/fixture-evals.md) | Not started | YAML case runner + CI wiring. `minitest_basic` fixture tree already authored in pass 1 at its EVAL-2 path. |

Offline experiments (not conformance work, see [`eval-plan.md`](eval-plan.md)):

| Experiment | Status | Notes |
|---|---|---|
| Tier 0 anchor viability spike | **Done** (2026-07-05) | **91.0% engine-excluded average across Mastodon/Discourse/Zammad → ≥ 70% gate passes; proceed as designed.** Full method, taxonomy, and raw data in [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md). Zero compiler crashes across 1,967 real-app pairs. |
| Tier 2 agent A/B | Not started | Tier 0 gate cleared; still gated on a working end-to-end CLI. |

## Next steps

1. **ANCH amendment mini-pass** (decided 2026-07-05, see decision log):
   amend `packet-compilation.md` for (a) class-by-file matching —
   underscore-insensitive acceptance of the class defined in the resolved
   controller file, replacing the exact camelized-name lookup — and
   (b) ANCH-1 action grammar tolerating trailing `?`/`!` and leading `_`.
   Reconcile `design.md`, TDD the lib change in-session (deliberate
   deviation from the Codex delegation loop: amendment to existing pass 1
   code, too small for the delegate → review overhead). Optionally re-run
   the Tier 0 classifier afterward to confirm the predicted ~94% average.
2. **Pass 2: implement `packet-format.md`** — renderer + manifest over the
   existing packet object; same delegate → review → fix loop.
3. **Pass 3: `cli.md`** — decide OptionParser vs Thor at pass start.
4. **Pass 4: `fixture-evals.md`** — YAML runner, CI job (Tier 1 only, per
   EVAL-10).

## Decision log

- **2026-07-05** — Both Tier 0-surfaced ANCH amendments adopted: (a)
  class-by-file matching (51/169 spike failures were acronym-inflection
  class-name mismatches with the literal `def <action>` present — the
  acronyms live in per-app `inflections.rb` initializers, unreachable
  without booting, so the fix is to trust the resolved file's class rather
  than guess its name); (b) ANCH-1 grammar admits `?`/`!`-suffixed and
  `_`-prefixed actions (2 real routed actions rejected). To be implemented
  in-session as a mini-pass before pass 2 — a deliberate deviation from the
  Codex delegation loop, which is reserved for full spec passes.
- **2026-07-05** — Tier 0 spike executed per the pre-registered plan:
  91.0% engine-excluded average (Mastodon 92.2 / Discourse 96.3 /
  Zammad 84.4) → gate passed, vertical slice proceeds unchanged. Route
  tables came via the plan's documented fallback (stubbed `routes.rb` eval
  against real actionpack, no app boot); limitations recorded in
  `eval/tier0/RESULTS.md`. Failure taxonomy promoted two candidate spec
  amendments (class-by-file matching, ANCH-1 action grammar) into next
  steps — recommendations only, not gate-forced rework.
- **2026-07-05** — Specs README reordered to dependency/build order
  (compilation → format → CLI → evals) and a "Cross-spec contracts" section
  added (packet object schema, code registries, repo stamp timing, root/task
  as inputs, fixture dual-use).
- **2026-07-05** — CB-2 amended: literal `only:`/`except:` filters now include
  single symbol/string literals, not just arrays — the array-only rule pushed
  the dominant Rails style (`only: :upgrade`) into uncertainty notes.
  `design.md` reconciled.
- **2026-07-05** — CB-4 amended: "list names of callbacks declared outside the
  controller file" was unimplementable (v0 never reads superclasses/concerns);
  now scoped to in-file declarations whose method has no direct definition in
  the file. FMT-7's `unresolved_external_callbacks` row and `design.md`
  reconciled.

## Known debt / open questions

- LIM-1 values (8/4/2/120) are unvalidated guesses until Tier 0/Tier 2 produce
  evidence (tracked in `design.md`).
- The `max_total_files` guard is untested because it is unreachable by v0
  construction (see `implementation-notes.md`).
- Generic validators that auto-load every `*_test.rb` will trip over the
  static fixture tests under `test/fixtures/apps/`; the Rake task excludes
  them deliberately (TEST-4: content is never read).
