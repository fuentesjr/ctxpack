# Implementation Notes

## Scope

- Implemented only packet compilation: anchor -> controller/action/callbacks -> constants -> tests -> limits -> internal packet object.
- Did not implement root discovery, CLI, artifact naming, Markdown rendering, JSON manifest writing, or output paths.
- Fixture app lives at `test/fixtures/apps/minitest_basic/` and is static Rails-shaped code only; fixture app tests are intentionally not runnable and are excluded from the Rake task.
- Fixture app test files are plain Rails-shaped Minitest files. They intentionally do not include local framework shims or repo-level `test_helper` requires; ctxpack uses path rules only and never reads their content.

## Decisions

- Public API is `Ctxpack.compile(app_root:, anchor:, task: nil, constant_resolver: nil)`.
- The packet object keeps ordered `FileEntry` objects with per-file `EvidenceItem` records. `Packet#to_h` exposes a MAN-2-shaped hash by flattening evidence items into file records.
- Convention-only constant matches do not invent an FMT-7 uncertainty code. They are kept as `packet.convention_constant_matches` for the formatter's FMT-8 prose.
- Outside git, the packet repo stamp uses `commit: nil` and `dirty: false`, matching MAN-2. Rendering the fixed string from FMT-11 is left to packet-format.
- Repo stamping uses `Open3.capture2` with stderr routed away from stdout so git warnings cannot contaminate the SHA or dirty-state checks.
- Literal callback applicability follows amended CB-2: literal `only:` / `except:` arrays and single symbol/string literals are resolved (the spec originally admitted arrays only; it was amended after review because `only: :upgrade` is the dominant Rails style). Other keywords, computed names, splats, and any non-literal filters produce `dynamic_callback_args`.
- Dynamic callback uncertainties fall back to the declaration kind as the subject when no literal callback name exists, so notes are deterministic and non-empty.
- `LIMITS[:max_total_files]` is enforced by priority-ordered truncation. With views, the category ceilings can sum to 1 controller + 2 views + 4 constants + 2 tests = 9, so `add_test_candidates` caps included tests against the remaining total-file slots and records dropped tests as omitted candidates.

## Spec / Design Reconciliation

- No direct contradictions found between `specs/packet-compilation.md` and `design.md`.
- The spec's TEST-1 contiguous action-token rule is treated as a refinement of design.md's looser integration-test wording.
- MAN-2 shows a simple single-reason file example, while FMT-4 allows multiple evidence blocks per file. The internal object uses multiple evidence items per file so the formatter can render FMT-4; `to_h` remains manifest-shaped.

## Requirement Coverage

- ANCH-1: `AnchorResolutionTest#test_anch_1_2_accepts_namespaced_anchor_and_maps_by_convention`, `#test_anch_1_rejects_non_snake_case_anchor_tokens`
- ANCH-2: `AnchorResolutionTest#test_anch_1_2_accepts_namespaced_anchor_and_maps_by_convention`
- ANCH-3: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`, `AnchorResolutionTest#test_anch_3_visibility_is_ignored_for_direct_action_methods`, `AnchorResolutionTest#test_anch_3_inline_visibility_modifier_action_is_a_direct_action_method`
- ANCH-4: `AnchorResolutionTest#test_anch_4_6_missing_controller_file_fails_exactly`
- ANCH-5: `AnchorResolutionTest#test_anch_5_7_missing_direct_action_fails_without_guessing`
- ANCH-6: `AnchorResolutionTest#test_anch_4_6_missing_controller_file_fails_exactly`
- ANCH-7: `AnchorResolutionTest#test_anch_5_7_missing_direct_action_fails_without_guessing`
- PARSE-1: Not directly unit-tested; verified by dependency/code inspection (`prism` is the only parser/runtime dependency, no Rubydex usage).
- PARSE-2: `ConstantsTest#test_parse_2_constant_resolution_uses_swappable_resolver_interface`
- CB-1: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`
- CB-1a: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`, `CallbacksTest#test_cb_1_cb_2_cb_2a_cb_4_callback_applicability_and_uncertainty`
- CB-2: `CallbacksTest#test_cb_1_cb_2_cb_2a_cb_4_callback_applicability_and_uncertainty`
- CB-2a: `CallbacksTest#test_cb_1_cb_2_cb_2a_cb_4_callback_applicability_and_uncertainty`
- CB-3: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`
- CB-4: `CallbacksTest#test_cb_1_cb_2_cb_2a_cb_4_callback_applicability_and_uncertainty`
- CONST-1: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`, `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`
- CONST-2: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`
- CONST-2a: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`, `#test_const_2a_root_qualified_references_skip_lexical_walk`
- CONST-2b: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`
- CONST-2c: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`
- CONST-3: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`
- CONST-4: `ConstantsTest#test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order`, `LimitsTest#test_const_4_lim_1_lim_2_truncates_constant_files_in_first_reference_order`
- TEST-1: `TestCandidatesTest#test_test_1_rule_2_requires_contiguous_action_tokens_and_excludes_negative_order`, `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`
- TEST-2: `TestCandidatesTest#test_test_2_lim_2_truncates_test_candidates_and_records_omissions`
- TEST-3: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`, `TestCandidatesTest#test_test_1_rule_2_requires_contiguous_action_tokens_and_excludes_negative_order`
- TEST-4: `TestCandidatesTest#test_test_4_5_path_rules_only_and_explicit_no_candidates_state`
- TEST-5: `TestCandidatesTest#test_test_4_5_path_rules_only_and_explicit_no_candidates_state`
- TEST-6: `CompileBasicTest#test_anch_cb_const_test_fmt_man_happy_path_packet_object`
- LIM-1: `LimitsTest#test_lim_1_v0_limits_are_internal_constants`, `PacketObjectTest#test_man_2_det_2_packet_object_exposes_manifest_shape_and_file_order`, `ViewResolutionTest#test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run`
- LIM-2: `LimitsTest#test_const_4_lim_1_lim_2_truncates_constant_files_in_first_reference_order`, `TestCandidatesTest#test_test_2_lim_2_truncates_test_candidates_and_records_omissions`, `LimitsTest#test_lim_4_truncates_long_action_and_names_dropped_callback_snippets`, `ViewResolutionTest#test_view_5_truncates_view_variants_and_records_omitted_candidate`, `ViewResolutionTest#test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run`
- LIM-3: Not directly unit-tested; it is rationale for fixed limit values, covered by keeping limits internal and documenting this scope boundary.
- LIM-4: `LimitsTest#test_lim_4_truncates_long_action_and_names_dropped_callback_snippets`

Cross-spec packet object coverage:

