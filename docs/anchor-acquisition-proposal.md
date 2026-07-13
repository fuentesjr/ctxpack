# Design proposal: CLI ergonomics via anchor acquisition

**Status:** Reviewed draft — first review incorporated 2026-07-13 (§12); **re-scoped same day under the accepted seed ontology (§12a)**; still not normative; not yet reconciled with `specs/` or `design.md`  
**Date:** 2026-07-13  
**Problem priority:** Highest remaining **CLI / product ergonomics** gap — everything left of a valid `controller#action`  
**Authoring context:** Follow-on to CLI ergonomics review; supersedes “regenerate / same-task iterate” as the priority ergonomics bet

---

## 1. Summary

### 1.1 Ergonomics thesis

Recent CLI work made ctxpack **pleasant once you already know the anchor**:

- direct form (`ctxpack accounts#upgrade -t "…"`)
- short aliases, self-sufficient help, path-only success stdout
- pipelines (`--task-file`, `--stdout` / `--stdout=json`)
- force-only overwrite, Rails-shaped rejection messages

That is real ergonomics — for the **second half** of the journey. The **first half** is still awkward:

```text
what I actually have          what ctxpack wants
─────────────────────        ──────────────────
helper / URL / log /         controller#action
stack / test / bug report  →  (exact, snake_case)
```

**The highest-priority ergonomics problem is not more flags or regenerate UX.** It is **time-to-first-good-packet**: how quickly a human or agent turns messy Rails reality into a valid anchor and a successful `ctxpack` invocation — with low cognitive load, few dead-end errors, and copy-pasteable next steps.

Anchor acquisition is the **mechanism**; ergonomic improvement is the **goal**.

### 1.2 Proposal in one breath

Treat **anchor acquisition** as the next ergonomics program. Attack it with multiple fronts (richer diagnostics, Rails-backed resolve, stack/test extractors, docs/skills, optional route cache, soft ranking last). Keep packet compilation exact and deterministic (`ANCH-*`). Discovery may be best-effort; compile stays byte-stable once an anchor is fixed.

**Explicitly not the ergonomics bet:** “same task, iterate” / soft-overwrite of timestamped packets. Primary use is one point-in-time packet per attempt; automation already has `--out … --force`.

### 1.3 Before → after (user-visible)

| Situation | Today (friction) | Target ergonomics |
|---|---|---|
| I have `upgrade_account_path` | Reject or “try `rails routes`”; I run a second tool, parse a table, retype anchor | One resolve step (or a paste-ready suggested command) → anchor → packet |
| I paste a production log line | Unknown / invalid input noise | Recognized as anchor (or one confirm) → packet |
| I paste a stack frame | Manual path→controller mental math | Suggested `admin/accounts#upgrade` with evidence |
| I only have a bug title | Read FAQ; invent search terms; hope | Skill/docs ritual + ranked candidates; never a silent wrong compile |
| I type `AccountsController#upgrade` | Already improved (rewrite hint) | Keep; extend to more dialects |
| I know the anchor already | Fast path works well | **Unchanged** — do not make the golden path longer |

---

## 2. Problem statement

### 2.1 Ergonomics already shipped vs still open

| Layer | Ergonomics question | Status |
|---|---|---|
| **Invocation & output** | Is the CLI pleasant when the anchor is known? | Largely **done** (2026-07-12/13 passes) |
| **Compilation (Tier 0)** | Given a real route-table anchor, does compile succeed? | ~91% on sample apps; gate passed |
| **Acquisition (open)** | Can I get from helper/URL/stack/bug report to a correct anchor with low effort? | **Open** — docs + `bin/rails routes` + partial CLI-17c guidance |

Tier 0 answered viability of **anchors we already have**. Acquisition is the remaining **front-door ergonomics** gap.

### 2.2 Inputs people actually hold

| Input | Example | Distance to anchor | Ergonomic cost today |
|---|---|---|---|
| Route helper | `upgrade_account`, `upgrade_account_path` | 1 hop (route table) | Context switch to `rails routes`, parse table, retype |
| Path / URL | `/accounts/42/upgrade`, full HTTPS URL | 1–2 hops | Same; plus strip host/query yourself |
| Verb + path | `POST /accounts/:id/upgrade` | 1 hop | Shell quoting + routes grep |
| Class-style | `AccountsController#upgrade` | 0 hops | Mostly handled |
| Stack frame | `accounts_controller.rb:88:in \`upgrade\`` | 0–1 hop | Manual convention mapping |
| Request log | `Processing by AccountsController#upgrade as HTML` | 0 hops | Should be free; often isn’t recognized |
| Test path / name | `accounts_controller_test.rb`, `"upgrade creates invoice"` | 1 hop | CI-native; no first-class path |
| Bug prose | “annual billing upgrade fails after 3DS” | many hops | Highest cognitive load |
| Issue / PR body | mixed signals | multi-signal | Agent does ad-hoc grep; no shared contract |

