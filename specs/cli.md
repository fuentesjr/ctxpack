# Spec: CLI and artifacts

Status: Draft. Source: `design.md` — "Settled v0 direction", "Artifact location
and naming", "Machine-readable manifest".

## Command

**CLI-1.** The primary (and, in v0, only) packet-producing command is the
direct anchor form:

```bash
ctxpack <anchor> [options]
```

The original `ctxpack packet <anchor> [options]` form remains supported for
compatibility.

Non-normative: inside a Rails app the executable is typically reached via
`bundle exec ctxpack` or a binstub (`bundle binstubs ctxpack` → `bin/ctxpack`
next to `bin/rails`). Examples write bare `ctxpack` for brevity.

**CLI-1a.** No arguments, `ctxpack --help`, `ctxpack -h`, and `-h` / `--help`
in either packet-producing form and any position MUST print full packet help to
stdout and return success without discovering an application root, compiling a
packet, writing files, or terminating the caller through `SystemExit`. Help
MUST describe both command forms, every option, the `.ctxpack/` default, and
examples of the direct and compatibility forms. It MUST also be sufficient for
offline first use: name application-root discovery; distinguish the path bases
for task input, output resolution, and displayed success paths; show task-file
and JSON-stdout pipelines; and state the `--stdout` and `--out` conflicts.
**[fixed by spec]**

**CLI-1b.** `ctxpack --version` and `ctxpack -v`, when used as the sole
top-level argument, MUST print `ctxpack VERSION` to stdout and return success
without discovering an application root. **[fixed by spec]**

**CLI-1c.** `--task`, `--dir`, `--out`, and `--force` MUST also accept `-t`,
`-d`, `-o`, and `-f`, respectively. `--task-file`, `--stdout`, `--name`, and
`--manifest` remain long-only.
**[fixed by spec]**

**CLI-2.** `<anchor>` is a positional argument in exact `controller#action`
form (see `packet-compilation.md`, ANCH-1). Route strings
(`POST /accounts/:id/upgrade`) and route helpers (`upgrade_account`) MUST NOT
be accepted in v0.
They receive the syntactic guidance specified by CLI-17c, never resolution.

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

**CLI-4.** `-t TASK`, `--task TASK` — free-text description of the task the packet is
for. Optional. **[fixed by spec]** When omitted, the packet's Task section
records that no task was provided (see FMT-2) and name derivation uses the
anchor alone (CLI-8).

**CLI-4a.** `--task-file PATH` reads the task from a file resolved relative to
the invocation directory; `-` reads the CLI's injected stdin. It removes
exactly one final LF or CRLF and preserves all other whitespace. The resolved
text supplies both the packet task and derived artifact name. `--task` and
`--task-file` conflict in either order, including an explicitly empty task,
and MUST fail before root discovery, input reads, compilation, or writes.
Missing, unreadable, or directory inputs fail concisely through injected
stderr without usage or a backtrace. A failure while reading injected stdin
uses stdin-specific wording rather than describing `-` as a file path.
**[fixed by spec]**

**CLI-5.** `--name NAME` — artifact name, snake_case or CamelCase (normalized
per CLI-8b). Optional escape hatch for callers that need a curated stem; the
derived name is the normal workflow. Explicit names should carry enough context
to avoid vague artifacts like `upgrade.md`.

**CLI-6.** `-d DIR`, `--dir DIR` — output directory override. Default is `.ctxpack/`.
`docs/ctxpack/` is the canonical location when a packet is deliberately
committed (see CLI-13).

**CLI-7.** `-o PATH`, `--out PATH` — full output path override. It replaces the
default directory and timestamped filename. An explicit `--out` MUST be rejected
when combined with an explicitly supplied `--dir` or `--name`; the implicit
`.ctxpack/` default does not conflict. `--out` does not permit overwriting
(CLI-11), and `--out` with `--force` is valid. **[fixed by spec]**

**CLI-8.** When `--name` is omitted, ctxpack MUST derive a snake_case name
deterministically from the task and anchor (e.g. task "Implement billing
upgrade" + anchor `accounts#upgrade` →
`implement_billing_upgrade_accounts_upgrade`). With neither `--task` nor
`--task-file`, the name derives from the anchor alone. **[derivation from
anchor-only fixed by spec]**

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

**CLI-9.** `-f`, `--force` — permit overwriting an existing Markdown artifact
or sibling manifest at any computed or explicit output path.

**CLI-10.** `--manifest` — additionally write a JSON manifest next to the
Markdown artifact, same basename with `.json` extension (see MAN-1).

