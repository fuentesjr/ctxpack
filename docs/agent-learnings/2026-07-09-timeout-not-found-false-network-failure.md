# A missing `timeout` command produced a false "GitHub DNS failed" gate note

## Problem

The tracker was self-contradicting: commit `6688ff9` recorded the view-pass
Tier 0 corpus rescan as **PASSED** (detailed addendum in
`eval/tier0/RESULTS.md`) *and*, in the same commit, carried a Known-debt line
saying the rescan was "still pending because GitHub DNS failed during pinned
checkout fetches on 2026-07-09." Both were committed together; the debt line
even referenced a date after its own commit timestamp. One of them was wrong,
and it gated whether a compiler-behavior change was safe to push.

## Context

Because the rescan's expected result is *byte-identical to the existing
baseline* (view inclusion is additive/post-resolution), a genuine pass writes
**no new artifact** — so the filesystem could not distinguish "actually re-ran
and matched" from "asserted-to-match by reasoning after the fetch failed."

## Symptom / fingerprint

My own first reachability probe used `timeout 8 nslookup github.com` and
reported `DNS FAIL` for every host. On macOS the coreutils `timeout` binary is
**not** on PATH (it's `gtimeout`); the shell returns `command not found`
(exit 127) *before* running `nslookup`, so the guarded command "fails"
regardless of actual network state. The prior session almost certainly hit the
same trap: a `127` from a missing wrapper reads as "the fetch failed," and a
DNS/network-failure note gets written over a step that was actually fine.

## Key insight

A non-zero exit from a *wrapper* (`timeout`, `retry`, `xargs`, a shell
function) is not evidence the *wrapped* operation failed — it can mean the
wrapper itself never ran. Never record an environmental failure (DNS, network,
auth) from a single guarded command without confirming the guard executed. On
macOS, `timeout` specifically is absent by default.

## Final approach

Re-probed without the wrapper: `nslookup -timeout=5` (native flag), `curl
--max-time`, and `git ls-remote` (its own network handling) all succeeded —
GitHub was fully reachable. Then settled the doubted gate empirically by
**re-running the rescan**: fresh shallow checkouts of all three apps at the
pinned SHAs (`git rev-parse HEAD` verified), classifier re-run against the
committed route tables, and `diff -q` of each result JSON against
`results/post_amendment/` → **byte-identical**, 0 per-anchor change across
1,967 pairs. The committed addendum was genuine; the debt note was the artifact.
Removed the debt line, added a re-verification note, reconciled the tracker.

## Meta-lesson

When two committed records contradict each other and the filesystem can't
adjudicate (a pass that writes no new artifact), don't pick the more detailed
prose — **re-run the deterministic check and diff byte-for-byte.** It's cheap,
it's the only real proof, and it converts "which claim do I trust?" into a fact.
Prefer tools with built-in timeouts (`curl --max-time`, `nslookup -timeout`,
git's low-speed knobs) over an external `timeout` wrapper that may not exist.