### 2.3 What exists today (ergonomics inventory)

**Strong (keep):**

- Golden path: `ctxpack accounts#upgrade -t "…"`
- Pipelines: `--task-file`, `--stdout` / `--stdout=json`
- Composable success stdout; self-sufficient help
- CLI-17c partial “almost anchor” guidance

**Weak (this proposal):**

- No first-class **resolve** journey for helpers/URLs
- Incomplete recognition of log/stack/test dialects
- Recovery often ends at “go use Rails” without a **paste-ready next command** or structured candidates for agents
- Prose/bug reports live entirely outside the product

**Out of scope for this program (see §3.2):**

- Regenerating the same packet basename
- Limit flags, route browsers, interactive pickers

### 2.4 Success = ergonomic outcomes, measured

Not “more CLI flags.” Not “architecture completeness.”

| Outcome | How we know |
|---|---|
| **Faster time-to-first-good-packet** | Acquisition corpus: correct anchor in ≤1 command / ≤1 agent turn |
| **Less context switching** | Fewer mandatory trips through raw `rails routes` tables for common inputs |
| **Fewer dead-end errors** | Every rejection names input kind + next action; 0/1/N matches explicit |
| **Lower agent friction** | Stable candidate JSON; same contract as humans |
| **No confidence laundering** | False-unique rate near zero; no silent fuzzy compile |
| **Golden path stays short** | Known-anchor users never pay for discovery features |

**Primary metric:** % of acquisition-corpus cases where the correct `controller#action` is top suggestion (or unique resolve) in ≤1 command / ≤1 agent turn — scored as **commands/steps-to-anchor plus dead-end-error count**, not wall time. Wall time cannot be honestly measured for a retrospective human ritual; "time-to-first-good-packet" stays the conceptual north star, steps + dead-ends is the measured proxy.

**Secondary:** top-3 hit rate; false-unique rate; boot required?; latency; human vs agent split.

**Scoring discipline:** syntax/helper/log/stack cases are scored mechanically against an exact expected anchor fixed at corpus-authoring time. Prose cases require judgment to label "correct" and live in a **separate bucket**, never averaged into the mechanical score — corpus labels are written from route dumps by the corpus author, so pre-registration (Front I) is what keeps the prose bucket from grading its own homework.

---

## 3. Goals and non-goals

### 3.1 Ergonomic goals

1. **Minimize time and cognitive load** from messy input → exact `controller#action` → successful packet.
2. **Match Rails mental models** — helpers, paths, logs, stacks feel “understood,” not “invalid argv.”
3. **Progressive disclosure** — known anchor stays one command; discovery is opt-in or only when needed.
4. **Recoverable failure** — every error is a state-machine edge toward a valid anchor (copy-pasteable).
5. **Humans and agents share one contract** — human text + structured JSON candidates.
6. **Ship layered wins** — Phase 1 diagnostics improve ergonomics before any boot-time resolver.

### 3.2 Product / engineering goals (supporting)

1. Preserve **exact, fail-closed compilation** (`ANCH-4`).
2. Prefer **reuse of Rails** for “what routes exist?” over a second router as sole truth.
3. Make **ambiguity first-class** (0 / 1 / N); never silent pick among N by default.
4. Keep discovery and compile **phases separate** unless metrics justify a unique-match shortcut.

### 3.3 Non-goals (including ergonomics we are *not* chasing)

| Tempting “ergonomics” idea | Why not (for this program) |
|---|---|
| Soft-overwrite / “working packet” default | Primary flow is one snapshot per attempt, not re-fix the same bug |
| More output flags / limit knobs | CLI-18; doesn’t help get an anchor |
| Interactive route picker | CLI-19; fights scripting and agents |
| Fuzzy compile without confirm | High-confidence wrong packets — anti-ergonomic |
| LLM-in-gem anchor choice | Determinism, deps, eval story |
| Making the golden path polymorphic (`ctxpack upgrade_account` auto-boots always) | Hidden cost and ambiguity on every invocation |

### 3.4 Design principles