- FMT-6/FMT-7 code strings are asserted in compile, callback, constants, and test-candidate tests.
- FMT-10..FMT-12 repo stamp behavior is covered by `RepoStampTest`.
- MAN-2-shaped packet data is covered by `PacketObjectTest`.

## Verification

- `bundle exec rake test` passes: 20 runs, 87 assertions, 0 failures, 0 errors, 0 skips.
- The Rake task excludes `test/fixtures/` because those files are static fixture inputs, not ctxpack's own test suite. Generic validation tools that auto-load every changed `*_test.rb` need an equivalent fixture-directory exclusion; the strategic validator used here has no path-exclude option and reports those fixture files as load failures once the shims are removed, while its red-green, lint, and pending-comment gates pass with zero warnings.

## ANCH amendment mini-pass (2026-07-05)

Implemented in-session (deliberate deviation from the Codex delegation loop;
see tracker decision log). Red-green: 5 new tests written first, all failing
for the right reasons, then the smallest compiler change.

- ANCH-1 grammar: anchor regex action part is now `_?[a-z][a-z0-9_]*[?!]?` —
  one optional leading underscore, one optional trailing `?`/`!`, matching
  the two shapes the Tier 0 spike found in real route tables.
- Class-by-file matching (ANCH-2/3): `find_class` (exact camelized-name
  lookup) replaced by `find_controller_class` — first class in source order
  whose fully-qualified name matches the anchor path segment-by-segment,
  case- and underscore-insensitively, with the final segment's `Controller`
  suffix dropped. Root-qualified class names (`::Foo::BarController`) are
  normalized before comparison. Segment-count equality is required, so a
  flat class in a namespaced controller file does not match (preserves
  ANCH-4 exactness). `camelize`/`controller_class_name` deleted;
  `entrypoint.controller` and the constant resolver's lexical namespace now
  come from the class actually found in the file.
- New failure mode: file exists but no class matches → `Ctxpack::Error`
  "no controller class matching <path> was defined in <file>". The Tier 0
  classifier gained a case mapping this message to `other` with detail.
- TEST-1 ripple: integration-match action tokens strip a trailing `?`/`!`
  and drop the empty token from a leading `_`; otherwise the extended
  grammar could never match rule 2 (filenames cannot carry `?`). Spec
  amended with a one-sentence note.
- New coverage: ANCH-1 — `#test_anch_1_accepts_action_with_trailing_question_mark`,
  `#test_anch_1_accepts_action_with_leading_underscore`; ANCH-2 —
  `#test_anch_2_matches_acronym_class_defined_in_resolved_file`; ANCH-2/4 —
  `#test_anch_2_4_file_without_matching_controller_class_fails_exactly`;
  TEST-1 — `TestCandidatesTest#test_test_1_rule_2_normalizes_action_tokens_from_extended_grammar`.
  New fixtures: `ai_text_tools_controller.rb` (acronym class),
  `oddities_controller.rb` (odd action names), `mismatched_controller.rb`
  (non-matching class), two `oddities_*` integration test stubs.
- Verification: `bundle exec rake test` — 25 runs, 101 assertions, 0
  failures, 0 errors, 0 skips.

## Pass 2: packet-format

Implemented packet-format rendering only: Markdown and JSON manifest strings over
the internal packet object. No CLI code, file writing, artifact naming, output
paths, root discovery, flags, or dependencies were added.

### Decisions

- Public API is `Ctxpack.render_markdown(packet)` and
  `Ctxpack.render_manifest(packet)`.
- `Ctxpack::MarkdownRenderer` renders the Markdown packet from packet metadata
  and reads snippet text from `packet.app_root` plus each evidence item's
  1-based inclusive `snippet_ranges`. `packet.app_root` is read-only packet
  metadata, excluded from `Packet#to_h`.
- `Ctxpack::ManifestRenderer` builds directly on `Packet#to_h` and uses Ruby
  stdlib `JSON.pretty_generate`, preserving the insertion order already present
  in the MAN-2 hash.
- Markdown prose is centralized in renderer templates. Evidence items still
  provide the reason code, subject, snippet ranges, and test-path match reason;
  the renderer turns those fixed fields into FMT prose.
- The retrieve-more section is generated only from uncertainty codes,
  omission categories, and the explicit no-test-candidates state. Multiple
  items with the same code/category collapse to one templated suggestion with
  deterministic subject ordering.
- Known coupling: `MarkdownRenderer#test_candidate_why` matches the compiler's
  stored `why` strings exactly and falls back silently if they drift.
- The design.md example shows the short SHA as inline code, while
  `packet-format.md` and this pass's task fixed the stamp line as plain text.
  This was treated as example formatting rather than a blocking
  spec-vs-design conflict.

### Requirement Coverage

| Requirement | Coverage |
|---|---|
| FMT-1 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture` |
| FMT-2 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`, `#test_fmt_2_retrieve_more_uses_one_templated_suggestion_per_uncertainty_code`, `#test_fmt_2_11_test_5_renders_nil_task_unknown_repo_and_no_test_candidates`, `#test_fmt_2_retrieve_more_is_omitted_when_no_uncertainty_or_omission_codes_are_present` |
| FMT-3 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture` |
| FMT-4 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture` |
| FMT-5 | `PacketFormatTest#test_fmt_5_truncated_snippet_marker_is_inside_the_ruby_fence`, `#test_fmt_5_truncated_snippet_marker_uses_current_compiler_limit` |
| FMT-6 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`; existing compile tests assert the registered reason-code strings. |
| FMT-7 | `PacketFormatTest#test_fmt_2_retrieve_more_uses_one_templated_suggestion_per_uncertainty_code`; existing compile tests assert the registered uncertainty-code strings. |
| FMT-8 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`, `#test_fmt_2_retrieve_more_uses_one_templated_suggestion_per_uncertainty_code` |
| FMT-9 | `PacketFormatTest#test_fmt_9_omitted_candidates_names_truncated_constants_and_tests`, `#test_fmt_5_truncated_snippet_marker_is_inside_the_ruby_fence` |
| FMT-10 | Existing `RepoStampTest#test_fmt_10_11_12_repo_stamp_uses_git_discovery_and_dirty_status`; renderer consumes the packet stamp without recomputing it. |
| FMT-11 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`, `#test_fmt_2_11_test_5_renders_nil_task_unknown_repo_and_no_test_candidates`, existing `RepoStampTest#test_fmt_11_man_2_repo_stamp_is_nil_outside_git` |
| FMT-12 | Existing `RepoStampTest#test_fmt_10_11_12_repo_stamp_uses_git_discovery_and_dirty_status`; renderer consumes the packet dirty flag without recomputing it. |
| DET-1 | `PacketFormatTest#test_man_2_3_render_manifest_uses_packet_hash_with_stable_key_order`; Markdown determinism is covered by templated rendering tests and by preserving packet order. |
| DET-2 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture` |
| DET-3 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`, `#test_fmt_2_retrieve_more_uses_one_templated_suggestion_per_uncertainty_code` |
| DET-4 | Covered by construction: renderers are pure over the packet plus stored snippet ranges and do not invoke retrieval, agents, or models. |
| DET-5 | `PacketFormatTest#test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture`; no renderer template includes timestamps. |
| MAN-1 | `PacketFormatTest#test_man_2_3_render_manifest_uses_packet_hash_with_stable_key_order`; CLI `--manifest` and sibling file writing remain pass 3 scope. |
| MAN-2 | `PacketFormatTest#test_man_2_3_render_manifest_uses_packet_hash_with_stable_key_order`, `#test_man_2_render_manifest_uses_null_commit_outside_git`; existing `PacketObjectTest#test_man_2_det_2_packet_object_exposes_manifest_shape_and_file_order` |
| MAN-3 | `PacketFormatTest#test_man_2_3_render_manifest_uses_packet_hash_with_stable_key_order` |

