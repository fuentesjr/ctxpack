# ctxpack v0 specifications

Status: Draft, derived from [`design.md`](../design.md) and [`eval-plan.md`](../eval-plan.md).

These documents restate the settled v0 design as normative, testable requirements.
`design.md` remains the record of rationale and tradeoffs; when a spec and the
design doc disagree, treat it as a bug in one of them and reconcile — do not
silently follow either.

## Documents

| Spec | Covers | Requirement prefix |
|---|---|---|
| [`cli.md`](cli.md) | Command surface, flags, artifact naming and location | `CLI` |
| [`packet-compilation.md`](packet-compilation.md) | Anchor resolution, parsing, callbacks, constants, test candidates, limits | `ANCH`, `PARSE`, `CB`, `CONST`, `TEST`, `LIM` |
| [`packet-format.md`](packet-format.md) | Markdown packet structure, reason/uncertainty codes, repo stamp, determinism, JSON manifest | `FMT`, `DET`, `MAN` |
| [`fixture-evals.md`](fixture-evals.md) | Tier 1 deterministic regression evals (fixtures, YAML cases, runner) | `EVAL` |

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
- **Application root** — the Rails application directory ctxpack is run from.
  v0 assumes the current working directory is the application root.
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
  resolution, no Rails engines, no Rails boot, no RSpec, no Rubydex dependency,
  no LLM anywhere in packet construction or evals.