1. **Ergonomics over feature count.** Prefer one clear resolve journey and better errors over a large flag surface.
2. **Resolution vs guidance stay distinct.** Guidance never pretends a packet was compiled.
3. **Prefer reuse over reimplementation.** Real apps have engines, Devise, constraints.
4. **Ambiguity is a product feature.** Ranked candidates + confirmation beat a wrong unique guess.
5. **Determinism applies to packets, not necessarily to discovery.**
6. **Agent and human share one contract.**
7. **Prose never becomes an anchor without confirm.**
8. **Don’t tax users who already know the anchor.**

---

## 4. Proposed architecture

### 4.1 Phase split: acquire → confirm → compile

```text
 messy input
     │
     ▼
┌─────────────────────┐
│  Acquisition layer  │  (new / expanded; may be best-effort)
│  candidates[]       │
└─────────┬───────────┘
          │  0 / 1 / N
          ▼
     confirm (human or agent)
          │
          ▼ exact controller#action
┌─────────────────────┐
│  Compile + render   │  (unchanged philosophy: ANCH, DET, limits)
│  packet / stdout    │
└─────────────────────┘
```

**Recommendation:** Keep compile entrypoints as they are (`ctxpack <anchor> …`). Add discovery as **`resolve` / extractors / docs+skill`**, with optional later “unique match then compile” only after measurement shows unique-match error rate is near zero.

### 4.2 Composition of fronts

```text
                    ┌─────────────────────────────┐
  bug report / URL  │  Front F: skill + docs      │
  helper / stack    │  (always on)                │
                    └─────────────┬───────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │  Front A: syntactic extract │
                    │  (class, URL strip, logs)   │
                    └─────────────┬───────────────┘
                                  ▼
              unique almost-anchor? ──yes──► print exact rewrite;
                                             user/agent runs compile
                     │ no
                     ▼
        ┌────────────┴────────────┐
        │                         │
   Front D/H                 Front B/C
   stack / test              route table
   file heuristics           (boot or cache)
        │                         │
        └────────────┬────────────┘
                     ▼
              candidates (0/1/N)
                     │
            human or agent picks
                     ▼
              ctxpack ANCHOR -t "…"
```

Front E (prose soft-rank) feeds **candidates into the same picker**, never into compile directly.

---

## 5. Attack fronts (detail)

Each front is justified by an **ergonomic outcome**, not by completeness for its own sake.

| Front | Ergonomic win (user-visible) |
|---|---|
| **A** Syntax dialects | “It understood what I pasted” without opening another tool |
| **B** `resolve` via Rails | One command replaces hand-parsing `rails routes` |
| **C** Route cache | Same as B but fast enough for tight agent loops |
| **D** Stack/log extract | Debugger/prod paste → anchor without mental Zeitwerk math |
| **E** Prose ranking | Bug title alone isn’t a dead end (always confirm) |
| **F** Docs + skill | First 30 seconds and agent workflows have a ritual |
| **G** Smarter failures | Errors teach the next hop instead of stopping thought |
| **H** From-test | CI failure path → packet without inventing a route |
| **I** Corpus | We improve what hurts, not what is fun to build |

### Front A — Recognize more “almost anchors” (CLI syntax only)

**Ergonomic win:** Paste-shaped inputs stop feeling like invalid CLI and start feeling like Rails.

**Cost:** Low · **Boot:** No · **Risk:** Low  

Expand CLI-17c-style recognition from a few shapes to a catalog of extractable Rails idioms. Still no route table: pure syntax → suggested next command and/or suggested anchor rewrite.

**Already shipped (CLI-17c):** snake_case route helpers, `AccountsController#upgrade`-style class references, quoted/split HTTP route strings, and slash-separated anchors. Front A's *new* scope is exactly: full URLs, `Processing by …` log lines, stack frames, controller file paths, and test filters/names. (Nested class references were originally listed here too, but the shipped recognizer already handles `Admin::AccountsController#…` — corrected 2026-07-13.) Phase 1 must not re-specify what already ships.

