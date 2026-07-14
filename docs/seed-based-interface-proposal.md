# Design proposal: Seed-based primary interface

**Status:** Accepted 2026-07-13 — decisions recorded (§14). **Normative surface landed** as `specs/seeds.md` + amendments to compilation/format/cli specs and `design.md` product definition (Phase 0 reconciliation, 2026-07-13 Grok campaign)  
**Date:** 2026-07-13  
**Related:** [`anchor-acquisition-proposal.md`](anchor-acquisition-proposal.md) (front-door ergonomics under today’s anchor-primary CLI)  
**Authoring context:** Greenfield rethink — demote `controller#action` from “the entrypoint of the system” to **one seed kind among many**

---

## 1. Summary

### 1.1 Thesis

ctxpack should not be defined as:

> “Give me a Rails anchor; I return a packet.”

It should be defined as:

> **Given a task and one or more seeds of evidence, deterministically expand a budgeted, provenanced context packet for a coding agent.**

A **seed** is evidence that says where to start, plus a **recipe** for how to expand.  
An **anchor** (`accounts#upgrade`) is simply **one seed kind**: a Rails-flavored way to name a controller action and pull the conventional vertical slice (callbacks, views, controller/request tests).

That demotion is the product move. It does not throw away today’s compiler strengths; it generalizes the ontology so tests, stacks, files, diffs, and methods are first-class — matching how work actually arrives.

### 1.2 Why this exists

| Observation | Implication |
|---|---|
| Humans/agents rarely *start* holding `controller#action` | Anchor-only primary interface creates a front-door tax |
| Work often arrives as red tests, logs, open files, or diffs | Those should be seeds, not second-class “ways to find an anchor” |
| Packet value is task + structural neighborhood + provenance | The center of gravity is **evidence + expansion**, not route-table dialect |
| v0 research bet (“Rails conventions beat generic search”) still holds | Keep it as the **anchor seed recipe**, not the identity of the tool |
| Determinism and evals matter | Seeds resolve to an explicit **focus set** before render; no silent LLM locus choice in the gem |

### 1.3 One-sentence product

**ctxpack is a deterministic context compiler: task + seeds → provenanced packet.**

---

## 2. Core concepts

### 2.1 Task

Free-text description of the work (issue body, agent goal, one-liner).  
Shapes packet guidance (“read for this purpose”) and may bias ranking when multiple expansions compete for budget.  
**Optional but strongly recommended** — this is already shipped CLI-4 behavior (the packet records that no task was provided; the artifact name derives from the anchor alone). The seed model keeps that status quo; no new mode is needed.

### 2.2 Seed

```text
seed = evidence + expansion recipe
```

| Piece | Meaning |
|---|---|
| **Evidence** | What the user/agent already has (path, test id, stack paste, diff range, method ref, anchor string, …) |
| **Recipe** | Deterministic rules for what else to pull and why (reason codes) |

Seeds are **inputs**. They are not the packet’s only content.

### 2.3 Focus set (internal)

After seed resolution, compilation works on a **focus set**:

- files (with roles: primary, neighbor, test, view, …)
- optional method/line ranges for snippets
- reason codes / uncertainty codes per inclusion
- ordered under stable sort + budget limits

This is the shared internal form for rendering.  
**Note:** This is *not* “everything becomes an anchor.” Focus sets are file/method/range oriented. Anchor seeds *contribute* to a focus set via their recipe.

### 2.4 Packet

Unchanged in spirit:

- task, repo stamp, inspect list, snippets, run suggestions, follow-ups  
- every inclusion has provenance  
- deterministic given same app tree + same resolved inputs  
- budgeted (limits remain constants until evidence says otherwise)

**Section vocabulary** may evolve away from a single mandatory “Anchor” heading toward **Seed / Focus** language (see §6). A compatibility mode can keep today’s Markdown shape for anchor-only invocations.

---

## 3. Seed catalog (v1 proposal)

Each kind is optional in the product roadmap; the **model** admits all of them. Recommended first ships are marked.

