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
- `LIMITS[:max_total_files]` is enforced at the end of compilation. It is unreachable by current v0 categories (1 controller + 4 constants + 2 tests = 7) but remains an outer safety invariant for future evidence categories.

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
- LIM-1: `LimitsTest#test_lim_1_v0_limits_are_internal_constants`, `PacketObjectTest#test_man_2_det_2_packet_object_exposes_manifest_shape_and_file_order`; max-total enforcement is guarded in code and untested because it is unreachable by v0 construction.
- LIM-2: `LimitsTest#test_const_4_lim_1_lim_2_truncates_constant_files_in_first_reference_order`, `TestCandidatesTest#test_test_2_lim_2_truncates_test_candidates_and_records_omissions`, `LimitsTest#test_lim_4_truncates_long_action_and_names_dropped_callback_snippets`
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

## Tier 0 spike (2026-07-05)

- Driver lives in `eval/tier0/` (`extract_routes.rb`, `classify_anchors.rb`); results and rationale in `eval/tier0/RESULTS.md`. Not part of the gem or CI.
- Key extraction decisions: stubbed `routes.rb` eval with the app's own pinned actionpack (no app boot, per eval-plan's documented fallback); routes drawn as production env; unique-per-call stub stringification plus an `add_route` name-sanitizing shim, because stub-derived route names otherwise collide or fail validation; `SpikeStub#+` must return a real String — `Mapper#map_match` silently drops paths that are neither String nor Symbol (cost one debugging round on Zammad, 147→596 pairs).
- Verification: 45 randomly sampled "resolved" anchors independently re-checked by grep (0 false positives); every inherited/concern label carries the file that satisfied the chase; `rake test` still 20 runs / 0 failures.
- Scope boundary: spike classifies anchors only; no lib/ changes. The two candidate ANCH amendments it surfaced are tracked in PROJECT_TRACKER next steps, not implemented.
