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

Dogfooding metz-scan (decided 2026-07-05): `rake metz` runs an advisory
[metz-scan](https://github.com/fuentesjr/metz-scan) design-pressure scan
over `lib/` (pinned 0.4.0, scoped to Metz cops via the committed
`.rubocop.yml`). It never gates the build or the Codex loop; findings
inform refactors at pass boundaries. Every metz-scan bug or friction
encountered gets logged in [`metz-scan-feedback.md`](metz-scan-feedback.md)
with enough detail to file upstream GitHub issues — we are dogfooding the
tool, not just consuming it. When pass 4 stands up CI, add a non-blocking
metz step with the pinned version.

End-of-session ritual: any session that changes the plan — and, always,
any session that completes the plan's work — rewrites the "Next step:
execution plan" section below before its final commit — one plan, covering
only the immediate next step, pointing into this file rather than
duplicating it. To make that self-enforcing, every execution plan's final
step is: rewrite this section for the work that follows. Sessions open
with: read this tracker, then execute that plan.

## Next step: execution plan

Written 2026-07-05 for Next steps item 1 (Pass 2: implement
[`specs/packet-format.md`](specs/packet-format.md)). If this section
disagrees with "Next steps", Next steps wins.

1. Read `specs/packet-format.md` plus the "Cross-spec contracts" section of
   `specs/README.md`. The input is the pass 1 packet object
   (`lib/ctxpack/packet.rb`); repo stamp is already computed there.
2. Delegate to Codex per the plugin mechanics in "Working process" above:
   brief = implement the Markdown renderer and JSON manifest over the
   existing packet object, TDD, no changes to compilation behavior.
3. Poll/fetch via the companion script; verify session-side:
   `bundle exec rake test` and a requirement-by-requirement review of the
   diff against the FMT-*/MAN-* codes.
4. Route confirmed defects back to the same Codex session (`--resume`);
   re-verify before acceptance.
5. Confirm Codex kept `implementation-notes.md` current (it owns the pass
   notes); update the Status/Next steps/Decision log sections here.
6. Ask before committing; rewrite this section for pass 3 first (per the
   end-of-session ritual).

## Status

| Pass | Spec | Status | Notes |
|---|---|---|---|
| 1 | [`packet-compilation.md`](specs/packet-compilation.md) | **Done** (2026-07-05) | `Ctxpack.compile(app_root:, anchor:, task:)` → internal packet object. ANCH amendment mini-pass landed same day (class-by-file matching, tolerant action grammar). 25 tests / 101 assertions green. |
| 2 | [`packet-format.md`](specs/packet-format.md) | Not started | Markdown renderer + JSON manifest from the packet object. Repo stamp already computed in pass 1. |
| 3 | [`cli.md`](specs/cli.md) | Not started | Root discovery, flags, artifact naming/paths, exit codes. OptionParser vs Thor undecided (lean OptionParser). |
| 4 | [`fixture-evals.md`](specs/fixture-evals.md) | Not started | YAML case runner + CI wiring. `minitest_basic` fixture tree already authored in pass 1 at its EVAL-2 path. |

Offline experiments (not conformance work, see [`eval-plan.md`](eval-plan.md)):

| Experiment | Status | Notes |
|---|---|---|
| Tier 0 anchor viability spike | **Done** (2026-07-05) | **91.0% engine-excluded average across Mastodon/Discourse/Zammad → ≥ 70% gate passes; proceed as designed.** Full method, taxonomy, and raw data in [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md). Zero compiler crashes across 1,967 real-app pairs. |
| Tier 2 agent A/B | Not started | Tier 0 gate cleared; still gated on a working end-to-end CLI. |

## Next steps

1. **Pass 2: implement `packet-format.md`** — renderer + manifest over the
   existing packet object; same delegate → review → fix loop.
2. **Pass 3: `cli.md`** — decide OptionParser vs Thor at pass start.
3. **Pass 4: `fixture-evals.md`** — YAML runner, CI job (Tier 1 only, per
   EVAL-10).

## Decision log

- **2026-07-05** — ANCH amendment mini-pass landed (in-session TDD, per the
  prior decision): ANCH-1 action grammar tolerates trailing `?`/`!` and
  leading `_`; ANCH-2/3 switched to class-by-file matching (first class in
  the resolved file matching the anchor path underscore-insensitively);
  TEST-1 action tokens normalized as a grammar ripple. Specs, `design.md`,
  and the Tier 0 classifier's error-message mapping reconciled in the same
  change. Suite: 25 tests / 101 assertions green. Classifier re-run at the
  spike SHAs confirmed the prediction: 93.9% average (Mastodon 94.8 /
  Discourse 96.4 / Zammad 90.4), exactly the 53 taxonomy-predicted pairs
  flipped, zero per-anchor regressions, zero crashes — addendum in
  `eval/tier0/RESULTS.md`.
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
- metz-scan baseline (2026-07-05, advisory): `Ctxpack::Compiler` is flagged
  `ClassesTooLong` [503/100] plus 24 long methods. Splitting the compiler
  (e.g. callbacks / constants / test-candidates collaborators) is a
  candidate refactor to weigh at a pass boundary, not mid-pass; the class
  will grow again when future reason codes land.
