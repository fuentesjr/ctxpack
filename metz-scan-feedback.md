# metz-scan dogfooding log

ctxpack runs [metz-scan](https://github.com/fuentesjr/metz-scan) on its own
`lib/` via `rake metz` — partly for design guidance, partly to dogfood
metz-scan itself. Log every bug, surprise, or UX friction here with enough
detail to turn into a GitHub issue on fuentesjr/metz-scan; when an issue is
filed, record the link on the entry and keep it for the record. The scan is
advisory and never gates ctxpack's build.

Pinned version: **0.4.0**. Install (GitHub Packages needs auth and the
README documents Bundler only):

```sh
gem install metz-scan -v 0.4.0 --clear-sources \
  --source "https://fuentesjr:$(gh auth token)@rubygems.pkg.github.com/fuentesjr" \
  --source "https://rubygems.org"
```

The committed `.rubocop.yml` (`DisabledByDefault` + `Metz: Enabled`) exists
solely to scope the scan to Metz cops — see the first entry below. ctxpack
has no general RuboCop style gate.

Entry format: date + version in the heading; what happened / expected /
workaround; `Status:` open, filed \<url\>, or fixed in \<version\>.

## Candidate issues

### 2026-07-05 (v0.4.0) — default scan runs the entire stock RuboCop suite

On a project with no `.rubocop.yml`, `metz-scan scan lib` reported hundreds
of stock findings — `Style/StringLiterals` on every double-quoted string,
`Layout/LineLength`, all `Metrics/*` — burying the 27 Metz findings.
`scan --help` shows no flag to restrict the cop set.

Expected, per the README's own positioning ("RuboCop is excellent at
enforcing local style and correctness, but design smells…"): Metz-only by
default, with the full suite opt-in (`--all-cops` or similar), or at least
an `--only Metz` passthrough.

Workaround that works: a target-project `.rubocop.yml` with
`AllCops: DisabledByDefault: true` and `Metz: Enabled: true` — metz-scan
respects the scanned project's config (good), and output becomes
Metz-only. But requiring the *scanned* project to carry config to get the
tool's headline behavior is friction.

Status: filed https://github.com/fuentesjr/metz-scan/issues/31

### 2026-07-05 (v0.4.0) — Metz cops duplicate their Metrics ancestors

In full-suite output, `Metz/ClassesTooLong` and `Metrics/ClassLength`
report the identical finding with identical thresholds (`[503/100]` twice
on the same class/line), and `Metz/MethodsTooLong` (max 5) re-reports every
method `Metrics/MethodLength` (max 10) already flagged. Expected: the
plugin's default config disables the shadowed `Metrics` cops so each
finding appears once. Mostly mooted if the scan becomes Metz-only by
default, but worth fixing for users who deliberately run the full suite.

Status: filed https://github.com/fuentesjr/metz-scan/issues/32

## Observations (not issues yet)

- **2026-07-05 (v0.4.0)** — Install docs gap: the README covers Bundler +
  GitHub Packages, but not plain `gem install` (which needs the two-source
  incantation above so dependencies resolve from rubygems.org). Minor.
- **2026-07-05 (v0.4.0)** — Working well: exit codes are correct (1 on
  findings, 0 clean), `--format json|sarif|gh-annotations` are available
  for future CI wiring, and the per-cop "Why it matters" preamble reads
  well in text output.
- **2026-07-05 (v0.4.0)** — ctxpack baseline (Metz-only): 27 findings —
  `ClassesTooLong` on `Ctxpack::Compiler` `[503/100]`, `MethodsTooLong`
  × 24 (the 5-line rule fires on most parser-shaped `case`/traversal
  methods), `MethodsTooManyParameters` × 2 (`[5/4]` on
  `add_controller_evidence` and `add_constant_evidence`). Thresholds are
  per-cop tunable in `.rubocop.yml`; defaults kept for now to gather
  signal on whether the 5-line rule is calibrated for this kind of code.