### Verification

- Red/green proof: first packet-format test failed with
  `NoMethodError: undefined method 'render_markdown'`; after adding the
  renderer APIs it passed. The retrieve-more grouping test then failed with
  four dynamic-callback suggestions and passed after grouping by code.
- Review-defect red/green proof: anchor-label/task-sentence expectations and
  the compiler-limit truncation-marker test failed against the reviewed code,
  then passed after relabeling the anchor section and deriving the marker count
  from `Ctxpack::Compiler::LIMITS[:max_snippet_lines_per_file]`.
- `bundle exec rake test` passes: 34 runs, 193 assertions, 0 failures, 0
  errors, 0 skips.
- No new runtime or development dependencies were added; manifest rendering uses
  stdlib `json`.
- No spec-vs-design conflict blocked implementation.

## Tier 0 spike (2026-07-05)

- Driver lives in `eval/tier0/` (`extract_routes.rb`, `classify_anchors.rb`); results and rationale in `eval/tier0/RESULTS.md`. Not part of the gem or CI.
- Key extraction decisions: stubbed `routes.rb` eval with the app's own pinned actionpack (no app boot, per eval-plan's documented fallback); routes drawn as production env; unique-per-call stub stringification plus an `add_route` name-sanitizing shim, because stub-derived route names otherwise collide or fail validation; `SpikeStub#+` must return a real String — `Mapper#map_match` silently drops paths that are neither String nor Symbol (cost one debugging round on Zammad, 147→596 pairs).
- Verification: 45 randomly sampled "resolved" anchors independently re-checked by grep (0 false positives); every inherited/concern label carries the file that satisfied the chase; `rake test` still 20 runs / 0 failures.
- Scope boundary: spike classifies anchors only; no lib/ changes. The two candidate ANCH amendments it surfaced are tracked in PROJECT_TRACKER next steps, not implemented.

## Pass 3: CLI and artifacts

Implemented only the v0 `ctxpack packet` command and artifact writing layer.
No compilation, packet object, Markdown rendering, or manifest rendering behavior
was changed in this pass.

### Decisions

- Public CLI seam is `Ctxpack::CLI#run(argv)`, returning an integer exit
  status and accepting injectable `stdout`, `stderr`, `cwd`, and `clock` for
  in-process tests.
- `exe/ctxpack` is intentionally thin: it requires `ctxpack/cli`, delegates to
  `Ctxpack::CLI`, and exits with the returned status.
- Root discovery walks upward from `cwd` to the nearest ancestor containing
  `config/application.rb`. Relative `--dir` and `--out` values are resolved
  against that root, and printed success paths are root-relative when the output
  lives under the root.
- Default artifact names use the spec's storage-only UTC timestamp plus a
  deterministic derived name. Explicit names are validated with
  `^[A-Za-z0-9_]+$` and normalized with a local Rails-style `underscore`
  implementation instead of adding ActiveSupport.
- Overwrite checks run before compilation. Computed Markdown and manifest paths
  fail if either target already exists unless `--force` is passed. Explicit
  `--out` permits overwrite without `--force`, per CLI-7/CLI-11.
- `.ctxpack/` creation prints a one-line gitignore reminder only when this CLI
  invocation creates that root-level directory. The CLI never prompts and never
  edits `.gitignore`.
- `Ctxpack::Error` is rescued at the CLI boundary, preserving the compiler's
  specific failure message and adding Rails-native `bin/rails routes -g` /
  `-c` guidance.

### Scope Boundaries

- No `ctxpack routes` command, route helper mode, route-string parsing,
  interactive picker, or internal limit flags were added.
- CLI tests build temporary Rails-shaped app roots by copying
  `test/fixtures/apps/minitest_basic/` and adding `config/application.rb` in
  the tempdir; the shared fixture tree itself remains unchanged.
- The gemspec now ships `exe/ctxpack` via `spec.bindir = "exe"` and
  `spec.executables = ["ctxpack"]`.

### Requirement Coverage

- CLI-1/CLI-2/CLI-18/CLI-19:
  `CLITest#test_packet_rejects_route_helper_input_and_routes_command`.
- CLI-3/CLI-12/DET-5:
  `CLITest#test_packet_discovers_root_from_nested_cwd_and_writes_default_artifact`.
- CLI-4/CLI-8/CLI-8a:
  `CLITest#test_packet_discovers_root_from_nested_cwd_and_writes_default_artifact`,
  `#test_packet_derives_name_from_namespaced_anchor_when_task_is_omitted`,
  `#test_packet_caps_derived_name_at_80_characters`.
- CLI-5/CLI-8b:
  `CLITest#test_packet_normalizes_explicit_camel_case_name`,
  `#test_packet_rejects_invalid_explicit_name`.
- CLI-6/CLI-10/CLI-15/MAN-1:
  `CLITest#test_packet_writes_manifest_next_to_markdown_and_prints_both_paths`.
- CLI-7/CLI-9/CLI-11:
  `CLITest#test_packet_refuses_to_overwrite_default_artifact_unless_forced`,
  `#test_packet_out_path_overwrites_without_force_and_takes_precedence_over_dir`.
- CLI-13/CLI-14:
  `CLITest#test_packet_prints_gitignore_reminder_only_when_creating_default_ctxpack_dir`,
  `#test_packet_prints_gitignore_reminder_when_ctxpack_dir_is_created_as_parent`.
