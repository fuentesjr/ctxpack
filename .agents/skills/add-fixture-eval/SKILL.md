---
name: add-fixture-eval
description: Turn a packet bug into a permanent Tier 1 regression case — a YAML file under test/fixtures/evals/ (plus fixture-tree edits under test/fixtures/apps/ if needed), red before the fix and green after. Use whenever any packet bug is found, per EVAL-9.
---

# add-fixture-eval

EVAL-9 (`specs/fixture-evals.md`): every packet bug found — in fixtures, real
usage, or Tier 0/2 experiments — becomes a new small deterministic eval case
before or alongside its fix. Tier 1 is the regression net; it only grows.

## When to use

- Any confirmed bug in packet compilation, rendering, or the manifest.
- A Tier 0/Tier 2 experiment surfaces a wrong packet (wrong file set, wrong
  reason code, wrong test candidate, limit violation, nondeterminism).

## When NOT to use

- Usefulness questions ("should the packet include X?") — that is Tier 2
  evidence territory, not a Tier 1 assertion. EVAL-1: Tier 1 is circular by
  design and must never be cited as evidence for the hypothesis.
- CLI flag/UX bugs with no packet-content component — cover those in
  `test/ctxpack/cli_test.rb` instead.
- Anything needing a bootable Rails app, generators, or app dependencies —
  EVAL-2 forbids it; fixture trees are static Rails-shaped files only.

## Workflow

1. **Reproduce** the bug against the current working tree (via
   `Ctxpack.compile` or in-process `Ctxpack::CLI#run`), so you know exactly
   which assertion will catch it.
2. **Pick or extend a fixture tree** under `test/fixtures/apps/`
   (`minitest_basic/`, `rspec_basic/`, or a new sibling for a new
   deterministic family). Rules:
   - Static files only; no boot, no generators, no dependencies (EVAL-2).
   - Fixture `*_test.rb` / `*_spec.rb` files are inert scaffolding: plain
     Rails-shaped source, no `test_helper` requires, never loaded by the
     suite (the Rakefile pattern `test/ctxpack/**/*_test.rb` excludes them
     deliberately — do not "fix" that).
3. **Author the YAML case** in `test/fixtures/evals/<name>.yml` in the EVAL-4
   shape (`accounts_upgrade.yml` is the canonical example): `name`, optional
   `app` (defaults to `minitest_basic`), `command.anchor`, `command.task`,
   and `expect` with `entrypoint`, `include` (path + reason_code), `exclude`,
   `tests`, `max_files`. Assert on stable packet-object/manifest fields, not
   Markdown prose (EVAL-5).
4. **Red:** run `bundle exec rake test` **before** fixing — the new case must
   fail, and fail for the right reason. If it passes pre-fix, it doesn't
   capture the bug; rewrite it.
5. **Fix** the bug with the smallest change that passes.
6. **Green:** `bundle exec rake test` — whole suite, 0 failures. The runner
   auto-generates two tests per case (packet expectations + CLI determinism),
   so no runner wiring is needed; but note the runner raises at load time if
   the case glob is empty — never delete the last case.
7. If the fix changed compiler behavior, the pass that lands it needs the
   `tier0-corpus-rescan` gate.

## Verification requirements

- [ ] New case demonstrated **red** on the pre-fix tree (paste the failure).
- [ ] Whole suite green post-fix (paste the summary line).
- [ ] Case asserts reason codes from the FMT-6 registry in
      `specs/packet-format.md` — never invent a code; a new code is a spec
      change (spec + `design.md` together).
- [ ] No fixture file requires app dependencies or repo test helpers.

## Expected output

One new YAML case (and any fixture-tree additions), the bug fix, a green
suite, and — if the bug came from a spec ambiguity — the reconciled spec +
`design.md` amendment in the same change.

## Escalation

- The bug can't be expressed as a deterministic fixture assertion → report
  why; it may be a Tier 2 (usefulness) question or a spec gap for the user.
- Capturing it needs a new reason/uncertainty code or a spec amendment →
  surface for user sign-off before landing.