| Kind | Evidence examples | Expansion recipe (sketch) | Priority |
|---|---|---|---|
| **`test`** | `path:line`, `TestClass#method`, RSpec example id | Test file + inferred production surface (path/constant/`described_class` heuristics) + factories/fixtures if conventional | **P0** |
| **`files`** | Explicit paths | Named files + budgeted neighbors (conventional tests, same-prefix views, path-token constants) | **P0** |
| **`error`** | Stack/log paste or file | Top application frames → file+line windows → local methods; skip pure framework frames | **P0** (gated — §3.3) |
| **`anchor`** | `accounts#upgrade`, `admin/accounts#upgrade` | Today’s v0 compiler path: controller file, direct `def`, callbacks, views, test candidates, constants | **P0** (exists) |
| **`method`** | `Billing::Upgrade#call`, `Billing::Invoice#finalize` — **non-controller constants only**; `*Controller#action` is anchor evidence (§4.2 rule 3) | Method body + the same narrow same-file literal-call expansion `design.md` already permits (no call graph, no cross-file dispatch) + tests naming symbol; its §3.3 spike must measure false inclusion, not just recall | **P1** |
| **`diff`** | `HEAD~1`, `main...HEAD`, patch file | Changed hunks + surrounding defs + paired tests | **P1** |
| **`route`** | helper, path, `VERB /path` | Resolve via Rails router or cache → then apply **anchor** or **method** recipe | **P1** (bridge; see §8) |
| **`area`** | `app/services/billing`, packwerk package | Budgeted sample of tree + tests under area | **P2** |
| **`task-only`** | No locus; task string alone | *(Skill recipe, outside the gem)* structural token search → ranked candidates → human/agent confirms a seed | **Skill-only** (decided — §14.6; the gem refuses) |

### 3.1 Anchor is not special ontologically

```text
--from-anchor accounts#upgrade
```

is the same *kind of thing* as:

```text
--from-test test/controllers/accounts_controller_test.rb:42
--from-files app/services/billing/upgrade.rb
--from-error -
```

What is special is only the **recipe quality** for classic Rails HTTP actions ( matured in v0). Other recipes start thinner and deepen with evidence.

### 3.2 Multi-seed

Allow combining seeds when useful:

```bash
ctxpack -t "…" \
  --from-test test/services/billing_upgrade_test.rb:12 \
  --from-files app/models/account.rb
```

**Merge rules (normative intent):**

1. Union focus candidates with stable ordering.  
2. Deduplicate files; merge reason codes (multi-reason allowed or primary+secondary — TBD).  
3. Apply global budgets (total files, snippet lines, etc.) after merge.  
4. Conflict policy: prefer explicit seeds over inferred neighbors; never drop a user-named file without an explicit follow-up uncertainty.

**Decided (§14.3):** the model admits multi-seed from day one; the CLI ships single-seed first. Phase 4 (§11) enables multiple seeds per invocation.

### 3.3 Viability gate: every seed kind earns its ship the way anchor did

Fixture evals are Tier 1: circular by design, and `design.md` says explicitly they are never evidence that packets are useful. The anchor recipe earned its P0 status through the Tier 0 spike — ~91% resolution against real route tables, plus a failure taxonomy that reshaped the design (inflection-tolerant class matching, `?`/`!` action tokens).

**Rule (mandatory phase gate):** each new seed kind runs a Tier-0-style viability spike against the real sample apps *before* it ships, with pre-registered scoring and a failure taxonomy. Fixture evals then hold the line as regression checks; they never substitute for the spike.

| Kind | Spike shape |
|---|---|
| `test` | Sample real test files across the sample apps; measure how often path/constant/`described_class` heuristics find the correct production surface; classify misses |
| `files` | Near-trivial (evidence is literal paths); spike covers only the neighbor rules (conventional tests, same-prefix views) |
| `error` | Sample real backtrace/log formats (Rails log, Minitest/RSpec failure output, production JSON logs, `backtrace_cleaner`-filtered traces); measure app-frame filtering precision |

