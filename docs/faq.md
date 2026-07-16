# ctxpack FAQ

Short answers for Rails developers. For a hands-on walkthrough, see
[examples.md](examples.md).

## What problem does ctxpack solve?

```text
task + seed(s) → provenanced packet
```

When you hand a task to an AI coding agent, it often spends its first minutes
*finding* relevant code. ctxpack is a local **context engineering CLI** for
Rails codebases: it deterministically selects, orders, bounds, and explains
evidence around user-supplied seeds for an agent's task. Its compiler expands
seed evidence you already have (a test path, stack frames, a diff, open files,
a service method, or a Rails `controller#action`) into a short, provenanced
packet — so the agent can start from a bounded list instead of open-ended search.

## What seeds exist? {#what-seeds-exist}

Shipped kinds (SEED-4 catalog as of Phase 5):

| Kind | CLI | Notes |
|---|---|---|
| `test` | `--from-test path[:line]` | Test/spec primary + inferred production surface |
| `error` | `--from-error paste\|-` | App frames only; raw paste never stored |
| `diff` | `--from-diff range\|patch` | Flag-only; changed files + conventional paired tests when present |
| `files` | `--from-files path…` | Named files + budgeted neighbors |
| `method` | `--from-method Const#method` | Non-controller methods; **no test-candidate leg** |
| `anchor` | `controller#action` / `--from-anchor` | Full action/callback/view/constant/test recipe |

