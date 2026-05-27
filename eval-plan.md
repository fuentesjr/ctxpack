# ctxpack evaluation plan

A simple evaluation plan for testing whether `ctxpack` context packets improve starting context for Rails coding tasks compared with generic repository search.

## Purpose

Compare a Rails-aware context packet generated from an exact `controller#action` anchor against generic search results.

## Example task shapes

Use 2–3 representative Rails tasks:

1. Feature work from a controller action
   - Example: `accounts#upgrade` — implement billing upgrade behavior.
2. Bug fix from a failing Minitest integration/controller test
   - Example: fix the behavior covered by `test/integration/accounts_upgrade_test.rb`.
3. Small behavior change in a controller/service path
   - Example: send confirmation email after account upgrade.

## Baseline comparison

For each task, compare the `ctxpack` packet against a generic search approach.

Generic search baseline examples:

```bash
rg "billing|upgrade|account"
find app test -iname "*account*"
find app test -iname "*billing*"
```

Record:

- files found by generic search
- files included in the packet
- files that were useful
- files that were distracting
- important files either approach missed

## Measurements

For each task, record:

| Metric | ctxpack packet | Generic search |
|---|---:|---:|
| Total files suggested | | |
| Useful files suggested | | |
| Distracting files suggested | | |
| True entry point found? | | |
| Relevant test found? | | |
| Uncertainty documented? | | |

Optional qualitative notes:

- Did the packet make the next action obvious?
- Did it reduce exploratory file reads?
- Did it prevent irrelevant edits?
- Did it expose package or architectural boundaries?

## Failure criteria

The approach is weak if:

- the controller action cannot be resolved reliably
- the controller action does not reveal useful next files
- the likely Minitest file cannot be found or guessed
- generic search finds the right context just as quickly
- the packet omits an essential file needed for the task
- the packet creates false confidence about an incomplete execution path