`error` is the **riskiest of the P0 set**: its recipe is the fuzziest thing yet proposed for the deterministic core. Its spike is an explicit go/no-go, and **demotion to P1 is the stated outcome** if the taxonomy is ugly — not a renegotiation.

---

## 4. Primary interface (CLI sketch)

### 4.1 Mental model

```bash
ctxpack --task "…" --from-<kind> <evidence>…
```

At least one seed required (`task-only` stays skill-side — §14.6).  
Task recommended.

**Flag spelling (§14.9):** `seed` remains the ontology term in the model and specs; the CLI spells the flags `--from-<kind>` — it avoids the `rails db:seed` collision in a Rails-native tool and reads naturally as “starting from this evidence.” Final spelling locks at Phase 2 spec time.

### 4.2 Human sugar (progressive disclosure)

Keep short forms so power users and today’s muscle memory don’t suffer:

| Sugar | Means |
|---|---|
| `ctxpack accounts#upgrade -t "…"` | `--from-anchor accounts#upgrade` |
| `ctxpack path/to/file.rb -t "…"` | `--from-files` (if path exists and lacks `#` action form) |
| `ctxpack path/to/test.rb:42 -t "…"` | `--from-test` |
| `ctxpack -t "…" --from-error -` | read stack from stdin |

**Dispatch rules (v1, decided — §14.7).** Classify argv token by shape/existence **before** compile; on ambiguity, fail with candidates (no silent wrong seed kind):

1. snake_case token containing `#` (`accounts#upgrade`, `admin/accounts#upgrade`) → **anchor** seed.
2. `#`-bearing token whose CamelCase segment ends in `Test` or `Spec` (`AccountsControllerTest#test_upgrade_creates_invoice`) → **test** seed — checked **before** the method rules, since the §3 catalog admits `TestClass#method` as test evidence.
3. `#`-bearing token whose CamelCase segment ends in `Controller` — including nested (`Admin::AccountsController#suspend`) — → **anchor** evidence, handled by the shipped CLI-17c suggest-only rewrite to the underscore anchor (`admin/accounts#suspend`). Per the inherited suggest-only constraint (§8) it coaches, never silently compiles. It is **never** routed to the method seed: that would compile a strictly weaker packet for an anchor-equivalent locus.
4. Any other token containing `::` or CamelCase before `#` (`Billing::Upgrade#call`) → **method** seed (non-controller constants); until `method` ships, rejected with a coaching rewrite — never silently treated as an anchor.
5. Existing path under `test/` or `spec/`, optionally with `:line` → **test** seed.
6. Any other existing path → **files** seed. `:line` on a non-test path is rejected with coaching (“strip the line, or use `--from-files`”); line-focused file seeds stay open in the model but out of v1 sugar.
7. Anything else → fail with labeled input kind and candidates/coaching.

**Stdin is single-occupancy:** `--from-error -` conflicts with `--task-file -` in either order; the conflict fails before either stream is read (same discipline as the shipped `--task`/`--task-file` conflict).

### 4.3 Agent / machine form

```bash
ctxpack --task-file task.md \
  --from-test spec/requests/billing_spec.rb:88 \
  --stdout
# or
ctxpack --task-file task.md --from-error - --stdout=json
```

Candidate/resolve subcommands (from the acquisition proposal) become **seed resolvers** for kinds that need disambiguation (`route`, messy errors, multi-match tests), not a separate product myth.

### 4.4 What we refuse

- Interactive pickers as the happy path  
- LLM-inside-gem seed choice  
- Silent fuzzy expansion past budgets  
- Always-on Rails boot for every invocation  
- Making `--from-anchor` mandatory forever

---

## 5. Pipeline