`route` is **not shipped** (see [Can I paste a URL or route?](#can-i-paste-a-url-or-route)).
`area` is not scheduled. Catalog and recipes: [`specs/seeds.md`](../specs/seeds.md).

Newer kinds shipped after per-kind viability spikes (can the recipe resolve real
evidence under pre-registered gates). That is not the same as a Tier 2 agent
A/B for those kinds — see [Does it actually help?](#does-it-actually-help).

## What does task-only do? {#task-only}

**Refused by the gem.** At least one seed is required (SEED-2). Example:

```console
$ bundle exec ctxpack packet --task "Just prose, no seed"
ctxpack: missing seed; pass controller#action, a path, CONST#method, or a --from-* flag
…
```

(The `…` is the CLI's usage block, elided here.)

Turning a free-text bug report into a seed (which test? which path? which
anchor?) is **skill / agent territory**. The skill may propose a `ctxpack …`
invocation; the compiler still needs concrete evidence. Task text remains
optional-but-recommended *when a seed is present* (CLI-4).

## Can I paste a URL or route? {#can-i-paste-a-url-or-route}

**Not as something ctxpack resolves.** Route-shaped input is recognized and
**coached** toward Rails, then rejected — never compiled:

```console
$ bundle exec ctxpack "GET /accounts"
ctxpack: Rails route strings are not supported; pass a controller#action anchor
Try `bin/rails routes -g accounts` to find it.
```

```console
$ bundle exec ctxpack upgrade_account
ctxpack: "upgrade_account" looks like a Rails route helper, not a controller#action anchor
Try `bin/rails routes -g upgrade_account`, then pass the controller#action anchor shown by Rails.
```

There is no `--from-route`. The Phase 5c route-seed spike failed its resolution
gate (3-app average **0.243 < 0.70**): bare paths are verb-ambiguous under REST,
and even verb+path stays ambiguous on apps with overlapping dynamic specs when
matching without router order/constraints. Recorded outcome:
[`eval/seed-spikes/route/RESULTS.md`](../eval/seed-spikes/route/RESULTS.md).
Re-opening needs a new pre-registered spike.

Practical path: `bin/rails routes -g …` → pass the printed `controller#action`
as an **anchor seed**.

## Does it actually help? {#does-it-actually-help}

Sometimes, and honestly measured. From **offline** A/B studies (agent-in-the-loop,
pre-registered, directional — not production field data), using **anchor-seed**
packets:

- The three-app Tier 2 expansion met its pre-registered per-app support rule on
  **3/3 apps** — Campfire, Lobsters, and Publify — spanning Minitest and RSpec.
- Pooled by task category, **feature tasks met the exploration bar on 5/6
  tasks**, with a **58.5% median reduction** on the better of the two
  exploration metrics. **Bug tasks were 0/3**: failing-test output already
  localized the code, leaving the packet nothing to shortcut.
- The expansion's blind diff-quality scores were equal and at ceiling in both
  arms (7.94/8 each). It found no quality regression, but it does **not** show
  that ctxpack produces better final code; the positive signal is exploration
  efficiency.
- Full results and the earlier single-app study:
  [`eval/tier2-expansion/RESULTS.md`](../eval/tier2-expansion/RESULTS.md) and
  [`eval/tier2/RESULTS.md`](../eval/tier2/RESULTS.md).

We do **not** claim that `test` / `error` / `diff` / `files` / `method` seeds
improve agent outcomes; they ship because their expansion recipes passed
existence/convention viability gates. Treat them as deterministic compilers of
evidence you already trust.

Caveats: these are small, offline, directional studies of **anchor-seed-only**
packets, not production field data; they do not establish benefit for newer
seed kinds or improvement in final code quality. Verify payoff in your own
workflow.

## Why not just let the agent grep or `@`-mention files itself? {#why-not-just-let-the-agent-grep}

You can, and for a one-file change that's often enough. ctxpack competes with the
agent's *first minutes*: it applies a fixed recipe (callbacks and constants for
anchors; frames for errors; mirrors for diffs; etc.) in one deterministic pass,
and it flags what it **guessed** in Follow-ups. The tradeoff is deliberate
narrowness (limits and refusals below) — a starting point, not a replacement for
reading code.

## Does it boot or run my app?

No. Pure static analysis via [`prism`](https://github.com/ruby/prism). No Rails
boot, no database, no execution of your code. Diff seeds shell out to `git`
only. That's why it is safe to run anywhere, and why it cannot see runtime-only
definitions (metaprogrammed actions, dynamic callbacks, etc.).

## Which Rails versions and test frameworks are supported?

ctxpack keys off conventional Rails file layout rather than a specific Rails
version, and requires **Ruby ≥ 3.4**. It detects **Minitest** (default) and
**RSpec** (`spec/` plus `spec/rails_helper.rb` or `rspec-rails`). Controller and
request/integration specs are in scope for recipes that emit test candidates;
`spec/system/` is out of scope for v0. The method seed does not emit test
candidates at all (by design after its spike).

## Why is a file I expected missing from the packet?

1. **Limits.** Caps: 8 files, 4 constants, 2 views, 2 tests. Truncation is named
   in `## Follow-ups`.
2. **Recipe scope.** Each seed expands only what its recipe allows (e.g. method
   seed: same-file constants only, no tests; files seed: budgeted neighbors only
   when conventions hit; anchor: intra-file call graph, not cross-file graphs or
   superclass/concern methods). Locale files are never scanned (standing pointer
   in scope text).

## Why does the "Run" section say no candidates were found?

Either no test path matched the recipe's rules (legacy layouts, services without
mirrors, etc.), or the seed kind **does not include a test leg** (method seed;
some files/error cases). Both are expected behavior, not silent failure.

## Why is there a "Follow-ups" section? Can I trust the packet?

Follow-ups name packet-specific inferences and omissions. Trust the packet as a
well-sourced *starting list*; treat each follow-up as “verify if the task
touches it.”

## Does it handle namespaced controllers?

Yes. Path-style prefix: `admin/users#destroy` →
`app/controllers/admin/users_controller.rb`.

## What about inherited, concern-defined, or metaprogrammed actions?

Unsupported in v0; refused explicitly:

```
ctxpack: action teleport was not directly defined in app/controllers/accounts_controller.rb;
inherited, concern-defined, and metaprogrammed actions are unsupported in v0
```

## Can I seed a mailer, job, or plain Ruby class?

- **Method seed:** non-controller `Namespace::Class#instance_method` (e.g.
  `Billing::UpgradeService#call`) when the constant maps by Zeitwerk convention
  under `app/` and the instance `def` exists.
- **Files seed:** any existing path.
- **Anchor seed:** controllers only (`controller#action`).
- Mailer/job “action” strings are not a separate seed kind in v0.

## Is the output deterministic?

Yes — byte-for-byte for the same seeds, task, and source tree (stable ordering,
no content timestamps). Diff seeds are deterministic *given repo state + range*
(or patch bytes). Enforced by the fixture-eval suite.

## Can I consume the manifest without creating packet files?

Yes. `ctxpack … --stdout=json` writes Format 3 manifest JSON and creates
nothing. Bare `--stdout` emits Markdown. Both conflict with artifact options
(`--out`, `--dir`, `--manifest`, …).

## Can I raise the limits? {#can-i-raise-the-limits}

No — fixed caps (8/4/2/2/120). An uncapped list recreates the exploration
problem. Follow-ups name what the cap hid.

## Should I commit packets to the repo?

Your call. Default `.ctxpack/` is meant to be gitignored. To commit (review,
shared context): `--dir docs/ctxpack`. Each packet carries a repo stamp and
goes stale as the code changes.

## Does ctxpack send my code anywhere?

No. Local only: reads source, writes packets. No network, no telemetry. What you
do with a generated packet (e.g. paste into a hosted agent) is up to you.

## How fast is it, and does it scale?

It parses a small, budgeted set of files per compile — typically well under a
second, no whole-repo index. The anchor-viability spike compiled 1,967 real
`controller#action` pairs across three large open-source apps with zero
crashes.
