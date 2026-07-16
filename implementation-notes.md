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
  against that root. At the end of pass 3, printed success paths were
  root-relative when the output lived under the root; the 2026-07-12 CLI
  ergonomics pass below supersedes that display behavior.
- Default artifact names use the spec's storage-only UTC timestamp plus a
  deterministic derived name. Explicit names are validated with
  `^[A-Za-z0-9_]+$` and normalized with a local Rails-style `underscore`
  implementation instead of adding ActiveSupport.
- Historical pass-3 behavior, superseded by the CLI developer-happiness
  follow-on below: overwrite checks ran before compilation, and explicit
  `--out` permitted overwrite without `--force` under the original CLI-7/CLI-11.
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
- Historical CLI-7/CLI-9/CLI-11 coverage, superseded by the follow-on below:
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
- The determinism check drives `Ctxpack::CLI#run` in-process twice with fixed
  `--out --force --manifest`, then compares SHA-256 hashes of both the
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
detected.

Requirement coverage: five dedicated cases in `test/ctxpack/constants_test.rb`
(`test_const_1a_follows_same_file_helper_called_by_action`,
`test_const_1a_4_appends_transitive_constants_after_action_and_callbacks_under_the_4_cap`,
`test_const_1a_terminates_mutual_recursion_in_bfs_order`,
`test_const_1a_traverses_through_callback_that_is_also_a_callee`,
`test_const_1a_ignores_dynamic_and_other_receiver_calls`) plus red-then-green
fixture evals. Verified session-side: `bundle exec rake test` — 89 runs,
815 assertions, 0 failures. Mandatory Tier 0 corpus re-scan for this
compiler-behavior change PASSED: zero per-anchor change, zero crashes across
all 1,967 pairs.

## Locale-pointer standing uncertainty note (2026-07-09)

Companion to the view pass, targeting the locale half of a measured quality
ding (an agent changed a nickname backend-only, adding no locale key). Chosen
shape (advisor-frozen): an **unconditional standing uncertainty note**, not a
view-gated coded uncertainty. Rationale: the frozen guidance
(`specs/views.md` companion item 2) calls for a "standing pointer, not a packet
file ... a note, not a resolver"; the locale gap is *newly-added keys*, which is
orthogonal to whether a view template exists (so view-gating wouldn't track the
failure mode); and `uncertainty_notes` already carries two unconditional
standing notes, so a third fits the precedent. It is renderer-only prose — no
compiler behavior, no resolution or manifest change — so the Tier 0 corpus
rescan is **N/A** for this pass.

