# ctxpack v0 specifications

Status: Draft, derived from [`design.md`](../design.md),
[`eval-plan.md`](../eval-plan.md), and (from 2026-07-13) the accepted
[`docs/seed-based-interface-proposal.md`](../docs/seed-based-interface-proposal.md).

These documents restate the settled design as normative, testable requirements.
`design.md` remains the record of rationale and tradeoffs; when a spec and the
design doc disagree, treat it as a bug in one of them and reconcile — do not
silently follow either.

## Documents

Listed in dependency (and intended build) order: seeds define the product
ontology; compilation resolves seeds into a packet object; format renders that
object; the CLI wires both behind a command; fixture evals exercise the whole.

| Spec | Covers | Requirement prefix |
|---|---|---|
| [`seeds.md`](seeds.md) | Seed kinds, evidence, recipes, merge, normalization, acquisition constraints | `SEED`, `MERGE` |
| [`packet-compilation.md`](packet-compilation.md) | Pipeline, anchor resolution, parsing, callbacks, constants, views, test candidates, limits | `PIPE`, `ANCH`, `PARSE`, `CB`, `CONST`, `VIEW`, `TEST`, `LIM` |
| [`packet-format.md`](packet-format.md) | Markdown packet structure, reason/uncertainty codes, repo stamp, determinism, public machine-fact manifest | `FMT`, `DET`, `MAN` |
| [`cli.md`](cli.md) | Command surface, flags, artifact naming and location | `CLI` |
| [`fixture-evals.md`](fixture-evals.md) | Tier 1 deterministic regression evals (fixtures, YAML cases, runner) | `EVAL` |

[`views.md`](views.md) is folded into compilation/format (VIEW-*); kept as the
view-resolution freeze record.

## Cross-spec contracts

The build order above keeps behavior dependencies one-directional, but a few
contracts cut across spec boundaries. They are recorded here so no
implementation pass discovers them late:

- **Internal packet object.** The central contract: compilation produces it,
  format renders it, the manifest serializes it (MAN-1), fixture evals assert
  on it (EVAL-5). The MAN-2/MAN-3 manifest shape is its de facto schema —
  everything MAN-* and FMT-2..FMT-9 need (task, seeds, optional anchor,
  entrypoint, snippet subjects/ranges and truncation state, test paths/rules,
  reason and uncertainty codes, omitted candidates, no-candidate state, repo
  availability/stamp, and typed supplemental history state) must exist on the packet object when compilation finishes,
  even though those requirements live in `packet-format.md`.
- **Reason and uncertainty codes.** Registered in FMT-6/FMT-7 but emitted by
  compilation and seed-resolution events. A compilation or seed change that needs
  a new code updates `packet-format.md` in the same change.
- **Repo stamp and history revision.** FMT-10..FMT-13 specify them, but the
  generation-state repo stamp is computed when the
  packet object is built, not at render time — the manifest carries it
  (MAN-2 `repo`), so it cannot be a format-layer concern. Historical commit
  OIDs may appear only as provenance for bounded history facts; they are not
  additional generation-state stamps.
- **Application root and task text.** Inputs to compilation, passed as
  parameters. Discovering the root (CLI-3) and validating/deriving artifact
  names (CLI-4..CLI-8b) belong to the CLI layer only. Seed identity (CLI-8a)
  is defined per kind in `cli.md` / `seeds.md`.
- **Fixture trees.** EVAL-2 fixture apps double as compilation scaffolding:
  author them at their final paths under `test/fixtures/apps/` so Tier 1 evals
  reuse them rather than duplicate them.
- **Format version.** Phase 1 emits format v2 (byte-identical goldens). Phase 2
  forces format v3, which **replaces** v2. The files-seed history tracer forces
  format v4, which **replaces** v3 for every packet. Markdown `Format:` and
  manifest `version` always bump together; anchor heading shape is preserved
  when an anchor seed is present.

## Conventions

- **MUST / MUST NOT** — conformance requirement; a violation is a bug.
- **SHOULD** — expected behavior; deviations need a recorded reason.
- **MAY** — explicitly permitted, never required.
- Requirements are numbered (`CLI-3`, `ANCH-2`, `SEED-10`, …) so eval cases and
  issues can reference them. Numbers are stable: never renumber; mark retired
  requirements as *Withdrawn* instead.
- Where `design.md` was silent and this spec fixes a decision (e.g. a canonical
  reason-code name), the requirement is annotated **[fixed by spec]**.

## Terminology

- **Seed** — evidence plus a deterministic expansion recipe (see `seeds.md`).
- **Anchor** — an exact `controller#action` reference in the shape shown by
  `bin/rails routes`, e.g. `accounts#upgrade`, `admin/accounts#upgrade`. One
  seed kind.
- **Focus set** — post-resolution ordered files/ranges/reasons before render.
- **Context packet** (or **packet**) — the compact Markdown artifact ctxpack
  compiles from task + seed(s): task, seeds/anchor, entry point or focus,
  Inspect-first map, snippet evidence, test commands, and packet-specific
  Follow-ups.
- **Application root** — the nearest ancestor of the current directory
  containing `config/application.rb`, discovered by upward search (CLI-3),
  matching `bin/rails`/Rake run-from-subdirectory ergonomics.
- **Reason code** — a fixed machine-readable token explaining why a file is in
  the packet (see `packet-format.md`).
- **Repo stamp** — the git commit SHA (plus dirty marker) embedded in packet
  content; the only generation-state marker allowed inside a packet.
- **Manifest** — optional JSON sibling of the Markdown packet, generated from
  the same internal packet object as a public machine-fact representation for
  eval assertions and other consumers; Markdown remains the primary artifact.

## Scope

In scope for these specs: everything the CLI does deterministically, plus
the Tier 1 fixture evals that run in CI, plus the seed catalog through P0
(`anchor`, `test`, `files`, `error` gated).

Out of scope:

- **Tier 0 (anchor viability spike) and Tier 2 (agent A/B)** — these are
  offline, pre-registered experiments defined in [`eval-plan.md`](../eval-plan.md).
  They gather evidence about whether ctxpack is worth building; they are not
  conformance requirements and have no spec here. Per-kind seed viability
  spikes (SEED-5) follow the same offline pattern under `eval/`.
- **P1/P2 seed kinds** — `method` ships Phase 5a (no test-candidate leg;
  SEED-25). Remaining (`diff`, `route`, `area`) ship only after their own
  spikes and a later plan.
- **v0 non-goals** — the full list lives in `design.md` ("Non-goals for v0").
  Highlights that shape these specs: no embeddings or generic RAG, no route
  browsing as silent compile input, no inherited/concern/metaprogrammed action
  resolution, no Rails engines, no Rails boot for static recipes, no
  system/browser spec discovery, no Rubydex dependency, no LLM anywhere in
  packet construction or Tier 1 evals, no task-only compilation in the gem.