- CLI-16/CLI-17:
  `CLITest#test_packet_maps_compilation_errors_to_nonzero_status_and_routes_hint`.

### Verification

- Red/green proof: first CLI test failed with
  `LoadError: cannot load such file -- ctxpack/cli`; after adding
  `Ctxpack::CLI`, the test passed.
- Pass 3 review red/green proof:
  `CLITest#test_packet_prints_gitignore_reminder_when_ctxpack_dir_is_created_as_parent`
  first failed because stdout omitted the `.ctxpack/` gitignore reminder; after
  changing directory creation to compare `.ctxpack/` existence before and after
  `mkdir_p`, it passed.
- Focused CLI suite: `bundle exec ruby -Itest test/ctxpack/cli_test.rb` passes:
  13 runs, 81 assertions, 0 failures, 0 errors, 0 skips.
- Full suite: `bundle exec rake test` passes: 47 runs, 274 assertions, 0
  failures, 0 errors, 0 skips.
- Strategic Software Design validator:
  `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb --type feature --task-file /private/tmp/ctxpack_pass3_task_statement.txt`
  passed `slice_tests`, `red_green`, and `todo`; `lint` was skipped.
  Warnings:
  - `rubocop run errored - Lint/Security gate skipped: Error: unrecognized cop or department Metz found in .rubocop.yml`
  - `head metrics unavailable (rubocop run failed); deltas omitted`
- Pass 3 review validator rerun: the repository `.git` directory is read-only
  in this sandbox, so the validator was run against a `/private/tmp` copy of
  the working tree with `--type bugfix`; it passed `slice_tests`,
  `red_green`, and `todo`, with the same RuboCop/metrics warnings above.
- The validator marked design review as required because 5 files changed, the
  diff exceeded 50 changed lines, and `lib/ctxpack/cli.rb` adds a public
  interface. The available sub-agent tool policy in this session forbids
  spawning agents unless the user explicitly asks for delegation, so the
  clean-context design review was not run.

## Pass 4: Tier 1 fixture evals

Implemented only fixture eval data, a Minitest runner, CI wiring, and these
notes. No compiler, renderer, or CLI behavior was changed.

### Decisions

- Eval case files live in `test/fixtures/evals/*.yml`. This keeps case data
  separate from Rails-shaped app inputs under `test/fixtures/apps/` while still
  letting `test/ctxpack/**/*_test.rb` load the runner without loading fixture
  app `*_test.rb` files.
- The initial Tier 1 case is exactly the EVAL-4 `accounts_upgrade` YAML case.
  No optional cases were added in this pass; the runner is ready to grow by
  adding more YAML files.
- `FixtureEvalsTest` globs case files and defines two tests per case: packet
  expectation checks and CLI determinism. It raises during test loading if the
  glob finds no YAML cases, so a path drift cannot silently remove Tier 1 from
  CI. Case assertions target the internal packet object, not Markdown prose.
- Packet checks cover the expected entrypoint file/action, required included
  files and reason codes, excluded paths, expected test commands, per-case
  `max_files`, and the LIM-1 file/test/snippet limits from
  `Ctxpack::Compiler::LIMITS`.
- The determinism check drives `Ctxpack::CLI#run` in-process twice with a fixed
  `--out` path plus `--manifest`, then compares SHA-256 hashes of both the
  written Markdown and sibling JSON manifest. Because the shared fixture tree
  has no `config/application.rb` marker, the CLI check copies the fixture tree
  into a temporary app root and adds only the marker required for CLI root
  discovery. This is per-run setup, not recorded state; the packet expectation
  checks still compile directly from the shared fixture tree in the working
  tree.
- CI lives in `.github/workflows/ci.yml`, runs on push and pull request, pins
  Ruby 3.2 to exercise the gemspec's declared floor, and runs
  `bundle exec rake test`. `ruby/setup-ruby`'s Bundler cache performs bundle
  installation, so there is no separate `bundle install` step. Tier 1 is
  covered through the existing Rake test pattern; no Tier 0 or Tier 2 workflow
  step was added.
- The workflow installs `metz-scan` pinned to 0.4.0 and runs
  `bundle exec rake metz` in a `continue-on-error` step, preserving the Rake
  task's advisory role.

### Verification

- Focused eval runner: `bundle exec ruby -Itest test/ctxpack/fixture_evals_test.rb`
  passes: 2 runs, 37 assertions, 0 failures, 0 errors, 0 skips.
- Full suite: `bundle exec rake test` passes: 49 runs, 311 assertions, 0
  failures, 0 errors, 0 skips.

## Tier 2 harness (2026-07-05)

Not a spec pass — built in-session (the Codex delegation loop is reserved for
spec passes; PROJECT_TRACKER "Next steps"). Executes the frozen
`eval/tier2/PREREGISTRATION.md`; this section records harness mechanics only.

### Decisions

- Single stdlib-only script `eval/tier2/harness.rb` with `setup` / `run [N]` /
  `status` subcommands. `runs.jsonl` is the resume key: tuples with
  `status: "complete"` are skipped, so batches across usage windows are
  `run N` invocations of the same script.
- Work area `tmp/tier2/` (gitignored; `tmp/` added to `.gitignore`): pinned
  Redmine template (shallow fetch of the exact SHA, branch `pinned`), sterile
  `CLAUDE_CONFIG_DIR`, per-session workspaces, scoring logs. Committed
  artifacts: `packets/` (+ `packets.json` meta with ctxpack SHA + SHA-256s),
  `transcripts/`, `diffs/`, `runs.jsonl`, `tasks/task2_failing_output.txt`.
- Workspaces are `git clone --local` of the template plus copied untracked
  prep (`config/database.yml`, `Gemfile.lock`, `db/redmine_test.sqlite3` —
  all Redmine-gitignored). Task 2 workspaces commit the seed patch on top.
  Bundler gems live in the shared mise Ruby (4.0.1), so clones are cheap.
- Final diff is captured as `git add -A` + `git diff --cached --binary`
  (includes files the agent created); the same staged state yields
  `--name-only` for the metric definitions. Workspaces are deleted after
  scoring; the patch and transcript are the durable artifacts.
- Session status mapping (frozen rules → mechanics): watchdog kill at 30 min
  → `timeout` (metrics kept, `task_success` false); non-zero exit or missing/
  non-`success` result event → `aborted` (metrics discarded, tuple re-run;
  the run loop stops on abort since the usage window is likely exhausted);
  otherwise `complete`. Claude stderr goes to `tmp/tier2/stderr/` for abort
  diagnosis.
