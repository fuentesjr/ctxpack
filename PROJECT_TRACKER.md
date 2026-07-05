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

1. **Decide on the two cheap ANCH amendments surfaced by Tier 0** before
   pass 2 freezes FMT wording (see `eval/tier0/RESULTS.md` "Implications"):
   (a) match the controller class by resolved file rather than exact
   camelized name — 51 of 169 failures were acronym-inflection class-name
   mismatches (`ActivityPub`, `AITextTools`, `SMIME`, …) where the literal
   `def <action>` was present; (b) ANCH-1 grammar for `?`/`!`-suffixed and
   `_`-prefixed actions. Both are spec amendments + `design.md`
   reconciliation, not reworks — the 70% gate passed without them.
2. **Pass 2: implement `packet-format.md`** — renderer + manifest over the
   existing packet object; same delegate → review → fix loop.
3. **Pass 3: `cli.md`** — decide OptionParser vs Thor at pass start.
4. **Pass 4: `fixture-evals.md`** — YAML runner, CI job (Tier 1 only, per
   EVAL-10).

## Decision log

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