```text
                    ┌─────────────┐
  task ────────────►│             │
                    │  validate   │
  seed(s) ─────────►│  + parse    │
                    └──────┬──────┘
                           ▼
                    ┌─────────────┐
                    │ resolve each│  (kind-specific; may call router only for route seeds)
                    │ seed → raw  │
                    │ candidates  │
                    └──────┬──────┘
                           ▼
                    ┌─────────────┐
                    │ merge +     │
                    │ budget      │
                    │ → focus set │
                    └──────┬──────┘
                           ▼
                    ┌─────────────┐
                    │ render MD / │
                    │ manifest    │
                    └─────────────┘
```

**Layers (preserve one-directional design):**

1. **Seed resolution** — evidence → candidates (new or generalized from today’s anchor resolution)  
2. **Focus assembly** — merge, reasons, limits (generalize today’s compiler body)  
3. **Format** — Markdown / manifest  
4. **CLI** — parse sugar, streams, artifacts  

Today’s `compiler.rb` is largely “anchor seed resolver + focus assembly.” The refactor is conceptual first; physical split can be incremental.

---

## 6. Packet & manifest shape (direction)

### 6.1 Toward seed-aware headings

Illustrative Markdown outline (not frozen):

```markdown
# Context packet

## Task
…

## Seeds
- test: test/controllers/accounts_controller_test.rb:42
- files: app/models/account.rb

## Focus
- path (reason_codes…)
…

## Snippets
…

## Run
…

## Follow-ups
…
```

### 6.2 Compatibility

- **The format bump is forced at the first non-anchor seed (Phase 2), not chosen later.** A test- or files-seed packet has no anchor: FMT’s mandatory `## Anchor` section and MAN-2’s `anchor` field cannot express it. The moment `--from-test` ships, either the format changes or the packet lies — so format **v3** ships with Phase 2 (§11): a `seeds: [...]` array (single element until Phase 4 enables multi-seed) and `anchor` optional/derived when an anchor seed is present.  
- **One live version, not a compat fork.** Consistent with MAN-2’s single-version discipline (v2 replaced v1 with no emission flag), **v3 replaces v2** — anchor packets are not frozen on v2. “Compat” means *heading-shape preservation within v3*: an anchor-seed packet still renders `## Anchor` and still carries the manifest `anchor` field, alongside its one-element `seeds[]`.  
- **Both version carriers bump together:** the Markdown `Format:` line and the manifest `version` go 2 → 3 in the same commit.  
- **Phase 2 therefore re-baselines every anchor golden** (`version`, `Format:`, and `seeds[]` change bytes). The “packet bytes unchanged” guarantee is a **Phase 1 property only** (§11).  
- Format version policy: explicit version bump over silent schema drift (consistent with packet format v2 discipline).

### 6.3 Determinism and seed normalization

Same app tree + same task + same normalized seeds → byte-identical packet (DET).  
Seed normalization rules (path relative to app root, stable ordering of multi-file seeds, stack frame filtering) must be specified.

**Error-seed provenance is a PII/secret hazard and must be normalized away.** Production log pastes carry tokens, emails, IDs; packets are durable artifacts, sometimes deliberately committed (`docs/ctxpack/`). Normalization persists **only the filtered application frames (`path:line`)** into the packet and manifest — never the raw paste. Frame-filtering rules must be deterministic and specified before `error` ships (they are also what the §3.3 spike measures).

---

## 7. Ergonomics goals

| Goal | How seeds help |
|---|---|
| **Time-to-first-good-packet** | Point at evidence you already have (test, log, files) |
| **Less dialect tax** | Anchor optional, not mandatory vocabulary |
| **Agent fit** | Seeds match tool outputs (paths, test ids, stderr) |
| **Rails still excellent** | Anchor (+ route) recipes keep v0 vertical-slice quality |
| **Golden path short** | Sugar preserves `ctxpack accounts#upgrade -t "…"` |
| **Fail closed** | Ambiguous seeds list candidates; no silent wrong focus |

**Primary metric:** % of realistic work-start scenarios (corpus) that produce a correct useful packet in ≤1 command / ≤1 agent turn — corpus includes tests, errors, files, diffs, anchors, not anchors alone.

**Secondary:** packet-vs-diff coverage, false inclusion rate, boot required rate, format stability.

