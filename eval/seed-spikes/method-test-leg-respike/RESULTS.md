# Method test-candidate leg respike — results

**Measured:** 2026-07-19 against the frozen `PREREGISTRATION.md`.

**Runner commit:** `abe74ca82bcc3289286cc4f01b65925193c4bc51`

**Command:**

```sh
ruby -Ilib eval/seed-spikes/run_method_test_leg_respike.rb \
  eval/seed-spikes/method-test-leg-respike/results
```

The runner verified all three checkout SHAs and confirmed that tracked files
under `app/`, `test/`, and `spec/` matched their pinned commits. There were no
candidate parse failures or runner crashes.

## Frozen verdict — DROP

Both precision gates failed. Coverage and candidate-yield gates passed, so the
rule is not failing from an absence of evidence; its candidates are usually
irrelevant to the named method.

| Gate | Observed | Threshold | Result |
|---|---:|---:|---|
| Mean precision | 0.1998 | >= 0.70 | FAIL |
| Per-app precision floor | 0.1163 | >= 0.60 | FAIL |
| Mean resolved-pair coverage | 0.6757 | >= 0.05 | PASS |
| Per-app candidate yield | 86 | >= 25 | PASS |

The pre-registered consequence is **DROP**. Exact production-to-test mirror
paths do not qualify for the method test-candidate leg. SEED-25 remains
unchanged, and production method packets keep no test-candidate leg.

## Per-app results

| App | Population | Resolved | Resolution | Candidate pairs | Precision | Strict precision | Coverage |
|---|---:|---:|---:|---:|---:|---:|---:|
| Redmine | 1,771 | 1,712 | 0.9667 | 1,405 | 0.2925 | 0.2790 | 0.8207 |
| Campfire | 254 | 241 | 0.9488 | 86 | 0.1163 | 0.0930 | 0.3568 |
| Lobsters | 360 | 352 | 0.9778 | 299 | 0.1906 | 0.1773 | 0.8494 |

Candidate rules contributed 325 modern Minitest mirrors and 1,080 legacy
`test/unit` mirrors on Redmine, 86 modern Minitest mirrors on Campfire, and 299
RSpec mirrors on Lobsters.

## Failure mechanism

The mirror path usually identifies a class-level test file, not a test for the
named method. `mirror_constant_only` is the dominant label: 866 Redmine pairs,
41 Campfire pairs, and 242 Lobsters pairs. The same test path is consequently
reused across many methods in its production class: 1,328 duplicate path-pairs
on Redmine, 68 on Campfire, and 268 on Lobsters.

| Label | Redmine | Campfire | Lobsters |
|---|---:|---:|---:|
| `mirror_relevant` | 411 | 10 | 57 |
| `mirror_constant_only` | 866 | 41 | 242 |
| `mirror_method_only` | 42 | 12 | 0 |
| `mirror_neither` | 86 | 23 | 0 |
| `resolved_no_mirror` | 307 | 155 | 53 |
| `resolution_failed` | 59 | 13 | 8 |
| `candidate_parse_failure` | 0 | 0 | 0 |
| `crash` | 0 | 0 | 0 |

This held-out result confirms the original demodulized-token failure was not
fixed by switching to exact mirror paths. The failure changes shape—from
unrelated files to class-relevant but method-irrelevant files—but still violates
the same false-inclusion constraint.

## Provenance

| Artifact | SHA-256 |
|---|---|
| `results/redmine.json` | `fbfa42c05ecc6ab304929fe0e28249a07d9ecbdc6c00da9192fb2c673ef6b0af` |
| `results/campfire.json` | `4b76378c540bb296ff62a741421ce7e20f089b310c0c9b5680fb29a0dc606bee` |
| `results/lobsters.json` | `c2d08e6bec4360a0eab3ac09bab9eb13cdfa3e754d9694092597d2a6d1e7534f` |
| `results/summary.json` | `038f7037921e7abb7e59d89ef8084ce8e1a0196e0d464860e9a41b2b3e24fee0` |

These results and the recorded verdict are frozen evidence. A different method
test-candidate rule requires a new preregistration and work order.