- Packets are generated anchor-only (no `--task`): CLI-4/8 make that
  deterministic, and it keeps every treatment byte either frozen text or
  ctxpack output — no unfrozen task-summary text invented at setup time.
- Task 2's packet is generated from the *seeded* tree (recorded as a
  PREREGISTRATION amendment): generating from the pristine tree inlined the
  pre-bug line into the packet snippet — a fix leak to the treatment arm.
- `tasks/task2_seed.patch` regenerated via `git diff --output=…` (recorded
  amendment): the original was corrupted at authoring time because the rtk
  hook filters `git diff` stdout, so `git diff > file` captured the filtered
  summary. Root cause worth remembering for any future committed-patch
  authoring.

### Verification

- Prompt builder: all 6 task/arm prompts render with no leftover
  `{placeholder}` tokens; task 2 embeds the verbatim captured failing output;
  treatment embeds the recorded packet bytes. Substitution uses block-form
  `sub` so packet/test-output bytes can't be mangled as backreferences.
- Scoring: task 2 simulated-correct-fix → true; empty diff → false; diff
  touching `test/` → false (frozen extra check). Tasks 1/3 acceptance tests
  red on the unmodified tree for exactly the missing behavior (no fixture or
  API drift — no amendment needed); task 3's valid-copy/no-param guards green.
- Metrics parser: synthetic stream-json transcript covering every frozen
  definition (load-bearing index over all tool_use events, distraction reads,
  discarded edits, usage sum) matches expected values.
- Baseline: unseeded `test_show_api_key` green in the template on
  Ruby 4.0.1 / Rails 8.1.3 / SQLite; seeded run errors with the captured
  `undefined method 'api_key' for nil`.
- Not yet verified: a real end-to-end session (blocked on a one-time
  interactive login into the sterile `CLAUDE_CONFIG_DIR`; the auto-mode
  classifier correctly refused materializing the keychain credential into a
  file). The pilot is the end-to-end shakeout by design.

### Pilot outcome (2026-07-06)

End-to-end shakeout clean. Both task-2 pilot sessions (`run 2`) completed,
`task_success=true`, scoring 56 runs / 0 failures each. Both produced the
identical minimal fix (`@current_user`→`@user`, single line, `test/`
untouched) — no mechanical acceptance-test fix needed, no PREREGISTRATION
amendment. Early directional signal (n=1, task 2 only, not inferential):
treatment hit the load-bearing read on call 1 (4 tool calls, 26s, 175k
tokens) vs control's call 2 (17 tool calls, 92s, 660k tokens). Calibration:
control ~660k / treatment ~175k total tokens/session on the trivial task;
tasks 1/3 expected heavier. Grid (18 sessions) not yet run — checkpointed for
go/no-go.

### Grid outcome (2026-07-06)

Full 18-session grid complete (20/20 including pilot), zero aborts/timeouts,
every session `task_success=true`. Ran in two batches (round 1, then rounds
2+3) same day; ~11.7M tokens / ~27 min elapsed total for the grid. Diffs
sane: task 1 both arms identical 3-file change; task 3 both arms near-
identical (agent adds its own test, allowed for 1/3, doesn't touch the
copied-in acceptance file).

**task_success is saturated (100% both arms)** — the discriminating signal is
in process metrics + the pending blind diff-quality judging. Pre-registered
per-task median analysis (≥30% reduction in LBR *or* distraction, ≥2 of 3
tasks):
- Task 1 (twofa feature, multi-file): treatment *worse* — median LBR 5→7
  (−40%), packet adds exploration/tokens. No improvement.
- Task 2 (bug fix): median LBR 4→2 (50% reduction). PASS.
- Task 3 (behavior change): median LBR 2→1 (50% reduction). PASS.
- => 2/3 tasks improve, success rate unregressed → **SUPPORT, conditional on
  blind diff-quality showing no regression** (judging not yet done).

Interesting signal: the packet helps the smaller-surface bug-fix/behavior
tasks but *hurts* the multi-file feature (task 1) — worth calling out in
RESULTS, not a harness defect. Remaining: blind-judge 18 diffs (0–8),
write RESULTS.md, tick PREREGISTRATION checkboxes, PROJECT_TRACKER ritual.

## P1: RSpec test-candidate rules (2026-07-07)

Implemented the Tier 2 expansion prerequisite for RSpec test candidates. Scope
was limited to TEST-1..6 and their format/eval cross-spec effects: no anchor,
callback, constant, CLI, or manifest schema behavior changed.

### Decisions

- Test discovery now selects one family before matching paths. RSpec wins when
  the app has `spec/` plus either `spec/rails_helper.rb` or an `rspec-rails`
  dependency in `Gemfile` / `Gemfile.lock`; otherwise Minitest remains the
  fallback.
- The RSpec family mirrors the existing two-rule shape:
  `spec/controllers/<controller_path>_controller_spec.rb`, then
  `spec/requests/*_spec.rb` path-token matches. `spec/system/` is deliberately
  ignored for v0.
- The rule-2 token matcher is shared with Minitest integration matching, so
  contiguous action-token behavior and the ANCH grammar normalization carry
  over unchanged.
- RSpec candidates use `rspec_candidate` and `bundle exec rspec <path>`.
  Rule-2 RSpec request matches reuse `test_inferred_by_path`; no new
  uncertainty code was needed.
- `Packet#test_framework` is internal render metadata only. It keeps no-test
  candidate and retrieve-more prose framework-aware without changing MAN-2.
- Fixture eval cases now accept optional top-level `app`, defaulting to
  `minitest_basic`, so the same runner can cover `rspec_basic`.

### Requirement Coverage

- TEST-1 RSpec detection and rules:
  `TestCandidatesTest#test_test_1_rspec_family_uses_controller_and_request_specs_only`,
  `#test_test_1_rspec_request_rule_uses_contiguous_action_tokens`,
  `#test_test_1_rspec_framework_detection_accepts_rspec_rails_dependency`.
- TEST-2 remains covered by the existing Minitest truncation test; RSpec uses
  the same candidate truncation path.
- TEST-3 RSpec reason code and rule-2 uncertainty:
  `TestCandidatesTest#test_test_1_rspec_family_uses_controller_and_request_specs_only`
  plus the `accounts_upgrade_rspec` fixture eval.
- TEST-4/TEST-5 cross-framework non-guessing:
  `TestCandidatesTest#test_test_1_rspec_family_uses_controller_and_request_specs_only`
  asserts RSpec ignores the colocated Minitest fixture and `spec/system/`.
- TEST-6 RSpec command:
  `TestCandidatesTest#test_test_1_rspec_family_uses_controller_and_request_specs_only`
  and `FixtureEvalsTest#test_eval_accounts_upgrade_rspec_packet_expectations`.