**Suggest-only, by design:** Front A never accepts a non-anchor form as argv. Even a fully unambiguous dialect (a log line names the exact controller#action) gets a printed rewrite and a non-zero exit, not a compile — accepting it would make the golden path polymorphic (§3.3), and it is the same product decision as unique-match auto-compile (§9.3), so it waits for the same false-unique evidence.

| Input pattern | Today | Deeper treatment |
|---|---|---|
| `AccountsController#upgrade` | Suggests `accounts#upgrade`; nested `Admin::AccountsController#…` already handled by the shipped recognizer | Keep (nested is **not** new scope — corrected 2026-07-13) |
| `accounts/upgrade` | Suggest `#` | Keep |
| `upgrade_account` / `_path` / `_url` | Helper → `rails routes -g` | Strip `_path`/`_url`; better `-g` token |
| `POST /accounts/:id/upgrade` | Route-string help | Extract stable segments + verb |
| Full URL | Often falls through | Strip scheme/host/query/fragment; treat path |
| `Processing by X#y` log line | Noise | Parse → suggest exact anchor rewrite |
| Stack: path + `` in `upgrade` `` | No | Combine → suggested anchor |
| `app/controllers/admin/accounts_controller.rb` | No | Controller prefix; action still needed |
| Test filter / example name | No | Weak action hint + controller from path |

**Why:** Many failures are “I already have the answer in another Rails dialect.”  
**Limit:** Does not solve pure prose or unnamed helpers without a table.

**Spec impact if shipped:** Amend CLI-17c (and tests); no compile changes; `design.md` “guidance is not resolution” preserved.

---

### Front B — “Ask Rails for me” (`resolve` via real router)

**Ergonomic win:** Collapse the context-switch tax: helper/URL → anchor without manually reading a routes table.

**Cost:** Medium · **Boot:** Yes · **Risk:** Medium (boot time, output drift, env)  

Explicit discovery mode that shells to the app’s router and prints anchors — never silent resolution inside `compile`.

Illustrative shapes (names TBD):

```bash
# Discovery only (no packet)
ctxpack resolve upgrade_account
ctxpack resolve POST /accounts/:id/upgrade
ctxpack resolve https://app.test/accounts/1/upgrade

# Happy path unchanged
ctxpack accounts#upgrade -t "…"
```

Implementation options (increasing structure):

1. **Parse `bin/rails routes -g TOKEN`**  
   - Pros: real app, engines, Devise, constraints as configured.  
   - Cons: boot cost; human table format can drift.

2. **`rails runner` / small script dumping JSON**  
   - Pros: structured rows (verb, path, controller, action, helper name).  
   - Cons: still boots; need binstub / load path handling.

3. **Cached dump** (see Front C) refreshed on demand; resolve against cache.

**Ambiguity policy (product decision — lock before implement):**

| Matches | Behavior |
|---|---|
| 0 | Fail; suggest how to widen search |
| 1 | Print exact anchor; optional later `--compile` only if measured safe |
| N | List rows (`METHOD PATH controller#action helper`); exit non-zero; **no** interactive picker by default |

**Why:** Closes helper/URL gap honestly without teaching ctxpack to own `routes.rb`.

**Earn its place:** an agent can already run `bin/rails routes -g TOKEN` itself, and Front A hands it that command paste-ready. Front B ships only if Phase 0 shows it beats the pre-registered **"Front A + F ritual, no gem resolve"** baseline arm (§8 Phase 0) by a pre-registered margin. The residual case for B is humans plus a stable JSON contract — real, but measured, not assumed.

**Spec impact:** New CLI requirements; explicit carve-out from CLI-19 for *resolve-token*, not *browse-routes*; still no interactive picker. **Also a `design.md` amendment, not just `specs/cli.md`:** design.md currently says guidance "never boots or browses the app" and lists booting Rails to inspect routes as out of scope — that sentence is load-bearing and its amendment needs its own justification in the same commit (§9.6).

---

### Front C — Offline / cached route map

**Ergonomic win:** Same mental model as B, without waiting on boot every agent turn (latency ergonomics).

**Cost:** Medium–high · **Boot:** Dump yes / resolve no · **Risk:** Staleness, incompleteness vs real routes  

Productize a `rails runner` JSON dump. (The offline static ActionDispatch extract descended from `eval/tier0/extract_routes.rb` is **dropped, not deferred** — a runner dump strictly dominates it; see §7 row 8.)

- `ctxpack routes:dump` (name TBD) → e.g. `.ctxpack/routes.json` (gitignored)
- Resolve path-like and helper-like inputs against the dump
- Packet compile remains static and dump-independent

**Pros:** Fast repeated discovery for agent loops.  
**Cons:** Second source of truth; gem DSLs, engines, env-conditional routes will miss (Tier 0 already documented these limits).

**Rule:** Cache is an accelerator with documented fallback to Front B — not the only resolver until measured on real apps.

---

### Front D — Stack / log extractors (bug-native, often no routes)

**Ergonomic win:** Meet developers where bugs actually show up (logs, traces), not only where routes live.

**Cost:** Medium · **Boot:** No · **Risk:** Heuristic false friends  

Bug reports often never mention routes. They paste:

- stack frames  
- `Processing by …` lines  
- exception pages with controller/action  

| Source | Extraction |
|---|---|
| Stack frame | `app/controllers/**` path + method → `admin/accounts#upgrade` |
| Request log | direct anchor |
| Exception page fields | controller + action when present |
| Job/mailer-only stack | Out of compile scope; say so; don’t invent a controller anchor |

**Idea:** `ctxpack resolve` reading a paste, or `--from-stack` / stdin mode.

---

### Front E — Free-text bug report ranking (hard; agent-first)

**Ergonomic win:** A prose-only issue is not “ctxpack can’t help”; it’s “here are candidates — confirm one.”

**Cost:** High · **Boot:** Optional · **Risk:** Hallucinated anchors  

Pipeline:

```text
bug report
  → extract hard tokens (URLs, helpers, paths, CamelCase controllers, #actions)
  → extract soft tokens (billing, upgrade, annual, …)
  → hard tokens → Fronts A/B/C/D
  → soft tokens → rank controllers/actions by path/view/test/route keywords
  → emit ranked candidates + evidence
  → never auto-pick top-1 into compile by default
```

| Placement | Fit |
|---|---|
| Agent skill / prompt recipe | Best first: `rg`, `rails routes`, judgment |
| `ctxpack suggest` from stdin | JSON candidates only |
| Inside `compile` | **Reject** — pollutes ANCH and determinism |

---

### Front F — Docs, skills, first-30-seconds UX

**Ergonomic win:** New users and agents don’t invent a workflow; they follow one short ritual.

**Cost:** Low · **Boot:** No · **Risk:** Low  

Independent of gem code; ship in parallel with A:

1. **One canonical ritual** (README, help, FAQ):
   ```text
   Have a helper/URL? → bin/rails routes -g TOKEN  (or ctxpack resolve … when shipped)
   Have a stack?      → path + method → controller#action
   Have only prose?   → routes -g <noun> then pick
   Then: ctxpack ANCHOR -t "…"
   ```
2. **`docs/finding-anchors.md`** with real-app-shaped examples (path, helper, log line, inherited-action failure).
3. **Agent skill** (e.g. find-ctxpack-anchor): issue body in → proposed `ctxpack …` line + evidence + the skill's own stated confidence (model-backed judgment, so a confidence is meaningful here — unlike the gem's candidate JSON, §9.5).
4. Optional: successful packets include a one-line “run again with:” copy-paste of the exact anchor command (discoverability, not regenerate-in-place).

