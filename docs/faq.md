# ctxpack FAQ

Short answers for Rails developers. For a hands-on walkthrough, see
[examples.md](examples.md).

## What problem does ctxpack solve?

When you hand a task to an AI coding agent, it usually spends its first minutes
*finding* the relevant code — grepping, opening files, backtracking. ctxpack
does that resolution once, statically and deterministically, and hands the agent
a short list of the files worth reading first (the controller action, its
callbacks, referenced constants, the view, the covering tests) so it can start
on the real work. Think of it as a precomputed "start here" for a
`controller#action`.

## Does it actually help? {#does-it-actually-help}

Sometimes, and honestly-measured. What we can say from **offline** A/B studies
(agent-in-the-loop, pre-registered, directional — not production field data):

- The packet meets a **≥ 30% median reduction in exploration** (calls to the
  first load-bearing file read) across three apps — Campfire, Lobsters, Publify
  — spanning both Minitest and RSpec. Details:
  [`eval/tier2-expansion/RESULTS.md`](../eval/tier2-expansion/RESULTS.md) and the
  earlier single-app run [`eval/tier2/RESULTS.md`](../eval/tier2/RESULTS.md).
- The lone consistent non-beneficiary is the **bug-fix task**, where a failing
  test already points straight at the code — the packet has nothing to shortcut.
- It did **not** produce better final code: diff quality scored at ceiling in
  *both* arms (packet and no-packet), so the measured value is getting to the
  right files faster, not writing a better patch.

Caveats: these are small, offline runs on a handful of open
Rails apps, and ctxpack is v0. Treat the exploration win as a real but bounded
effect on **focused** tasks, and verify it pays off in your own workflow.

## Why not just let the agent grep or `@`-mention files itself? {#why-not-just-let-the-agent-grep}

You can, and for a one-file change that's often enough. ctxpack competes with the
agent's *first two minutes*: it resolves callbacks, referenced constants, and the
covering tests in one deterministic pass, and — crucially — it flags what it
**guessed** in the Uncertainty section, which ad-hoc grepping doesn't. The
tradeoff is that ctxpack is deliberately narrow (see the limits and refusals
below); it's a fast starting point, not a replacement for the agent reading code.

## Does it boot or run my app?

No. ctxpack is pure static analysis using [`prism`](https://github.com/ruby/prism)
(Ruby's parser). It never loads Rails, never connects to a database, and never
executes your code. That's why it's fast and safe to run anywhere, and also why
it can't see anything that only exists at runtime (dynamically defined actions,
metaprogrammed callbacks, etc.).

## How do I find the anchor for a route? Does it read my `routes.rb`?

It does **not** read `config/routes.rb` — you supply the anchor as
`controller#action`. If you have a URL or route helper, ask Rails for the
mapping:

```console
$ bin/rails routes -g upgrade      # grep by action/path fragment
$ bin/rails routes -c accounts     # all routes for one controller
```

and anchor on the `controller#action` it prints.

## Which Rails versions and test frameworks are supported?

ctxpack keys off conventional Rails file layout rather than a specific Rails
version, and it requires **Ruby ≥ 3.2**. It detects **Minitest** (default) and
**RSpec** test suites: RSpec is recognized when `spec/` plus
`spec/rails_helper.rb` or `rspec-rails` is present, and the suggested commands
switch to `bundle exec rspec` automatically. Controller and request/integration
specs are covered; `spec/system/` is out of scope for v0.

## Why is a file I expected missing from the packet?

Two likely reasons:

1. **Limits.** The packet is capped (8 total files, 4 constants, 2 views, 2
   tests). When a cap truncates, the dropped candidates are named in the
   `## Omitted candidates` section — check there first.
2. **Resolution scope.** ctxpack follows an *intra-file* call graph: the action
   body, its applicable same-file callbacks, and same-file methods the action
   transitively calls. It does **not** chase cross-file call graphs, sibling
   models, or superclass/concern methods. Views are matched by path convention;
   locale files are never scanned (you get a standing pointer instead). Anything
   outside that scope won't appear — by design, to keep the packet small and
   precise.

## Why is the "Tests to run" section empty?

Because ctxpack found no test file matching its conventional or path-token rules.
This is common on apps with legacy layouts (e.g. Rails' old `test/functional/`
directory), which produce structurally zero candidates. It's expected behavior,
not a bug — add or point the agent at the right test yourself.

## Why is there an "Uncertainty" section? Can I trust the packet?

The Uncertainty section is the point: ctxpack names everything it inferred or
deliberately left unresolved — path-guessed tests, convention-only constant
matches, `around_action`/block callbacks it can't snippet, out-of-file
callbacks, and the locale pointer. Trust the packet as a well-sourced *starting
list*, and treat each uncertainty note as a "verify this if the task touches it"
flag. It's engineered to avoid false precision, not to be the last word.

## Does it handle namespaced controllers?

Yes. Use a path-style prefix in the anchor: `admin/users#destroy` resolves
`app/controllers/admin/users_controller.rb` and its `app/views/admin/users/`
templates.

## What about inherited, concern-defined, or metaprogrammed actions?

Unsupported in v0, and ctxpack refuses them explicitly rather than guessing:

```
ctxpack: action teleport was not directly defined in app/controllers/accounts_controller.rb;
inherited, concern-defined, and metaprogrammed actions are unsupported in v0
```

If the action is real but defined elsewhere (a base controller, a concern, a
gem like Devise), ctxpack can't statically see it. Anchor on a directly-defined
action, or read that code yourself.

## Can I anchor on a mailer, job, or route string?

No — anchors are **controllers only**, always exact `controller#action` in
snake_case. URLs, HTTP verbs (`POST /accounts`), and route helpers are rejected
with an "invalid anchor" error. Mailers, jobs, and other classes are out of
scope for v0.

## Is the output deterministic?

Yes — byte-for-byte. The same anchor against the same source tree always
produces an identical packet and manifest (files sorted, stable ordering, no
timestamps inside the content). Determinism is a design guarantee, enforced by
the fixture-eval suite, so packets are safe to diff, cache, or commit.

## Can I raise the limits? {#can-i-raise-the-limits}

No — the caps (8/4/2/2/120) are fixed with no flag to change them. The packet's
value is being *small enough to actually read*; an uncapped "include everything"
list would just recreate the exploration problem ctxpack exists to shrink. If the
cap is hiding something you need, the `## Omitted candidates` section tells you
what, so you can pull it in deliberately.

## Should I commit packets to the repo?

Your call. By default they go to `.ctxpack/` and ctxpack reminds you to gitignore
them — good for ephemeral, per-task use. To commit them (e.g. for review or
shared context), write to a tracked directory with `--dir docs/ctxpack`. Just
remember each packet carries a repo stamp and is a snapshot of one tree state; it
goes stale as the code changes.

## Does ctxpack send my code anywhere?

No. It runs entirely locally, reads your source files, and writes packet files to
disk. There are no network calls and no telemetry. What you do with the generated
packet afterward (e.g. pasting it into a hosted AI agent) is up to you.

## How fast is it, and does it scale?

It parses a small, bounded set of files per anchor (the controller plus a handful
of resolved targets), so a single packet compiles in well under a second even on
large apps — there's no whole-repo indexing step. In the anchor-viability spike
it compiled 1,967 real controller#action pairs across three large open-source
apps with zero crashes.