- FMT-6/FMT-8 RSpec rendering:
  `PacketFormatTest#test_fmt_6_8_test_3_renders_rspec_candidate_reason_and_uncertainty_text`.
- EVAL-4 optional `app` and RSpec fixture coverage:
  `FixtureEvalsTest#test_eval_accounts_upgrade_rspec_packet_expectations` and
  `#test_eval_accounts_upgrade_rspec_cli_output_is_deterministic`.

### Verification

- Red proof: direct RSpec candidate tests first failed because output was the
  existing `bin/rails test test/controllers/accounts_controller_test.rb`;
  the RSpec fixture eval first failed because
  `spec/requests/accounts_upgrade_spec.rb` was absent.
- Focused green:
  `bundle exec ruby -Itest test/ctxpack/test_candidates_test.rb` — 7 runs, 20
  assertions, 0 failures, 0 errors, 0 skips.
- Focused green:
  `bundle exec ruby -Itest test/ctxpack/fixture_evals_test.rb` — 4 runs, 71
  assertions, 0 failures, 0 errors, 0 skips.
- Focused green:
  `bundle exec ruby -Itest test/ctxpack/packet_format_test.rb` — 10 runs, 100
  assertions, 0 failures, 0 errors, 0 skips.
- Full suite: `bundle exec rake test` — 55 runs, 362 assertions, 0 failures,
  0 errors, 0 skips.
- Strategic validator: `ruby /Users/sal/Projects/strategic-software-design/scripts/validate.rb --type feature --task "Continue from PROJECT_TRACKER.md" --base-ref HEAD`
  passed slice tests, red-green, and pending-comment gates. RuboCop
  lint/metrics were skipped because plain RuboCop could not load the committed
  Metz cop namespace; logged in `metz-scan-feedback.md`.
- Advisory Metz scan: `bundle exec rake metz` completed. Findings remain the
  known class/method length pressure, with `Compiler` now at 553 lines and
  `MarkdownRenderer` at 226 lines; no gate.
- Clean-context design review was required by the validator but not run:
  this session's sub-agent tool policy forbids spawning unless the user
  explicitly asks for delegation.

## P2: multi-app Tier 2 harness configs (2026-07-07)

Implemented the Tier 2 expansion prerequisite for a multi-app harness. Scope
was limited to `eval/tier2/harness.rb`, per-app config files under
`eval/tier2/apps/`, and Tier 2/expansion docs. No `lib/`, `exe/`, `specs/`, or
committed Redmine run/task/packet/diff/transcript artifacts were changed.

### Decisions

- Added `Tier2::AppConfig` and `Tier2::TaskConfig` in
  `eval/tier2/apps/config.rb`, plus an app registry loaded by the optional CLI
  app selector.
- Moved Redmine-specific constants into `eval/tier2/apps/redmine.rb`: pinned
  SHA, template/work/artifact paths, prepared files, Minitest command/filter,
  runner signature, pilot task, and the three task configs.
- Added empty `campfire`, `lobsters`, and `publify` skeleton configs. Their
  SHA placeholders evaluate to the requested unauthored sentinel and their task
  arrays are empty, so `status` and `verify` are safe before templates, DBs,
  packets, or golden prompts exist.
- Generalized schedule, prompt construction, resume keys, workspace creation,
  packet generation, transcript metrics, and scoring to take an app config.
  Redmine's run id shape and per-file resume tuple remain
  `[task, arm, run_index, pilot]`.
- Added `"app" => config.name` to newly written run records only. Existing
  `eval/tier2/runs.jsonl` records are read unchanged and were not rewritten.
- Added offline `verify`: schedule/run-id comparison against
  `golden/schedule.json`, byte-for-byte prompt checks for every task/arm,
  prompt determinism checks, and packet SHA-256 verification.
- Packet generation now requests the JSON manifest with `--manifest` and, for
  newly generated packets, records `had_test_candidate` and
  `suggested_test_commands` in `packets.json`. Existing Redmine metadata that
  lacks these keys is interpreted as `false` / `[]`.
- Added pre-registered treatment-only metrics:
  `packet_had_test_candidate` and
  `ran_suggested_test_before_first_edit`.

### Verification

- `ruby eval/tier2/harness.rb verify`:
  `OK`
- `ruby eval/tier2/harness.rb status`: listed the frozen 20 Redmine tuples and
  ended with `20/20 complete`.
- `ruby -e 'require "./eval/tier2/apps/campfire"'`,
  `ruby -e 'require "./eval/tier2/apps/lobsters"'`, and
  `ruby -e 'require "./eval/tier2/apps/publify"'`: all exited 0 with no output.
- `ruby eval/tier2/harness.rb campfire status`,
  `ruby eval/tier2/harness.rb lobsters status`, and
  `ruby eval/tier2/harness.rb publify status`: each printed `0/0 complete`.
- Additional skeleton proof:
  `ruby eval/tier2/harness.rb campfire verify`,
  `ruby eval/tier2/harness.rb lobsters verify`, and
  `ruby eval/tier2/harness.rb publify verify` print
  `<app>: not yet authored (0 tasks)`.
- Full suite: `bundle exec rake test` — 55 runs, 362 assertions, 0 failures,
  0 errors, 0 skips.
- Strategic validator was run from a `/private/tmp` copy because this sandbox
  cannot create `.git/index.lock` in the working repo. With Ruby 4.0.1 on
  `PATH`, it passed `slice_tests` and `todo`; `red_green` was skipped, and
  RuboCop lint/metrics were skipped with the existing Metz cop warning:
  `unrecognized cop or department Metz found in .rubocop.yml`.
- Clean-context design review was required by the validator but not run:
  the available sub-agent tool policy forbids spawning unless the user
  explicitly asks for delegation.

## Tier 2 expansion packet coverage script (2026-07-08)

Added `eval/tier2-expansion/packet_coverage.rb`, an offline stdlib-only
analysis script for LIM-1 packet file-set coverage against the 72 committed
Tier 2 expansion diffs. Scope was limited to the new script and generated
`eval/tier2-expansion/coverage/` JSON outputs; no `lib/`, `exe/`, `specs/`,
packet JSON, or committed diff data changed.

### Decisions

- Packet file-sets are canonicalized from each packet manifest's
  `files[].path`, with duplicates removed and paths sorted.
- Diff file-sets are parsed only from `diff --git a/<path> b/<path>` headers,
  using the `b/` path. New-file and deleted-file hunks are covered by that
  header shape; malformed headers abort instead of being guessed.
