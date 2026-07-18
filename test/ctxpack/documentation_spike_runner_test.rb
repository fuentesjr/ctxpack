require "test_helper"
require "fileutils"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../../eval/documentation-spike/run_documentation_spike"

class DocumentationSpikeRunnerTest < Minitest::Test
  FIXTURES = File.expand_path("../../eval/documentation-spike/fixtures", __dir__)

  def test_retrieves_nearest_ancestor_conventional_document
    with_fixture_repository("ancestor") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal ["app/models/user.rb"], result.fetch("focus_paths")
      assert_equal revision, result.fetch("revision")
      assert_equal 1, result.fetch("candidates").length

      candidate = result.fetch("candidates").first
      assert_equal "ancestor_conventional", candidate.fetch("recipe")
      assert_equal "app/models/README.md", candidate.fetch("document_path")
      assert_includes candidate.fetch("excerpt"), "public domain vocabulary"
      refute_includes candidate.fetch("excerpt"), "outside the introduction"
    end
  end

  def test_retrieves_section_that_links_exactly_to_focus
    with_fixture_repository("reverse_link") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal 1, result.fetch("candidates").length
      candidate = result.fetch("candidates").first
      assert_equal "reverse_exact_link", candidate.fetch("recipe")
      assert_equal "docs/models.md", candidate.fetch("document_path")
      assert_equal 5, candidate.fetch("start_line")
      assert_includes candidate.fetch("excerpt"), "owns account lifecycle"
      refute_includes candidate.fetch("excerpt"), "This section is unrelated"
    end
  end

  def test_retrieves_document_section_from_exact_source_comment_reference
    with_fixture_repository("forward_reference") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal 1, result.fetch("candidates").length
      candidate = result.fetch("candidates").first
      assert_equal "forward_exact_reference", candidate.fetch("recipe")
      assert_equal "docs/users.md", candidate.fetch("document_path")
      assert_equal 5, candidate.fetch("start_line")
      assert_includes candidate.fetch("excerpt"), "identifiers are immutable"
      refute_includes candidate.fetch("excerpt"), "Session details"
    end
  end

  def test_retrieves_document_at_mirrored_focus_path
    with_fixture_repository("mirrored_path") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal 1, result.fetch("candidates").length
      candidate = result.fetch("candidates").first
      assert_equal "mirrored_path", candidate.fetch("recipe")
      assert_equal "docs/app/models/user.md", candidate.fetch("document_path")
      assert_includes candidate.fetch("excerpt"), "soft deletion"
      refute_includes candidate.fetch("excerpt"), "outside the introduction"
    end
  end

  def test_counts_but_never_emits_governing_instructions
    with_fixture_repository("governing_instructions") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_empty result.fetch("candidates")
      assert_equal 2, result.fetch("governing_instruction_count")
    end
  end

  def test_retains_only_first_three_candidates_in_frozen_recipe_order
    with_fixture_repository("candidate_cap") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal(
        %w[forward_exact_reference reverse_exact_link mirrored_path],
        result.fetch("candidates").map { |candidate| candidate.fetch("recipe") }
      )
      assert_equal(
        %w[ancestor_conventional forward_exact_reference mirrored_path reverse_exact_link],
        result.fetch("recipe_candidates").keys.sort
      )
      assert result.fetch("recipe_candidates").values.all? { |items| items.length == 1 }
    end
  end

  def test_enforces_per_candidate_and_total_excerpt_byte_budgets_on_whole_lines
    prepare = lambda do |repo|
      %w[docs/forward.md docs/reverse.md docs/app/models/user.md].each do |path|
        heading = "# #{File.basename(path, ".md")}\n\n"
        body = (1..20).map { |index| "line-#{index}-#{"x" * 72}\n" }.join
        File.write(File.join(repo, path), heading + body)
      end
      File.write(
        File.join(repo, "docs/reverse.md"),
        "# reverse\n\n[User](../app/models/user.rb)\n" +
          (1..20).map { |index| "line-#{index}-#{"x" * 72}\n" }.join
      )
    end

    with_fixture_repository("candidate_cap", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      excerpts = result.fetch("candidates").map { |candidate| candidate.fetch("excerpt") }
      assert excerpts.all? { |excerpt| excerpt.bytesize <= 1_024 }
      assert_operator excerpts.sum(&:bytesize), :<=, 2_048
      assert excerpts.all? { |excerpt| excerpt.end_with?("\n") }
    end
  end

  def test_reports_broken_forward_reference_without_emitting_a_candidate
    with_fixture_repository("broken_reference") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_empty result.fetch("candidates")
      assert_equal ["broken_reference"], result.fetch("omissions").map { |item| item.fetch("reason") }
    end
  end

  def test_reports_oversized_and_invalid_utf8_documents_as_typed_omissions
    prepare = lambda do |repo|
      File.binwrite(File.join(repo, "docs/large.md"), "x" * (256 * 1_024 + 1))
      File.binwrite(File.join(repo, "docs/invalid.md"), "# Invalid\n\xFF\n".b)
      File.binwrite(File.join(repo, "docs/binary.md"), "# Binary\n\0payload\n".b)
    end

    with_fixture_repository("unavailable_documents", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal(
        %w[binary_document invalid_utf8 oversized_document],
        result.fetch("omissions").map { |item| item.fetch("reason") }.sort
      )
    end
  end

  def test_reports_documentary_gitlink_as_typed_submodule_omission
    with_fixture_repository("no_candidates") do |repo, revision|
      git!(repo, "update-index", "--add", "--cacheinfo", "160000,#{revision},docs/external.md")
      git!(repo, "commit", "--quiet", "-m", "add gitlink")
      current_revision = git!(repo, "rev-parse", "HEAD").strip

      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: current_revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_includes result.fetch("omissions").map { |item| item.fetch("reason") },
                      "submodule_document"
    end
  end

  def test_extensionless_contributing_is_eligible_but_not_an_ancestor_recipe
    prepare = lambda do |repo|
      File.write(File.join(repo, "app/models/user.rb"), "# See ../../CONTRIBUTING\nclass User\nend\n")
      File.write(File.join(repo, "CONTRIBUTING"), "Contribution workflow\n")
    end

    with_fixture_repository("no_candidates", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal "CONTRIBUTING", result.dig("recipe_candidates", "forward_exact_reference", 0, "document_path")
      assert_empty result.dig("recipe_candidates", "ancestor_conventional")
    end
  end

  def test_matches_extensionless_conventional_document_case_insensitively
    with_fixture_repository("case_insensitive_conventional") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      candidate = result.fetch("candidates").fetch(0)
      assert_equal "ancestor_conventional", candidate.fetch("recipe")
      assert_equal "app/models/readme", candidate.fetch("document_path")
    end
  end

  def test_reports_symlink_document_without_following_it
    prepare = lambda do |repo|
      path = File.join(repo, "docs/link.md")
      File.unlink(path)
      File.symlink("target.txt", path)
    end

    with_fixture_repository("symlink_document", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_includes result.fetch("omissions").map { |item| item.fetch("reason") },
                      "symlink_document"
    end
  end

  def test_fails_closed_when_checkout_head_does_not_match_revision
    with_fixture_repository("ancestor") do |repo, revision|
      git!(repo, "commit", "--quiet", "--allow-empty", "-m", "new head")

      assert_raises(DocumentationSpike::RevisionMismatch) do
        DocumentationSpike.retrieve(
          repo_root: repo,
          revision: revision,
          focus_paths: ["app/models/user.rb"]
        )
      end
    end
  end

  def test_canonical_json_is_replay_stable_and_contains_no_absolute_paths
    with_fixture_repository("reverse_link") do |repo, revision|
      first = DocumentationSpike.canonical_json(
        DocumentationSpike.retrieve(
          repo_root: repo,
          revision: revision,
          focus_paths: ["app/models/user.rb"]
        )
      )
      second = DocumentationSpike.canonical_json(
        DocumentationSpike.retrieve(
          repo_root: repo,
          revision: revision,
          focus_paths: ["app/models/user.rb"]
        )
      )

      assert_equal first, second
      assert first.start_with?("{\"candidates\":")
      assert first.end_with?("\n")
      refute_includes first, repo
    end
  end

  def test_reverse_recipe_emits_each_distinct_linking_section
    with_fixture_repository("multiple_reverse_sections") do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      sections = result.fetch("recipe_candidates").fetch("reverse_exact_link")
      assert_equal [3, 7, 11, 15], sections.map { |candidate| candidate.fetch("start_line") }
      assert_equal 3, result.fetch("candidates").length
    end
  end

  def test_reverse_recipe_ignores_markdown_shaped_links_in_plain_text
    prepare = lambda do |repo|
      FileUtils.mkdir_p(File.join(repo, "docs"))
      File.write(
        File.join(repo, "docs/models.txt"),
        "# User notes\n\n[User](../app/models/user.rb)\n"
      )
    end

    with_fixture_repository("no_candidates", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_empty result.fetch("recipe_candidates").fetch("reverse_exact_link")
    end
  end

  def test_fixed_document_exclusions_do_not_drop_plugin_or_engine_paths
    prepare = lambda do |repo|
      FileUtils.mkdir_p(File.join(repo, "plugins/accounts"))
      File.write(
        File.join(repo, "plugins/accounts/README.md"),
        "# Accounts\n\n[User](../../app/models/user.rb)\n"
      )
    end

    with_fixture_repository("no_candidates", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal "plugins/accounts/README.md",
                   result.dig("recipe_candidates", "reverse_exact_link", 0, "document_path")
    end
  end

  def test_mirrored_candidates_rank_by_document_path_within_focus
    prepare = lambda do |repo|
      %w[app/models/user.md doc/app/models/user.md docs/app/models/user.md].each do |path|
        FileUtils.mkdir_p(File.dirname(File.join(repo, path)))
        File.write(File.join(repo, path), "# #{path}\n")
      end
    end

    with_fixture_repository("no_candidates", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal(
        %w[app/models/user.md doc/app/models/user.md docs/app/models/user.md],
        result.fetch("recipe_candidates").fetch("mirrored_path").map { |candidate| candidate.fetch("document_path") }
      )
    end
  end

  def test_non_markdown_forward_reference_treats_document_as_one_unit
    prepare = lambda do |repo|
      FileUtils.mkdir_p(File.join(repo, "docs"))
      File.write(File.join(repo, "app/models/user.rb"), "# See ../../docs/users.txt#details\nclass User\nend\n")
      File.write(File.join(repo, "docs/users.txt"), "# Intro\nfirst\n# Details\nsecond\n")
    end

    with_fixture_repository("no_candidates", prepare: prepare) do |repo, revision|
      result = DocumentationSpike.retrieve(
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"]
      )

      assert_equal "# Intro\nfirst\n# Details\nsecond\n",
                   result.dig("candidates", 0, "excerpt")
    end
  end

  def test_study_reuses_all_fifteen_pinned_tasks_and_rotates_focus_within_each_app
    tasks = DocumentationSpike::Study.tasks(ctxpack_root: File.expand_path("../..", __dir__))

    assert_equal 15, tasks.length
    redmine = tasks.select { |task| task.app == "redmine" }
    assert_equal [1, 2, 3], redmine.map(&:id)
    assert_equal(
      %w[app/controllers/twofa_controller.rb app/models/user.rb],
      redmine.fetch(0).focus_paths
    )
    assert_equal redmine.fetch(1).focus_paths, redmine.fetch(0).rotated_focus_paths
    assert tasks.all? { |task| File.file?(task.prompt_path) }
    assert tasks.all? { |task| File.file?(task.reference_diff_path) }
  end

  def test_study_generation_builds_stable_provenance_and_blinded_label_rows
    with_fixture_repository("reverse_link") do |repo, revision|
      task = DocumentationSpike::StudyTask.new(
        app: "fixture",
        id: 1,
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"],
        rotated_focus_paths: ["app/models/other.rb"],
        prompt_path: __FILE__,
        focus_artifact_path: __FILE__,
        reference_diff_path: __FILE__
      )

      first = DocumentationSpike::Study.generate(tasks: [task], runner_commit: "a" * 40)
      second = DocumentationSpike::Study.generate(tasks: [task], runner_commit: "a" * 40)

      assert_equal DocumentationSpike.canonical_json(first.bundle),
                   DocumentationSpike.canonical_json(second.bundle)
      assert_equal %w[recipe combined],
                   first.bundle.fetch("candidates").map { |record| record.fetch("population") }
      assert_equal first.bundle.fetch("label_sheet").map { |row| row.fetch("id") }.sort,
                   first.bundle.fetch("label_sheet").map { |row| row.fetch("id") }
      candidate = first.bundle.fetch("candidates").find { |record| record.fetch("population") == "combined" }
      assert_equal "fixture", candidate.fetch("app")
      assert_equal 1, candidate.fetch("task")
      assert_equal "real", candidate.fetch("arm")
      assert_equal revision, candidate.fetch("revision")
      assert_equal 64, candidate.fetch("id").length
      assert_equal true, candidate.fetch("selected_combined")
      assert_equal ["app/models/user.rb"], candidate.fetch("focus_paths")
      assert_equal ["app/models/user.rb"], candidate.fetch("retrieval_focus_paths")

      label_row = first.bundle.fetch("label_sheet").find { |row| row.fetch("id") == candidate.fetch("id") }
      assert_equal candidate.fetch("id"), label_row.fetch("id")
      refute label_row.key?("recipe")
      refute label_row.key?("arm")
      refute label_row.key?("retrieval_focus_paths")
      refute_includes DocumentationSpike.canonical_json(first.bundle), repo
      assert_equal 1, first.bundle.fetch("inventories").length
      assert_equal 2, first.bundle.fetch("retrievals").length
      assert_equal [], first.bundle.fetch("retrievals").first.fetch("omissions")
      assert_equal 3, first.timings.length
      assert_equal %w[inventory retrieval retrieval], first.timings.map { |timing| timing.fetch("kind") }
    end
  end

  def test_study_generation_preserves_combined_truncation_and_recipe_population
    prepare = lambda do |repo|
      body = (1..9).map { |index| "line-#{index}-#{"x" * 80}\n" }.join
      File.write(File.join(repo, "docs/forward.md"), "# Forward\n\n#{body}")
      File.write(File.join(repo, "docs/reverse.md"), "# Reverse\n\n[User](../app/models/user.rb)\n#{body}")
      File.write(File.join(repo, "docs/app/models/user.md"), "# Mirrored\n\n#{body}")
    end

    with_fixture_repository("candidate_cap", prepare: prepare) do |repo, revision|
      task = fixture_study_task(repo, revision, rotated_focus_paths: ["app/models/user.rb"])
      run = DocumentationSpike::Study.generate(tasks: [task], runner_commit: "a" * 40)
      real = run.bundle.fetch("candidates").select { |candidate| candidate.fetch("arm") == "real" }
      combined = real.select { |candidate| candidate.fetch("population") == "combined" }
      recipes = real.select { |candidate| candidate.fetch("population") == "recipe" }

      assert_equal 3, combined.length
      assert_operator combined.sum { |candidate| candidate.fetch("excerpt").bytesize }, :<=, 2_048
      assert combined.any? { |candidate| candidate.fetch("truncated") }
      assert_operator recipes.length, :>, combined.length
    end
  end

  def test_rotated_label_rows_keep_original_oracle_focus_and_hide_retrieval_focus
    with_fixture_repository("reverse_link") do |repo, revision|
      task = fixture_study_task(
        repo,
        revision,
        focus_paths: ["app/models/other.rb"],
        rotated_focus_paths: ["app/models/user.rb"]
      )
      run = DocumentationSpike::Study.generate(tasks: [task], runner_commit: "a" * 40)
      rotated = run.bundle.fetch("candidates").find do |candidate|
        candidate.fetch("arm") == "rotated" && candidate.fetch("population") == "combined"
      end
      label_row = run.bundle.fetch("label_sheet").find { |row| row.fetch("id") == rotated.fetch("id") }

      assert_equal ["app/models/other.rb"], rotated.fetch("focus_paths")
      assert_equal ["app/models/user.rb"], rotated.fetch("retrieval_focus_paths")
      assert_equal ["app/models/other.rb"], label_row.fetch("focus_paths")
      refute label_row.key?("retrieval_focus_paths")
    end
  end

  def test_generate_command_writes_canonical_unlabeled_artifacts
    with_fixture_repository("reverse_link") do |repo, revision|
      task = DocumentationSpike::StudyTask.new(
        app: "fixture",
        id: 1,
        repo_root: repo,
        revision: revision,
        focus_paths: ["app/models/user.rb"],
        rotated_focus_paths: ["app/models/other.rb"],
        prompt_path: __FILE__,
        focus_artifact_path: __FILE__,
        reference_diff_path: __FILE__
      )
      Dir.mktmpdir("ctxpack-documentation-output-") do |output_dir|
        stdout = StringIO.new
        status = DocumentationSpike::Runner.run(
          ["generate", output_dir],
          stdout: stdout,
          tasks_loader: -> { [task] },
          runner_guard: -> { "a" * 40 }
        )

        assert_equal 0, status
        candidates = JSON.parse(File.read(File.join(output_dir, "candidates.json")))
        label_sheet = JSON.parse(File.read(File.join(output_dir, "label-sheet.json")))
        timings = JSON.parse(File.read(File.join(output_dir, "timings.json")))
        replay = JSON.parse(File.read(File.join(output_dir, "replay.json")))
        refute candidates.key?("label_sheet")
        assert_equal 2, candidates.fetch("candidates").length
        assert_equal 2, label_sheet.length
        assert_equal 3, timings.length
        assert_equal "a" * 40, replay.fetch("runner_commit")
        assert_equal 36, replay.fetch("invocation_id").length
        assert_equal "generated 2 candidates\n", stdout.string
      end
    end
  end

  def test_self_check_command_reports_success_without_subject_repositories
    stdout = StringIO.new

    status = DocumentationSpike::Runner.run(
      ["self-check"],
      stdout: stdout,
      fixtures_root: FIXTURES
    )

    assert_equal 0, status
    assert JSON.parse(stdout.string).fetch("pass")
  end

  def test_runner_provenance_rejects_uncommitted_measurement_sources
    Dir.mktmpdir("ctxpack-runner-provenance-") do |root|
      runner_path = File.join(root, "eval/documentation-spike/run_documentation_spike.rb")
      FileUtils.mkdir_p(File.dirname(runner_path))
      File.write(runner_path, "# committed\n")
      git!(root, "init", "--quiet")
      git!(root, "add", ".")
      git!(root, "-c", "user.name=ctxpack", "-c", "user.email=ctxpack@example.invalid",
           "commit", "--quiet", "-m", "runner")
      revision = git!(root, "rev-parse", "HEAD").strip

      assert_equal revision, DocumentationSpike::Study.committed_runner_revision!(ctxpack_root: root)

      File.write(runner_path, "# modified\n")
      assert_raises(DocumentationSpike::UncommittedRunner) do
        DocumentationSpike::Study.committed_runner_revision!(ctxpack_root: root)
      end
    end
  end

  def test_score_command_writes_raw_results_gate_summary_and_results_markdown
    inputs = passing_score_inputs
    Dir.mktmpdir("ctxpack-documentation-score-") do |output_dir|
      candidates_path = File.join(output_dir, "candidates.json")
      File.write(candidates_path, DocumentationSpike.canonical_json(inputs.fetch(:bundle)))
      File.write(File.join(output_dir, "labels.json"), DocumentationSpike.canonical_json(inputs.fetch(:labels)))
      File.write(File.join(output_dir, "timings.json"), DocumentationSpike.canonical_json(inputs.fetch(:timings)))
      replay_paths = inputs.fetch(:replays).each_with_index.map do |replay, index|
        path = File.join(output_dir, "replay-#{index}")
        FileUtils.mkdir_p(path)
        FileUtils.cp(candidates_path, File.join(path, "candidates.json"))
        File.write(File.join(path, "replay.json"), DocumentationSpike.canonical_json(replay))
        path
      end
      stdout = StringIO.new

      status = DocumentationSpike::Runner.run(
        ["score", output_dir, *replay_paths],
        stdout: stdout,
        fixtures_root: FIXTURES,
        runner_guard: -> { "a" * 40 }
      )

      assert_equal 0, status
      assert_equal "proceed\n", stdout.string
      assert_equal "proceed", JSON.parse(File.read(File.join(output_dir, "results/result.json"))).fetch("verdict")
      assert JSON.parse(File.read(File.join(output_dir, "results/summary.json"))).fetch("ship")
      assert JSON.parse(File.read(File.join(output_dir, "results/app0.json"))).dig("metrics", "rotated_combined")
      assert_includes File.read(File.join(output_dir, "RESULTS.md")), "**Verdict: PROCEED**"
    end
  end

  def test_scoring_applies_frozen_gates_and_returns_proceed_for_passing_evidence
    result = DocumentationSpike::Study.score(**passing_score_inputs)

    assert_equal "proceed", result.fetch("verdict")
    assert_in_delta 5.0 / 15, result.dig("metrics", "combined", "incremental_task_hit_rate")
    assert_equal 0.0, result.dig("metrics", "combined", "distraction_rate")
    assert_in_delta 0.5, result.dig("metrics", "per_app", "app0", "task_hit_rate")
    assert_equal({"median" => 0, "p95" => 1, "maximum" => 1},
                 result.dig("metrics", "budget", "selected_candidates"))
    assert_equal 10.0, result.dig("metrics", "latency", "median_ms")
    assert_equal 10.0, result.dig("metrics", "latency", "p95_ms")
    assert_equal 10.0, result.dig("metrics", "latency", "max_ms")
    assert_equal %w[app0 app1 app2 app3], result.dig("metrics", "rotated_per_app").keys.sort
    assert_equal(
      %w[ancestor_conventional forward_exact_reference mirrored_path reverse_exact_link],
      result.dig("metrics", "rotated_per_recipe").keys.sort
    )
    assert result.fetch("gates").values.all? { |gate| gate.fetch("pass") }
  end

  def test_scoring_retains_apps_with_empty_candidate_denominators
    inputs = passing_score_inputs
    removed = inputs.dig(:bundle, "candidates").find { |candidate| candidate.fetch("app") == "app3" }
    inputs.dig(:bundle, "candidates").delete(removed)
    inputs.fetch(:labels).delete(removed.fetch("id"))
    bundle_hash = Digest::SHA256.hexdigest(DocumentationSpike.canonical_json(inputs.fetch(:bundle)))
    inputs.fetch(:replays).each { |replay| replay["candidate_sha256"] = bundle_hash }

    result = DocumentationSpike::Study.score(**inputs)

    assert_equal 0, result.dig("metrics", "per_app", "app3", "candidates")
    assert_nil result.dig("metrics", "per_app", "app3", "precision")
  end

  def test_scoring_reports_typed_omissions_and_primary_changes
    inputs = passing_score_inputs
    inputs.dig(:bundle, "retrievals").first["omissions"] = [
      {"reason" => "broken_reference", "reference" => "docs/missing.md"}
    ]
    inputs.dig(:bundle, "retrievals").first["primary_preserved"] = false

    result = DocumentationSpike::Study.score(**inputs)

    assert_equal 1, result.dig("metrics", "availability", "counts", "broken_reference")
    assert_equal 1, result.dig("metrics", "availability", "samples", "broken_reference").length
    assert_equal 1, result.dig("metrics", "safety", "primary_changes")
    refute result.dig("gates", "safety", "pass")
    assert_equal "defer", result.fetch("verdict")
  end

  def test_synthetic_self_check_exercises_every_frozen_control
    result = DocumentationSpike::Study.self_check(fixtures_root: FIXTURES)

    assert result.fetch("pass")
    assert_equal(
      %w[
        broken_reference candidate_and_byte_caps governing_instruction_excluded
        no_candidates unavailable_documents
      ],
      result.fetch("controls").keys.sort
    )
    assert result.fetch("controls").values.all? { |control| control.fetch("pass") }
  end

  def test_scoring_rejects_labels_outside_frozen_taxonomy
    inputs = passing_score_inputs
    first_id = inputs.fetch(:labels).keys.first
    inputs.fetch(:labels).fetch(first_id)["label"] = "interesting"

    assert_raises(DocumentationSpike::LabelError) do
      DocumentationSpike::Study.score(**inputs)
    end
  end

  def test_determinism_gate_requires_replays_to_match_scored_bundle
    inputs = passing_score_inputs
    inputs.fetch(:replays).each { |replay| replay["candidate_sha256"] = "f" * 64 }

    result = DocumentationSpike::Study.score(**inputs)

    refute result.dig("gates", "determinism", "pass")
    assert_equal "defer", result.fetch("verdict")
  end

  def test_determinism_gate_requires_distinct_replay_invocations
    inputs = passing_score_inputs
    inputs.fetch(:replays).last["invocation_id"] = inputs.fetch(:replays).first.fetch("invocation_id")

    result = DocumentationSpike::Study.score(**inputs)

    refute result.dig("gates", "determinism", "pass")
    assert_equal "defer", result.fetch("verdict")
  end

  def test_incremental_precision_counts_candidates_not_distinct_tasks
    inputs = passing_score_inputs
    original = inputs.dig(:bundle, "candidates").first
    duplicate_task_candidate = original.merge(
      "id" => Digest::SHA256.hexdigest("second-candidate-same-task"),
      "document_path" => "docs/second.md"
    )
    inputs.dig(:bundle, "candidates") << duplicate_task_candidate
    inputs.fetch(:labels)[duplicate_task_candidate.fetch("id")] = {
      "label" => "relevant_unique",
      "rationale" => "second task-relevant document",
      "truncation_hid_context" => false
    }

    result = DocumentationSpike::Study.score(**inputs)

    assert_equal 1.0, result.dig("metrics", "combined", "incremental_precision")
  end

  private

  def fixture_study_task(repo, revision, focus_paths: ["app/models/user.rb"],
                         rotated_focus_paths: ["app/models/other.rb"])
    DocumentationSpike::StudyTask.new(
      app: "fixture",
      id: 1,
      repo_root: repo,
      revision: revision,
      focus_paths: focus_paths,
      rotated_focus_paths: rotated_focus_paths,
      prompt_path: __FILE__,
      focus_artifact_path: __FILE__,
      reference_diff_path: __FILE__
    )
  end

  def passing_score_inputs
    tasks = (1..15).map do |id|
      {"app" => "app#{(id - 1) % 4}", "task" => id, "revision" => "a" * 40}
    end
    candidates = tasks.first(5).map do |task|
      id = Digest::SHA256.hexdigest("candidate-#{task.fetch("task")}")
      {
        "id" => id,
        "app" => task.fetch("app"),
        "task" => task.fetch("task"),
        "arm" => "real",
        "population" => "combined",
        "revision" => task.fetch("revision"),
        "recipe" => "reverse_exact_link",
        "focus_paths" => ["app/models/user.rb"],
        "retrieval_focus_paths" => ["app/models/user.rb"],
        "document_path" => "docs/user.md",
        "start_line" => 1,
        "end_line" => 2,
        "excerpt" => "# User\n",
        "excerpt_sha256" => Digest::SHA256.hexdigest("# User\n"),
        "resolved_reference" => "app/models/user.rb",
        "selected_combined" => true,
        "truncated" => false,
        "oracle_hashes" => {
          "prompt_sha256" => "b" * 64,
          "focus_artifact_sha256" => "c" * 64,
          "reference_diff_sha256" => "d" * 64
        }
      }
    end
    labels = candidates.to_h do |candidate|
      [
        candidate.fetch("id"),
        {
          "label" => "relevant_unique",
          "rationale" => "task guidance",
          "truncation_hid_context" => false
        }
      ]
    end
    timings = tasks.flat_map do |task|
      %w[real rotated].map do |arm|
        {"app" => task.fetch("app"), "task" => task.fetch("task"), "arm" => arm, "elapsed_ms" => 10.0}
      end
    end
    retrievals = tasks.flat_map do |task|
      %w[real rotated].map do |arm|
        selected = arm == "real" && task.fetch("task") <= 5 ? 1 : 0
        {
          "app" => task.fetch("app"),
          "task" => task.fetch("task"),
          "arm" => arm,
          "revision" => task.fetch("revision"),
          "focus_paths" => ["app/models/user.rb"],
          "primary_preserved" => true,
          "governing_instruction_count" => 0,
          "omissions" => [],
          "selected_candidates" => selected,
          "selected_excerpt_bytes" => selected * "# User\n".bytesize
        }
      end
    end

    bundle = {
      "runner_commit" => "a" * 40,
      "tasks" => tasks,
      "retrievals" => retrievals,
      "candidates" => candidates
    }
    bundle_hash = Digest::SHA256.hexdigest(DocumentationSpike.canonical_json(bundle))
    {
      bundle: bundle,
      labels: labels,
      timings: timings,
      replays: [
        {
          "invocation_id" => "00000000-0000-4000-8000-000000000001",
          "runner_commit" => "a" * 40,
          "candidate_sha256" => bundle_hash,
          "locale" => "C",
          "timezone" => "UTC"
        },
        {
          "invocation_id" => "00000000-0000-4000-8000-000000000002",
          "runner_commit" => "a" * 40,
          "candidate_sha256" => bundle_hash,
          "locale" => "C.UTF-8",
          "timezone" => "America/Los_Angeles"
        },
        {
          "invocation_id" => "00000000-0000-4000-8000-000000000003",
          "runner_commit" => "a" * 40,
          "candidate_sha256" => bundle_hash,
          "locale" => "C",
          "timezone" => "UTC"
        }
      ],
      synthetic_controls: {"pass" => true, "controls" => {"fixture" => {"pass" => true}}}
    }
  end

  def with_fixture_repository(name, prepare: nil)
    Dir.mktmpdir("ctxpack-documentation-spike-") do |repo|
      FileUtils.cp_r(File.join(FIXTURES, name, "."), repo)
      prepare&.call(repo)
      git!(repo, "init", "--quiet")
      git!(repo, "add", ".")
      git!(repo, "-c", "user.name=ctxpack", "-c", "user.email=ctxpack@example.invalid",
           "commit", "--quiet", "-m", "fixture")
      revision = git!(repo, "rev-parse", "HEAD").strip
      yield repo, revision
    end
  end

  def git!(repo, *args)
    stdout, stderr, status = Open3.capture3("git", "-C", repo, *args)
    assert status.success?, stderr
    stdout
  end
end