---

### Front G — Failures as state-machine edges

**Ergonomic win:** Failure mode feels like coaching, not a brick wall — the signature of a good CLI.

**Cost:** Low–medium · **Boot:** No  

When compile fails (ANCH-6/7) or input is rejected, every message should push toward a valid anchor:

| Failure | Extra recovery |
|---|---|
| `file_not_found` | Namespace hints; helper → routes |
| Action not directly defined | Inherited/concern pointer; `routes -c`; “list defs in file” |
| Invalid input | Label input kind: `helper` \| `url` \| `class` \| `stack` \| `unknown` |
| Ambiguous resolve | Top N rows + how to disambiguate |

---

### Front H — Start from failing tests

**Ergonomic win:** From red CI line to packet without inventing a route name under pressure.

**Cost:** Medium · **Boot:** No  

```bash
# illustrative
ctxpack resolve --from-test test/controllers/accounts_controller_test.rb:42
ctxpack resolve --from-test "AccountsControllerTest#test_upgrade_creates_invoice"
```

Heuristics:

- controller / request spec path → controller prefix  
- test name tokens → candidate actions among `def`s in that controller  
- unique direct `def` → propose anchor; else list defs  

Common CI/bug path that skips routes entirely.

**Same leash as Front E:** test-name-token matching is fuzzy inference inside the gem — the category §6 rejects for prose. It is acceptable only because it emits candidates and never compiles; the confirm step is as mandatory here as for E.

---

### Front I — Measurement (acquisition corpus)

**Ergonomic win:** Indirect — stops us shipping “clever” features that don’t reduce time-to-packet.

**Cost:** Low–medium · **Risk:** Low if pre-registered  

Build a **30–50 case corpus** per sample app (or pooled):

- helper names and paths from route dumps  
- synthetic stack lines  
- paraphrased issue titles  
- class-style and log lines  

Score each strategy: top-1, top-3, boot required, false unique, latency.

**Without this, Front B vs C is taste.** Pre-register scoring before tuning messages or matchers (same discipline as Tier 0/2).

---

## 6. Explicitly deferred / rejected ideas