- Production-only coverage removes only top-level `test/` and `spec/` paths
  from both packet and diff sets. Other non-test files, including
  `config/locales/en.yml`, remain production files.
- Aggregates are means of per-session recall/precision values. Null metrics
  from empty denominator sets are excluded from means and counted in the JSON.
- Control and treatment are kept separate in every table and aggregate because
  control is the unbiased packet-budget read, while treatment is a steering
  read.

### Verification

- `ruby eval/tier2-expansion/packet_coverage.rb` processed 72 sessions and
  wrote `coverage_summary.json` plus `coverage_by_session.json`.
- JSON shape check: `coverage_summary.json` reports `session_count=72` and
  `coverage_by_session.json` has 72 rows.
- Spot-check: every non-pilot Campfire task 4 diff touches
  `app/controllers/rooms/involvements_controller.rb` and
  `config/locales/en.yml`, with test-file edits in most rounds. The task 4
  packet lists the controller and its test candidate, so production-only
  overlap is the controller only: recall `1/2 = 0.5`, precision `1/1 = 1.0`.
- `ruby -c eval/tier2-expansion/packet_coverage.rb`: `Syntax OK`.
- Full suite: `bundle exec rake test` — 55 runs, 362 assertions, 0 failures,
  0 errors, 0 skips.

## View resolution spec freeze + canonical-spec fold (2026-07-08)

Spec-only pass: froze `specs/views.md`'s four `[FREEZE]` decisions per
explicit user sign-off and folded VIEW-1..VIEW-7 into `packet-compilation.md`
and `packet-format.md`. No `lib/`, `exe/`, or `test/` touched — nothing to
run.

### Decisions (as directed, not independently chosen)

- VIEW-2 format variants: all existing variants match (not `*.html.*`-only).
- VIEW-3: list-only `view_candidate`, empty `snippet_ranges`, no ERB
  snippeting.
- VIEW-4: convention-only, existence-gated, no render-target analysis
  (already the recommendation; just de-hedged).
- VIEW-5a `max_view_files` = 2.
- VIEW-5b priority: reorder file inclusion/display order to
  controller → view(s) → constants → tests; `max_total_files` ceiling stays
  at 8 (not raised to `8 + max_view_files`).

### Fold judgment calls

- **[orchestrator adjudication, 2026-07-08]** The fold agent flagged that the
  pipeline diagrams (`… → constant files → views → …`) placed views *after*
  constants while LIM-1/DET-2 place them *before*. Resolved toward one
  consistent order: edited both pipeline diagrams (`packet-compilation.md`
  and `design.md`'s two) to `… → action + applicable callbacks → views →
  referenced constants → constant files → test candidates → …`. Rationale:
  view resolution has no data dependency on constants (needs only
  `controller_path` + `action`, available at ANCH-3), so views-before-constants
  is equally accurate as compute order; and the single-pass `add_*` append
  implementation makes call order == display order, so the "two different axes"
  framing doesn't match the code. DET-2 (views before constants) is the
  normative file order Codex implements against; the pipeline now agrees.
  (The `## Views` doc section remains placed after `## Constants` — section
  order is organizational, not normative.)
- **[implementation flag for Phase 2 / Codex]** With views, `max_total_files`
  is now reachable (1+2+4+2 = 9). `compiler.rb`'s `enforce_total_file_limit`
  currently *raises* on > 8 (the "unreachable by construction" backstop, noted
  at implementation-notes "Decisions" line ~19). Per the revised LIM-1 it must
  become **priority-ordered truncation**: include in controller → views →
  constants → tests order and truncate the category still filling when the
  ceiling is reached (in practice the 2nd test), naming every dropped file in
  the LIM-2 omitted note *and* removing a dropped test from "Tests to run".
  Recommended shape: cap tests at `min(max_test_files, max_total_files -
  files_so_far)` at allocation time rather than post-hoc truncating
  `packet.files`, so `packet.tests`/omitted stay consistent.