---

## 8. Relationship to anchor acquisition

[`anchor-acquisition-proposal.md`](anchor-acquisition-proposal.md) optimizes the front door **assuming anchor-primary CLI**.

Under this proposal, that work is **re-scoped**, not discarded:

| Acquisition front | Becomes |
|---|---|
| Syntactic almost-anchors | Classifier for `--from-anchor` vs other kinds; coaching errors |
| `resolve` via Rails | **Route seed resolver** → emits anchor or method seed evidence |
| Stack/log extractors | **`--from-error`** implementation |
| From-test | **`--from-test`** implementation |
| Docs/skills | Teach “pick a seed kind,” not only “find an anchor” |
| Soft prose | Task + optional structural search; prefer asking for a seed |

**Strategic order shift:**  
Prefer shipping **test / files / error** seeds (high arrival frequency) **alongside** keeping anchor, rather than only deepening anchor acquisition.

**Inherited decisions (not reopened).** The acquisition review’s recorded decisions (§12 there) transfer as standing constraints of the future seeds spec:

- suggest-only classification — a rewrite/coaching message never compiles on the user’s behalf;
- no `confidence` field in candidate JSON — uniqueness (`match_count`) and `evidence[]` only;
- no auto-compile on unique match — revisit only with false-unique ≈ 0 corpus data;
- prose ranking stays **skill-only**, likely permanently. This settles task-only mode (§14.6): the gem refuses; prose → seed lives in skills.

**Corpus re-scope (sequencing).** Acquisition Phase 0 pre-registered its corpus around steps-to-anchor with exact expected `controller#action` labels. Under seeds, a red-test case’s correct answer is a `--from-test` invocation — no anchor label exists. The corpus is therefore authored **after** this ontology freeze, re-scoped to *work-start scenarios → correct packet* with seed-kind labels (§7 primary metric), and pinned to Phase 2 (§11) so it doesn’t drift ownerless. **Front sequencing:** Fronts G/F proceed immediately (coaching errors, docs); Front A’s anchor-recognition surface (shipped CLI-17c plus its planned extensions) proceeds in Phase 1 — but the full multi-kind argv classifier (§4.2) is a **Phase 2 deliverable**, since it can only route to seed kinds that exist. **Only the corpus waits on re-scoping.** The acquisition doc carries a matching re-scope note.

**Structural argument for the demotion.** The acquisition doc’s own §2.2 input table shows almost every real starting input is ≥1 hop from an anchor, and its Front D explicitly punts job/mailer-only stacks because no controller anchor exists — a hole anchor-*acquisition* can never close, no matter how good the resolvers get. The seed model closes it structurally.

---

## 9. What stays from v0 (do not throw away)

- Deterministic compile; prism-only runtime dependency policy  
- Provenance / reason codes / uncertainty codes as registries  
- Budgets (limits as constants until evidence says otherwise)  
- No embeddings/RAG required for core  
- No Rails boot for static recipes (anchor, files, method, test path rules)  
- Tiered eval mindset: fixture cases per seed kind; real-app spikes where needed  
- OptionParser CLI, injectable streams, composable stdout  

**Anchor recipe implementation** (callbacks, views, constants, tests) remains the gold standard for that seed kind.

---

## 10. Non-goals

- Replacing the packet with chatty multi-turn tools inside the gem  
- Interactive seed pickers  
- Booting Rails for every packet  
- Task-only compilation of any kind inside the gem (prose → seed is skill-only — §14.6)  
- Full call-graph / whole-program analysis in v1 of the model  
- Silent migration that breaks FMT/MAN consumers without a version story  
- Treating diff/PR as the *only* product (it’s one seed)

---

## 11. Migration path (from today’s CLI)

### Phase 0 — Ontology freeze (docs only) — **entered 2026-07-13**

- This proposal accepted; decisions recorded (§14).  
- Reconciliation commits land here: `design.md` product definition, tracker language, acquisition-doc re-scope note.  
- No behavior change required.