| Idea | Why it looks like ergonomics | Disposition |
|---|---|---|
| Soft-overwrite / “same task iterate” | Fewer files in `.ctxpack/` | **Out of scope** — wrong primary workflow |
| Interactive route picker | Feels friendly | **Reject** — breaks agents/scripts (CLI-19) |
| Silent fuzzy compile | “It just works” | **Reject** — wrong packet is worse UX (ANCH-4) |
| LLM in gem for anchors | Magic from bug text | **Reject** for v0-adjacent work |
| Limit flags | “Include more context” | **Reject** (CLI-18) — not acquisition |
| Full `ctxpack routes` browser | Discoverability theater | **Reject**; token resolve is enough |
| Discovery inside `compile` | One less concept | **Reject** — confuses exactness guarantees |
| Taxing the golden path with always-on boot | Accept any token as argv[0] | **Reject** unless unique-match metrics are near-perfect |

---

## 7. Prioritized backlog (ergonomics ROI)

Ranked by **expected ergonomic return per unit cost**, not by architectural ambition.

| # | Idea | Front | Cost | Ergonomic ROI | Primary inputs |
|---|---|---|---|---|---|
| 1 | Richer syntactic extract + coaching errors | A, G | Low | **Very high** — zero-boot “it understood me” | Logs, URLs, `_path`, stacks, near-misses |
| 2 | Doc ritual + agent skill | F | Low | **High** — first-run and agent path | Bug reports, onboarding |
| 3 | Acquisition corpus + baseline | I | Low–med | **High** — decides what to build next | Decision quality |
| 4 | `ctxpack resolve` via real Rails router | B | Med | **High** — kills routes-table context switch | Helpers, paths, verbs |
| 5 | Stack / test-path candidates | D, H | Med | **High** for CI/debug workflows | Debugger, CI |
| 6 | Unique-match compile shortcut | B | Med | Medium — only if false-unique ≈ 0 | Power users / agents |
| 7 | Cached routes index | C | Med–high | Medium — latency, not clarity | Tight agent loops |
| 8 | Offline ActionDispatch extract | C | High | **Dropped** — `rails runner` dump (row 7) strictly dominates | — |
| 9 | Prose soft-rank in gem | E | High | Low — stays skill-only, likely permanently (§12) | Only-text issues |
| 10 | Interactive picker | — | — | **Negative** for this product | Skip |

---

## 8. Phased campaign

### Phase 0 — Instrument the pain (ergonomics baseline)

- Draft acquisition corpus format and 30–50 cases (helpers, paths, stacks, prose); prose cases live in the separate judgment-scored bucket (§2.4).  
- Score **today’s** CLI + human `rails routes` ritual: steps-to-anchor and dead-end count (not wall time).  
- Pre-register a **“Front A + F ritual, no gem resolve” baseline arm** and the margin Phase 2 must beat — Front B is falsifiable or it doesn’t ship.  
- **Exit:** Numbers that rank Front A/B/D by ergonomic ROI; no compile changes required.

### Phase 1 — Zero-boot ergonomics wins (parallel)

- Front A: expand syntactic extractors + stderr (suggest-only; §5A).  
- Front F: finding-anchors doc + agent skill.  
- Front G: richer ANCH / input failure recovery.  
- **Exit criterion (ergonomic):** measurable drop in dead-end errors and steps for “almost anchor” inputs; suite green; CLI specs amended only for diagnostics.  
- **User-visible:** paste a log line or `_path` helper and get a coaching next step (or exact rewrite), not a shrug.

### Phase 2 — Explicit resolve (largest step-change ergonomics)

- `ctxpack resolve …` (Front B), human + JSON output.  
- Spec: ambiguity, exit codes, no packet write unless a later measured `--compile`.  
- Re-score corpus for **steps-to-anchor** and false-unique.  
- **Exit criterion (ergonomic):** helper/URL cases mostly lose the manual routes-table parse; resolve beats the Phase 0 ritual-only baseline by the pre-registered margin; golden path for known anchors still one command.  
- **Decide:** unique-match auto-compile ever allowed?

### Phase 3 — Bug-native ergonomics

- Stack paste + from-test (D/H).  
- Optional routes cache (C) only if Phase 2 **latency** hurts real agent loops (ergonomics of waiting).

### Phase 4 — Soft prose (only if still a top pain)

- Codify skill ranking rules only after the skill proves stable.  
- Gem `suggest` optional; still confirm-before-compile.  
- **Exit:** prose-only issues have a default path that doesn’t feel like “ctxpack isn’t for this.”

---

## 9. Open decisions (sign-off status as of the 2026-07-13 review)

1. **Where does discovery live?**  
   - **Decided: hybrid** — gem owns structured `resolve` + syntax; skill owns prose + multi-tool judgment.  
   - Conditional: gem-side `resolve` must beat the Phase 0 ritual-only baseline arm (§8) or it stays skill-side.