- `packet-format.md` had no existing per-reason-code registry of literal
  "Why:" text (only `design.md`'s worked example demonstrates concrete Why
  lines; FMT-6's table gives a "Meaning," not literal packet prose). Added a
  new lettered sub-requirement, **FMT-4a**, spelling out the literal
  `view_candidate` Why template — following the CONST-2a/b/c and CB-2a
  lettered-subrequirement convention already used in `packet-compilation.md`.
  Existing codes' Why text remains implicit via `design.md`'s example; not
  retrofitted, since that was out of scope.
- `specs/README.md`'s non-goals echo and `design.md`'s "Non-goals for v0"
  list never named views as excluded (verified by grep) — so there was
  nothing to remove per the "adjust ... if appropriate" instruction. Noted
  as a no-op rather than silently skipped.
- `design.md`: added a new "## View resolution" section (mirroring "## Test
  candidate rules" in structure) between "Parsing and static analysis
  strategy" and "v0 packet contents," rather than editing the worked
  "Example packet shape" — the task only asked to reconcile prose/rationale
  and record probe evidence/the VIEW-4 boundary, not to add a views entry to
  the worked example. Also extended the "v0 packet contents" bullet list,
  the "v0 packet limits" numbers block, and the stale "Open questions" limits
  line (which enumerated the old 4 numbers) to include `max_view_files`.
- Left `packet-format.md`'s MAN-2 example JSON manifest untouched — the
  "On freeze" checklist doesn't call for a manifest example update, and a
  view file in `files[]` needs no new manifest field (reason_code +
  snippet_ranges already cover it), so there's nothing the example is
  missing.

### Not done in this pass (explicitly out of scope, per `specs/views.md`
"Folded into the canonical specs")

- Fixture-eval YAML cases (red-then-green) for the new view-resolution
  behavior.
- Tier 0 corpus re-scan (mandatory before implementation acceptance, not
  before this spec-only freeze).
- The two "Companion work" items in `specs/views.md` (CONST-1 whole-
  controller-file widening; locale-as-pointer) — deliberately kept out of
  this pass.

### Verification

- Spec-only pass; no code changed, so `bundle exec rake test` was not run.
  Verification here is read-through consistency: re-read
  `specs/packet-compilation.md`, `specs/packet-format.md`, `specs/README.md`,
  and `design.md` in full after editing to confirm the new VIEW/FMT-4a/LIM-1/
  DET-2 text reads in the surrounding requirement-code voice and that the
  `max total files` / `max view files` alignment block in
  `packet-compilation.md` matches the existing column-aligned formatting
  (verified programmatically, not by eye).
- Confirmed VIEW-1..VIEW-7 numbering is unchanged from the draft (no
  renumbering), per `specs/README.md`'s numbering-stability convention.

## View resolution implementation pass (2026-07-08)

Implemented the frozen VIEW-1..VIEW-7 compiler pass and the associated
packet-format renderer additions. No packet schema change was needed:
`Packet#to_h` already serializes view evidence as `files[]` records with the
`view_candidate` reason code and `snippet_ranges: []`.

### Requirement coverage

- VIEW-1: `test/fixtures/evals/view_namespaced.yml`,
  `test/fixtures/evals/view_no_template.yml`,
  `ViewResolutionTest#test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty`,
  `ViewResolutionTest#test_view_1_missing_template_does_not_fail_or_emit_view_uncertainty`
- VIEW-2: `test/fixtures/evals/view_multi_format.yml`,
  `test/fixtures/evals/view_partial_excluded.yml`,
  `ViewResolutionTest#test_view_2_includes_all_format_variants_in_lexicographic_order`,
  `ViewResolutionTest#test_view_2_excludes_partials`
- VIEW-3: `test/fixtures/evals/view_namespaced.yml`,
  `ViewResolutionTest#test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty`
- VIEW-4: code inspection of `Compiler#add_view_candidates` confirms
  convention-only existence-gated globbing with no action-body render-target
  analysis; VIEW-6 disclosure covered by renderer tests below.
- VIEW-5: `test/fixtures/evals/view_budget_truncation.yml`,
  `test/fixtures/evals/view_total_file_truncation.yml`,
  `ViewResolutionTest#test_view_5_truncates_view_variants_and_records_omitted_candidate`,
  `ViewResolutionTest#test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run`
- VIEW-6: `ViewResolutionTest#test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty`,
  `ViewResolutionTest#test_fmt_4a_8_9_renders_view_reason_uncertainty_and_omission_suggestions`
- VIEW-7 / DET-2: `ViewResolutionTest#test_view_2_includes_all_format_variants_in_lexicographic_order`,
  `ViewResolutionTest#test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run`
- FMT-4a: `ViewResolutionTest#test_fmt_4a_8_9_renders_view_reason_uncertainty_and_omission_suggestions`
- FMT-6: all new fixture evals that include a view assert
  `reason_code: view_candidate`; `ViewResolutionTest#test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty`
  asserts the packet object reason code.
- FMT-7 / FMT-8: `ViewResolutionTest#test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty`,
  `ViewResolutionTest#test_fmt_4a_8_9_renders_view_reason_uncertainty_and_omission_suggestions`
- LIM-1 / LIM-2: `LimitsTest#test_lim_1_v0_limits_are_internal_constants`,
  `ViewResolutionTest#test_view_5_truncates_view_variants_and_records_omitted_candidate`,
  `ViewResolutionTest#test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run`

### Fixture eval note

The YAML fixture-eval schema covers stable packet fields (`entrypoint`,
`include`, `exclude`, `tests`, `max_files`) but has no omitted-candidate
assertion shape. Per the brief, omitted view and total-file truncation checks
live in `ViewResolutionTest` against `packet.omitted_candidates`; the YAML
cases still exercise the public compile and CLI determinism paths.

### Red / green record

- Red, fixture evals before `lib/` changes:
  `bundle exec ruby -Itest -Ilib test/ctxpack/fixture_evals_test.rb --name '/view_(namespaced|multi_format|partial_excluded|budget_truncation|total_file_truncation)_packet_expectations/'`
  -> `5 runs, 30 assertions, 5 failures, 0 errors, 0 skips`; each failure was
  an expected view file absent from the packet. The `view_no_template` case is
  intentionally not listed in this red command because the pre-view compiler
  already satisfied "missing conventional template adds nothing and does not
  fail"; it remains a regression guard after implementation.
- Red, focused unit tests before `lib/` changes:
  `bundle exec ruby -Itest -Ilib test/ctxpack/view_resolution_test.rb` ->
  `7 runs, 11 assertions, 6 failures, 0 errors, 0 skips`.
- Green, focused unit tests after implementation:
  `bundle exec ruby -Itest -Ilib test/ctxpack/view_resolution_test.rb` ->
  `7 runs, 33 assertions, 0 failures, 0 errors, 0 skips`.
- Green, new fixture eval packet expectations after implementation:
  `bundle exec ruby -Itest -Ilib test/ctxpack/fixture_evals_test.rb --name '/view_(namespaced|multi_format|no_template|partial_excluded|budget_truncation|total_file_truncation)_packet_expectations/'`
  -> `6 runs, 174 assertions, 0 failures, 0 errors, 0 skips`.
- Green, full suite before this note-only edit:
  `bundle exec rake test` -> `74 runs, 621 assertions, 0 failures, 0 errors,
  0 skips`.
- Full suite after README/tracker/note reconciliation:
  `bundle exec rake test` -> `74 runs, 621 assertions, 0 failures, 0 errors,
  0 skips`.
- Tier 0 corpus re-scan: attempted, but not completed. Cloning into
  `/private/tmp/ctxpack-tier0-view-pass/` initially succeeded for default
  branches, then `git fetch`/`git checkout` of the pinned SHAs failed with
  `Could not resolve host: github.com`. The scratch clones were verified to be
  at non-pinned HEADs and were not used for classification. No
  `eval/tier0/RESULTS.md` addendum was written because the gate did not run.

## CONST-1a intra-file call-graph constants pass (2026-07-09)

Implemented the frozen CONST-1 widening as a narrow intra-file action call
graph, not a whole-controller scan. Constant collection now uses three ordered
groups: action-body constants, applicable same-file callback constants in
declaration order, then transitive same-file callee constants in BFS discovery
order. Appending callees last is deliberate: under
`LIMITS[:max_constant_files] == 4`, the widening is strictly additive, so a
callee constant can never evict a direct action or callback constant.

Call detection follows only literal same-file controller method calls: a
`Prism::CallNode` with no receiver or a `Prism::SelfNode` receiver, whose name
matches a direct method in the controller's method map. Calls with other
receivers are ignored. Dynamic dispatch and aliases (`send`, `public_send`,
`method`, `alias_method`, etc.) are out of scope.

Expansion is action-only: callback bodies still contribute constants, but
their calls are not followed unless the callback method is also reached from
the action. For the callback-that-is-also-a-callee case, BFS seeds `visited`
with only the action name, not callback names, so traversal can pass through
the callback method to discover its callees while path-level dedup keeps the
callback's own constants at their callback position.

Known limitations: constants in method parameter defaults are not scanned
because ctxpack scans method bodies only; dynamic dispatch and aliases are not
detected. Mandatory Tier 0 corpus re-scan for this compiler-behavior change is
run session-side by the orchestrator.