### Phase 1 — Conceptual split in code (behavior-compatible)

- Introduce internal `Seed` / focus-set types.  
- Implement current CLI as **only `--from-anchor`** (spelled as today’s positional anchor; no new flags yet).  
- All existing tests green; **packet bytes unchanged for golden paths** — mechanically checkable against existing goldens. This guarantee is **Phase 1-only**: Phase 2’s format bump re-baselines the goldens (§6.2).

### Phase 2 — First non-anchor seeds **+ forced format v3**

- **Gates:** `test` seed viability spike passes a pre-registered bar, and the (thin) `files` neighbor-rule spike is done (§3.3).  
- Ship `--from-test` and `--from-files` (highest agent/human leverage).  
- **Format v3 ships here, not later** (§6.2): a non-anchor packet cannot be expressed in v2. v3 **replaces** v2 as the only emitted version; `seeds[]` single-element, `anchor` optional/derived; Markdown `## Seeds` / `## Focus` for non-anchor packets; anchor packets keep `## Anchor` heading shape within v3; both version carriers bump; anchor goldens re-baseline.  
- **Default artifact naming generalizes off the anchor:** CLI-8/8a derive names from task + anchor with the anchor as required suffix — non-anchor seeds have no anchor, so the suffix becomes the **seed identity** (test file basename, first file stem), specified here as part of the CLI spec amendment.  
- The **full multi-kind argv classifier (§4.2) lands here** — it can only route to seed kinds that exist (see §8 on Front A sequencing).  
- Sugar per §4.2 dispatch rules; fixture evals per kind (regression only, per §3.3); docs/examples recipes.  
- The **re-scoped work-start corpus (§8) is authored in this phase** and re-scored at each later phase gate, so it doesn’t drift ownerless.  
- Flag-spelling bikeshed locks here (§14.9).

### Phase 3 — `--from-error`

- **Gate:** `error` viability spike (§3.3) is go/no-go; demotion to P1 is the stated fallback. Spike scoring pre-registers its ground truth: the definition of “application frame” (e.g. frames under the app root’s `app/`/`lib/`, never gem/framework paths) is fixed before scoring, or the gate cannot actually be scored.  
- PII-safe normalization specified before ship (§6.3): filtered app frames only, never the raw paste.  
- Stack/log paste path; shared with acquisition “Front D.”

### Phase 4 — Multi-seed

- Enable multiple seeds per invocation (the model and v3 `seeds[]` already admit it).  
- Merge rules (§3.2) become normative: dedup, reason-code merge, budget conflicts, follow-ups for dropped items.

### Phase 5 — `method`, `diff`, `route`

- Each kind gets its §3.3 spike before shipping.  
- Route seed may shell out / use cache (see acquisition Phase 2); its `design.md` boot-sentence amendment carries over from the acquisition review.  
- Diff seed for continue/review workflows.

### Phase 6 — Soften anchor-centrism in marketing

- README leads with “task + seed,” shows test/error examples first or equal to anchor.

---

## 12. Spec impact (when normative)

Likely new or amended surfaces (names TBD):

| Area | Change |
|---|---|
| New `specs/seeds.md` (or similar) | Seed kinds, evidence grammar, recipes, normalization (incl. error-frame filtering, §6.3), multi-seed merge, budgets; inherited acquisition constraints (§8) |
| `specs/packet-compilation.md` | Generalize away from anchor-only pipeline; anchor becomes one resolver |
| `specs/packet-format.md` | Manifest v3 at Phase 2 (§6.2): `seeds[]`, optional `anchor`; `## Seeds` / `## Focus`; anchor-only compat mode |
| `specs/cli.md` | §4.2 dispatch rules; `--from-*` flags; CLI-8/8a name derivation generalized from anchor to seed identity (§11 Phase 2); conflicts; stdout |
| `design.md` | Product definition rewrite: seed compiler, not anchor CLI (Phase 0 reconciliation commit) |
| `eval/` | **Per-kind Tier-0-style viability spikes (§3.3, phase gates)**; Tier 1 fixture cases per seed kind (regression only); keep anchor cases; corpus re-scoped to work-start scenarios with seed-kind labels (§8) |

