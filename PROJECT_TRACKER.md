# ctxpack project tracker

Tracks implementation progress against the normative specs in [`specs/`](specs/)
and the next steps. Update this file whenever a pass lands or a decision
changes scope. Per-pass technical decisions live in
[`implementation-notes.md`](implementation-notes.md); rationale lives in
[`design.md`](design.md).

## Resuming a session

The only prompt a fresh session needs is: **"Continue from
PROJECT_TRACKER.md."** Concretely, that session reads this file, treats
"Next step: execution plan" as its authoritative work order, runs the pass per
"Working process" below, and closes with the end-of-session ritual. "Next
steps" is a summary and must agree with that work order. Each section owns its
own altitude: this one is only the bootstrap, "Working process" owns the loop
mechanics, and the execution plan carries only pass-specific content.

## Working process

Each spec is implemented in its own pass, in the dependency order from
[`specs/README.md`](specs/README.md): implementation is delegated to the
active delegation profile's implementer (see `CLAUDE.md` "Delegation
profiles"; default `grok-loop`, with `codex-loop` mechanics below serving as
the loop's reference shape), then reviewed requirement-by-requirement by
Claude, confirmed defects are routed back to the same delegate session, and
the result is re-verified before acceptance. Spec bugs discovered during implementation are
amended in the spec *and* reconciled with `design.md` in the same change.

Codex plugin mechanics (learned in pass 1): the `codex:codex-rescue` agent is
a one-shot forwarder — it hands the brief to Codex and returns a task ID
without waiting. Polling and result retrieval happen from the main session
via the plugin's companion script at
`$(jq -r '.plugins["codex@openai-codex"][0].installPath' ~/.claude/plugins/installed_plugins.json)/scripts/codex-companion.mjs`
(resolve via `installed_plugins.json`, not by picking a cache version dir —
stale versions linger there): `status <task-id>` / `result <task-id>`,
backgrounding a polling loop for long runs. Follow-up fix rounds resume the
same Codex session by forwarding a `--resume` request. Always instruct the
forwarder to launch via the companion's own `--background` flag: if it
instead runs the companion in foreground inside a harness background shell,
the shell reap at subagent exit kills the companion mid-turn and the job
wedges at "running" forever (upstream codex-plugin-cc#432, root cause #222;
hit twice on 2026-07-05). Fingerprint of a wedged foreground run: the job
JSON under the plugin's `state/<ws>/jobs/` has no `request` key. The Codex
turn usually completes server-side anyway — verify the working tree, then
`cancel` the stale record. Verification is
always session-side, never trusted from Codex's own summary: run
`bundle exec rake test`, check git state, and review the diff
requirement-by-requirement against the pass's spec codes; route confirmed
defects back via `--resume` and re-verify before acceptance. Codex owns the
pass notes in `implementation-notes.md` — confirm they are current before
accepting the pass.

