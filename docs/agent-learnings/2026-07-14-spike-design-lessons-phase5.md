# Viability-spike design lessons from the Phase 5 seed campaign

## Problem
Three seed kinds (`method`, `diff`, `route`) each needed a pre-registered
SEED-5 viability spike, and the design choices inside those pre-regs —
matching heuristics, gate predicates, evidence populations — decided ship
outcomes irreversibly. Three transferable design lessons emerged that no
repo document captured.

## Context
Phase 5 sub-passes 5a/5b/5c; pre-regs and results under
`eval/seed-spikes/{method,diff,route}/`; advisor corrections recorded in
each PREREGISTRATION.md status line; tracker decision log 2026-07-14.

## Failed approaches
- **Basename token matching for test candidates (5a):** globbing tests
  whose filename contains the constant's demodulized snake token hit 0.474
  precision on Zammad (`AI::Agent` → token `agent` matches every
  `agent_*` browser test) and failed its 0.70 gate at 0.6996 overall.
- **Asymmetric arm predicates for a baseline gate (5c, caught pre-freeze):**
  the draft required the ritual arm to produce *exactly one correct hit*
  while the resolver arm got convergent-multi credit — biasing the margin
  gate toward the tool being evaluated and making it near-non-falsifiable.
- **Pooling heterogeneous evidence variants under one gate (5c):** bare
  paths are ~0% resolvable under set-semantics (REST maps one path to many
  verb-dependent actions) while verb-qualified paths hit 97% on Mastodon;
  pooling buried the strong class under the impossible one. (Also the
  inverse hazard, caught by the advisor: the helper variant is ~1.0 by
  construction and would have padded the gate.)

## Key insight
Spike gates are only as honest as three structural choices: match by
*path-mirror convention* rather than name tokens (tokens flood on generic
names); score both arms of any baseline comparison with *one symmetric
success predicate*; and *segment evidence classes* whose ceilings differ
structurally — gate each class it makes sense to ship, report the rest.

## Final approach
5a shipped without its token-matched leg (pre-registered demotion); 5b
pre-registered mirror-conventions-only paired tests and passed at 0.810;
5c pre-registered the symmetric predicate + per-variant reporting, failed
its pooled resolution gate legitimately, and the per-variant report still
yielded the actionable insight (router-order-faithful first-match resolver
on verb-qualified evidence is the re-spike candidate).

## Verification
`eval/seed-spikes/method/results/` (precision 0.797/0.827/0.474),
`diff/results/` (agreement 0.810 avg), `route/results/` (bare path
`ambiguous_multi` 742/742 Mastodon with zero `no_match` — ambiguity real,
matcher sound; verb+path 720/742 unique).

## Reusable rule
When pre-registering a heuristic spike, match by path-mirror convention
(never basename tokens), define one success predicate shared by every
compared arm, and gate structurally-different evidence classes separately.

## When to apply again
Designing any new SEED-5 pre-registration (the `area` seed, the route
re-spike, test-leg re-promotion), or any eval comparing a tool arm against
a ritual/baseline arm.
