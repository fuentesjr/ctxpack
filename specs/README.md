# ctxpack v0 specifications

Status: Draft, derived from [`design.md`](../design.md) and [`eval-plan.md`](../eval-plan.md).

These documents restate the settled v0 design as normative, testable requirements.
`design.md` remains the record of rationale and tradeoffs; when a spec and the
design doc disagree, treat it as a bug in one of them and reconcile — do not
silently follow either.

## Documents

Listed in dependency (and intended build) order: compilation is a standalone
pipeline from anchor to internal packet object; format renders that object;
the CLI wires both behind a command; fixture evals exercise the whole.

| Spec | Covers | Requirement prefix |
|---|---|---|
| [`packet-compilation.md`](packet-compilation.md) | Anchor resolution, parsing, callbacks, constants, test candidates, limits | `ANCH`, `PARSE`, `CB`, `CONST`, `TEST`, `LIM` |
| [`packet-format.md`](packet-format.md) | Markdown packet structure, reason/uncertainty codes, repo stamp, determinism, JSON manifest | `FMT`, `DET`, `MAN` |
| [`cli.md`](cli.md) | Command surface, flags, artifact naming and location | `CLI` |
| [`fixture-evals.md`](fixture-evals.md) | Tier 1 deterministic regression evals (fixtures, YAML cases, runner) | `EVAL` |

## Cross-spec contracts

The build order above keeps behavior dependencies one-directional, but a few
contracts cut across spec boundaries. They are recorded here so no
implementation pass discovers them late:

- **Internal packet object.** The central contract: compilation produces it,
  format renders it, the manifest serializes it (MAN-1), fixture evals assert
  on it (EVAL-5). The MAN-2 manifest shape is its de facto schema — everything
  MAN-2 and FMT-2..FMT-9 need (entrypoint, snippet ranges, reason codes,
  uncertainty codes, omitted candidates, repo stamp) must exist on the packet
  object when compilation finishes, even though those requirements live in
  `packet-format.md`.
- **Reason and uncertainty codes.** Registered in FMT-6/FMT-7 but emitted by
  compilation events (CB-1a, CB-2, CB-2a, CB-4, TEST-3, LIM-2). Compilation
  depends on the registries as data; a compilation change that needs a new
  code updates `packet-format.md` in the same change.
- **Repo stamp.** FMT-10..FMT-12 specify it, but it is computed when the
  packet object is built, not at render time — the manifest carries it
  (MAN-2 `repo`), so it cannot be a format-layer concern.
- **Application root and task text.** Inputs to compilation, passed as
  parameters. Discovering the root (CLI-3) and validating/deriving artifact
  names (CLI-4..CLI-8b) belong to the CLI layer only.
- **Fixture trees.** EVAL-2 fixture apps double as compilation scaffolding:
  author them at their final paths under `test/fixtures/apps/` so Tier 1 evals
  reuse them rather than duplicate them.

## Conventions

- **MUST / MUST NOT** — conformance requirement; a violation is a bug.
- **SHOULD** — expected behavior; deviations need a recorded reason.
- **MAY** — explicitly permitted, never required.
- Requirements are numbered (`CLI-3`, `ANCH-2`, …) so eval cases and issues can
  reference them. Numbers are stable: never renumber; mark retired requirements
  as *Withdrawn* instead.
- Where `design.md` was silent and this spec fixes a decision (e.g. a canonical
  reason-code name), the requirement is annotated **[fixed by spec]**.

## Terminology

- **Anchor** — an exact `controller#action` reference in the shape shown by
  `bin/rails routes`, e.g. `accounts#upgrade`, `admin/accounts#upgrade`.
- **Context packet** (or **packet**) — the compact Markdown artifact ctxpack
  compiles from an anchor: task, anchor, entry point, files with snippets and
  reasons, test candidates, uncertainty notes.
- **Application root** — the nearest ancestor of the current directory
  containing `config/application.rb`, discovered by upward search (CLI-3),
  matching `bin/rails`/Rake run-from-subdirectory ergonomics.
- **Reason code** — a fixed machine-readable token explaining why a file is in
  the packet (see `packet-format.md`).
- **Repo stamp** — the git commit SHA (plus dirty marker) embedded in packet
  content; the only repo-state marker allowed inside a packet.
- **Manifest** — optional JSON sibling of the Markdown packet, generated from
  the same internal packet object, for eval assertions.

## Scope

In scope for these specs: everything the v0 CLI does deterministically, plus
the Tier 1 fixture evals that run in CI.

Out of scope:

- **Tier 0 (anchor viability spike) and Tier 2 (agent A/B)** — these are
  offline, pre-registered experiments defined in [`eval-plan.md`](../eval-plan.md).
  They gather evidence about whether ctxpack is worth building; they are not
  conformance requirements and have no spec here.
- **v0 non-goals** — the full list lives in `design.md` ("Non-goals for v0").
  Highlights that shape these specs: no embeddings or generic RAG, no route
  browsing or route-string parsing, no inherited/concern/metaprogrammed action
  resolution, no Rails engines, no Rails boot, no system/browser spec
  discovery, no Rubydex dependency, no LLM anywhere in packet construction or
  evals.