2. **May resolve boot Rails?**  
   - **Decided: yes**, boot-first for Phase 2 fidelity; add cache (C) only on measured **latency** pain. Cache-first would recreate Tier 0's documented gaps (engines, env-conditional routes) as silent product behavior.

3. **On unique match, auto-compile?**  
   - **Decided: never in Phase 2**; revisit only with false-unique ≈ 0 corpus data. Resolve prints anchor; user/agent runs `ctxpack ANCHOR`.  
   - One saved command is not worth a confidently wrong packet.

4. **Command naming**  
   - `resolve` vs `anchor` vs flags on the main command — bikeshed after Phase 0; prefer a subcommand so the **golden path stays short**.

5. **JSON schema for candidates**  
   - Stable fields for agents: `anchor`, `match_count`, `source` (`syntax`\|`routes`\|`stack`\|`test`), `evidence[]`, `rails_hint`.  
   - **No `confidence` field:** without a model there is no principled confidence number for syntax/routes/stack sources — what exists is uniqueness. Emitting a made-up float is exactly the confidence laundering §2.4 forbids; consumers decide from `match_count` and `evidence[]`.  
   - Align with existing `--stdout=json` packet manifest philosophy (separate schema; do not overload MAN-2).  
   - Ergonomics for agents: stable schema > clever prose-only errors.

6. **Spec / design reconciliation**  
   - This file is **not** normative. Landing any Phase 1+ behavior requires same-commit updates to `specs/cli.md` (and possibly a new acquisition spec), `design.md`, README/examples/FAQ, and tests per repo rules.  
   - Phase 2 specifically amends `design.md`’s “guidance … never boots or browses the app” sentence and its out-of-scope item “booting Rails to inspect routes.” Name that amendment explicitly in the landing commit — it is a philosophy change, not housekeeping.

---

## 10. Relationship to existing docs and constraints

| Artifact | Relationship |
|---|---|
| `design.md` | Settled v0: anchor exact; use Rails for route discovery; no custom route browser; helper support optional later. This proposal **extends** “later” into a plan without discarding those constraints. |
| `specs/cli.md` CLI-17c / CLI-19 | Guidance today; Phase 2 needs careful CLI-19 amendment (resolve ≠ browse). |
| `specs/packet-compilation.md` ANCH-* | Unchanged philosophy: exact anchors; fail closed. |
| `eval/tier0/` | Compilation viability evidence; **not** acquisition evidence. Reuse route dumps as raw material for corpus helpers/paths. |
| CLI ergonomics passes (2026-07-12/13) | Pipelines, help, stdout — keep; they help agents **after** an anchor exists. |

---

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Wrong unique resolve → confident bad packet | No auto-compile by default; measure false unique |
| Boot cost kills agent UX | Corpus latency numbers; optional cache later |
| Incomplete offline map trusted too much | Document fallback; never claim dump == `rails routes` |
| Scope creep into route browser | Token resolve only; list N max; no TUI |
| Spec drift | No merge without specs/`design.md` reconciliation |
| Prose ranking launders guesses | Confirm step mandatory; skill before gem |

---

## 12. First review — decisions recorded (2026-07-13)