**Rule:** no silent behavior change to existing anchor packets without eval coverage and intentional format/version policy.

---

## 13. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Scope explosion (“support everything”) | P0 = test + files + error + existing anchor; freeze catalog |
| Weaker packets for non-anchor seeds | Per-kind viability spikes as phase gates (§3.3); start honest (smaller recipes); deepen with evals, not vibes |
| Dual ontology confuses users | One mental model in docs; anchor as “Rails action seed” |
| Manifest/Markdown churn | One forced, explicit v3 bump at Phase 2 (§6.2); compat mode for anchor-only |
| Error paste leaks PII/secrets into durable packets | Persist only filtered app frames (`path:line`); never the raw paste (§6.3) |
| Multi-seed budget fights | Explicit priority rules; follow-ups for dropped items |
| Route seed reintroduces boot pain | Optional kind; cache; never required for core path |
| Refactor churn in `compiler.rb` | Phase 1 wrap-without-change; extract resolvers incrementally |
| Corpus pre-registered against the wrong ontology | Corpus authored after Phase 0 freeze, seed-kind labels (§8) |

---

## 14. Decisions (recorded 2026-07-13, first review)

1. **North star: accepted.** ctxpack is a seed compiler; anchor is one seed kind. The `design.md` product-definition rewrite lands with the Phase 0 reconciliation commit.  
2. **P0 seed set: accepted** — `test` + `files` + `error` + `anchor`. `error` is gated on its §3.3 viability spike, with demotion to P1 the stated fallback.  
3. **Multi-seed: admitted in the model from day one; ship single-seed first.** Phase 4 enables multiple seeds per invocation.  
4. **Format: bump forced at Phase 2, not chosen.** The first non-anchor seed cannot be expressed in v2 (mandatory `## Anchor`, required manifest `anchor`). **v3 replaces v2 as the only emitted version** (MAN-2 single-version discipline — no compat fork); “compat” is anchor heading-shape preservation *within* v3; both the Markdown `Format:` line and the manifest `version` bump together; anchor goldens re-baseline at Phase 2 (§6.2).  
5. **Task: status quo.** Already optional under shipped CLI-4; stays optional-but-recommended. No new mode.  
6. **Task-only mode: inherited from the acquisition review** — the gem refuses; prose → seed lives in skills (likely permanently).  
7. **Sugar disambiguation: decided per §4.2 dispatch rules.** snake_case + `#` → anchor; `…Test`/`…Spec` + `#` → test; `…Controller#action` (incl. nested) → **anchor evidence via the CLI-17c suggest-only rewrite, never the method seed**; other `::`/CamelCase + `#` → method (coaching rejection until `method` ships); `:line` accepted only on test paths in v1 sugar.  
8. **Acquisition relationship: subsumed.** One doc track — acquisition fronts become seed resolvers; its recorded decisions transfer as standing constraints (§8); its doc carries a matching re-scope note.  
9. **Naming: `seed` is the ontology term in model/specs; the CLI spells flags `--from-<kind>`** (avoids the `rails db:seed` collision; reads naturally). Final spelling locks at Phase 2 spec time.

---

## 15. Worked examples

### A. Red CI (no anchor in sight)

```bash
ctxpack -t "Fix annual upgrade after 3DS" \
  --from-test test/services/billing_upgrade_test.rb:42
```

Focus: test + `Billing::Upgrade` (inferred) + `Account` if referenced + run that test.

### B. Production log

```bash
grep -A20 "Error" log/production.log | ctxpack -t "…" --from-error -
```

Focus: app frames’ files/lines; follow-ups if only gem frames found.  
Only the filtered app frames (`path:line`) persist into the packet — the raw paste is never stored (§6.3).

### C. Classic Rails endpoint (today’s strength)