The note is appended in `markdown_renderer.rb#uncertainty_notes` after the
route-discovery note. It deliberately adds **no** "Retrieve more only if needed"
suggestion: FMT-2 §8 fixes that section as a pure function of uncertainty/
omission *codes*, and this is a code-less standing note, so the conditional
action ("add or update the matching locale key(s)") is embedded in the note
itself (mirroring the route note's embedded `bin/rails routes` action). Wording
states the scan gap without false precision ("not scanned", "conventionally").
FMT-8 amended to enumerate the note; no FMT-7 code added, no MAN-2/manifest
change (standing notes are Markdown-only, consistent with the existing two).
Implemented by a local coding-worker; verified session-side red-then-green
(89 runs / 817 assertions).

## CLI ergonomics pass (2026-07-12)

Change type: bugfix. User task statement: “Ok go ahead”. Implemented with an
Agenticons `coding_worker`; an `edge_case_analyst` independently challenged the
acceptance criteria, and the orchestrator reviewed the diff and verified every
result session-side.

The pass fixes six user-facing seams without adding commands or dependencies:

- `--out packet.json --manifest` and extension-case variants fail before
  compilation instead of allowing the manifest to replace the Markdown.
- saved paths are relative to the invocation directory, not the discovered app
  root, so each stdout line resolves where the user ran ctxpack.
- success stdout contains artifact paths only; the first-run gitignore reminder
  moved to stderr.
- top-level and packet `-h` / `--help` return through injected streams without
  Rails-root discovery or `SystemExit`.
- the 80-character derived-name cap truncates the task first and keeps the
  anchor suffix; an anchor over the cap keeps its trailing 80 characters.
- route-recovery hints substitute safe controller/action tokens and retain
  generic placeholders for malformed or shell-sensitive anchors.

Normative coverage: CLI-1a, CLI-8a, CLI-10a, CLI-14, CLI-15, and CLI-17. The
fixture-eval skill classified the manifest collision as CLI/artifact UX with no
packet-content component, so its regression belongs in `cli_test.rb`, not a
Tier 1 YAML case.

### Red / green record

- Clean-HEAD red proof with the final CLI tests overlaid: the help case reached
  OptionParser's process-exiting handler; the remaining targeted cases produced
  `11 runs, 40 assertions, 9 failures, 0 errors, 0 skips`. Failures covered both
  manifest collisions, both reminder-stream cases, invocation-relative paths,
  anchor-preserving truncation, and contextual route hints.
- Focused green: `bundle exec ruby -Itest test/ctxpack/cli_test.rb` →
  `24 runs, 148 assertions, 0 failures, 0 errors, 0 skips`.
- Full green: `bundle exec rake test` → `102 runs, 912 assertions, 0 failures,
  0 errors, 0 skips`.
- Tier 0 corpus re-scan: N/A. This pass changes CLI argument, naming, stream,
  path-display, and error-hint behavior only; packet compilation is unchanged.

## CLI developer-happiness follow-on (2026-07-12)

Change type: feature. User task statement: “Let's go ahead and fix all
these. Use agenticons to accomplish that.” This follow-on keeps the deterministic
compiler and artifact contract intact while reducing ceremony and removing
surprising output behavior.

Implemented contract:

- `ctxpack <anchor> [options]` is the golden path; the original
  `ctxpack packet <anchor> [options]` form remains compatible.
- no arguments and help in either form/position print full descriptive help to
  injected stdout and return normally without Rails-root discovery;
  sole top-level `-v` / `--version` has the same root-independent behavior.
- common options have conservative aliases: `-t` / `--task`, `-d` / `--dir`,
  `-o` / `--out`, and `-f` / `--force`; `--name` and `--manifest` remain
  long-only.
- explicit `--out` conflicts with explicitly supplied `--dir` or `--name`.
  It never grants overwrite permission: an existing Markdown artifact or
  sibling manifest requires `--force`; fresh `--out` and `--out --force` are
  valid.
- overwrite and filesystem error paths are invocation-relative. Directory and
  write failures return concise injected `ctxpack:` errors with status 1 and no
  usage or backtrace. Existing destinations must be regular files even under
  `--force`; validation occurs before compilation and prevents the reproduced
  directory-valued manifest target from leaving a partial Markdown artifact.
- the common typo `ctxpack packets` suggests `ctxpack packet`; unrelated unknown
  commands do not receive a speculative suggestion.

Normative coverage: amended CLI-1, CLI-1a, CLI-4, CLI-5, CLI-6, CLI-7, CLI-9, and
CLI-11; added CLI-1b, CLI-1c, CLI-17a, and CLI-17b. `design.md`, README, and the
examples guide are reconciled. No dependency, compiler behavior, packet
content, or recorded eval data changes; Tier 0 corpus re-scan is therefore N/A.

### Verification record

- Red/green proof: individual tracer bullets failed first for help after an
  anchor, no-argument help, version output, direct-anchor dispatch, descriptive
  help, output-option conflicts, force-only overwrites, typo guidance,
  filesystem translation, and non-file manifest preflight. The strategic
  validator independently confirmed 28 merge-base red/green behaviors.
- The first full-suite run exposed 14 Tier 1 determinism failures because the
  runner repeated fixed `--out` without stating overwrite intent. Adding
  `--force` to that harness made its focused **28 runs / 509 assertions** green
  and reconciled EVAL-7/design/tracker notes.
- Focused CLI suite: **38 runs, 241 assertions, 0 failures, 0 errors, 0 skips**.
- Full `bundle exec rake test`: **116 runs, 1005 assertions, 0 failures, 0
  errors, 0 skips**.
- Strategic validator: slice-tests pass (66), red/green pass (28 behaviors),
  pending-comment gate pass, final clean-context design review clean with no findings.
- Validator warnings (verbatim):
  - `rubocop run errored - Lint/Security gate skipped: Error: unrecognized cop or department Metz found in .rubocop.yml`
  - `head metrics unavailable (rubocop run failed); deltas omitted`
- Advisory `bundle exec rake metz`: 55 offenses; CLI pressure is one
  `ClassesTooLong` and six `MethodsTooLong` findings. No code was split merely
  to improve an advisory metric.
- Agenticons documentation review findings were fixed. Exploratory QA passed
  the approved scenarios and re-verified that a directory-valued sibling
  manifest is rejected before Markdown is written. General two-artifact
  atomicity under races or later I/O failure remains outside this pass.
- `Gemfile.lock` unchanged; no new dependency. Tier 0 corpus re-scan N/A because
  compilation behavior is unchanged.

## CLI pipelines and Rails-aware recovery pass (2026-07-12)

Change type: feature. User task statement: “Go ahead and implement all these.
Use agenticons. You are simply the orchestrator and directly responsible
agent.” This distinct follow-on preserves the committed CLI ergonomics pass
(`b8c2dc8`) and the earlier uncommitted CLI developer-happiness follow-on.

Implemented contract:

- `--task-file PATH` resolves from invocation cwd; `-` reads injected stdin.
  Exactly one final LF/CRLF is removed. It conflicts with an explicitly
  supplied `--task` before discovery or reads.
- `--stdout` renders raw Markdown without artifact creation and conflicts with
  explicit artifact options before discovery, task reads, or compilation.
- narrow, syntactic Rails-aware diagnostics reject route helpers,
  controller-class references, HTTP route strings, and slash-for-`#` anchors
  before discovery without accepting or resolving them.
- the default-directory reminder delegates ignore semantics to Git and appears
  only when this invocation created the implicit `.ctxpack/` and Git reports it
  unignored. Explicit destinations, existing directories, ignored paths,
  non-Git apps, and operational failures stay quiet.

Normative coverage: CLI-1a/1c/2/4/8/14/15/19 amended; CLI-4a, CLI-10b,
CLI-14a, and CLI-17c added. No compiler, renderer, packet, dependency, recorded
eval, or pre-registration changes; Tier 0 and fixture-YAML additions are N/A.

### Red / green record

- `--task-file -`: red `ArgumentError: unknown keyword: :stdin`; green 1 run /
  5 assertions.
- `--stdout`: red status 1 (unknown option); green 1 run / 6 assertions.
- route-helper guidance: red generic unknown-command output; green direct and
  compatibility coverage, 1 run / 16 assertions.
- remaining Rails shapes exposed `String#rsplit` (not a Ruby API); regex
  captures replaced it and the slice passed, 1 run / 34 assertions.
- ignored default output: red old unconditional reminder; green after the Git
  check, 1 run / 9 assertions.

Final verification is recorded by the completing session below; parent-only
Agenticons review/QA gates remain pending until the orchestrator performs them.

- Focused CLI: `56 runs, 424 assertions, 0 failures, 0 errors, 0 skips`.
- Full suite: `134 runs, 1188 assertions, 0 failures, 0 errors, 0 skips`.
- No dependency or lockfile change from this pass. Tier 0 rescan is N/A because
  compiler behavior did not change.
- Strategic validator: slice-tests, merge-base red/green, and pending-comment
  gates passed; lint was skipped. Clean-context review is required and remains
  parent-side. Warnings (verbatim):
  - `rubocop run errored - Lint/Security gate skipped: Error: unrecognized cop or department Metz found in .rubocop.yml`
  - `head metrics unavailable (rubocop run failed); deltas omitted`
- The failed Ruby `String#rsplit` attempt crossed the extract-approach
  threshold; the reusable capture rule is recorded in
  `docs/agent-learnings/2026-07-12-ruby-right-split-with-captures.md`.
- Parent audit follow-up: an injected stdin whose `read` raises `IOError`
  initially escaped with a backtrace; after stdin-specific translation it
  returns status 1 with concise stderr and no output mutation (red: 1 error;
  green: 1 run / 6 assertions). Exact byte equality now covers both ordinary
  `--stdout` and the composed `--task-file - --stdout` path. `-d`, `-o`, and
  `-f` are explicitly covered by stdout-conflict tests.

## Unavailable-Git repo-stamp closure (2026-07-12)

Change type: bugfix. User task statement: “Ok proceed.”

- `Compiler#repo_stamp` now treats an unavailable Git executable like the
  existing outside-repository case: `commit: nil`, `dirty: false`, which the
  renderer presents as FMT-11's fixed unknown state.
- Red proof: a public `Ctxpack.compile` test with the `Open3.capture2` system
  boundary raising `Errno::ENOENT` failed with 1 error at `repo_stamp`.
- Green proof: the focused repo-stamp file passed with 3 runs / 7 assertions.
- Full suite: `135 runs, 1190 assertions, 0 failures, 0 errors, 0 skips`.
- Parent verification repeated the focused and full suites with the same green
  counts. Strategic slice, merge-base red/green, and pending-comment gates
  passed. The delegated clean-context reviewer was terminated at the explicit
  60-second boundary; parent diff/spec review found no additional defect.
- No Tier 1 YAML case was added. Git executable availability is an environment
  condition, while the fixture-eval DSL describes deterministic Rails-shaped
  source trees and cannot control process availability; the public unit-level
  regression test owns this behavior.
- Tier 0 is N/A. This changes repo-stamp collection only, not resolution,
  callbacks, constants, test candidates, limits, or per-anchor classification.
- No dependency or lockfile change; no recorded experiment data changed.

## Packet format v2 (2026-07-12)

Change type: feature. User task statement: “include slice 4 because so far I'm
the only person using/testing this tool so far”.

- Markdown Format 2 blockquotes each task line, adds fixed How-to-use guidance,
  renders one DET-2 flat file map, expands only snippet-bearing Evidence with
  visible 1-based ranges, keeps path-inference beside Run commands, and folds
  packet-specific uncertainty/omissions into deduplicated imperative Follow-ups.
- Standing routes, superclass/concern callback, and locale boundaries appear
  exactly once in Anchor's `Scope:` line. Unavailable Git renders the honest
  observable state rather than an inferred cause.
- Manifest v2 is the sole schema. It serializes raw task, repo availability,
  grouped per-file evidence facts, complete test facts, raw follow-up facts,
  omissions, and explicit no-test-candidate state. Public `render_*` interfaces
  are unchanged.
- Renderer red/green cycles: task containment failed because the raw `##`
  heading escaped Task, then passed at 1 run / 3 assertions; hierarchy/map/
  evidence/run failed with missing How-to-use, then passed at 1 / 24; Scope and
  Follow-ups failed with missing Follow-ups, then passed at 1 / 22; manifest v2
  failed on the v1 top-level key order, then passed at 1 / 24.
- EVAL-9: Markdown containment is most honestly represented by the public
  renderer test because EVAL-5 prefers stable packet/manifest fields over
  parsing prose. The
  stable manifest half is captured by `multiline_task_manifest_v2.yml`; replay
  against version 1 failed at 1 run / 10 assertions (expected 2, actual 1), and
  version 2 passed at 1 run / 31 assertions.
- Frozen Tier 2 packet/prompt artifacts remain historical format-v1 evidence and
  were not regenerated. No dependency or lockfile change. Tier 0 is N/A because
  resolution, callbacks, constants, test candidates, limits, and per-anchor
  classification do not change.

### Strategic review closure (2026-07-13)

The parent independently verified the initial implementation at `142 runs,
1280 assertions, 0 failures, 0 errors, 0 skips`, then confirmed and fixed one
bounded set of blockers. The final clean-context design review is clean with no
findings.

- Renderer test provenance now derives path inference from the semantic
  `test_inferred_by_path` packet uncertainty instead of compiler rule strings.
- Every `OmittedCandidate` carries a `limit_key`; all seven compiler creation
  sites set it, manifest v2 serializes it, and renderer limit prose fetches the
  corresponding `Compiler::LIMITS` value without interpreting category/reason
  prose.
- `view_inferred_by_convention` is emitted once per included view path; the
  Markdown and manifest now name each path specifically.
- Task rendering normalizes CRLF, bare CR, and LF for display only while raw
  `packet.task`/manifest data remains unchanged. Every level-two heading now
  has the proposal's blank line before content.
- EVAL-4/EVAL-6 document optional exact top-level `expect.manifest` checks;
  MAN-1 documents the approved public machine-fact role; active Format-1 terms
  and examples were reconciled. The release-boundary harness rerun remains
  pending explicit user sign-off and was not run.
- Fix-round full suite: `147 runs, 1325 assertions, 0 failures, 0 errors, 0
  skips`.
- Strategic validator: slice-tests, merge-base red/green, and pending-comment
  gate pass. The final clean-context reviewer returned `clean` with zero
  findings and summarized that the public rendering interfaces remain narrow,
  the packet carries the required semantic facts, and the earlier path,
  omission-limit, and view-uncertainty leakage risks are resolved. Warnings
  (verbatim):
  - `rubocop run errored - Lint/Security gate skipped: Error: unrecognized cop or department Metz found in .rubocop.yml`
  - `head metrics unavailable (rubocop run failed); deltas omitted`

## Ruby 3.4 compatibility floor (2026-07-13)

Change type: chore. User task statement: “Make Ruby 3.4 the new floor and I
approve.”

- `ctxpack.gemspec` now requires Ruby 3.4 or newer, and CI pins its single test
  job to that exact floor.
- The CI shape is otherwise unchanged: the full Minitest suite remains the
  gate, and metz-scan remains version-pinned to 0.4.0 and non-blocking.
- Active install, compatibility, proposal, operating-manual, and backlog text
  now names Ruby 3.4. Historical records retain the Ruby versions that were
  actually used at the time.
- No production compiler behavior, dependency, lockfile, frozen experiment
  data, or pre-registration changed. Tier 0 corpus re-scan is N/A.

### Verification

- `ruby -e` loaded `ctxpack.gemspec` and confirmed
  `required_ruby_version=>= 3.4`.
- `gem build ctxpack.gemspec --output /tmp/ctxpack-ruby-floor-check.gem`
  successfully built ctxpack 0.1.0. RubyGems emitted only the existing
  advisory license/homepage metadata warnings.
- Workflow YAML loaded successfully; a semantic check confirmed Ruby 3.4,
  `continue-on-error: true`, and metz-scan 0.4.0.
- Full `bundle exec rake test`: `147 runs, 1325 assertions, 0 failures, 0
  errors, 0 skips` (local Ruby 4.0.1; CI exercises the 3.4 floor after push).

## CLI help and manifest-stdout ergonomics (2026-07-13)

Change type: feature. User task statement: “1. Yes 2. Yes 3. what? I don't
understand 4. Not right now”. In context, items 1 and 2 approved
self-sufficient help and `--stdout=json`; item 3 was only a documentation recipe
for fixed-path regeneration and was left alone; packet verification was
explicitly deferred.

- Bare `--stdout` remains exact rendered Markdown, and
  `--stdout=markdown` makes that selection explicit. `--stdout=json` emits the
  exact public manifest-renderer output, including MAN-2 version 2, without
  creating artifacts.
- The existing stdout invariants apply to both representations: artifact
  options conflict before root discovery or task reads, invalid formats are
  option errors, compilation/rendering completes before output, and success
  contains rendered bytes only.
- Help now names application-root discovery, the distinct path bases for task
  files, output destinations, and displayed success paths, plus pipeline
  examples, output modes, and the `--stdout`/`--out` conflicts.
- The CLI interface stays one mode with a representation parameter rather than
  adding a second machine-output command or a shallow manifest-stdout flag.
- CLI-1a and CLI-10b, `design.md`, README, examples, FAQ, tracker, and tests are
  reconciled. No compiler, packet, renderer, dependency, lockfile,
  fixture-eval, or recorded experiment behavior changed. Tier 0 corpus re-scan
  is N/A.

### Red / green record

- `--stdout=json`: red `1 run, 1 assertion, 1 failure` (status 1 because the
  existing boolean option rejected the argument); green `1 run, 5 assertions,
  0 failures, 0 errors` with exact `Ctxpack.render_manifest` equality and no
  artifact.
- Help completeness: red `1 run, 3 assertions, 1 failure` on the missing
  task-file/stdout pipeline; green `1 run, 18 assertions, 0 failures, 0 errors`
  after the help interface carried pipeline, path, output, and conflict facts.

### Verification

- Focused `test/ctxpack/cli_test.rb`: `60 runs, 464 assertions, 0 failures, 0
  errors, 0 skips`.
- Full `bundle exec rake test`: `151 runs, 1365 assertions, 0 failures, 0
  errors, 0 skips`.
- Strategic validator: slice-tests, merge-base red/green, and pending-comment
  gates passed; lint was skipped. Warnings (verbatim):
  - `rubocop run errored - Lint/Security gate skipped: Error: unrecognized cop or department Metz found in .rubocop.yml`
  - `head metrics unavailable (rubocop run failed); deltas omitted`
- Final clean-context design review: `clean`, zero findings. Reviewer summary:
  “The change cleanly extends the existing stdout mode to select either
  established renderer without adding unnecessary abstraction or leaking
  renderer internals. The new tests constrain exact output, failure ordering,
  compatibility, and mutation-free behavior.”
- `Gemfile.lock` and recorded experiment data are unchanged. Tier 0 corpus
  re-scan is N/A because compilation behavior is unchanged.

## Pass: Phase 0 seed-ontology specs (2026-07-13)

### Scope
- Normative specs only — no `lib/` behavior change.
- New `specs/seeds.md` (SEED-*, MERGE-*).
- Amended `packet-compilation.md` (PIPE-1..3; anchor recipe unchanged).
- Amended `packet-format.md` (FMT-0; v3 policy; seed reason codes; MAN-2 v3 shape).
- Amended `cli.md` (CLI-1d/1e/4b/20; CLI-8/8a seed identity; SEED-10 dispatch from Phase 2).
- `specs/README.md`, `design.md` product definition, README product statement.
- Seed proposal status line updated to point at normative specs.

### Decisions
- Traced every requirement to seed proposal §14 or fixed-by-spec where silent.
- Format v3 replaces v2 at Phase 2 (no compat fork); Phase 1 still emits v2.
- Error demotion-on-spike-fail is normative (SEED-22).
- Inherited acquisition constraints (suggest-only, no confidence, no auto-compile, prose skill-only) locked in SEED-18/19.

### Verification
- Docs-only; suite not required for behavior but will be run before commit to confirm no accidental code touch.

## Pass: Phase 1 seed wrap (2026-07-13)

### Scope
- Internal `Ctxpack::Seed` (`lib/ctxpack/seed.rb`); `Packet#seeds`;
  `Compiler` normalizes `anchor:` / `seeds:` and routes through
  `resolve_anchor_seed`.
- Public `Ctxpack.compile` accepts optional `seeds:`; `anchor:` unchanged.
- Format v2 only: `Packet#to_h` still omits `seeds[]`; Markdown still
  `Format: 2` / `## Anchor`. Packet bytes unchanged for golden paths.
- No new CLI flags.

### Decisions
- Phase 1 rejects non-anchor seeds at compile time (explicit error) so later
  kinds cannot accidentally ship untested.
- View evidence subjects use `packet.anchor` (not a removed `@anchor` ivar).

### Verification
- Red-then-green: `test/ctxpack/seed_test.rb` (4 tests).
- Full suite: `155 runs, 1383 assertions, 0 failures, 0 errors`.
- Tier 0 rescan: byte-identical to `post_amendment` on all three apps
  (1,967 pairs, 0 crashes) — see `eval/tier0/RESULTS.md` Phase 1 addendum.

## Pass: Phase 2 test/files seeds + format v3 (2026-07-13)

### Scope
- Gates: test-seed spike 78.2% (≥70%), files neighbor spike 80.3% (≥40%).
- Format v3 replaces v2: `seeds[]`, `Format: 3`, `## Seeds` + anchor heading
  preserved for anchor seeds.
- `--from-test`, `--from-files`, `--from-anchor`; SEED-10 positional classifier.
- Artifact names use seed identity (CLI-8a).
- Fixture evals: `test_seed_accounts_controller`, `files_seed_accounts_controller`;
  multiline manifest eval rebaselined to v3.
- Work-start corpus authored under `eval/seed-spikes/work-start-corpus.md`.

### Decisions
- Single seed only until Phase 4.
- Test surface heuristics match the pre-registered spike (path → request token →
  constant).
- Files neighbors are existence-gated only.
- CLI-17c still runs before root discovery for non-path, non-anchor tokens.

### Verification
- Full suite: `161 runs, 1455 assertions, 0 failures, 0 errors`.
- Tier 0 rescan: byte-identical to post_amendment, 0 crashes.

## Pass: Phase 3 error seed + Phase 4 multi-seed (2026-07-13)

### Scope
- Error spike pre-reg + RESULTS: P=1.0 R=1.0 → ship `--from-error`.
- Normalize paste to app/lib/config `path:line` only (SEED-20); never raw paste.
- Multi-seed: `Compiler#merge_packets`, CLI accepts multiple `--from-*` (+ positional).
- Fixture evals: `error_seed_accounts_frame`, `multi_seed_test_and_anchor`.

### Decisions
- Stdin single-occupancy: `--from-error -` vs `--task-file -`.
- Multi-seed identity for filenames: join seed identities with `_`, cap 80.
- CLI determinism evals for error/multi still use a primary-seed CLI path;
  full merge is asserted via `Ctxpack.compile` packet expectations.

### Verification
- Full suite: `167 runs, 1530 assertions, 0 failures, 0 errors`.
- Tier 0: byte-identical to post_amendment, 0 crashes.

## Pass: Phase 5a method seed (2026-07-14)

### Scope
- Gate evidence (frozen): `eval/seed-spikes/method/PREREGISTRATION.md` +
  `RESULTS.md` — resolution PASS (82.1%), test-leg precision FAIL (0.6996).
- Ship `--from-method` / SEED-10 rule-4 positional sugar **without** a
  test-candidate expansion leg (SEED-25 demotion).
- Spec amendments: SEED-4 row, SEED-10 rule 4, SEED-25 recipe, SEED-22 table,
  MERGE-4 user-named list, FMT-6 `method_seed_primary`, CLI-1/2/4b/8a, design.md.
- No new FMT-7 uncertainty code (fail-closed resolution does not need one).
- No new LIMITS keys; reuses `max_constant_files` / `max_snippet_lines_per_file` /
  `max_total_files`.

### Implementation
- `Seed.method` factory (singleton; deliberately shadows `Object#method` for
  this class), `method?`, `method_const_and_name`.
- `DefaultConstantResolver#resolve_exact` — CONST-2b path probe with **no**
  segment trimming (evidence constant only).
- `Compiler#resolve_method_seed`: exact resolve → FQN-matched instance def →
  primary snippet (`method_seed_primary`) → CONST-1a-style same-file BFS →
  `referenced_constant` under append-last cap; `no_test_candidates = true`.
- CLI: `--from-method`, SEED-10 rule 4 dispatches method-shaped tokens;
  `*Controller#action` / Test/Spec rules unchanged.
- Markdown inventory for `method_seed_primary`; manifest seeds[] via existing
  `Seed#manifest_hash`.
- Fixtures: `app/services/billing/upgrade_service.rb`,
  `app/models/admin/compact_report.rb`.
- Evals: `method_seed_billing_upgrade`, `method_seed_call_graph_cap`,
  `multi_seed_method_and_anchor`.
- Unit: `test/ctxpack/method_seed_test.rb` (happy path, compact nesting, no
  trimming, fail-closed, `def self.` rejection, BFS cap, CLI flag + sugar).

### Decisions / tradeoffs
- **No test leg** — spike outcome applied without renegotiation; re-promotion
  needs a new pre-reg with better-than-token matching.
- Evidence constant resolution is exact-only; body constants still use the
  normal resolver (with CONST-2c trimming) so expansion matches anchor
  constant behavior.
- Fail closed with coaching messages naming constant/path/def tried — no
  uncertainty code for resolution miss.
- Primary is never counted against `max_constant_files`; callee constants
  append last and cannot evict target-method constants.

### Scope boundaries
- No Tier 0 rescan run in this pass (compiler behavior for anchor path is
  unchanged; method is a new seed branch). Orchestrator may still run the
  corpus re-scan as a pass-boundary gate.
- Did not touch `eval/seed-spikes/`, `eval/tier0/`, or existing anchor
  goldens.
- Did not commit.

### Verification
- Full suite (this session): `185 runs, 1704 assertions, 0 failures, 0 errors`.

## Pass: Phase 5b diff seed (2026-07-14)

### Scope
- Gate evidence (frozen): `eval/seed-spikes/diff/PREREGISTRATION.md` +
  `RESULTS.md` — paired-test agreement PASS (0.810 ≥ 0.70).
- Ship `--from-diff` **with** the paired-test mirror leg (mirror conventions
  only; no basename token matching — 5a lesson).
- Spec amendments: SEED-4/7/10/22/26, MERGE-4, FMT-6 codes
  `diff_seed_primary` / `diff_seed_paired_test`, CLI-1/4b/8a, design.md,
  README.md.
- No new LIMITS keys; reuses `max_total_files`, `max_test_files`,
  `max_snippet_lines_per_file`. Snippet context window matches the error-seed
  ±15 helper (shared `snippet_context_window`).
- No new runtime dependencies. Did not touch `eval/` results or `tmp/`.

### Implementation
- `Seed.diff(evidence, identity:)` — patch basename stem or sanitized range;
  CLI resolves range identity to short-SHA form when git can.
- `Compiler#resolve_diff_seed`:
  - Range: `git diff --name-status -M` + `-U0` hunk lines; fail-closed on
    missing git / non-repo / bad range (FMT-11-style, coaching errors).
  - Patch: `git apply --numstat --summary` (repo-independent) + unified-diff
    hunk parse for post-image lines.
  - Primaries: working-tree-existing paths in git order,
    `diff_seed_primary`; deleted/renamed-away → `diff_files` omitted
    follow-ups.
  - `.rb` snippets: Prism enclosing def when a changed line is inside a
    `DefNode`, else ±15 window; `max_snippet_lines_per_file` truncation.
  - Paired tests for `app/**/*.rb` via controller/general/lib mirror paths
    only → `diff_seed_paired_test` under test-file budget.
- CLI: `--from-diff RANGE|PATCH` explicit-flag-only; positional `.patch`/
  `.diff` stays files seed (SEED-10 rule 6); `path_like_positional?` accepts
  those suffixes so positional classification can reach the files seed.
- Markdown inventory labels for the two new reason codes.
- Fixture: `patches/upgrade_accounts.patch` under minitest_basic.
- Evals: `diff_seed_patch_accounts`, `multi_seed_diff_and_files`.
- Unit: `test/ctxpack/diff_seed_test.rb` (range, patch, delete follow-up,
  paired hit/miss, def vs window snippet, fail-closed, multi-seed, budget,
  CLI flag, positional-not-diff).

### Decisions / tradeoffs
- **No stdin / no positional sugar** for diff — keeps SEED-11 matrix stable
  and avoids SEED-10 rule 6 collision with files seed on real patch paths.
- Pure-deletion ranges produce a packet with omitted follow-ups and no
  primaries (do not raise empty-primary); empty name-status still fails closed.
- Identity for ranges: short-SHA form at CLI when resolvable; Seed factory
  falls back to sanitized evidence for compile-API callers.
- Mirror list matches the frozen spike exactly (controller + general app dir
  + lib); no token flood.

### Scope boundaries
- Anchor compilation path untouched (new seed branch only). Orchestrator may
  still run Tier 0 rescan as pass-boundary SEED-23 gate.
- Did not touch `eval/seed-spikes/`, recorded RESULTS, or commit.

### Verification
- Red first: `diff_seed_test.rb` 16 runs with 11 errors / 5 failures before
  lib/ (Seed.diff undefined / CLI missing flag).
- Full suite (this session): `205 runs, 1834 assertions, 0 failures, 0 errors`.

## Phase 6 — docs/marketing lead with task + seed (2026-07-14)

Docs-only pass (`docs/seed-based-interface-proposal.md` §11 Phase 6). No
`lib/`, no `specs/` changes.

### Scope
- `README.md` — product lead is task+seed; quick-start spreads
  `--from-test` / `--from-error` / `--from-diff` / `--from-files` /
  `--from-method` **before or equal to** anchor; anchor framed as most
  mature seed kind, not identity.
- `docs/examples.md` — same shift; worked Format 3 packets for all shipped
  kinds including Phase 5 method + diff; multi-seed, refusals, reason codes.
- `docs/faq.md` — seed catalog, task-only refusal, route coaching-only with
  spike link, evidence-linked Tier 2 claim only for anchor packets.

### Claims discipline
- Usefulness: only Tier 2 / Tier 2-expansion exploration reduction
  (≥30% median, 3/3 apps); explicit no code-quality claim; new seed kinds
  described as recipe behavior after viability gates, not agent-benefit.
- Real output: excerpts generated from `test/fixtures/apps/minitest_basic`
  (and a temp git app cloned from that fixture for `HEAD~1` / paired-test
  illustration). Method example uses fixture constant
  `Billing::UpgradeService#call` (no `Billing::Upgrade` class in tree).
- Install remains `github: "fuentesjr/ctxpack"`.

### Decisions / tradeoffs
- Format 2 → Format 3 throughout marketing docs (seeds section, version 3
  manifests) to match shipped Phase 2+ output.
- HEAD~1 worked example notes a temp app built from the fixture: the fixture
  tree itself is not a git repo with history, so a pure in-place
  `--from-diff HEAD~1` is not reproducible from the bare fixture path.
  Patch-file example is fully fixture-native
  (`patches/upgrade_accounts.patch`).
- Route FAQ cites `eval/seed-spikes/route/RESULTS.md` (0.243 FAIL) and does
  not imply future ship.

### Verification
- Every documented CLI success and refusal form run against a temp app with
  `config/application.rb` + fixture tree; all OK.
- Full suite (this session, docs-only): `205 runs, 1834 assertions, 0 failures, 0 errors`.
- No test asserts README/examples/faq content; no suite reconciliation needed.
- Not committed (orchestrator owns commit/push).

#### Phase 6 fix round (orchestrator-applied, 2026-07-14)
Two doc-reviewers audited the pass; all claims/commands verified real. Five
excerpt-fidelity fixes applied orchestrator-side (Grok resume was blocked:
background write requires a clean tree and the draft was uncommitted):
diff-range and files-seed excerpts restored to full renderer output
(`Generated from:`/`Scope:` lines, diff SHA regenerated from a real temp
app), task-only refusal excerpts marked as truncated in examples+faq,
README exploration claim reworded to the per-task/per-app pre-registered
bar, and a reproduce-it-yourself setup note added to the examples intro.

## Context-engineering positioning pass (2026-07-15)

Agenticons `coding_worker` implementation; parent session is orchestrator-DRA
and owns independent acceptance.

### Terminology decisions
- Preserve **Task + seed(s) → deterministic context packet** as the first
  product promise.
- Use **local context engineering CLI** as the user-facing category and
  **deterministic context compiler** as the mechanism.
- Define context engineering operationally: deterministically selecting,
  ordering, bounding, and explaining evidence around user-supplied seeds for
  an agent's task. This keeps seed evidence—not task prose—as the selection
  input and covers continuation/review flows such as `--from-diff`.
- Keep Rails explicit as v0 scope/research bet; no language-general, platform,
  autonomous-agent, or newer-seed benefit claim.

### Scope and evidence
- Docs/metadata only: README, gemspec summary, examples, FAQ, design, tracker,
  and these notes. No `lib/`, `exe/`, tests, specs, dependency/version/URI,
  lockfile, CI, eval preregistration/results/recorded-data, or `tmp/` change.
- Corrected the stale “many-file features help less” line from the earlier
  single-app Tier 2 result. Recorded Tier 2 expansion evidence: per-app support
  rule met on 3/3 apps; feature tasks 5/6 with median 58.5% reduction on the
  better exploration metric; bug tasks 0/3. Claims remain offline,
  directional, anchor-seed-only, and do not claim better final code quality.
- Red-green/TDD and Tier 0 corpus re-scan are N/A: no observable or compiler
  behavior changed. No fixture eval applies because this is not a packet bug.

### Delegate verification
- `bundle exec rake test`: **205 runs, 1834 assertions, 0 failures, 0 errors,
  0 skips**.
- Gemspec load validation: `ctxpack 0.1.0`; Ruby `>= 3.4`; runtime dependency
  list exactly `prism`; updated summary loaded successfully.
- `git diff --check`: passed.
- Parent orchestrator-DRA independently reviewed the diff and reran the full
  suite with the same result. Documentation review then corrected the initial
  definition's implication that task prose drives selection and that packets
  only precede new work; it also refreshed the design reconciliation date.
- Uncommitted and unpushed; GitHub metadata draft is report-only.

## Broader context-source issue planning and publication (2026-07-15)

Read-only agenticons investigation (`helper_worker` + `edge_case_analyst`);
the parent orchestrator-DRA verified the repo and git-recon evidence. The user
rejected a single oversized epic, approved the dependency-ordered breakdown,
and signed off on the exact title/body of the two bounded spike tasks before
publication.

### Domain and scope decisions
- A **seed** says where work starts; a **context source** says which evidence
  corpus may enrich the resolved focus. Documentation/history start as bounded
  enrichers, not automatically as new seed kinds.
- First candidate families: repository guidance/architecture docs; focused Git
  history/rationale; repository contracts/configuration; and build/ownership
  metadata. External issues/PRs/CI/telemetry remain deferred.
- `--from-files` can already include a named document as a pointer; the open
  question is deterministic discovery, excerpting, ranking, and budgeting.
- History is a post-v0 hypothesis: `design.md` currently names PR-history
  mining as a v0 non-goal. No behavior/spec change is authorized by the issue.

### git-recon finding
- Do not integrate or parse the current executable. Its interface is capped
  human-readable text with relative-time windows, locale-sensitive ordering,
  no versioned JSON/library API, and no LICENSE file; those conflict with the
  packet determinism/dependency contract.
- Use git-recon concepts and outputs as offline spike evidence. Plain Git is
  the baseline. A passing history spike must decide between typed direct-Git
  facts, optional user evidence, or an upstream stable adapter; it does not
  predetermine implementation.

### Evidence gates
- Freeze one preregistration per source family before labels/measurement and
  record the existing runner considered per `eval/README.md`.
- Score excerpt/fact units with precision primary, incremental task hit/recall,
  distraction, bytes, latency, deterministic replay, staleness/privacy, and
  unavailable-source behavior. Explicit seed primaries may never be evicted.
- Passing retrieval proves viability only. Any agent-benefit claim requires a
  later, separately approved packet-vs-enriched-packet behavioral A/B.
- Non-file facts likely require a typed packet surface and a format/manifest
  version decision; current `Packet`/renderer fields are file/Ruby-snippet
  shaped. That design work begins only for source families that pass.

### Verification / side effects
- Read-only inspection covered current packet/spec/eval seams, all ctxpack
  issues/labels, git-recon history/help/implementation/metadata, and official
  repository-instruction/ownership prior art.
- Published and then verified the approved title, body, `type: task` label,
  and open state of ctxpack
  [#6](https://github.com/fuentesjr/ctxpack/issues/6) and
  [#7](https://github.com/fuentesjr/ctxpack/issues/7).
- Conditional follow-ons remain deliberately unopened: the files-seed
  git-recon mini-epic waits for #6 and any evidence-backed git-recon interface
  issue; remaining seed kinds wait for that tracer; documentation integration
  waits for #7. Any git-recon interface issue requires separate exact-text
  sign-off before publication.
- No spike, compiler change, dependency change, commit, push, or GitHub
  repository-metadata update was performed.

### Execution selection
- Agenticons `planner` recommended #6 before #7: it starts the longer
  dependency chain and front-loads the higher-risk history/interface
  questions. The user selected #6 for execution.
- The user separately authorized a local commit of the already accepted
  context-engineering positioning pass. No push was authorized.
- The next gate is a complete, independently reviewed preregistration draft
  shown to the user for exact sign-off. Measurement and preregistration commit
  remain blocked until that approval.
