# Spec: CLI and artifacts

Status: Draft. Source: `design.md` — "Settled v0 direction", "Artifact location
and naming", "Machine-readable manifest".

## Command

**CLI-1.** The primary (and, in v0, only) packet-producing command is:

```bash
ctxpack packet <anchor> [--task TASK] [--name NAME] [--dir DIR] [--out PATH] [--force] [--manifest]
```

Non-normative: inside a Rails app the executable is typically reached via
`bundle exec ctxpack` or a binstub (`bundle binstubs ctxpack` → `bin/ctxpack`
next to `bin/rails`). Examples write bare `ctxpack` for brevity.

**CLI-1a.** `ctxpack --help`, `ctxpack -h`, `ctxpack packet --help`, and
`ctxpack packet -h` MUST print packet-command help to stdout and return success
without discovering an application root, compiling a packet, writing files, or
terminating the caller through `SystemExit`. **[fixed by spec]**

**CLI-2.** `<anchor>` is a positional argument in exact `controller#action`
form (see `packet-compilation.md`, ANCH-1). Route strings
(`POST /accounts/:id/upgrade`) and route helpers (`upgrade_account`) MUST NOT
be accepted in v0.

**CLI-3.** ctxpack discovers the application root the way Rails tooling does:
starting from the current directory, it walks upward to the nearest ancestor
containing `config/application.rb` and treats that directory as the
application root. All compilation resolution, output destinations, and the
repo stamp are relative to the discovered root; displayed success paths follow
CLI-15. If no ancestor contains
`config/application.rb`, the command fails with a message saying it searched
upward for a Rails application root and found none. **[upward discovery
fixed by spec; matches `bin/rails`/Rake run-from-subdirectory ergonomics]**

## Flags

**CLI-4.** `--task TASK` — free-text description of the task the packet is
for. Optional. **[fixed by spec]** When omitted, the packet's Task section
records that no task was provided (see FMT-2) and name derivation uses the
anchor alone (CLI-8).

**CLI-5.** `--name NAME` — artifact name, snake_case or CamelCase (normalized
per CLI-8b). Recommended for clear feature/bug/context naming; names should
carry enough context to avoid vague artifacts like `upgrade.md`.

**CLI-6.** `--dir DIR` — output directory override. Default is `.ctxpack/`.
`docs/ctxpack/` is the canonical location when a packet is deliberately
committed (see CLI-13).

**CLI-7.** `--out PATH` — full output path override. When given, it takes
precedence over `--dir` and the default filename, and overwriting the target
is permitted (CLI-11).

**CLI-8.** When `--name` is omitted, ctxpack MUST derive a snake_case name
deterministically from the task and anchor (e.g. task "Implement billing
upgrade" + anchor `accounts#upgrade` →
`implement_billing_upgrade_accounts_upgrade`). With no `--task`, the name
derives from the anchor alone. **[derivation from anchor-only fixed by spec]**

**CLI-8a.** Derivation rules **[fixed by spec]**: downcase; replace each run
of non-`[a-z0-9]` characters with a single underscore; strip leading/trailing
underscores; append the sanitized anchor (`admin/accounts#upgrade` →
`admin_accounts_upgrade`); cap the whole derived name at 80 characters while
preserving the anchor as the suffix. When the combined task + anchor exceeds
the cap, ctxpack truncates the task prefix to the available space and strips
any trailing underscore from that prefix. If the sanitized anchor alone is
longer than 80 characters, its trailing 80 characters are used so the action
suffix survives.

**CLI-8b.** An explicit `--name` MUST match `^[A-Za-z0-9_]+$`; anything else
(spaces, punctuation) fails with a clear message. CamelCase input is
normalized with the standard Rails underscore transformation
(`BillingUpgrade` → `billing_upgrade`) — that is the canonical Rails
generator behavior (`rails g model BillingAccount` and `billing_account`
produce the same file), not a surprising rewrite. **[fixed by spec]**

**CLI-9.** `--force` — permit overwriting an existing artifact at the computed
default path.

**CLI-10.** `--manifest` — additionally write a JSON manifest next to the
Markdown artifact, same basename with `.json` extension (see MAN-1).

**CLI-10a.** If `--out` and `--manifest` would resolve the Markdown artifact
and manifest to the same path, including paths that differ only by extension
case, the command MUST fail before compiling or writing either artifact and
tell the user to choose a non-JSON Markdown output path. **[fixed by spec]**

## Output behavior

**CLI-11.** ctxpack MUST NOT silently overwrite an existing artifact. If the
computed output path exists, the command fails with a clear message unless
`--force` was passed or the path came from an explicit `--out`.

**CLI-12.** Default output path:

```text
<dir>/<YYYYMMDDHHMMSS>_<name>.md
```

The timestamp is Rails-migration style in UTC (matching Rails migration
generators) **[fixed by spec]**, exists for chronological ordering and
collision resistance, and is a storage concern only — it MUST NOT appear
inside packet content (DET-5).

**CLI-13.** The default directory `.ctxpack/` is intended to be gitignored.
Committing a packet is opt-in, never a side effect; `docs/ctxpack/` is the
standard committed location, reached via `--dir docs/ctxpack`.

**CLI-14.** When ctxpack creates `.ctxpack/` for the first time, it MUST print
a one-line reminder to stderr to add the directory to `.gitignore`. It MUST NOT
prompt interactively and MUST NOT edit `.gitignore` itself. **[stderr fixed by
spec so success stdout remains composable]**

**CLI-15.** On success, the command prints the saved artifact path (and the
manifest path when `--manifest` was given). Artifact paths are printed one per
line to stdout, relative to the invocation directory, so each line resolves
directly from the directory where ctxpack was run. No reminder or other status
text appears on success stdout. **[path base and stdout contract fixed by spec]**

## Failure behavior

**CLI-16.** When the anchor cannot be resolved under v0 rules, the command
MUST fail with a nonzero exit status and a message that names the specific
unsupported case (file not found, no direct `def <action>`, etc. — see
ANCH-6/ANCH-7). It MUST NOT fall back to guessing, searching, or partial
packets.

**CLI-17.** Failure messages SHOULD point the user at Rails-native discovery
(`bin/rails routes -g …`, `bin/rails routes -c …`) rather than offering any
ctxpack-side route browsing, which is a v0 non-goal. When the supplied anchor
contains shell-safe controller/action tokens, the hint SHOULD substitute those
values into copy-pasteable commands. Malformed or shell-sensitive anchors MUST
use generic `ACTION` / `CONTROLLER` placeholders. **[fixed by spec]**

## Explicit non-features

**CLI-18.** v0 MUST NOT expose flags for the internal packet limits (max
files, snippet lines, etc. — see LIM-1). Limits become flags only if fixture
evals or real usage show the defaults are wrong.

**CLI-19.** No `ctxpack routes` command, no interactive pickers, no
`--helper` flag in v0. Route-helper input is a possible later extension only.
