# Rubydex constant resolution depends on the working directory

## Problem

An offline probe (`eval/tier3-rubydex/four_column_coverage.rb`) used
`Rubydex::Graph` to resolve the constants a Rails controller references, to see
which sibling files a semantic resolver recalls over path convention. Run from
the ctxpack repo root with `graph.workspace_path` set to the pinned app
checkout, Rubydex left the interesting refs (`User`, `Current`, sibling models)
**unresolved** — only superclasses (`ApplicationController`) resolved. The same
code run from *inside* the app checkout resolved all of them.

## Context

`Rubydex::Graph.new; g.workspace_path = <app>; g.index_workspace; g.resolve`.
The gem's own `exe/rdx` calls `graph.load_config` then `index_workspace` with no
explicit `workspace_path`, i.e. it relies on the process cwd. Setting
`workspace_path` explicitly is **not** sufficient — resolution (require-path /
load-path / autoload inference that maps `User` → `app/models/user.rb`) keys off
the actual current working directory.

## Symptom / fingerprint

`g.constant_references` for a controller file returns mostly
`Rubydex::UnresolvedConstantReference` (only the literal superclass resolves)
when cwd ≠ app root; the same query returns `ResolvedConstantReference`s with
`.declaration.definitions` pointing at real app files when cwd == app root.

## Key insight

Rubydex resolution is cwd-sensitive, independent of `workspace_path`. Any
tool-to-tool driver that indexes an app from a different working directory must
`Dir.chdir(app_root) { index/resolve }`, not just set `workspace_path`.

## Final approach

Wrap the index/resolve in `Dir.chdir(app_template_abs) do … end`. Post-fix,
campfire `autocompletable/users#index` resolved `User` → `app/models/user.rb`
(recall 0.500 → 1.000 on that cell).

## Meta-lesson

The convention-column self-check (reproduce the committed coverage numbers)
proved the *baseline* faithful but could **not** catch this — it only guarded the
unchanged column. New/added columns need their own spot-check against a
hand-verified case (here: the campfire `user.rb` reachability I had confirmed
by hand before writing the brief). A green self-check on the old data is not
proof the new data is right.