Dogfooding metz-scan (decided 2026-07-05): `rake metz` runs an advisory
[metz-scan](https://github.com/fuentesjr/metz-scan) design-pressure scan
over `lib/` (pinned 0.4.0, scoped to Metz cops via the committed
`.rubocop.yml`). It never gates the build or the Codex loop; findings
inform refactors at pass boundaries. Every metz-scan bug or friction
encountered gets logged in [`metz-scan-feedback.md`](metz-scan-feedback.md)
with enough detail to file upstream GitHub issues — we are dogfooding the
tool, not just consuming it. CI (pass 4) runs metz as a non-blocking step
with the pinned version.

Corpus re-scan at pass boundaries (decided 2026-07-05): any pass that
changes compiler behavior re-runs the Tier 0 classifier at the spike SHAs
(Mastodon/Discourse/Zammad; method in
[`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md)) and diffs per-anchor
resolution against the last recorded run before acceptance. Unlike
`rake metz` this is not purely advisory: every per-anchor regression must
be either predicted by the change (as in the ANCH-amendment re-run, which
flipped exactly the 53 taxonomy-predicted pairs) or routed back as a
defect. Passes that don't touch compiler behavior (e.g. the CLI pass)
skip it.

End-of-session ritual: any session that changes the plan — and, always,
any session that completes the plan's work — rewrites the "Next step:
execution plan" section below before its final commit — one plan, covering
only the immediate next step, pointing into this file rather than
duplicating it. To make that self-enforcing, every execution plan's final
step is: rewrite this section for the work that follows. (How a fresh
session picks this up is spelled out in "Resuming a session" above.)

## Next step: execution plan

Updated 2026-07-17 after the post-optimization ctxpack provider-seam recheck
passed with healthy margin. The tracer is already on ctxpack `origin/main`;
the optimized git-recon commit and this measurement reconciliation remain to
be pushed. **This plan is the authoritative work order for that publication
boundary**; "Next steps" must agree.

### State (ground truth, re-verified 2026-07-17)

- **Git state:** ctxpack `3e7cf79` (the tracer commit) already matched
  `origin/main` when this session began; this session did not push it. The
  measurement/docs reconciliation lands in the local commit containing this
  tracker update. git-recon local `main` is at `7682b2c`, one commit ahead of
  `origin/main` at `87032f6`, with a clean worktree. No remaining push is
  authorized in either repository.
- **Context-engineering positioning pass:** complete and pushed in `3669e79`.
  README, gemspec metadata, examples, FAQ, and
  design now use **context engineering CLI** as the category and
  **deterministic context compiler** as the mechanism, while keeping the
  concrete task + seed promise first and Rails as v0 scope. No behavior, spec,
  dependency, lockfile, CI, or recorded-evidence change.
- **ctxpack parent verification (2026-07-15):** after the `coding_worker` pass, the
  orchestrator-DRA reviewed the diff and ran `bundle exec rake test` → **205
  runs, 1834 assertions, 0 failures, 0 errors, 0 skips**; gemspec load
  validation confirmed Ruby `>= 3.4` and `prism` as the sole runtime
  dependency; `git diff --check` passed. `doc_reviewer` found two bounded copy
  defects (seed-driven selection / continuation wording and stale work-order
  state); both were corrected before acceptance.
- **Cross-repo eval process is live:** conventions + convergence ledger in
  `~/Projects/evalkit` (local-only repo, no remote yet); this repo's
  inventory + binding authoring rule in
  [`eval/README.md`](eval/README.md); five repos onboarded to the ledger.
  User declined the gist addition (2026-07-15).
- **Shipped this campaign:** `--from-method` (no test-candidate leg, SEED-25)
  and `--from-diff` (with paired-test mirror leg, SEED-26). **Not shipped:**
  `--from-route` — its double-gated spike failed the resolution gate
  (0.243 < 0.70); route evidence stays CLI-17c coaching-only.
- **Gate evidence:** `eval/seed-spikes/{method,diff,route}/` (frozen pre-regs
  + results). Tier 0 rescans at both compiler boundaries (5a, 5b):
  byte-identical to `post_amendment`, 0 crashes / 1,967 pairs.
- **Context-source issue planning:** complete. The user rejected a single
  oversized epic, approved a dependency-ordered mini-epic breakdown, and gave
  exact-text sign-off for two bounded `type: task` spikes: ctxpack
  [#6](https://github.com/fuentesjr/ctxpack/issues/6) for seed-driven
  git-recon signals and [#7](https://github.com/fuentesjr/ctxpack/issues/7)
  for repository-documentation enrichment. Both issues are open and their
  published title/body/label were verified against the approved drafts. No
  repository metadata was published.
- **git-recon interface:** complete and pushed in `87032f6`. The
  `git-recon facts` command accepts JSON format, revision, optional line range,
  and path arguments and emits versioned compact tuples for recent/repair
  commits, current
  coupling with representative commit provenance, and optional line origins.
  The contract is deterministic and bounded (five facts per list, 20 shared
  commits), refuses shallow history, returns typed errors, and omits author
  metadata, message bodies, patches, and raw Git output. No package dependency
  was added; the system `iconv` command is required.
- **git-recon evidence:** the committed interface fixture suite, ShellCheck,
  Bash 3.2 parsing, schema parsing, diff checks, and final reviews pass. The
  representative query originally completed in 10.27–13.02 seconds. Trace2
  then isolated three history walks at 4.776 seconds and Bash parsing 38,092
  diff records at 4.763 seconds. Commit `7682b2c` reuses the first
  history result for repair matching and prefilters oversized commits before
  exact NUL parsing. Its opt-in 8-second benchmark was RED at 10.776 seconds
  and GREEN at 4.965 seconds; final runs were **4.838s, 4.845s, and 5.192s**,
  byte-identical at 1,920 bytes. The fixture suite, ShellCheck, Bash syntax,
  and diff checks remain green. This proves interface performance and contract
  preservation, not that history facts earn ctxpack packet budget.
- **Companion verification:** `~/.local/bin/git-recon` was already present
  and resolves to the clean checkout at `7682b2c`; this session did not create
  or reinstall the symlink. It remains a separate user-level installation:
  ctxpack does not co-install, vendor, download, or add a gem dependency.
- **Files-seed tracer implementation:** complete, parent-accepted, committed,
  and already pushed in ctxpack `3e7cf79`. The first retained files primary gets
  at most one revision-pinned `git-recon facts --format=json` request; typed
  bounded facts enter packet Format 4, while absence/failure preserves source
  evidence with one coarse Follow-up. Provider execution is argv-only,
  time/output bounded, TERM→KILL reaped, schema-validated, and renderer-pure.
  Files paths are canonical before identity/storage/deduplication.
- **Acceptance evidence:** fixture RED was **207 runs / 1843 assertions / 1
  failure** for the intended canonical-path omission, then GREEN. Final whole
  suite: **225 runs, 1976 assertions, 0 failures, 0 errors, 0 skips**. Focused
  provider/integration/seed suites, Ruby syntax, and `git diff --check` pass.
  `rake metz` completed as advisory with the repository's existing design
  pressure plus the new adapter's concentrated process/schema responsibilities.
  A real existing-companion fixture smoke returned included typed history.
  Parent end-to-end smoke on Rails
  `activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb`
  completed in **19.021s, 19.018s, and 18.623s**; every run returned included
  history with 5 facts, 10 truncated, and no error. Those runs predate the
  companion optimization and triggered the performance work. The recorded
  post-optimization provider-seam recheck now supersedes them for the landing
  decision: **6.020s**, included history, 5 facts, 10 truncated, no error.
- **Parent gates:** Agenticons code/docs review found no P0/P1 code defect;
  two P2 documentation examples were corrected. Tier 0 is byte-identical to
  `post_amendment` for all three pinned apps: 0 per-anchor changes and 0
  crashes across 1,967 pairs. The strategic validator passed twice (the known
  Metz/RuboCop lint/metric warnings remain), and the final clean-context design
  review is `clean` with no findings. Final parent suite: **225 runs / 1976
  assertions / 0 failures / 0 errors / 0 skips**; diff check clean.
- **Latency judgment:** a fake-provider compile took 0.068 seconds, the direct
  git-recon path now takes 4.838–5.192 seconds rather than 10.27–13.02, and the
  production provider seam completed in **6.020 seconds**. It returned the
  expected 5 facts / 10 truncated / no-error shape and left **13.98 seconds**
  before the unchanged 20-second deadline. The recipe and checkout assumptions
  are now recorded in `implementation-notes.md`, and the debt-ledger item is
  paid. A batching or Zig/Rust/C rewrite is not justified by this one-path
  result.
- **ctxpack reconciliation:** tracer code, specs, append-only Tier 0 addendum,
  learning note, and tracker landed and were pushed in `3e7cf79`. This session
  changes only measurement wording, implementation notes, the existing
  learning note, the benchmark-recording agent rule, debt status, and tracker
  continuity; it does not change behavior, dependencies, specs, CI, or recorded
  experiment evidence. Full suite: **225 runs / 1976 assertions / 0 failures /
  0 errors / 0 skips**; `git diff --check` passes.

### Next session work order

1. **Current gate: wait for push authorization.** The consumer seam passed in
   6.020 seconds with 13.98 seconds of deadline margin. If the user approves,
   push git-recon `7682b2c` and the current ctxpack measurement-reconciliation
   commit, then verify both remote SHAs. Do not push either repository without
   that explicit authorization.
2. **Do not infer batching or a compiled rewrite from this result.** The
   tracer makes one request, fake-provider compile time is 0.068 seconds, and
   Git history traversal dominates the optimized 4.838–5.192-second direct
   query. Revisit only if multiple paths or a tighter latency target become a
   current requirement.
3. **Keep the stale fixture filename out of this publication.** Renaming
   `test/fixtures/evals/multiline_task_manifest_v3.yml` is a separate
   non-generated-file change and still requires explicit approval.
4. **Keep published issues unchanged pending exact approval.** ctxpack #6
   still describes the superseded corpus spike and must not be silently closed
   or rewritten; #7 remains the independent documentation-enrichment spike.
5. Final step of any executing session: rewrite this section for the work that
   follows.

### Known follow-ups (non-blocking)

- Multi-seed CLI determinism in fixture evals currently exercises a primary
  seed for error/multi cases; full merge is asserted via `Ctxpack.compile`
  packet expectations.
- `TestClass#method` sugar still coaches “use `--from-test PATH`” (method
  seed is Phase 5).

## Status

| Pass | Spec | Status | Notes |
|---|---|---|---|
| 1 | [`packet-compilation.md`](specs/packet-compilation.md) | **Done** (2026-07-05) | `Ctxpack.compile(app_root:, anchor:, task:)` → internal packet object. ANCH amendment mini-pass landed same day (class-by-file matching, tolerant action grammar). 25 tests / 101 assertions green. |
| 2 | [`packet-format.md`](specs/packet-format.md) | **Done** (2026-07-05) | `Ctxpack.render_markdown` / `Ctxpack.render_manifest` over the pass 1 packet object. One review fix round (FMT-5 marker drift, Anchor labels). 34 tests / 193 assertions green. |
| 3 | [`cli.md`](specs/cli.md) | **Done** (2026-07-05) | `Ctxpack::CLI` + `exe/ctxpack` over OptionParser, wiring the pass 1/2 APIs. One review fix round (CLI-14 reminder on implicit `.ctxpack/` creation, CLI-8 anchor-only derivation test). 47 tests / 274 assertions green. |
| CLI ergonomics | [`cli.md`](specs/cli.md) | **Done — verified, COMMITTED (`b8c2dc8`)** (2026-07-12) | Agenticons implementation + edge-case review; CLI-1a/8a/10a/14/15/17 reconciled. Clean-HEAD red proof; focused CLI **24 runs / 148 assertions** and full suite **102 runs / 912 assertions**, zero failures. Tier 0 N/A (no compiler behavior). |
| CLI developer happiness follow-on | [`cli.md`](specs/cli.md) | **Done — verified, COMMITTED (`1b55cce`) + PUSHED** (2026-07-12) | Agenticons pass: direct-anchor golden path, descriptive help/version, short aliases, explicit output-option conflicts, force-only overwrite permission, concise filesystem errors, non-file destination preflight, and typo suggestion. Focused CLI **38 runs / 241 assertions**; full suite **116 runs / 1005 assertions**, zero failures; final design review clean. No compiler behavior or dependencies; Tier 0 N/A. |
| CLI pipelines and Rails-aware recovery | [`cli.md`](specs/cli.md) | **Done — parent-verified, COMMITTED (`1b55cce`) + PUSHED** (2026-07-12) | `--task-file`, `--stdout`, syntactic Rails-aware recovery, Git-aware reminder, and unavailable-Git repo-stamp fallback; CLI-4a/10b/14a/17c and FMT-11. Parent full suite **135/1190**, green; strategic gates passed. No dependencies. Tier 0 N/A because classifier behavior is unchanged. |
| Packet format v2 | [`packet-format.md`](specs/packet-format.md) | **Done — parent-verified, COMMITTED (`6a23690`) + PUSHED** (2026-07-13) | Agenticons implementation of all four accepted slices plus one bounded blocker-fix round. Final full suite **147/1325**, green; strategic gates passed and the final clean-context design review was clean with no findings. No compiler selection/order/limit behavior or dependencies; Tier 0 N/A. |
| Ruby 3.4 floor | `ctxpack.gemspec`, [CI](.github/workflows/ci.yml) | **Done — verified, COMMITTED (`6a23690`) + PUSHED** (2026-07-13) | User-authorized compatibility-floor change: gem requires Ruby ≥ 3.4 and CI exercises exactly that floor; current docs and the open floor-plus-current backlog item are reconciled. Gemspec load/build and workflow checks passed; full suite **147/1325**, green. No dependency or lockfile change; historical run records retain their actual Ruby versions. |
| CLI help + manifest stdout | [`cli.md`](specs/cli.md) | **Done — parent-verified, COMMITTED (`b71af62`) + PUSHED** (2026-07-13) | Self-sufficient offline help plus exact MAN-2 streaming through `--stdout=json`; bare/explicit Markdown stdout remains compatible. Focused CLI **60/464** and full suite **151/1365**, green; strategic gates passed and final design review clean. No compiler behavior, dependencies, or recorded evidence; Tier 0 N/A. (An earlier tracker draft called this UNCOMMITTED after it had in fact landed and pushed; corrected 2026-07-13 against git ground truth.) |
| 4 | [`fixture-evals.md`](specs/fixture-evals.md) | **Done** (2026-07-05) | `FixtureEvalsTest` generates packet-expectation + CLI-determinism tests from `test/fixtures/evals/*.yml`; CI (`.github/workflows/ci.yml`) runs the suite at the current Ruby 3.4 floor plus a non-blocking pinned metz step. One review fix round (empty-glob guard, manifest-inclusive determinism, CI Ruby floor). 49 tests / 311 assertions green. |
| View resolution | [`views.md`](specs/views.md), [`packet-compilation.md`](specs/packet-compilation.md), [`packet-format.md`](specs/packet-format.md) | **Done — gate-passed, COMMITTED (`6688ff9`) + PUSHED** (2026-07-08; rescan re-verified + pushed 2026-07-09) | VIEW-1..VIEW-7 frozen + folded; `add_view_candidates` between controller and constants; `view_candidate` (list-only) + `view_inferred_by_convention`; `max_view_files = 2`; `max_total_files` truncates by priority. Red-then-green fixture evals + `ViewResolutionTest` (independently re-verified 6/7 red with `lib/` reverted). Suite green **74 runs / 621 assertions**. **Mandatory Tier 0 re-scan PASSED and RE-VERIFIED 2026-07-09** — classifier output byte-identical to the post-amendment baseline, zero per-anchor change, zero crashes across 1,967 pairs (addendum + re-verification note in [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md)). Remaining: push (user go) + optional release-boundary Tier 2 validation (needs a `--dangerously-skip-permissions` session). |
| CONST-1 widening (companion) | [`packet-compilation.md`](specs/packet-compilation.md) | **Done — gate-passed, COMMITTED (`ab72137`) + PUSHED** (2026-07-09) | Codex-implemented (fable-frozen), intra-file action call graph: constant scan now covers action body + applicable same-file callbacks + same-file methods **transitively called from the action** (BFS, nil/`self` receiver + direct-method-name only; dynamic dispatch out). CONST-4 three-group order (action → callbacks → callees appended LAST) makes it **strictly additive under the 4-cap** (no eviction). CONST-1/1a/4 amended, `design.md` reconciled; new `file_order`/`omitted` fixture-eval DSL. 5 red-then-green fixtures + `constants_test` cases (independently re-verified red with `lib/` reverted). Suite green **89 runs / 815 assertions**. **Mandatory Tier 0 re-scan PASSED** — zero per-anchor change, zero crashes across 1,967 pairs (also a crash-stress test of the new call-graph code). |
| Locale pointer (companion) | [`packet-format.md`](specs/packet-format.md) FMT-8, [`views.md`](specs/views.md) | **Done — COMMITTED + PUSHED** (2026-07-09) | coding-worker-implemented (fable-frozen), targets the locale half of the P06/P20 ding. An **unconditional standing uncertainty note** ("Locale files are not scanned; user-facing strings conventionally live in `config/locales/`…") in `markdown_renderer.rb#uncertainty_notes` — chosen over a view-gated coded uncertainty because the gap is *newly-added keys* (orthogonal to view presence) and it mirrors the two existing standing notes. **No** retrieve-more suggestion (FMT-2 §8: code-less note ⇒ no suggestion; action embedded in the note). FMT-8 amended, `design.md` reconciled; no FMT-7/manifest change. Red-then-green in `packet_format_test.rb` (independently re-verified). Suite green **89 runs / 817 assertions**. **Tier 0 rescan N/A** — prose-only renderer change, no resolution/manifest behavior touched. |
| Seed Phase 0 (specs) | [`seeds.md`](specs/seeds.md) + amended specs/`design.md` | **Done — COMMITTED (`93f2b07`) + PUSHED** (2026-07-13) | Grok campaign: normative seed ontology + `design.md` product rewrite. |
| Seed Phase 1 (wrap) | `Seed` / compiler wrap | **Done — COMMITTED (`ce9e9cd`) + PUSHED** (2026-07-13) | Internal wrap; format v2 at land; Tier 0 byte-identical. |
| Seed Phase 2 gates | [`eval/seed-spikes/`](eval/seed-spikes/) test + files | **Done — COMMITTED (`ea0a2a6`) + PUSHED** (2026-07-13) | Pre-reg then measure; test 78.2% (≥70%), files neighbors 80.3% (≥40%). |
| Seed Phase 2 (test/files + v3) | seeds + format v3 + CLI | **Done — COMMITTED (`564fa11`) + PUSHED** (2026-07-13) | `--from-test`/`--from-files`, SEED-10 classifier, work-start corpus; suite **161/1455** at land; Tier 0 clean. |
| Seed Phase 3 (error) | `--from-error` | **Done — COMMITTED (`de587a1` w/ Phase 4) + PUSHED** (2026-07-13) | Spike P=1.0 R=1.0; PII-safe app frames only (SEED-20). |
| Seed Phase 4 (multi-seed) | MERGE-* | **Done — COMMITTED (`de587a1`) + PUSHED** (2026-07-13) | Multi-seed merge + multi `--from-*`; final suite **167/1530**; Tier 0 clean. **Campaign complete through Phase 4; stack on origin.** |
| Seed Phase 5a (method) | SEED-25, [`eval/seed-spikes/method/`](eval/seed-spikes/method/) | **Done — COMMITTED (`1ea31a8` gate + `517c97a`) + PUSHED** (2026-07-14) | Advisor-reviewed pre-reg; spike resolution 82.1% PASS / test-leg precision 0.6996 FAIL → `--from-method` ships **without** test-candidate leg. Grok-implemented; red-then-green re-verified; suite 185/0; Tier 0 byte-identical. |
| Seed Phase 5b (diff) | SEED-26, [`eval/seed-spikes/diff/`](eval/seed-spikes/diff/) | **Done — COMMITTED (`f5bdb37` gate + `b5450dd`) + PUSHED** (2026-07-14) | Paired-test co-change agreement 0.810 PASS → `--from-diff` ships **with** mirror-convention paired-test leg (explicit flag only). Grok-implemented; red-then-green re-verified; suite 205/0; Tier 0 byte-identical. |
| Seed Phase 5c (route) | [`eval/seed-spikes/route/`](eval/seed-spikes/route/) | **Closed — NO SHIP, COMMITTED (`3f69230`) + PUSHED** (2026-07-14) | Double-gated spike: resolution 0.243 FAIL (Front B margin +0.124 moot). Route evidence stays CLI-17c coaching-only; no implementation pass. Re-open needs a new pre-reg (router-order first-match resolver noted). |
| Context-engineering positioning | README/gemspec/examples/FAQ/`design.md` | **Done — parent-verified, COMMITTED (`3669e79`) + PUSHED** (2026-07-16) | Agenticons `coding_worker` + `doc_reviewer` pass: product category is context engineering CLI; mechanism remains deterministic context compiler; task + seed promise stays first; Rails remains v0 scope. Corrected the stale feature caveat against Tier 2 expansion (features 5/6, median 58.5%; bugs 0/3), with anchor-seed/offline/directional/no-quality-benefit boundaries. Parent full suite 205/1834 green; gemspec and diff checks pass. |
| git-recon agent facts interface | `~/Projects/git-recon` `facts --format=json` | **Done — optimization COMMITTED LOCALLY (`7682b2c`), not pushed** (2026-07-16) | Contract and prior reviews remain green. Trace2 found redundant history traversal plus 38,092 Bash-parsed diff records. Reuse + prefilter optimization: benchmark RED 10.776s → GREEN 4.965s; final 4.838–5.192s, byte-identical 1,920 bytes. Fixture suite/ShellCheck/Bash/diff gates pass; no dependency or schema change. |
| Files-seed history tracer | SEED-27 / Format 4 / git-recon adapter | **Done — parent-verified, COMMITTED (`3e7cf79`) + PUSHED** (2026-07-16; latency gate closed 2026-07-17) | Existing PATH-discovered companion, one revision-pinned request for the first retained files primary, typed bounded facts/omissions, no source eviction, deterministic replay. Parent suite 225/1976 green; Tier 0 byte-identical across 1,967 anchors; final strategic review clean. Recorded production provider-seam recheck: 6.020s, included 5 facts / 10 truncated / no error, leaving 13.98s under the unchanged deadline. |

Offline experiments (not conformance work, see [`eval-plan.md`](eval-plan.md)):

| Experiment | Status | Notes |
|---|---|---|
| Tier 0 anchor viability spike | **Done** (2026-07-05) | **91.0% engine-excluded average across Mastodon/Discourse/Zammad → ≥ 70% gate passes; proceed as designed.** Post-ANCH-amendment re-run: **93.9%**, zero regressions (addendum in RESULTS.md). Full method, taxonomy, and raw data in [`eval/tier0/RESULTS.md`](eval/tier0/RESULTS.md). Zero compiler crashes across 1,967 real-app pairs. |
| Tier 2 agent A/B | **Done — SUPPORT** (2026-07-06) | Harness (`eval/tier2/harness.rb`) + 18-session grid + pilot run; all 20 sessions `complete`, zero aborts, 100% `task_success`. 2/3 tasks (bug-fix, behavior-change) show ≥ 30% median reduction in calls-to-first-load-bearing-read; multi-file feature (task 1) mildly worse; diff quality at ceiling (control 8.00 / treatment 7.89, agent first-pass pending author confirmation). Directional support per the frozen rule. Full analysis: [`eval/tier2/RESULTS.md`](eval/tier2/RESULTS.md). |
| Tier 3 Rubydex offline probe | **Done — DEFER Rubydex, build view layer** (2026-07-08) | Gate PASSED (Rubydex indexes all 3 pinned apps offline <1s). Four-column offline recompute over the committed diffs ([`eval/tier3-rubydex/RESULTS.md`](eval/tier3-rubydex/RESULTS.md)): feature control prod-recall convention 0.685 → +view **0.815** (+0.130R/−0.097P) vs +rubydex 0.769 (+0.083R/**−0.312P**, halves precision; recall gain = 1 file, convention-reachable). Verdict: build a Rails view path-convention layer + widen the constant-scan to the whole controller file (dependency-free); locale = a pointer; **defer Rubydex** (native dep unjustified); **no new grid**. Fable advised (caught a GATE error + measured harm P06/P20). Bug caught + fixed: Rubydex resolution is cwd-dependent. Uncommitted. |
| Tier 2 expansion | **Done — SUPPORT / generalizes** (2026-07-08) | Grid complete (72 sessions + 6 pilots), verdict in [`eval/tier2-expansion/RESULTS.md`](eval/tier2-expansion/RESULTS.md): the packet meets the ≥30%-exploration-reduction bar on **3/3 apps across both frameworks**; multi-file features help (Tier 2 scare refuted); wins don't depend on the test pointer (code content is the driver); the bug task is the sole non-meeter (failing test already localizes). `task_success` saturated 71/72. **Both confirmatory passes now landed** (2026-07-08 eve): blind diff-quality 0–8 = control 7.94 / treatment 7.94 (no regression, gate closed); packet-vs-diff coverage (LIM-1 north-star) = control prod recall 0.80 / precision 0.63, recall gap concentrated in feature tasks and near-orthogonal to the exploration wins. Tier 3 (Rubydex) drafted (not frozen). [`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md) signed off. Adds Campfire (Minitest) + Lobsters + Publify (RSpec), 4 tasks/app (feature-weighted), test-pointer sub-analysis. P1 (RSpec rules, `21505b0`) + P2 (harness per-app config) landed. **Campfire** (`v1.4.3`, SQLite/Minitest) 4/4 test-candidate. **Lobsters** (`430d864b`, RSpec/MariaDB) within-app **2/2** split (the sharp sub-analysis contrast). **Publify** (`publify_core` **engine** v10.0.3 `80ede867`, RSpec/SQLite, Ruby 3.1.7) 4/4: anchors frozen (bug=`articles#preview`, behavior=`admin/users#destroy`, features=`setup#index`/`tags#index`), 4 tasks + hidden RSpec request specs authored (Codex) and **verified red-then-green session-side**, config wired, golden captured, `verify` OK, 2-session pilot green (both arms `complete`/`success`, minimal single-file fixes, no `spec/` edits, no amendments). Publify pins the `publify_core` ENGINE (the deploy app is a controller-less shell); bridged with a benchmark-only stub `config/application.rb` + `concurrent-ruby 1.3.4` pin + `spec/dummy` route extraction — no ctxpack compiler behavior touched. Grid ran 72 sessions + 6 pilots; verdict SUPPORT/generalizes. |
| View-pass release-boundary validation | **Done — coverage confirmed** (2026-07-09) | Packet-coverage check of view + CONST-1 + locale on publify ([`eval/tier2-expansion/VIEW_PASS_VALIDATION.md`](eval/tier2-expansion/VIEW_PASS_VALIDATION.md)): regenerated t1/t3 packets at the new lib (`c7a4ae3`) vs the frozen-grid packets. **t1 `setup#index` now surfaces the setup view + locale pointer** — the two-part P06/P20 omission — while **t3 `articles#preview` is byte-identical** (no view exists → no added distraction surface). Both watch-items pass. Per user decision the coverage confirmation is sufficient; subject-session behavioral re-run not spent (established prior + would risk frozen provenance). Frozen grid `runs.jsonl`/`packets/` untouched. |
| Seed test/files viability spikes | **Done — SUPPORT** (2026-07-13) | Pre-registered under [`eval/seed-spikes/test/`](eval/seed-spikes/test/) and [`files/`](eval/seed-spikes/files/); both gates passed (test avg 78.2%, files neighbor avg 80.3%). Committed `ea0a2a6`. |
| Seed error viability spike | **Done — SUPPORT / ship** (2026-07-13) | Pre-registered under [`eval/seed-spikes/error/`](eval/seed-spikes/error/); precision 1.0 / recall 1.0 → shipped `--from-error` in `de587a1`. |
| RubricLLM spike (issue #5) | **Done — DEFER, borrow-on-demand** (2026-07-14) | Source review at pinned `02ceec3` + offline side-by-side on committed coverage artifacts ([`eval/rubricllm-spike/`](eval/rubricllm-spike/)): retrieval metrics reproduce our numbers 72/72 exactly but replace ~30 lines; judge stack structurally mismatched (no blinding/offline/caching, [0,1] schema); paired t-test reports a uniform n=3 improvement as p=1.0 (se=0 landmine, demonstrated). Neither issue-#5 value criterion met → defer; borrow map recorded (t-test `comparison.rb:73–153` with se=0 fix + caveats; NDCG/MRR). No live pilot proposed; zero paid calls; no dependency change. |

## Next steps

1. **The files-seed tracer is complete and already pushed in ctxpack
   `3e7cf79`.** At this session's start ctxpack matched `origin/main`; this
   session did not push it. The already-present `~/.local/bin/git-recon`
   symlink resolves to the optimized local checkout and was not created or
   reinstalled.
2. **The post-optimization consumer gate passed.** The exact production
   provider-seam recipe is recorded in `implementation-notes.md`; its one
   measured run took 6.020 seconds and returned included history with 5 facts,
   10 truncated, and no error. That leaves 13.98 seconds before the unchanged
   20-second deadline.
3. **Current work order:** await explicit approval to push git-recon `7682b2c`
   and the ctxpack commit containing this measurement reconciliation. Verify
   both remote SHAs after an approved push. Current evidence does not justify
   batching or a Zig/Rust/C rewrite.
4. **Do not open a batch issue from this evidence alone.** ctxpack baseline is
   0.068s with a fake provider and the tracer already makes one request, so
   this is a single-path provider cost. The broader packet-value eval remains
   deferred, ctxpack #6 remains externally unchanged, and
   [#7](https://github.com/fuentesjr/ctxpack/issues/7) remains open but
   unscheduled. Ask before committing, pushing, or publishing issue text.
5. **Phase 5 and Phase 6 are complete and closed.** RubricLLM issue #5 is
   decided DEFER, borrow-on-demand, and closed.
6. **The release-boundary three-app harness rerun awaits explicit user
   sign-off.** Do not spend its ~50M subject tokens implicitly.
7. **Real-usage dogfooding remains discretionary.** Exercise LIM-1 against
   packet-vs-diff coverage on live work.
8. **Method test-leg and route resolver re-spikes need new frozen
   pre-registrations and new user work orders.**
9. **Tier 3 Rubydex remains deferred.**

## Decision log

- **2026-07-17 (consumer latency gate passed; push approval pending)** — The
  benchmark seam was deliberately redefined before measurement as a direct
  call to the production `GitReconHistoryProvider` with `Compiler::LIMITS`,
  avoiding a third speculative CLI reconstruction. The recorded recipe pins
  Rails at `1d19b2a1f90eb64f7cda2209621eb21a43511be0`, the PostgreSQL adapter
  path, the ctxpack bundle's Ruby, and the PATH-discovered optimized git-recon
  at `7682b2c`. Its predeclared landing rule required included history, 5 facts,
  10 truncated, no error, and less than the existing 8-second representative
  threshold. The one measured run passed in **6.020 seconds**, leaving 13.98
  seconds before the unchanged 20-second provider deadline. The exact recipe
  is now in `implementation-notes.md`, and the debt-ledger item is paid. Git
  ground truth also showed that ctxpack tracer commit `3e7cf79` already matched
  `origin/main` before this session; this session did not push. No behavior,
  timeout, dependency, CI, spec, recorded-evidence, issue, or published-text
  change occurred. The optimized git-recon commit and this ctxpack
  reconciliation still require push approval.

- **2026-07-16 (git-recon query optimized; consumer recheck pending)** — The
  user required a profile/optimization before landing and asked whether the
  companion should be rewritten in Zig, Rust, or C. Trace2 falsified the
  initial `diff-tree` hypothesis: Git processes used 5.116s of a 10.417s run,
  while Bash spent 4.763s parsing 38,092 diff records. The uncommitted
  git-recon change reuses the ordinary history result for repair filtering and
  uses a quoted-name count pass to reject oversized commits before exact
  NUL-delimited parsing. The opt-in benchmark was RED at 10.776s and GREEN at
  4.965s; final runs were 4.838s, 4.845s, and 5.192s with byte-identical
  1,920-byte output. Fixture tests, ShellCheck, Bash syntax, and diff checks
  pass. A compiled rewrite is deferred: Git history now dominates and a true
  replacement would create a semantic-equivalence/dependency/distribution
  project for roughly one remaining second of orchestration. The old ctxpack
  end-to-end numbers remain pre-optimization evidence. Two attempts to
  reconstruct that consumer benchmark hit the wrong Ruby and then Rails-app
  root discovery; per the two-attempt rule, further guessing stopped and the
  missing recipe was logged in `debt.md`. The optimization was committed
  locally as `7682b2c`; ctxpack was then authorized to commit. No push,
  dependency, timeout, default-on, or published-text change occurred.

- **2026-07-16 (files-seed tracer technically accepted; landing pending)** — The
  user approved the bounded vertical tracer and explicitly chose not to
  co-install git-recon. The existing `~/.local/bin/git-recon` symlink was
  verified to resolve to the clean `87032f6` checkout; this session did not
  create or reinstall it. ctxpack only discovers a compatible executable
  already on standard PATH. The uncommitted implementation adds one
  revision-pinned request for the first retained files primary, independent
  fact/byte/time limits, typed Format 4 history, graceful omission, and no raw
  Git fallback. Three end-to-end Rails runs completed in 19.021s, 19.018s, and
  18.623s with included history (5 facts / 10 truncated, no error), close to
  the unchanged 20-second provider deadline. Parent review found no P0/P1 code
  defects; two P2 documentation examples were corrected. Tier 0 is
  byte-identical to `post_amendment` across 1,967 anchors with zero crashes;
  the strategic validator passes and the final clean-context review is clean
  with no findings; the parent suite is 225/1976 green. A fake-provider compile
  took 0.068 seconds, so the orchestrator recommends improving single-path
  git-recon latency before landing default-on behavior. No batching issue,
  commit, push, or published text was created.

- **2026-07-16 (git-recon facts interface accepted)** — Implemented the
  interface-first decision directly in `~/Projects/git-recon` as compact,
  schema-typed JSON over a generic repo-relative path, optional line range,
  and explicit revision. The normalized commit table lets recent, repair,
  coupling, and origin facts share provenance without repeated metadata; all
  lists and the 20-row table are fixture-proven. Real Rails profiling caught
  and removed process amplification hidden by small fixtures; final measured
  direct git-recon runtime is 10.27–13.02 seconds on the selected high-churn
  PostgreSQL adapter and 1.26 seconds on git-recon itself. Two independent
  final reviews PASS.
  This enables but does not implement ctxpack integration and does not prove
  history deserves packet budget. After exact commit-message and push approval,
  git-recon `87032f6` and ctxpack reconciliation `233e6cd` were privacy-scanned
  and pushed to their upstream `main` branches; the earlier positioning commit
  `3669e79` shipped with the ctxpack push. No issue or repository-metadata
  mutation occurred.

- **2026-07-15 (git-recon interface before value eval)** — After reviewing
  the complete #6 preregistration, the user declined the 15-task corpus eval
  as disproportionate to the immediate, low-cost decision and chose to add an
  agent-facing git-recon interface first. The unapproved draft was deleted;
  it was never frozen, committed, or measured. Agenticons recon confirmed the
  underlying focused signals already exist in git-recon, while the missing
  seam is a versioned machine-readable command with explicit history bounds,
  stable ordering/caps, provenance, privacy-safe output, and deterministic
  replay. Those contract properties still get cheap fixture tests. The user's
  latest direction supersedes the earlier issue-only fallback, so the proposed
  next action is direct git-recon implementation after confirmation of the
  cross-repo multi-file plan; no git-recon issue was published. The interface
  enables ctxpack integration but does not prove that history facts improve a
  packet; that broader value eval is deferred. Published ctxpack #6 remains
  untouched pending exact approval of its disposition. No push was authorized.

- **2026-07-15 (#6 selected)** — Agenticons `planner` recommended executing
  the git-recon signal spike before the documentation spike because #6 starts
  the longer dependency chain and carries the larger leakage, privacy,
  determinism, and external-interface risks. The user authorized #6 and a
  local commit of the accepted positioning pass. The preregistration remains a
  separate exact-sign-off and commit/freeze gate before measurement. No push
  was authorized.

- **2026-07-15 (supplemental-context issue split)** — The initial broad epic
  was rejected as too large. The user approved a dependency-ordered breakdown
  and exact final text for two independent `type: task` spikes: ctxpack
  [#6](https://github.com/fuentesjr/ctxpack/issues/6) tests seed-driven
  git-recon signals, default-on if the evidence gate passes; ctxpack
  [#7](https://github.com/fuentesjr/ctxpack/issues/7) tests deterministic
  repository-documentation enrichment. Both were published and verified.
  Conditional integration mini-epics remain unopened until their respective
  spike results establish scope. Any high-value git-recon interface gap gets
  its own exact-text-approved issue in `fuentesjr/git-recon` before ctxpack
  depends on it. No commit, push, compiler change, spike run, or repository
  metadata update accompanied issue creation.

- **2026-07-15 (context-engineering positioning)** — User approved a local
  docs/metadata pass to name ctxpack's category without weakening its concrete
  promise. Agenticons `coding_worker` updated README, gemspec summary,
  examples, FAQ, and `design.md`: task + seed remains the lead; **context
  engineering CLI** is the user-facing category; **deterministic context
  compiler** remains the mechanism; Rails remains the v0/research scope. The
  stale many-file-feature warning was corrected against the recorded Tier 2
  expansion: features 5/6 at median 58.5% reduction on the better exploration
  metric; bugs 0/3. Claims stay offline, directional, anchor-seed-only, and do
  not assert better final code. No specs, behavior, dependencies, lockfile, CI,
  or recorded eval data changed. Parent verification: full suite 205/1834
  green, gemspec load/dependency check green, `git diff --check` green. The
  documentation review's seed-driven-selection and continuation wording fixes
  landed before acceptance. No positioning change was committed or pushed,
  and no repository metadata was published.

- **2026-07-14 (cross-repo eval process)** — User work order: prevent
  per-repo eval-framework proliferation ahead of an anticipated shared eval
  system. Created `~/Projects/evalkit` (new local repo, docs-first):
  binding conventions (vocabulary; required artifacts — frozen pre-reg,
  reuse line, results, inventory, provenance; extraction bar = duplicated
  in ≥2 repos AND plumbing-only, own work order, never retrofit measured
  runners) plus a convergence ledger seeded from real recon. Headline
  ledger row: the headless subject-session runner is already at the
  two-repo bar (this repo's Tier 2 harness + skill-tester's executor);
  extraction deliberately deferred until either runner next needs material
  change. skill-tester gained a docs-only inventory + pointer (its commit
  `891a649`); this repo's `eval/README.md` gained the evalkit pointer.
  User decisions: new dedicated repo over gist/skills-tree; conventions
  prescribe vocabulary + artifacts only (formats stay per-repo until
  extraction).

- **2026-07-14 (late)** — Anti-proliferation guardrails for eval tooling
  (user work order, prompted by six spike scripts duplicating the same
  plumbing): (a) `eval/README.md` — full runner inventory + **binding
  authoring rule** (new eval scripts must record which existing runner was
  considered and why it doesn't fit); (b) SEED-5 amended to require that
  line in every spike pre-registration, `design.md` reconciled in the same
  change, AGENTS.md project map row added; (c) `eval/lib/spike_harness.rb`
  extracted (pinned-apps table, exclusions, percentile, taxonomy, gate
  summaries) for FUTURE spikes only — measured spike scripts stay
  untouched as historical artifacts. Verified by
  `eval/lib/spike_harness_check.rb`: 14 checks including recomputing the
  recorded route-spike summary gates byte-for-value and a live pinned-SHA
  checkout verification. Deliberate non-goal recorded: no unified eval
  framework across tiers — plumbing and discoverability only.

- **2026-07-14 (evening)** — Two user work orders executed. **(a) Phase 6
  docs shift landed + pushed (`145ed4d`):** README/examples/FAQ now lead
  with task+seed; Grok drafted (grok-loop), two doc-reviewer audits found
  all claims/commands/numbers verified-real with five excerpt-fidelity
  fixes (missing `Generated from:`/`Scope:` renderer lines, an unmarked
  truncation, the README exploration claim reworded to the per-task/per-app
  pre-registered bar, a reproduce-it-yourself note). Fixes applied
  orchestrator-side because the companion refuses background-write resume
  on a dirty tree and committing a known-defective draft first was worse;
  recorded in the pass notes. Suite 205/0; Tier 0 N/A (docs-only).
  **(b) RubricLLM issue #5 decided: DEFER, borrow-on-demand**
  ([`eval/rubricllm-spike/`](eval/rubricllm-spike/)): source-verified
  review at pinned `02ceec3`; offline side-by-side reproduces committed
  coverage 72/72 exactly (zero LLM calls, zero paid spend, no dependency
  change, recorded evidence untouched); the se=0 t-test landmine
  demonstrated empirically (uniform n=3 improvement → p=1.0). Neither
  value criterion met; borrow map recorded; no live pilot proposed.
  Issue-closing comment posted with user sign-off and #5 closed; spike
  commit pushed (both user-approved 2026-07-14).
- **2026-07-14 (push)** — User explicit push approval; Phase 5 stack pushed
  `3951d1b..c10351a` to `origin/main` (staged plan, both gate commits, 5a/5b
  implementation, 5c no-ship gate, closure). Tracker Status/plan marked
  PUSHED / in sync.

- **2026-07-14 (later)** — Phase 5 campaign executed to completion under the
  user's explicit go ("do 5a, then 5b, then 5c") with commit-per-sub-pass
  approval (push not approved). Profile `grok-loop`; fable advised every
  pre-reg freeze (4 corrections on method, 2 on diff, 4 on route — the route
  ones load-bearing: symmetric arm predicate, per-population stub exclusion,
  helper variant demoted from the gate). Outcomes, all pre-registered and
  applied without renegotiation: **5a** `--from-method` shipped WITHOUT its
  test-candidate leg (resolution 82.1% PASS; token-match precision 0.6996
  FAIL by 4bp — Zammad generic-name flooding); **5b** `--from-diff` shipped
  WITH the mirror-convention paired-test leg (co-change agreement 0.810
  PASS); **5c** route NO SHIP (pooled resolution 0.243 FAIL — bare paths
  inherently REST-ambiguous, Discourse dynamic routes defeat verb matching;
  margin +0.124 moot) — coaching-only stands, re-open needs a new pre-reg.
  User decision in-session: the §12a Front B baseline was scored **offline/
  analytically** (no agent sessions). Both compiler boundaries re-scanned:
  Tier 0 byte-identical, 0 crashes / 1,967 pairs each. SEED-24 corpus
  re-scored (WS-7/8/9 added). Final suite **205 runs / 0 failures**.
  Learning note: `docs/agent-learnings/2026-07-14-spike-design-lessons-phase5.md`.
  Commits: `1ea31a8`/`517c97a` (5a), `f5bdb37`/`b5450dd` (5b), `3f69230`
  (5c gate) + this closure commit. Ops note: pinned-checkout history
  deepening for the diff spike fought repeated GitHub connection resets;
  Zammad ended up as a fresh depth-601 fetch at the pinned SHA (recorded in
  the 5b pre-reg as environment mechanics; Tier 0 worktrees untouched).
- **2026-07-14** — Planning-only session staged the Phase 5 plan (method →
  diff → route, one sub-pass each, per-kind SEED-5 spikes with frozen
  pre-registrations; method spike measures false-inclusion precision in
  addition to the ≥70% resolution bar; route double-gated on the acquisition
  §12a Front B ritual-only baseline and may validly not ship; work-start
  corpus re-scored at each gate per SEED-24). Implementation stays gated on
  an explicit user go per the 2026-07-13 work order. Ground truth
  re-verified: suite 167 runs / 0 failures at `7228efe`, tree clean, two
  local doc commits unpushed pending push approval.
- **2026-07-13** — User explicit **push approval**; campaign stack pushed
  `b71af62..5e1e87e` to `origin/main`. Tracker Status/execution plan marked
  PUSHED / in sync.
- **2026-07-13** — Tracker refreshed post-campaign for session resume: Status
  rows carry exact SHAs (`93f2b07`…`de587a1`); suite re-verify **167/1530**.
  User reconfirmed commit-after-phase yes; push only with explicit go (then
  granted same day — see entry above).
- **2026-07-13** — Grok run-to-completion campaign **completed Phases 0–4**
  (later pushed same day). Commits: `93f2b07` (Phase 0 specs), `ce9e9cd`
  (Phase 1 wrap), `ea0a2a6` (Phase 2 gates), `564fa11` (Phase 2 ship),
  `de587a1` (Phase 3–4 error + multi-seed). Spikes: test 78.2%, files
  neighbors 80.3%, error P=1.0/R=1.0. All compiler-boundary Tier 0 rescans
  byte-identical to `post_amendment` (1,967 pairs, 0 crashes). Final suite
  **167 runs / 1530 assertions, 0 failures**. Phase 5/6 out of scope.
- **2026-07-13** — Authorized the seed-interface implementation as a **Grok
  run-to-completion campaign** (user decisions, recorded via four explicit
  answers): (1) evidence gates honored **autonomously** — spikes run inside
  the campaign and their outcomes obeyed without pausing (a failed error
  spike demotes to P1 and the run continues); (2) scope is **Phases 0–4**
  (full P0: specs, anchor wrap, test/files/error seeds, format v3,
  multi-seed) — Phases 5–6 excluded; (3) **commit yes, push no** — the
  session commits each verified pass locally, the user reviews and pushes;
  (4) **Grok is the session itself**, not a delegate of a Claude
  orchestrator, so the Codex loop in "Working process" does not apply while
  every verification rule does. Same session: corrected a stale tracker
  claim — the CLI help + `--stdout=json` pass was already **committed and
  pushed as `b71af62`** (git verified `origin/main` in sync), not
  uncommitted as the previous plan draft said.
- **2026-07-13** — Accepted `docs/seed-based-interface-proposal.md` as the
  north-star product definition: **task + seeds → deterministic packet**,
  `controller#action` demoted to one seed kind. The doc survived three review
  rounds the same day — session review (fixes recorded as accepted decisions),
  an independent Opus review (7 findings applied, most notably making the
  format decision coherent: format v3 **replaces** v2 at Phase 2, no compat
  fork, anchor goldens re-baseline), and an independent Grok review (1 high
  finding applied: `*Controller#action`, including nested, stays **anchor
  evidence** via the CLI-17c suggest-only rewrite, never the method seed).
  Key recorded decisions (its §14): per-kind Tier-0-style viability spikes as
  phase gates, `error` seed go/no-go with PII-safe frame-only normalization,
  flags spelled `--from-<kind>`, multi-seed in the model but single-seed
  first, task-only refused in the gem. `docs/anchor-acquisition-proposal.md`
  §12a re-scopes that program (corpus paused pending seed-kind labels; G/F
  proceed; Front B priority drops; its recorded constraints inherited).
  The execution plan was first rewritten to a two-pass shape (Phase 0
  reconciliation + Phase 1 wrap), then superseded the same day — before
  anything was committed — by the Grok run-to-completion campaign recorded
  in the entry above.
- **2026-07-13** — Extended the existing mutation-free stdout mode with an
  explicit representation parameter instead of adding a second command or
  shallow flag: bare/`=markdown` emits Markdown and `=json` emits the exact
  public manifest renderer output. Help became a self-sufficient offline
  interface by carrying path bases, pipelines, output modes, and conflicts.
  Packet verification and a new fixed-path regeneration feature remain out of
  scope by explicit user direction.
- **2026-07-13** — Opened GitHub issue
  [#5](https://github.com/fuentesjr/ctxpack/issues/5) for an in-depth,
  evidence-gated RubricLLM spike. The issue requires measuring incremental
  value against ctxpack's existing deterministic and human-scored evaluation
  layers before proposing adoption; no dependency or paid call is authorized.
- **2026-07-13** — Raised ctxpack's supported Ruby floor from 3.2 to 3.4 with
  explicit user approval. The gemspec and CI remain coupled at the floor; CI
  still runs only the full suite plus the version-pinned, non-blocking metz
  step. Active install/compatibility docs and the open floor-plus-current CI
  backlog item now use 3.4. Historical notes retain older Ruby versions when
  they describe the environment in which recorded work actually ran.
- **2026-07-12** — Accepted and implemented all four packet-format v2 slices
  atomically because the user is the only current consumer. Manifest v2
  replaces v1 without a compatibility flag; consumers must inspect and reject
  unsupported versions. Markdown task containment is tested through the public
  renderer (EVAL-5 prefers stable fields over parsing prose), while a new YAML
  eval constrains the raw multiline task and manifest version facts. Historical
  format-v1 Tier 2 packets/prompts remain frozen and untouched. Tier 0 is N/A:
  no resolution, callback, constant, test-candidate, limit, or per-anchor
  classifier behavior changed.
- **2026-07-12** — CLI pipelines and Rails-aware recovery implemented locally
  with Agenticons orchestration. Added invocation-relative/injected multiline
  task input, artifact-free raw Markdown stdout, narrow pre-discovery recovery
  for common Rails-shaped mistakes, and Git-native ignore detection for the
  new implicit default directory. The reminder honors repo, info/exclude, and
  configured excludes and suppresses non-Git/operational cases. Parent
  verification and review remain pending; no commit/push is authorized.
- **2026-07-12** — Unavailable Git during compiler repo-stamp collection now
  degrades to the existing FMT-11 unknown repo state instead of crashing.
  Public compile coverage controls the executable boundary. No fixture YAML was
  added because Git availability is an environment condition that the static
  Tier 1 fixture DSL cannot deterministically express. Tier 0 is N/A because
  resolution, callbacks, constants, test candidates, limits, and per-anchor
  classification are unchanged. Parent verification remains pending.
- **2026-07-12** — CLI developer-happiness follow-on completed with Agenticons.
  Delivered: direct-anchor golden path with compatible `packet` form;
  root-independent descriptive help/no-argument help/version; `-t`/`-d`/`-o`/
  `-f`; unambiguous `--out`; `--force` for every overwrite; invocation-relative
  overwrite/filesystem errors; concise filesystem failure handling; and a
  targeted `packets` typo suggestion. QA found a pre-existing partial-output
  case when a forced sibling manifest destination was a directory; destination
  preflight now rejects it before compilation or either write, and QA re-ran the
  reproduction successfully. Documentation review found and fixed derived-name,
  EVAL-7 `--force`, CLI-5 coverage, and historical-note drift. Strategic
  validation passed 66 changed-slice tests and 28 merge-base red/green behaviors;
  final clean-context design review: clean, no findings. Focused CLI **38 runs /
  241 assertions**; full suite **116 runs / 1005 assertions**, zero failures.
  No compiler behavior or dependencies changed; Tier 0 N/A. Work remains
  uncommitted pending user direction.
- **2026-07-12** — CLI ergonomics pass completed locally with Agenticons
  (`coding_worker` implementation, `edge_case_analyst` acceptance audit; parent
  verification). Fixed six seams: manifest collision refusal, cwd-relative
  saved paths, path-only stdout/reminder-on-stderr, injected top-level/subcommand
  help, anchor-preserving 80-character names, and safe contextual route hints.
  Specs/design/user docs reconciled. Clean-HEAD red proof: 11 targeted runs, 9
  failures, plus the expected pre-fix help `SystemExit`; green: 24 CLI runs / 148
  assertions and 102 full-suite runs / 912 assertions, zero failures. Tier 0 N/A
  because no compiler behavior changed. The work was subsequently committed as
  `b8c2dc8`; this entry preserves the completion-time history rather than
  treating that prior pass as part of the current working tree.
- **2026-07-09** — Docs-quality session (committed, NOT pushed; orchestrated:
  Claude orchestrator, **4 parallel `doc-reviewer` subagents** for the drift
  sweep, **fable** advised the new docs' structure). Three landed changes:
  **(a) Doc-drift review** (`e5269f0`) — four doc-reviewers over disjoint groups
  (README/AGENTS/CLAUDE; compilation+views specs; format+CLI+eval specs;
  design/notes/plan) found six drifts, all verified by the orchestrator against
  code/git and fixed: README "Status"/"Current next step" described a
  pre-implementation state and linked closed #1/#2 (rewritten to shipped v0 +
  pointer to this tracker); tracker "NOT PUSHED" claims corrected (git shows
  `origin/main` synced); **VIEW-1 spec text** in `packet-compilation.md` +
  `views.md` claimed the view token drops a leading `_` (code only strips
  trailing `?`/`!`) — clause removed and the real VIEW-2 consequence documented
  (a `_`-prefixed action can't surface its own view); FMT-9 omitted-candidate
  categories under-enumerated; eval-plan Tier 2 lacked an "Executed" block;
  CONST-1a notes lacked the per-pass Verification block. AGENTS/CLAUDE/design/
  cli/fixture-evals specs were clean. **(b) VIEW-1 characterization eval**
  (`bcfed2f`) — Tier 1 fixture locking the leading-underscore behavior; a
  characterization test of already-correct behavior (green from the start, no
  `lib/` change), teeth shown by neutralizing the partial-exclusion filter
  (green → red → restore). **(c) User-facing docs** (`3edcc74`) —
  `docs/examples.md` + `docs/faq.md` for Rails devs; fable (advisor) corrected
  the install path (unpublished gem → github source), kept the usefulness claim
  honest/evidence-linked (offline exploration wins, no code-quality claim), and
  pushed for real generated packet output over fabricated examples. Suite green
  **91 runs / 0 failures**. No compiler-behavior change ⇒ no Tier 0 rescan.
- **2026-07-09** — View-pass release-boundary validation done; **coverage
  confirmed, subject re-run judged unnecessary** (user decision). Rather than a
  new grid, regenerated the publify t1/t3 packets at the current lib (`c7a4ae3`)
  and diffed coverage against the frozen-grid committed packets (write-up:
  `eval/tier2-expansion/VIEW_PASS_VALIDATION.md`). **(1) P06/P20 target closed at
  the packet level:** t1 `setup#index` now surfaces `app/views/setup/index.html.erb`
  (view_candidate) AND the locale standing note — the exact two-part omission
  (no form field + no locale) behind the two treatment-arm quality dings. CONST-1
  contributed nothing on publify (`User` was already action-body-reachable; its
  target was campfire t1). **(2) No bug-task regression surface:** t3
  `articles#preview` packet is byte-identical old-vs-new (no conventional view →
  the existence-gated glob adds nothing; the only universal addition is the
  one-line locale uncertainty note, not a file), so the added view surface cannot
  introduce distraction-read regression on the bug task. Given the frozen 72-session
  grid already established that treatment agents act on packet files, the
  coverage fact is load-bearing and the behavioral value follows; the optional
  subject-session re-run was not spent (predictable, and would require isolating
  regenerated packets from the committed frozen-grid provenance). Frozen grid
  `runs.jsonl`/`packets/` left untouched (regeneration went to scratch). Closes
  the last of the three companion work items requested this session (epic issue
  #4 filed, CONST-1, locale pointer, view-pass validation).
- **2026-07-09** — Locale-pointer companion pass landed (committed, not yet
  pushed; orchestrated: Claude orchestrator/verifier, **fable** froze the design,
  a local **coding-worker** implemented it). **Design fork resolved by fable
  (Option A over B):** an **unconditional standing uncertainty note** ("Locale
  files are not scanned; user-facing strings conventionally live in
  `config/locales/`. If the task adds or changes user-visible copy, add or update
  the matching locale key(s).") appended in `markdown_renderer.rb#uncertainty_notes`
  after the route note — chosen over a **view-gated coded uncertainty** because
  (i) the frozen guidance calls for "a standing pointer, not a resolver", (ii) the
  locale gap is *newly-added keys*, orthogonal to whether a view template exists
  (so view-gating wouldn't track the failure mode and would miss flash-only
  actions), (iii) it mirrors the two pre-existing unconditional standing notes,
  and (iv) it stays renderer-only (no compiler risk, no rescan). **fable caught
  two spec-compliance points** the orchestrator's first sketch missed: it must add
  **no** "Retrieve more only if needed" suggestion (FMT-2 §8 fixes that section as
  a pure function of uncertainty/omission *codes*; a code-less standing note would
  wrongly render it), so the conditional action is embedded in the note itself;
  and **FMT-8 must be amended** to enumerate the third standing note (no FMT-7 code,
  no MAN-2/manifest change — standing notes are Markdown-only, like the existing
  two). `design.md` reconciled. **Verified session-side:** red-then-green in
  `packet_format_test.rb` (independently re-confirmed red with the renderer line
  reverted; the RED output also confirms the note does not leak into the
  retrieve-more section), suite green **89 runs / 817 assertions**. **Tier 0
  rescan N/A** — prose-only renderer change, no resolution or manifest behavior
  touched (stated explicitly per the proof checklist, not silently skipped).
- **2026-07-09** — CONST-1 widening companion pass landed (committed, not yet
  pushed; orchestrated: Claude orchestrator/verifier, **fable** froze the design,
  **Codex** implemented via the `codex-spec-pass` loop with flags
  `--write` — full slice — then `--write --resume` for the pass notes). **Design
  fork resolved by fable** (over the orchestrator's first proposal): widen the
  constant scan from the action body to an **intra-file action call graph** —
  action body + applicable same-file callbacks + same-file methods transitively
  called from the action (the chosen option over "whole controller class", which
  the Tier 3 probe rejected for precision). **Ordering (CONST-4 amendment):**
  three groups — action → applicable callbacks → transitive callees **appended
  last** in BFS discovery order. fable's decisive argument: append-last makes the
  widening **strictly additive under `max_constant_files=4`**, so a transitive
  constant can never evict a direct action/callback constant (the precision
  failure that got whole-class rejected can't sneak back). **Detection:**
  `Prism::CallNode` with nil or `self` receiver whose name is a controller direct
  method; dynamic dispatch (`send`/`method`/aliases) out of scope. **BFS visited
  seeded on the action name only** so a callback-that-is-also-a-callee is still
  traversed *through* (path-dedup keeps its constants at the callback position).
  Spec CONST-1 reworded ("no **cross-file** call-graph"), CONST-1a added, CONST-4
  amended; `design.md` reconciled (Codex also fixed a design.md view-rationale
  that still referenced the rejected whole-controller option). Fixture-eval DSL
  gained `file_order`/`omitted` assertions to express the no-eviction test.
  **Verified session-side:** 5 red-then-green fixtures + `constants_test` cases
  (independently re-confirmed red with `lib/` reverted), suite green **89 runs /
  815 assertions**, and the **mandatory Tier 0 re-scan PASSED** — zero per-anchor
  change and **zero crashes across all 1,967 pairs** (doubles as a crash-stress
  test of the new BFS call-graph code; constant widening is additive and
  post-resolution). Codex owns the `implementation-notes.md` entry (confirmed
  current). Orchestrator note: an initial default-effort dispatch was cancelled to
  redispatch at higher effort, but it had already written the full diff to disk —
  so the output was verified in place rather than re-run (effort label is moot
  when the output passes requirement-by-requirement review + the rescan gate).
- **2026-07-09** — Tracker reconciled + view-pass Tier 0 rescan independently
  re-verified. A "Continue from PROJECT_TRACKER.md" session found the tracker
  self-contradicting: the execution plan/Status/commit called the view pass
  "COMPLETE but UNCOMMITTED" and the Tier 0 rescan "PASSED," while a "Known debt"
  line (committed in the *same* commit `6688ff9`, and referencing a date after
  its own timestamp) said the rescan was "still pending because GitHub DNS
  failed." Ground truth established: (a) the pass is **already committed**
  (`6688ff9` + `2e9284e`), tree clean, **3 commits ahead of `origin/main`,
  unpushed**; (b) GitHub is reachable — the "DNS failed" reading was a transient
  fetch artifact (the same `timeout`-command-not-found trap that also produced a
  false DNS-FAIL in this session's first probe); (c) the rescan was **re-run**
  at the three pinned SHAs (fresh shallow checkouts, `git rev-parse HEAD`
  verified, committed route tables) and its per-app/per-anchor output is
  **byte-identical** to `results/post_amendment/` — 0 regressions / 0
  newly-resolved / 0 label-flips / 0 crashes across all 1,967 pairs. Conclusion:
  the committed rescan addendum is genuine and the compiler-behavior gate is
  satisfied. Actions (local docs only, uncommitted): removed the disproven debt
  line; added a re-verification note to `eval/tier0/RESULTS.md`; rewrote the
  execution plan / Status / Next-steps to reflect committed-not-pushed +
  rescan-re-verified. No `lib/`/spec changes. Remaining next steps are all
  outward-facing (push; file the Tier 2 epic issue) or session-gated
  (release-boundary Tier 2 validation) — awaiting user go.
- **2026-07-08** — View path-convention pass landed in the working tree
  (uncommitted; orchestrated: Claude DRA/judge, a **Sonnet** worker folded the
  spec, **Codex** did the heavy compiler implementation). **(a) Freeze** — the
  four `[FREEZE]` decisions signed off by the user: all format variants,
  list-only `view_candidate` (empty snippet), `max_view_files = 2`, priority
  reorder controller → views → constants → tests with `max_total_files` held at
  8. **(b) Fold** — `specs/views.md` frozen; VIEW-1..VIEW-7 into
  `packet-compilation.md` (`## Views` + LIM-1 revised from an unreachable raise
  to priority-ordered truncation) and `packet-format.md`
  (FMT-4a/FMT-6/FMT-7/FMT-8/DET-2); `specs/README.md`, root `README.md`,
  `design.md` reconciled. Orchestrator adjudicated the fold's one flagged
  tension by making all pipeline diagrams place views before constants (matching
  DET-2/LIM-1; views have no data dependency on constants). **(c) Implement** —
  `add_view_candidates` between controller and constants; existence-gated glob
  `app/views/<controller_path>/<action>.*`, all variants sorted, partials and
  other-action prefixes excluded; single `view_inferred_by_convention`
  uncertainty; the total-file limit truncates the later test from both
  `packet.files` and "Tests to run" and names it omitted. **(d) Verify** —
  new red-then-green fixture evals (`view_*.yml`) + `ViewResolutionTest`,
  independently re-verified session-side (6/7 red with `lib/` reverted, green
  restored); full suite **74 runs / 621 assertions / 0 failures**; existing
  goldens (`accounts_upgrade`) unperturbed; no new deps. **(e) Mandatory Tier 0
  corpus re-scan PASSED** — classifier re-run at the three pinned SHAs against
  committed routes, **zero per-anchor change / zero crashes** across all 1,967
  pairs vs `results/post_amendment/` (view inclusion is additive and
  post-resolution; addendum in `eval/tier0/RESULTS.md`). Minor debt: the
  `enforce_total_file_limit` slice is now unreachable dead code (the allocation
  cap bounds total ≤ 8) — harmless, retained as a defensive invariant. Nothing
  committed (awaiting user go). Remaining: commit + optional release-boundary
  Tier 2 harness validation (needs a `--dangerously-skip-permissions` session).
- **2026-07-08 (late)** — OFFLINE Rubydex-recall probe **complete**
  ([`eval/tier3-rubydex/RESULTS.md`](eval/tier3-rubydex/RESULTS.md); orchestrated:
  Claude DRA/judge, Codex authored the recompute script, **Fable** consulted as an
  independent advisor). **(a) Gate PASSED** — Rubydex 0.2.8 is a *static* Rust
  indexer (no boot/DB); indexes all three pinned apps offline in <1s
  ([`GATE.md`](eval/tier3-rubydex/GATE.md)). **(b) Reframe (Fable-surfaced,
  verified):** the feature recall gap is *two* mechanisms, not one — Rubydex
  reaches only Ruby files (not `.erb`/`.yml`); its demonstrated reach is sibling
  models via the call graph, while views need a Rails path convention and locales
  are newly-added keys. Fable also caught a real error in the first `GATE.md`
  draft (`lobsters user_standing.rb` is an *agent-created* file, unreachable by
  any resolver) and pointed at *measured* harm (the only two treatment-arm
  quality dings in the 72-session grid, publify t1 P06/P20, are the view/locale
  omission). **(c) Four-column offline recompute** (`four_column_coverage.rb`,
  Codex-authored + session-verified; convention column self-checks byte-exact
  against the committed coverage baseline): feature control prod-only recall
  convention 0.685 → **+view 0.815** (+0.130R for −0.097P, ratio 1.33) vs
  **+rubydex 0.769** (+0.083R for **−0.312P** — halves precision). Rubydex raises
  recall on exactly **1 of 12 tasks** (campfire t1 `user.rb`, a literal `User.all`
  in a private helper — reachable by widening the convention scan to the whole
  controller file, no dependency); everywhere else it only floods precision
  (superclasses/jobs/concerns). **(d) A real bug caught session-side** (the
  self-check couldn't — it only guards the convention column): Rubydex resolution
  is **cwd-dependent**, not just `workspace_path`; fixed with `Dir.chdir(app_root)`
  around index/resolve (learning note
  `docs/agent-learnings/2026-07-08-rubydex-cwd-dependent-resolution.md`).
  **Verdict:** build a **view path-convention layer** + **widen the constant-scan
  to the whole controller file** (dependency-free, targets the measured harm);
  **locale = a pointer**; **DEFER Rubydex** (one convention-reachable file of
  recall for a halved precision + a native Rust dep `design.md` excludes); **no
  new agent grid** — validate the view pass at the release boundary via the
  existing harness. `rake test` green (55 runs; only `eval/` touched); corpus
  re-scan skipped (analysis script only, no compiler behavior touched). The
  `eval/tier3-rubydex/PROPOSAL.md` Rubydex grid is now **not pursued** on this
  corpus. Nothing committed (awaiting user go).
- **2026-07-08 (evening)** — Two confirmatory Tier 2 expansion passes landed via
  an orchestrated session (Claude as orchestrator/judge/DRA; Codex for the heavy
  analysis script; Sonnet subagents for scaffolding). **(a) Blind diff-quality
  0–8 pass** (commit `cac1190`): the pre-registered four-dimension rubric over all
  72 grid diffs — arm labels stripped, each app's diffs shuffled by a PRNG seeded
  on its app SHA, byte-identical diffs forced to identical scores (47 unique
  across 72), judge scored **blind to arm** (mapping sealed until scoring
  finalized). Result **control 7.94 / treatment 7.94 — no regression, gate
  closed**; diff quality is at ceiling in both arms (non-discriminating, as in
  Tier 2). The four sub-8s split 2 control / 2 treatment, so parity is insensitive
  to any single call; treatment's only misses are both on `pub t1` (setup nickname
  done backend-only, no view field). Harness `build_blind_judging.rb` +
  `tabulate_quality.rb` + committed provenance under
  `eval/tier2-expansion/judging/`. **(b) Packet-vs-diff coverage** (commit
  `c1e5f82`, `packet_coverage.rb`, Codex-authored + session-verified): recall/
  precision of each packet file-set vs the files each diff touched. Control
  (unbiased) prod-only **recall 0.80 / precision 0.63** — the ≤8-file packet
  recalls ~80% of production files sight-unseen; **no sign LIM-1's 8/4/2/120
  starves recall or grossly over-includes**. The recall gap is a **feature-task,
  resolution-scope gap** (feature 0.69 vs bug 1.00 vs behavior 0.83 — missed files
  are views/locales/sibling models the Zeitwerk path resolver can't reach) and is
  **near-orthogonal to the exploration wins** (highest recall on bug tasks, which
  show no win) → the packet's value is landing the first load-bearing file fast,
  not completeness. Verified session-side: quality tabulation + coverage re-run
  byte-identical, cells hand-checked against raw packets/diffs, `rake test` 55/362
  green (no `lib/` touched). No compiler behavior touched → corpus re-scan skipped
  (both passes). **(c)** GitHub issues #1/#2/#3 closed with pointers (user
  pre-authorized). **(d)** Tier 3 (Rubydex) drafted as
  `eval/tier3-rubydex/PROPOSAL.md` — **not frozen**; the coverage finding reshaped
  it (real gap, but orthogonal to value), so the DRA recommendation is a cheap
  offline Rubydex-recall probe before any grid, gated on whether Rubydex can index
  the pinned apps. The expansion epic's confirmatory work is now fully closed; the
  next step is the Tier 3 go/no-go decision, not execution.
- **2026-07-08** — Tier 2 expansion grid executed; verdict **SUPPORT /
  generalizes** ([`eval/tier2-expansion/RESULTS.md`](eval/tier2-expansion/RESULTS.md)).
  All **72 grid sessions** (3 apps × 4 tasks × 2 arms × 3 rounds) + 6 pilots ran
  `complete` on the subscription (`--dangerously-skip-permissions` session),
  serial, resumable; ≈51.4M subject tokens (~$20 Sonnet-equiv). Publify batched
  first as a usage-measurement run (hit the 5-hour rolling-window cap once,
  resumed clean); Campfire + Lobsters each swept 24/24 in one window. **Finding:
  the packet meets the frozen ≥30%-median-exploration-reduction bar on 3/3 apps
  across both frameworks** (Campfire 2/4, Lobsters 3/4, Publify 3/4; no treatment
  success regression). The two Tier-2-open questions resolved: **(1) multi-file
  features are the strongest category** (5/6 task-instances meet the bar, median
  58.5% reduction) — the Tier 2 n=1 "packet hurts features" pattern was noise;
  the sole weak category is the **bug task** (0/3), where control localizes
  directly from the failing-test output. **(2) The test-candidate pointer is not
  the driver** — wins persist/strengthen when the packet carries no test
  candidate (had_tc=false 2/2 meet, median 53.5% vs had_tc=true 6/10, 50%), so
  the packet's file/constant/callback content carries the value (caveat: n=2
  false, Lobsters' 2/2 split). `task_success` saturated 71/72 (only Publify
  control bug round-2 missed) → exploration metric carries the verdict, as in
  Tier 2. **Run-hygiene** (pre-registered): throttle-induced timeout/abort records
  (subject process hung on the usage cap, 0 tokens) re-run and kept only as
  provenance; one degraded 4 s `complete` (publify) deleted + re-run; every tuple
  has exactly one `complete`. **Usage note:** subject sessions run under the
  sterile `CLAUDE_CONFIG_DIR`, so `/usage` on the orchestrator config does not
  tally them (the account weekly limit is shared server-side; the grid's true
  draw is ~$20 Sonnet, small). Blind diff-quality 0–8 pass is a pending
  confirmatory follow-up. No compiler behavior touched → corpus re-scan skipped.
- **2026-07-08** — Publify (third Tier 2 expansion app) authored + validated +
  piloted; **the pinned unit is the `publify_core` engine, not the `publify`
  deploy app** (user-approved fork). Discovered at template prep that the deploy
  app is a controller-less shell — its 31 real controllers live in the
  `publify_core` engine gem — i.e. the engine + dummy-app shape the pre-reg
  rejected for Solidus (the "frictionless monolith" premise for picking Publify
  was false). User chose (over drop-to-2-apps or ancient monolithic Publify v8)
  to pin the **engine repo** `publify/publify_core` **v10.0.3** (commit
  `80ede867`) — a self-contained single engine with a committed `spec/dummy`
  app, SQLite, RSpec (much milder than Solidus's multi-gem monorepo). **Ruby
  3.1.7** via mise (`tmp/tier2-expansion/publify/mise.toml`; Rails 6.1). Three
  benchmark-only template shims, none touching ctxpack compiler behavior or the
  `runs.jsonl`/metric contract: (a) a **stub `config/application.rb`** — the
  engine root has none, and ctxpack's app-root discovery only checks
  `File.file?`; it is never booted (RSpec loads `spec/dummy/config/environment`);
  baked into the workspace baseline so it never appears in a subject diff; (b) a
  **`concurrent-ruby 1.3.4`** pin in the Gemfile (>= 1.3.5 dropped the implicit
  `require "logger"` Rails 6.1 needs); (c) prepared **`Gemfile.lock`** +
  dummy-app **`test.sqlite3`** (both gitignored upstream). Route table built by
  `bin/rails routes` from `spec/dummy` with `BUNDLE_GEMFILE` at the engine
  Gemfile (non-isolated engine routes draw into the dummy host app); 118 app
  pairs, classifier 98/118 resolved, 0 crashes. **Anchors drawn blind** (seed =
  engine SHA, `--features 2`): bug=`articles#preview`, behavior=`admin/users#destroy`,
  feature_1=`setup#index`, feature_2=`tags#index`; all four fire
  `had_test_candidate=true` (**4/4**, like Campfire — the within-app test-pointer
  contrast comes from Lobsters' 2/2). **4 tasks + hidden RSpec request specs +
  seed authored (Codex)** and **independently verified red-then-green
  session-side** (Codex's sandbox lacks Ruby 3.1.7/bundle/DB; it authored +
  git-apply-checked, the orchestrator ran red-green via the harness `setup`/`score`
  paths + throwaway clones): task1 (setup nickname) 2→0, task2 (tags JSON) 1→0,
  task3 (preview bug) seed→failing-output captured / base spec green 54/0, task4
  (self-delete) 2→0; additive check green (setup 13 / tags 15 / admin-users 8, all
  0 failures). **Golden captured, `verify` OK, 2-session pilot green** (task 3;
  both arms `complete`/`success`, each a minimal single-file
  `articles_controller.rb` fix — control reimplemented the last-draft lookup
  inline, treatment restored `Article.last_draft` — neither touched `spec/`, no
  amendments; ~64-74s). No harness contract change (Redmine/Campfire/Lobsters
  `verify` still OK). No compiler behavior touched → corpus re-scan skipped per
  its rule. ctxpack suite green (55 runs, 362 assertions). All three expansion
  apps are now ready; the gate is the grid run (needs a
  `--dangerously-skip-permissions` session).
- **2026-07-07** — Lobsters (second Tier 2 expansion app) authored + validated +
  piloted. Pinned to HEAD **`430d864b`** (no tagged releases; SHA recorded
  verbatim), RSpec + FactoryBot. **Env setup** (README has full detail):
  `brew install mariadb` + a local server (name resolution maps the app's TCP
  `127.0.0.1` peer → `localhost`, so `root@localhost`'s password was set to match
  the app's committed `database.yml.sample` local-dev value); `brew install vips` (the app
  won't boot without libvips); Ruby **4.0.0** via `mise install` (exact
  `.ruby-version`; the machine's mise global 4.0.1 mismatches Bundler's
  `ruby file:` pin). **Anchors drawn blind** (seed = app SHA): bug=`inbox#all`,
  behavior=`stories#update`, feature_1=`comments#disown`,
  feature_2=`users#standing`; route table via `bin/rails routes`
  (`build_routes_from_rails.rb`; 189 pairs, classifier 170/189 resolved, 0
  crashes). **4 tasks + hidden RSpec acceptance specs + task-3 seed authored
  (Codex)** and **independently verified red-then-green session-side** — Codex's
  managed sandbox blocks local MariaDB (learning note
  `docs/agent-learnings/2026-07-07-sandbox-blocked-db-validation.md`), so it
  authored + syntax/patch-checked but the orchestrator ran the actual red-green
  via the harness `setup`/`score` paths + a warm clone: task1 1→0 failures,
  task2 green passes (base loops → timeout→false), task3 seed 2→fix 0, task4 1→0;
  additive check green (stories 27 / comments 9 / users 12). **Within-app 2/2
  test-candidate split** (tasks 1,3 fire the pointer; 2,4 don't — the request-spec
  path match needs both controller+action tokens in the filename) — sharper
  sub-analysis contrast than Campfire's 4/4. **Golden captured, `verify` OK,
  2-session pilot green** (task 3; both arms `complete`/`success`, minimal
  `:unread`→`:all,:unread` fix, neither touches `spec/`, no amendments; ~62-64s
  each). **Two additive harness changes** (P2-compatible; `runs.jsonl` schema,
  metric definitions, prompts, abort/timeout rules unchanged; Redmine + Campfire
  `verify` still OK): (a) `remove_files` config + a guarded workspace-baseline
  commit in `make_workspace` — strips the repo's `CLAUDE.md`/`AGENTS.md`
  (auto-loaded by subject sessions; also removed from the template working tree
  so agents in the ctxpack repo don't load the "refuse to write code"
  instruction) and bakes the `Gemfile.lock` platform patch into the baseline so
  neither leaks into the subject diff; no-op for clean-tree apps; (b)
  `SCORE_TIMEOUT_S` (6 min) + `run_test_with_timeout` — a non-terminating
  acceptance run (the base `users#standing` action infinite-loops on a `.json`
  request) is process-group-killed and scored `false` rather than wedging the
  serial grid. Both recorded as pre-registration amendments
  (`eval/tier2-expansion/PREREGISTRATION.md`). The Lobsters `CLAUDE.md`/`AGENTS.md`
  forbid LLM *contributions* (PR-scoped per user confirmation); using a pinned,
  read-only checkout as an offline benchmark (diffs discarded, nothing upstream)
  is outside that scope. No compiler behavior touched → corpus re-scan skipped.
  ctxpack suite green (55 runs, 362 assertions).
- **2026-07-07** — Campfire (first Tier 2 expansion app) authored + piloted.
  Pinned to tag **`v1.4.3`** (`71ffeeea…`), not a moving HEAD — a stable release
  whose committed `Gemfile.lock` (rails 8.2.0.alpha, pinned git revision) makes
  bundling reproducible. **Anchors drawn blind** (seed = app SHA, before any
  packet): bug=`rooms#index`, behavior=`rooms/involvements#update`,
  feature_1=`autocompletable/users#index`, feature_2=`accounts#edit`; frozen in
  `eval/tier2-expansion/campfire/anchors.json`. Route table via
  `bin/rails routes` (new committed helper `eval/tier2-expansion/build_routes_from_rails.rb`
  — Campfire is rails-edge, so the Tier 0 no-boot stub can't fetch its
  unpublished actionpack; 118 app pairs, 77 resolved). **`draw_anchors.rb`
  generalized** (Codex) for the feature-weighted mix + parameterized test-file
  layout (`--test-glob`, `--features N`); still reproduces Redmine's frozen draw
  exactly. **4 tasks + 4 hidden acceptance tests authored** (Codex) and
  **independently verified red-then-green session-side** (I wrote throwaway
  reference impls for the 3 non-pilot tasks — the 2-session pilot only exercises
  the bug — and confirmed all are additive: existing app suites stay green).
  **All four packets fire `had_test_candidate: true`** — Campfire's modern
  `test/controllers/` layout fires the TEST-1 pointer that Redmine's
  `test/functional/` could not, so the pre-registered test-pointer sub-analysis
  now has signal. Pilot (task 3, both arms): `complete`/`success=true`, minimal
  `rooms.first`→`.last` fix, no `test/` edits, scoring green, no amendments.
  Two harness changes, both additive app-parameterization (P2-compatible, not a
  contract change): `draw_anchors.rb` generalization (above), and an
  `AppConfig#config_dir` override so Campfire reuses Redmine's authenticated
  sterile `CLAUDE_CONFIG_DIR` — Claude Code binds OAuth to the *literal*
  config-dir path (macOS Keychain), so a copied/symlinked dir is not
  authenticated; the override points at the exact authed path. Redmine `verify`
  still OK (regression). **Environment trap recorded** for Lobsters/Publify: the
  machine runs mise (active) + rbenv; mise ignores `.ruby-version` and its global
  Ruby (4.0.1) is too new for Campfire's lock — fixed with a `mise.toml` pinning
  3.4.5 in the app tree and launching all harness/test commands via
  `mise exec ruby@3.4.5 --`. No compiler behavior touched → corpus re-scan
  skipped per its rule. ctxpack suite green (55 runs, 362 assertions).
- **2026-07-07** — P2 (Tier 2 harness multi-app generalization) landed via the
  Codex delegation loop. `eval/tier2/harness.rb` is now driven by per-app Ruby
  config objects (`AppConfig`/`TaskConfig` in `eval/tier2/apps/config.rb`), one
  file per app; `redmine.rb` carries the former Redmine constants (SHA, prepared
  files, anchors, Minitest command/filter, task2 seed + failing-capture,
  scoring). Orchestrator decisions before dispatch: **Ruby config objects (not
  YAML)** — per-task scoring has real logic (task2's forbid-`test/` rule,
  acceptance-test copy) that resists declarative config; **harness stays at
  `eval/tier2/harness.rb` with Redmine's committed tree untouched**, new apps get
  their own artifact trees under `eval/tier2-expansion/<app>/`; **the
  pre-registered test-pointer sub-analysis metrics were plumbed now** (they are
  harness code). New capabilities: an offline `verify` subcommand proving app
  representability (schedule/run-ids, byte-for-byte prompts, prompt determinism,
  packet SHA-256s) against a committed `golden/` oracle; per-app `runs.jsonl`
  with an additive `app` field; `packets.json` now records `had_test_candidate`
  + `suggested_test_commands` from the packet manifest; two treatment-only
  metrics (`packet_had_test_candidate`, `ran_suggested_test_before_first_edit`).
  Skeleton `campfire`/`lobsters`/`publify` configs load and short-circuit on 0
  tasks. `runs.jsonl` schema (additive only), status meanings, existing metric
  definitions, transcript/diff artifacts, and resume semantics are unchanged.
  Session-side verification (never trusting Codex's summary): the on-disk
  `golden/` was regenerated from the **original committed harness** (`git show
  HEAD`) and confirmed byte-identical — so `verify` passing is a real
  representability proof, not circular; `harness.rb verify` prints `OK` and
  `status` lists the frozen 20 tuples; `analyze_transcript` recomputed the
  existing metrics **byte-identical to the committed records** across 4 real
  sessions (both arms, tasks 1–3), with the new metrics correct (`nil` on
  control, `false` on Redmine treatment per the `test/functional/` limitation);
  `bundle exec rake test` green (55 runs); no changes to `lib/`/`exe/`/`specs/`
  or committed Redmine artifacts. Corpus re-scan skipped per its own rule (no
  compiler behavior touched). Both expansion prerequisites (P1 `21505b0`, P2) are
  now landed; the gate is per-app task authoring.
- **2026-07-07** — P1 for the Tier 2 expansion landed: ctxpack now detects an
  RSpec test family when `spec/` plus `spec/rails_helper.rb` or `rspec-rails`
  is present, emits `rspec_candidate` entries for
  `spec/controllers/<controller>_controller_spec.rb` and path-token-matched
  `spec/requests/*_spec.rb`, ignores `spec/system/` for v0, and suggests
  `bundle exec rspec <path>`. Minitest remains the fallback family and keeps
  `bin/rails test <path>`. Specs, `design.md`, README, fixture evals, and
  implementation notes were reconciled; `accounts_upgrade_rspec.yml` covers
  the new path. P2 is now the expansion gate.
- **2026-07-06** — Tier 2 expansion pre-registration frozen (user sign-off in
  session); [`eval/tier2-expansion/PREREGISTRATION.md`](eval/tier2-expansion/PREREGISTRATION.md).
  Post-SUPPORT fork resolved as **expand** (not the compiler refactor). Verified
  app candidates via two background research agents (Minitest modern-layout hunt
  + runnable-RSpec hunt). Frozen app set: **Campfire** (`basecamp/once-campfire`,
  Minitest, modern `test/controllers/`, MIT/SQLite — fires the test-pointer rule
  Redmine's `test/functional/` layout could not) + **Lobsters** (`lobsters/lobsters`,
  RSpec, Rails 8, MariaDB-only, `spec/controllers` + `spec/requests`) + **Publify**
  (`publify/publify`, RSpec, SQLite, frictionless). Solidus considered, rejected
  for v0 (monorepo + generated-dummy-app, per-engine scoring complexity).
  Sign-off decisions: Publify over Solidus; 4 tasks/app (2 feature / 1 bug /
  1 behavior — feature-weighted to probe Tier 2's one loss, the multi-file
  `twofa` feature); RSpec extension scoped to controllers + requests (no
  `spec/system/`). Design answers three questions: multi-file-feature effect,
  test-pointer contribution (pre-registered sub-analysis splitting deltas by
  `packet_had_test_candidate`), and cross-framework generalization. Two build
  passes gate the grid — P1 (ctxpack RSpec test-candidate rules) then P2
  (harness multi-app config + `bundle exec rspec` scoring); `runs.jsonl`
  contract and metric definitions unchanged. Grid ~72 sessions
  (3 apps × 4 tasks × 2 arms × 3 runs), resumable across usage windows.
- **2026-07-06** — Tier 2 grid executed; verdict **SUPPORT** (directional).
  Harness (`eval/tier2/harness.rb`) ran the 2-session pilot then the
  18-session grid in two same-day batches (round 1, then rounds 2+3) on the
  user's subscription; all 20 sessions `complete`, zero aborts/timeouts,
  ≈10.64M grid tokens, ~44 min elapsed. No acceptance-test or harness
  amendment was needed (pilot diffs correct first try). Per the frozen rule
  (≥30% median reduction in calls-to-first-load-bearing-read or distraction,
  ≥2/3 tasks, no success/quality regression): tasks 2 (bug-fix, LBR 4→2) and 3
  (behavior, 2→1) clear the bar; task 1 (multi-file feature) is mildly *worse*
  (5→7) — the packet aids small-surface tasks and adds exploration overhead on
  spread-out feature work, the study's key nuance. `task_success` is 100% in
  both arms (saturated → non-discriminating); blind diff quality is at ceiling
  (control 8.00 / treatment 7.89, no regression) but those 0–8 scores are an
  agent first-pass (`tmp/tier2/judging/`, seed = app SHA) pending author
  confirmation, so the load-bearing claim is the exploration metric, not the
  quality gap. Pre-registered follow-up rule ("support → expand to more tasks
  and a second app") now live; task-1 regression + Redmine's structurally
  empty test-candidate pointer (`test/functional/` layout, TEST-5) make a
  modern-layout, multi-file-feature follow-up the sharpest next probe. Full
  method and tables: `eval/tier2/RESULTS.md`.
- **2026-07-05** — Tier 2 pre-registration frozen (user sign-off in session);
  full design in `eval/tier2/PREREGISTRATION.md`. Key decisions: app is
  Redmine @ `3386d959` — the only large conventional Minitest candidate
  (Tier 0 trio are RSpec; ctxpack test rules and task shape 2 assume
  Minitest); its anchor scan gave 98.2% resolution (330/336, zero crashes),
  data under `eval/tier2/{routes,results}/`. Subject pinned to Claude Code +
  Sonnet 5 — the current Sonnet is the honest strong control (same sticker
  price as older Sonnets, cheaper on intro pricing; downgrading the subject
  would inflate the packet's measured benefit; if budget ever binds, cut
  runs, not the control). Anchors drawn deterministically before any packet
  existed (`draw_anchors.rb`, seed = app SHA, skips logged). 3 runs/arm
  (18 sessions + 2-session pilot) with a pre-registered all-tasks-at-once,
  no-post-peek extension rule to 5. Grid runs on the user's Claude
  subscription: serial sessions, arm order alternating by round, batches
  resumable across 5-hour usage windows via `runs.jsonl`, throttled
  sessions recorded `aborted` + re-run (vs `timeout` = agent failure,
  metrics kept). Known limitation recorded: Redmine's `test/functional/`
  layout means packet test candidates are structurally empty — this
  instance measures code-content value, not the test pointer. Runner shape:
  a Minitest test file (`test/ctxpack/fixture_evals_test.rb`) that globs
  `test/fixtures/evals/*.yml` and defines two tests per case (packet
  expectations against the internal packet object per EVAL-5; CLI
  determinism per EVAL-7 via in-process `Ctxpack::CLI#run` with fixed
  `--out --force --manifest`, SHA-256 over both artifacts), so `bundle exec rake
  test` runs Tier 1 with zero extra wiring and EVAL-11 re-runnability holds
  by construction. First CI workflow authored: push/PR, Ruby 3.2 (the
  gemspec floor; local dev covers newer), `rake test`, plus the
  non-blocking metz step pinned to 0.4.0. Session-side review confirmed one
  defect, fixed in one `--resume` round: an empty case-file glob silently
  defined zero tests — CI would stay green with the whole Tier 1 net gone
  — now a load-time raise; the same round removed a redundant
  `bundle install` CI step, made determinism manifest-inclusive, and moved
  the CI Ruby pin to the floor. The fix round hit the known stale-"running"
  failure mode (work complete, log dead ~29 min); record cancelled after
  session-side verification per the playbook. Corpus re-scan skipped per
  its own rule (no compiler behavior touched). Metz split refactor weighed
  at the pass boundary per plan: stays deferred — pass 4 added zero lines
  to `lib/`, so pressure is unchanged; re-weigh at the next pass that
  touches the compiler. Suite: 49 tests / 311 assertions green.
- **2026-07-05** — Pass 3 landed via the Codex delegation loop. OptionParser
  chosen over Thor at pass start (spec doesn't demand Thor; keeps prism the
  only runtime dependency). `Ctxpack::CLI#run(argv)` behind a thin
  `exe/ctxpack`, with injectable stdout/stderr/cwd/clock for in-process
  tests; gemspec ships the executable. Session-side review verified all 19
  CLI requirements and confirmed one defect, fixed in one `--resume` round:
  the CLI-14 gitignore reminder was skipped when `.ctxpack/` was created
  implicitly as a parent (e.g. `--dir .ctxpack/sub`) — directory creation
  now compares `.ctxpack/` existence before/after instead of matching
  created dirnames. The same round added the missing CLI-8 anchor-only
  derivation test. Corpus re-scan skipped per its own rule (no compiler
  behavior touched). Suite: 47 tests / 274 assertions green.
- **2026-07-05** — Eval platforms (promptfoo, Langfuse, Braintrust) evaluated
  and deferred. Rationale: Tiers 0/1 have no LLM output to score — their value
  is being boring, deterministic, and CI-native (EVAL-8) — and Tier 2's
  metrics are custom mechanical scorers over transcripts and diffs that no
  platform provides; what a platform would add (run storage, comparison UI)
  doesn't pay for itself at 18–30 pre-registered sessions, and
  prompt-iteration-oriented tooling pressures against the pre-registered
  discipline. Revisit trigger: the eval-plan decision rule "Tier 2 support →
  expand to more tasks and a second app," when bookkeeping pain is real and
  specific. If adopted then, Braintrust is the closest fit (experiment/dataset
  model, custom scorers); promptfoo is the weakest (prompt-matrix testing;
  the wrapper prompt is fixed across arms by design). Hedge adopted now
  instead: the Tier 2 harness emits a stable JSONL run record per session
  (recorded in `eval-plan.md`, Tier 2 setup), so any later platform adoption
  is an import problem, not a redesign.
- **2026-07-05** — Three feedback-loop decisions adopted (in-session
  discussion): (a) the corpus re-scan is now a standing pass-boundary step
  for compiler-behavior changes (mechanics in "Working process" above) —
  it had already run twice as habit and paid off both times; (b) pass 4's
  eval runner must be designed re-runnable at any SHA, and the Tier 2
  harness follows the same principle, so Tier 2 becomes a repeatable
  usefulness-regression check at release boundaries rather than a one-shot
  gate; (c) packet-vs-diff coverage — files the completed task actually
  touched vs. files in the packet, read as recall/precision — is the
  post-v0 north-star metric and the designated evidence source for
  validating the LIM-1 limits. No telemetry or `ctxpack feedback` command
  gets built until real usage exists to measure. Reconciled into the durable
  docs in the same change: EVAL-11 (re-runnable runner) added to
  `specs/fixture-evals.md`; `design.md` ("Simple v0 evals", "v0 packet
  limits") and `eval-plan.md` (Tier 0 classifier reuse, Tier 2 re-runnable
  harness) updated to match.
- **2026-07-05** — Pass 2 landed via the Codex delegation loop.
  `Ctxpack.render_markdown` / `Ctxpack.render_manifest` render the pass 1
  packet object; snippets are read at render time from `packet.app_root`
  (new read-only packet metadata, excluded from the manifest); the manifest
  is `JSON.pretty_generate(packet.to_h)`. Session-side review confirmed two
  defects, fixed in one `--resume` round: the FMT-5 truncation marker now
  derives its line count from `Compiler::LIMITS[:max_snippet_lines_per_file]`
  (LIM-1 values are provisional, a hardcoded "120" would drift), and the
  Anchor section's mislabeled lines were split into correctly labeled
  Anchor/Controller/Action lines. Known coupling recorded in
  `implementation-notes.md`: the renderer's test-candidate Why templates
  match the compiler's stored `why` strings exactly. Suite: 34 tests /
  193 assertions green.
- **2026-07-05** — metz-scan adopted as an advisory dev linter on ctxpack's
  own `lib/` (dogfooding; mechanics in "Working process" above): pinned
  0.4.0, `rake metz`, Metz-only via committed `.rubocop.yml`, never gating.
  Explicitly *not* a packet-content integration — that idea is deferred
  post-v0, gated on Tier 2 evidence. Day-one dogfooding filed
  [metz-scan#31](https://github.com/fuentesjr/metz-scan/issues/31)
  (full-suite default noise) and
  [metz-scan#32](https://github.com/fuentesjr/metz-scan/issues/32)
  (Metz/Metrics duplication); log in `metz-scan-feedback.md`.
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
  evidence (tracked in `design.md`). Long-term, packet-vs-diff coverage is the
  designated evidence source (decision log 2026-07-05).
- Generic validators that auto-load every `*_test.rb` will trip over the
  static fixture tests under `test/fixtures/apps/`; the Rake task excludes
  them deliberately (TEST-4: content is never read).
- metz-scan baseline (2026-07-05, advisory; re-scanned at the pass 3
  boundary): `Ctxpack::Compiler` is flagged `ClassesTooLong` [504/100],
  `MarkdownRenderer` [216/100], and now `Ctxpack::CLI` [145/100], plus long
  methods across all three. Splitting the compiler (e.g. callbacks /
  constants / test-candidates collaborators) remains the highest-pressure
  candidate refactor to weigh at a pass boundary, not mid-pass; the class
  will grow again when future reason codes land. Weighed at the pass 4
  boundary: deferred (pass 4 added zero lines to `lib/`); re-weigh at the
  next compiler-touching pass.