**CLI-10a.** If `--out` and `--manifest` would resolve the Markdown artifact
and manifest to the same path, including paths that differ only by extension
case, the command MUST fail before compiling or writing either artifact and
tell the user to choose a non-JSON Markdown output path. **[fixed by spec]**

**CLI-10b.** Bare `--stdout` and explicit `--stdout=markdown` emit exactly the
fully rendered Markdown through the injected stdout stream. `--stdout=json`
emits exactly the MAN-2 JSON returned by `Ctxpack.render_manifest(packet)`.
Other format values are rejected as option errors. Every stdout form creates
or writes nothing and prints no saved path or reminder. Every form conflicts
with explicitly supplied `--dir`, `--out`, `--name`, `--force`, and
`--manifest`, but not with the implicit default directory or either task input.
Conflicts fail before root discovery, task reads, compilation, or mutation.
Compilation and rendering complete before stdout is written, so a compiler or
renderer failure leaves stdout empty. Help still wins in any position.
**[fixed by spec]**

## Output behavior

**CLI-11.** ctxpack MUST NOT silently overwrite an existing artifact. If the
Markdown path or sibling manifest path exists, the command fails with a clear
message unless `--force` was passed. An explicit `--out` never grants overwrite
permission. The error path follows CLI-15 and is relative to the invocation
directory. **[fixed by spec]**

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

**CLI-14.** The implicit/default `.ctxpack/` output is eligible for a one-line
gitignore reminder only when this invocation creates that directory. Explicit
destinations supplied with `--dir` or `--out`, and an existing `.ctxpack/`, are
not eligible. `--name` and `--manifest` still use the implicit/default directory
and remain eligible. The CLI MUST NOT prompt interactively or edit ignore files.
**[stderr fixed by spec so success stdout remains composable]**

**CLI-14a.** For an eligible reminder, ctxpack MUST ask Git itself whether
`.ctxpack/` is ignored, honoring repository, `.git/info/exclude`, and configured
global rules (`git -C APP_ROOT check-ignore --quiet --no-index -- .ctxpack/`).
It warns only when Git returns 1 (unignored), and suppresses the reminder for 0,
all other statuses, non-Git apps, operational failures, or unavailable Git.
The command uses argv form and `--`; ignore files are never parsed manually.
**[fixed by spec]**

**CLI-15.** On success, the command prints the saved artifact path (and the
manifest path when `--manifest` was given). Artifact paths are printed one per
line to stdout, relative to the invocation directory, so each line resolves
directly from the directory where ctxpack was run. No reminder or other status
text appears on success stdout. **[path base and stdout contract fixed by spec]**
CLI-10b is the rendered-content exception to saved-path output.

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

**CLI-17a.** Filesystem failures while creating an output directory or writing
an artifact MUST return status 1 and write one concise `ctxpack:` error through
the injected stderr stream. They MUST NOT print usage or expose a Ruby
backtrace. Paths in these errors follow CLI-15. If an existing Markdown or
manifest destination is not a regular file, the command MUST fail before
compilation or writing either artifact, even with `--force`. **[fixed by spec]**

**CLI-17b.** An unknown command MUST fail with concise usage. The common typo
`ctxpack packets` MUST additionally suggest `ctxpack packet`; unrelated unknown
commands MUST NOT receive that suggestion. **[fixed by spec]**

**CLI-17c.** Before root discovery, ctxpack MUST syntactically reject common
Rails-shaped non-anchor inputs with tailored, Rails-native recovery guidance:
snake_case route helpers containing `_`; `AccountsController#upgrade`-style
class references; quoted or split HTTP route strings; and slash-separated
anchors whose final `/` should be `#`. Direct and compatibility forms SHOULD
receive the guidance where their syntax is unambiguous. Safe helper/action
tokens may appear in copy-pasteable `bin/rails routes -g` commands; unsafe
tokens use generic placeholders. The CLI MUST NOT browse, resolve, or accept
these forms. Unrelated commands, `routes`, shell-sensitive inputs, and the
targeted `packets` behavior remain unchanged. **[fixed by spec]**

## Explicit non-features

**CLI-18.** v0 MUST NOT expose flags for the internal packet limits (max
files, snippet lines, etc. — see LIM-1). Limits become flags only if fixture
evals or real usage show the defaults are wrong.

**CLI-19.** No `ctxpack routes` command, no interactive pickers, no
`--helper` flag in v0. Tailored diagnostics do not resolve routes or turn route
helpers into accepted input; route-helper resolution remains a possible later
extension only.
