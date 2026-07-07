# Pinning a Tier 2 subject app's Ruby (mise/rbenv) and reusing an authed CLAUDE_CONFIG_DIR

## Problem
Standing up a new Tier 2 expansion app (Campfire) so the harness can run it: the
throwaway `git clone --local` workspaces the harness scores in kept resolving the
wrong Ruby and couldn't find the app's gems, and the copied authenticated
`CLAUDE_CONFIG_DIR` reported "Not logged in".

## Context
Harness model: each subject/scoring session runs in a `git clone --local` of a
pinned template (committed files only + explicit `prepared_files`). So gems must
be in the resolved Ruby's **default gem home** (not a per-app `vendor/bundle`,
which is untracked and gitignored), and the test DB must be a `prepared_file`.
Campfire pins Ruby 3.4.5 via `.ruby-version`; its committed `Gemfile.lock`
(rails 8.2.0.alpha) only installs cleanly on 3.4.5.

## Failed approaches
1. `bundle install` with `--path vendor/bundle` — untracked, absent from clones.
2. Bundling under the machine's default Ruby (mise global **4.0.1**) — too new for
   the locked gems; bundler silently **rewrote the committed `Gemfile.lock`** to
   newer versions, so clones (which carry the *committed* lock) failed with
   `Bundler::GemNotFound`.
3. Assuming `.ruby-version` selects the Ruby — modern **mise ignores idiomatic
   version files by default**, so it used its global 4.0.1 everywhere.
4. Installing 3.4.5 under **rbenv** — rbenv's shims aren't on PATH (mise's Ruby
   bin is), so it never won.
5. **Copying / symlinking** the authenticated `CLAUDE_CONFIG_DIR` — still "Not
   logged in": Claude Code binds OAuth to the **literal** `CLAUDE_CONFIG_DIR`
   path (macOS Keychain), and the lookup uses the literal string, not the
   realpath.

## Key insight
Two literal-string bindings, both defeated by copies/symlinks: mise resolves the
Ruby from a **native `mise.toml`/`.tool-versions` found by walking up from cwd**
(not `.ruby-version`), and Claude's Keychain entry is keyed by the **literal
config-dir path**. Fix each by making the real path/version manager see the right
value, not by duplicating state.

## Final approach
- Drop a `mise.toml` (`[tools]\nruby = "<ver>"`) at an **ancestor of both the
  template and the workspaces dir** (e.g. `tmp/tier2-expansion/<app>/`) and
  `mise trust` it. A shell that starts anywhere under that tree resolves the
  pinned Ruby (verified: `zsh -ic` in a workspace clone).
- Bundle the app under that Ruby (`mise exec ruby@<ver> -- bundle install`) so
  gems land in that Ruby's default gem home; restore the committed `Gemfile.lock`
  first if a wrong-Ruby bundle churned it.
- Launch **all** harness/test commands via `mise exec ruby@<ver> -- …` so the
  harness process and its `Open3` scoring children inherit the right Ruby; the
  subject session inherits it too (spawned with `chdir: workspace`, its shell
  re-activates mise from the ancestor `mise.toml`).
- For auth, don't copy — add a per-app `AppConfig#config_dir` override pointing
  at the exact already-authenticated path (e.g. Redmine's `tmp/tier2/claude-config`).

## Verification
A `git clone --local` of the template + copied `prepared_files` ran an existing
suite green via both paths — scoring (`mise exec … bin/rails test`) and subject
(fresh `zsh -ic` + bare `bin/rails test`). `CLAUDE_CONFIG_DIR=<authed path>
claude -p …` → `OK`. Pilot: both sessions `complete`/`success=true`.

## Reusable rule
On a machine with mise active: pin a subject app's Ruby with an ancestor
`mise.toml` (not `.ruby-version`), bundle to the default gem home under that
Ruby, and run the harness under `mise exec ruby@<ver> --`. Reuse an authenticated
`CLAUDE_CONFIG_DIR` by pointing at its **exact path**, never a copy/symlink.

## When to apply again
Authoring the remaining Tier 2 expansion apps (Lobsters — MariaDB, Publify) or
any harness that scores work in throwaway clones of a version-pinned app; and any
time a copied Claude config is unexpectedly "Not logged in".