```bash
ctxpack accounts#upgrade -t "Implement billing upgrade"
# equivalent:
ctxpack -t "…" --from-anchor accounts#upgrade
```

Focus: today’s vertical slice.

### D. Service-oriented change

```bash
ctxpack -t "…" --from-files app/services/billing/upgrade.rb app/models/account.rb
```

Focus: those files + conventional tests; no fake controller anchor.

### E. Continue a branch

```bash
ctxpack -t "Finish upgrade work" --from-diff main...HEAD
```

Focus: changed surface + paired tests.

### F. Multi-seed

```bash
ctxpack -t "…" \
  --from-test test/controllers/accounts_controller_test.rb:10 \
  --from-anchor accounts#upgrade
```

Merge: action slice ∪ test emphasis; budgets apply once.

---

## 16. Success criteria for accepting this proposal

Proposal is “accepted” when we agree (all recorded 2026-07-13, §14):

- [x] Product one-liner is task + seeds → packet  
- [x] Anchor is documented as one seed kind, not the system identity  
- [x] P0 seed set and phase order are approved (`error` gated — §3.3)  
- [x] Compatibility/version policy for packets is accepted (forced v3 at Phase 2 — §6.2)  
- [x] Acquisition work is re-framed as seed resolution, not only anchor hunting (§8)  
- [x] Next implementation phase is named: Phase 0 reconciliation commits, then Phase 1 wrap + Phase 2 `--from-test`/`--from-files` behind the test-seed spike

---

## 17. Review checklist (resolved by §14)

- [x] Agree / disagree with demoting anchor → **agreed** (§14.1)  
- [x] P0 seeds: test, files, error, anchor → **kept**, `error` gated (§14.2)  
- [x] Multi-seed now vs later → **model now, ship later** (§14.3)  
- [x] Format bump timing → **forced at Phase 2** (§14.4)  
- [x] Naming: seed vs alternative → **seed ontology, `--from-*` flags** (§14.9)  
- [x] Pause anchor-acquisition implementation? → **only the corpus waits**; Fronts A/G/F proceed re-labeled (§8)  
- [x] Tracker: next-step plan rewritten to Pass A (Phase 0 reconciliation) + Pass B (Phase 1 wrap) — done 2026-07-13  

---

## 18. Document history

| Date | Change |
|---|---|
| 2026-07-13 | Initial draft: seed-based primary interface; anchor as one seed kind |
| 2026-07-13 | First review applied; decisions recorded (§14): north star accepted; format v3 forced at Phase 2 (§6.2, §11); per-kind Tier-0-style viability gates added (§3.3), `error` go/no-go; acquisition decisions inherited + corpus re-scoped (§8); error-seed PII normalization rule (§6.3); dispatch rules locked (§4.2); flags respelled `--from-<kind>`; task-optionality aligned with shipped CLI-4 |
| 2026-07-13 | Second (independent, Opus) review applied: format decision made coherent — v3 **replaces** v2, no compat fork, both version carriers bump, anchor goldens re-baseline at Phase 2 (§6.2, §14.4); `TestClass#method` dispatch precedence added (§4.2); non-anchor artifact naming specified (CLI-8/8a suffix → seed identity, §11 Phase 2); Phase 2 gate names both spikes; task-only non-goal reworded, catalog row marked skill recipe (§3, §10); `method` recipe leashed to design.md’s same-file expansion (§3); Front A vs full classifier sequencing split (§8); corpus pinned to Phase 2; error-spike ground truth pre-registration (§11 Phase 3) |
| 2026-07-13 | Third (independent, Grok) review applied: `*Controller#action` (incl. nested) is **anchor evidence via the CLI-17c suggest-only rewrite, never the method seed** — §4.2 rule 3 added, method-seed catalog examples restricted to non-controller constants, §14.7 updated; stdin single-occupancy conflict (`--from-error -` vs `--task-file -`) specified (§4.2); acquisition Front A nested-scope claim corrected against the shipped recognizer |

---

*End of proposal. Normative behavior remains in `specs/` until explicitly amended.*