- [x] **North star:** time-to-first-good-packet stays the conceptual metric; the *measured* proxy is steps-to-anchor + dead-end count (§2.4).  
- [x] **Program:** acquisition confirmed as the ergonomics program (not regenerate/limits/browsers).  
- [x] **Hybrid gem+skill:** confirmed, conditional on Front B beating the ritual-only baseline arm (§8 Phase 0).  
- [x] **Phase order:** Phase 0 corpus mandatory before Phase 2; Phase 1’s pure-diagnostics pieces (A/F/G) may ship without it.  
- [x] **Boot for `resolve`:** yes, boot-first; cache only on measured latency pain.  
- [x] **Auto-compile on unique match:** never in Phase 2; revisit only with false-unique ≈ 0 data.  
- [x] **Fronts dropped:** offline ActionDispatch extract (#8) dropped outright — `rails runner` dump dominates. Prose ranking in gem (#9) stays skill-only, likely permanently.  
- [x] **Naming:** `resolve` is the working name; final bikeshed after Phase 0.  
- [x] **Tracker:** commit this doc alone first; Phase 0 + Phase 1 (A/F/G) become the next execution plan. *(Superseded same day — see §12a.)*

---

## 12a. Re-scope under the seed ontology (2026-07-13, same day)

[`seed-based-interface-proposal.md`](seed-based-interface-proposal.md) was accepted later the same day as the north-star product definition: **task + seeds → packet**, with anchor demoted to one seed kind. This program is **re-scoped, not discarded** (mapping in that doc’s §8):

- **Fronts G / F proceed immediately** (coaching errors, docs); **Front A’s anchor-recognition surface** (shipped CLI-17c plus its planned extensions) proceeds in the seed doc’s Phase 1. The **full multi-kind argv classifier** (seed doc §4.2) is a Phase 2 deliverable there — it can only route to seed kinds that exist.
- **Fronts D / H become the `error` / `test` seed resolvers** rather than anchor extractors, each behind a Tier-0-style viability spike (seed doc §3.3).
- **Phase 0’s corpus is paused until re-scoped.** Its pre-registered steps-to-anchor scoring and expected-`controller#action` labels do not survive the ontology change: a red-test case’s correct answer is now a `--from-test` invocation, not an anchor. The corpus is authored after the seed doc’s ontology freeze, scored as *work-start scenarios → correct packet* with seed-kind labels.
- **Front B (`resolve` via Rails) drops in priority**: test/files/error seeds bypass routes entirely, so it serves only the `route` seed bridge (seed doc P1) and remains conditional on beating the ritual-only baseline.
- **The recorded decisions above stand and transfer** as standing constraints of the future seeds spec: suggest-only classification, no `confidence` field, no auto-compile on unique match, prose ranking skill-only. They are inherited, not reopened.

This section supersedes §12’s tracker bullet: the next execution plan is the seed doc’s Phase 0 reconciliation + Phase 1 wrap, with A/G/F work folded in re-labeled.

---

## 13. Appendix: illustrative user journeys (ergonomics stories)

Each journey is written as **friction removed**, not only as a pipeline.

### A. Helper in a PR comment

```text
“use upgrade_account_path”
  → Front A strips _path, labels helper          # no “invalid anchor” shrug
  → Front B: ctxpack resolve upgrade_account     # no hand-parsing rails routes
  → unique → accounts#upgrade
  → ctxpack accounts#upgrade -t "Fix upgrade PR feedback"
```

**Ergonomics:** one discovery command + one compile; stays in-tool.

### B. Production log paste

```text
Processing by Admin::AccountsController#suspend as HTML
  → Front A parses log → prints admin/accounts#suspend   # zero tool hop
  → ctxpack admin/accounts#suspend -t "…"                # user/agent runs the rewrite
```

**Ergonomics:** paste → exact anchor with zero thought; one explicit compile command (suggest-only — §5A).

### C. Only prose

```text
“annual billing upgrade fails after 3DS”
  → Front F skill extracts soft tokens
  → rails routes -g upgrade / billing; rg controllers
  → ranked candidates; human/agent picks
  → compile
```

**Ergonomics:** not “ctxpack can’t help”; a default ritual with confirm.

### D. Failing test in CI

```text
test/controllers/accounts_controller_test.rb:42
  → Front H → accounts#… candidates from defs + test name
  → pick → compile
```

**Ergonomics:** red line → candidates without inventing a route under time pressure.

### E. I already know the anchor (non-regression)

```text
ctxpack accounts#upgrade -t "…"
```

**Ergonomics:** still one command; discovery features must not slow or complicate this path.

---

## 14. Document history

| Date | Change |
|---|---|
| 2026-07-13 | Initial draft: multi-front acquisition plan; regenerate-loop deprioritized |
| 2026-07-13 | Reframe: lead with **CLI ergonomics** thesis, before/after, ROI-ranked backlog, phase exit criteria as user-visible wins |
| 2026-07-13 | First review incorporated: Front A locked **suggest-only**; Phase 0 gains a **ritual-only baseline arm** Front B must beat; measured metric is **steps + dead-ends**, not wall time; candidate JSON drops `confidence` for `match_count`; Front A scope stated against shipped CLI-17c; Front H leashed to candidates-only; offline extract (#8) dropped; §9 decisions recorded |
| 2026-07-13 | Re-scoped under the accepted seed ontology (§12a): G/F proceed immediately, Front A’s anchor recognition in seed Phase 1 with the full multi-kind classifier a Phase 2 deliverable; D/H become seed resolvers; Phase 0 corpus paused pending seed-kind re-scope; Front B priority drops; recorded decisions inherited by the seeds spec |
| 2026-07-13 | Independent (Grok) review correction: Front A nested-class-reference scope claim was stale — the shipped CLI-17c recognizer already handles `Admin::AccountsController#…` (§5A table updated) |

---

*End of proposal. Normative behavior remains in `specs/` until explicitly amended.*
