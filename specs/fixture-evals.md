# Spec: Tier 1 fixture evals

Status: Draft. Source: `design.md` — "Simple v0 evals"; `eval-plan.md` —
"Tier 1 — determinism regression".

## Standing limitation

**EVAL-1.** Tier 1 proves the tool agrees with itself on fixtures authored to
match its own assumptions. It is circular by design and says nothing about
usefulness. Tier 1 results MUST NOT be cited as evidence for the ctxpack
hypothesis — that is Tier 2's job (`eval-plan.md`). This paragraph exists so
the limitation is never misread.

## Fixtures

**EVAL-2.** Fixtures are static Rails-shaped directory trees under
`test/fixtures/apps/`. They MUST NOT require booting Rails, running
generators, or installing app dependencies — only enough Rails-shaped
structure to exercise deterministic packet construction.

First fixture:

```text
test/fixtures/apps/minitest_basic/
  app/controllers/accounts_controller.rb
  app/services/billing/subscriptions.rb
  app/jobs/sync_billing_account_job.rb
  test/controllers/accounts_controller_test.rb
  test/integration/accounts_upgrade_test.rb
```

Additional fixture trees MAY exercise other deterministic families, e.g.
`test/fixtures/apps/rspec_basic/` for RSpec controller/request spec discovery.

**EVAL-3.** Fixture trees live inside ctxpack's own repository, so packets
generated from them stamp ctxpack's current commit SHA. Consequences:
double-run determinism checks are unaffected (same repo state → same stamp),
but golden-content assertions MUST normalize the repo-stamp line, exactly as
they normalize output paths.

## Eval cases

**EVAL-4.** One case = one YAML file:

```yaml
name: accounts_upgrade
app: minitest_basic
command:
  anchor: accounts#upgrade
  task: Implement billing upgrade

expect:
  entrypoint:
    file: app/controllers/accounts_controller.rb
    action: upgrade

  include:
    - path: app/controllers/accounts_controller.rb
      reason_code: controller_action
    - path: test/integration/accounts_upgrade_test.rb
      reason_code: minitest_candidate

  exclude:
    - app/controllers/admin/accounts_controller.rb

  tests:
    - bin/rails test test/integration/accounts_upgrade_test.rb

  max_files: 8
```

Semantics: `app` names the fixture tree under `test/fixtures/apps/` and
defaults to `minitest_basic` when omitted. `include` entries must all be
present with the stated reason code; `exclude` paths must be absent; `tests`
commands must all be suggested; `max_files` bounds the packet's total file
count.

**EVAL-5.** Assertions SHOULD target stable fields (via the internal packet
object or the JSON manifest, MAN-1) rather than parsing Markdown prose.

## Runner

**EVAL-6.** For each case, the runner checks:

- correct entry point
- required files included, with expected reason codes
- forbidden files excluded
- expected test commands suggested
- packet stays under file and snippet limits (LIM-1)

**EVAL-7.** Determinism check: running the same command twice — with a fixed
`--out`, or with output paths normalized — produces the same content hash.
Cross-repo-state comparisons (golden files) additionally normalize the
repo-stamp line (EVAL-3).

**EVAL-8.** No LLM judge, anywhere in Tier 1. Every check is a deterministic
assertion.

**EVAL-9.** Every packet bug found — in fixtures, real usage, or Tier 0/2
experiments — becomes a new small deterministic eval case before or alongside
its fix. Tier 1 is the regression net; it only grows.

**EVAL-10.** Tier 1 is the only eval tier that runs in CI. Tiers 0 and 2 are
offline experiments (`eval-plan.md`) and MUST NOT be wired into CI.

**EVAL-11.** The runner MUST be re-runnable at any checkout: invoking it at
any commit (clean or dirty) runs every case against the working tree as-is,
with no one-shot setup, recorded state, or dependencies beyond the repository
itself. Re-runnability is a design property that is hard to retrofit; the
Tier 2 harness follows the same principle (`eval-plan.md`).
