# Error-seed viability spike — pre-registration

**Status:** Frozen before measurement (2026-07-13), Grok Phase 3 gate.  
**Source:** seed proposal §3.3 / §11 Phase 3; SEED-16, SEED-20, SEED-22.

## Question

Can deterministic frame filtering recover **application** `path:line` frames from
realistic Rails/Minitest/RSpec-style backtraces with high enough precision that
shipping `--from-error` is safe (no gem/framework pollution; no raw paste retention)?

## Ground truth: application frame (fixed before scoring)

A frame is an **application frame** iff after normalizing the path:

1. It is absolute or relative and resolves under the app root, **and**
2. The relative path starts with `app/`, `lib/`, or `config/`  
   (not `test/`/`spec/` for this spike — production error pastes are the P0 target),
3. It is **not** under `vendor/`, `node_modules/`, or a path segment named
   `gems`, `ruby/`, or `bundler/`.

All other frames are non-application (framework/gem/stdlib/noise).

## Population

For each of the three pinned apps, build **40 synthetic backtraces**
deterministically:

- Pick up to 40 existing `app/**/*.rb` files (sorted, stride sample).
- Each backtrace is 12 lines: 4 fixed framework/gem decoys + 1 true app frame
  at a fixed line (min(10, file line count)) + 4 more decoys + 1 second app
  frame if available + trailing decoys.
- Formats cycled by index modulo 3:
  0: Ruby MRI `from PATH:LINE:in \`method\``
  1: Rails log `PATH:LINE:in \`block in method\``
  2: JSON-ish `"file":"PATH","line":LINE`

## Heuristic under test

Same filter the product will ship (SEED-20): extract path:line candidates via
regexes for the three formats; keep only application frames per the definition
above; drop everything else.

## Metrics and gate

- **Precision:** among frames labeled application by the heuristic, fraction
  that are true application frames.  
- **Recall:** among true application frames in the population, fraction kept.  
- **Gate (both required):** precision ≥ **0.95** and recall ≥ **0.80**,
  averaged unweighted across the three apps.  
- **On fail:** demote `error` seed to **P1**, record in proposal + tracker,
  **continue to Phase 4 without shipping `--from-error`** (SEED-22 / §14.2).

## Explicit non-goals

- Not measuring snippet quality around frames.  
- Not storing raw pastes (product forbids it).  
- Not CI-wired.
