require "test_helper"
require "ctxpack/cli"
require "fileutils"
require "json"
require "open3"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  def test_no_arguments_prints_help_and_returns_success
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli([], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_equal "", result.stderr
    end
  end

  def test_version_flags_print_version_without_discovering_a_rails_app
    Dir.mktmpdir("ctxpack-version") do |cwd|
      long = run_cli(["--version"], cwd: cwd)
      short = run_cli(["-v"], cwd: cwd)

      assert_equal 0, long.status
      assert_equal "ctxpack #{Ctxpack::VERSION}\n", long.stdout
      assert_equal "", long.stderr
      assert_equal 0, short.status
      assert_equal long.stdout, short.stdout
      assert_equal "", short.stderr
    end
  end

  def test_top_level_help_uses_injected_stdout_and_returns_success
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["--help"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "--manifest"
      assert_equal "", result.stderr
    end
  end

  def test_help_describes_the_golden_path_options_defaults_and_examples
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["--help"], cwd: cwd)

      assert_includes result.stdout, "Generate a deterministic Rails context packet."
      assert_includes result.stdout, "ctxpack accounts#upgrade -t"
      assert_includes result.stdout, "ctxpack packet accounts#upgrade --task"
      assert_includes result.stdout, "-d, --dir DIR"
      assert_includes result.stdout, "Default: .ctxpack/"
      assert_includes result.stdout, "-o, --out PATH"
      assert_includes result.stdout, "-f, --force"
      assert_includes result.stdout, "Also write a sibling JSON manifest"
      assert_includes result.stdout, "-v, --version"
      assert_includes result.stdout, "top-level only"
    end
  end

  def test_help_explains_pipelines_path_bases_output_modes_and_conflicts
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["--help"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, "--task-file - --stdout"
      assert_includes result.stdout, "--stdout=json"
      assert_includes result.stdout, "Run from any Rails app subdirectory"
      assert_includes result.stdout, "Task-file paths are relative to the invocation directory"
      assert_includes result.stdout, "Output destinations are relative to the Rails application root"
      assert_includes result.stdout, "Saved paths are printed relative to the invocation directory"
      assert_includes result.stdout, "--stdout conflicts with --dir, --out, --name, --force, and --manifest"
      assert_includes result.stdout, "--out conflicts with --dir and --name"
      assert_equal "", result.stderr
    end
  end

  def test_top_level_short_help_returns_success
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["-h"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "--manifest"
      assert_includes result.stdout, "--task-file PATH"
      assert_includes result.stdout, "--stdout"
      assert_equal "", result.stderr
    end
  end

  def test_packet_help_uses_injected_stdout_without_exiting
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = nil
      exit_error = begin
        result = run_cli(["packet", "--help"], cwd: cwd)
        nil
      rescue SystemExit => error
        error
      end

      assert_nil exit_error
      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "--task TASK"
      assert_includes result.stdout, "--manifest"
      assert_equal "", result.stderr
    end
  end

  def test_packet_short_help_uses_injected_stdout_without_exiting
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = nil
      exit_error = begin
        result = run_cli(["packet", "-h"], cwd: cwd)
        nil
      rescue SystemExit => error
        error
      end

      assert_nil exit_error
      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "--manifest"
      assert_equal "", result.stderr
    end
  end

  def test_packet_help_after_anchor_uses_injected_stdout_without_exiting
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = nil
      exit_error = nil
      global_stdout, global_stderr = capture_io do
        exit_error = begin
          result = run_cli(["packet", "accounts#upgrade", "--help"], cwd: cwd)
          nil
        rescue SystemExit => error
          error
        end
      end

      assert_nil exit_error
      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_equal "", result.stderr
      assert_equal "", global_stdout
      assert_equal "", global_stderr
    end
  end

  def test_direct_anchor_help_uses_injected_stdout_without_discovering_a_rails_app
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["accounts#upgrade", "--help"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_equal "", result.stderr
    end
  end

  def test_packet_discovers_root_from_nested_cwd_and_writes_default_artifact
    with_cli_app do |app_root|
      nested_cwd = File.join(app_root, "app", "controllers")

      result = run_cli(
        ["packet", "accounts#upgrade", "--task", "Implement billing upgrade"],
        cwd: nested_cwd,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      artifact = File.join(app_root, ".ctxpack", "20260527143015_implement_billing_upgrade_accounts_upgrade.md")
      assert_equal 0, result.status
      assert File.file?(artifact), "expected #{artifact} to be written"
      assert_includes File.read(artifact), "## Task\n\n> Implement billing upgrade\n\n"
      refute_includes File.read(artifact), "20260527143015"
      assert_includes result.stdout, ".ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md"
      assert_equal "", result.stderr
    end
  end

  def test_direct_anchor_shorthand_and_short_task_flag_write_a_packet
    with_cli_app do |app_root|
      result = run_cli(
        ["accounts#upgrade", "-t", "Implement billing upgrade"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      artifact = File.join(app_root, ".ctxpack", "20260527143015_implement_billing_upgrade_accounts_upgrade.md")
      assert_equal 0, result.status
      assert File.file?(artifact)
      assert_includes File.read(artifact), "## Task\n\n> Implement billing upgrade\n\n"
      assert_equal [".ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md"], result.stdout.lines.map(&:chomp)
    end
  end

  def test_task_file_reads_from_injected_stdin_and_removes_one_final_line_ending
    with_cli_app do |app_root|
      result = run_cli(
        ["accounts#upgrade", "--task-file", "-"],
        cwd: app_root,
        stdin: "First line\nSecond line\n\n"
      )

      assert_equal 0, result.status
      artifact = Dir[File.join(app_root, ".ctxpack", "*.md")].fetch(0)
      assert_includes File.binread(artifact), "## Task\n\n> First line\n> Second line\n\n"
      assert_includes File.basename(artifact), "first_line_second_line_accounts_upgrade"
    end
  end

  def test_task_and_task_file_conflict_in_either_order_before_reading_or_root_discovery
    Dir.mktmpdir("ctxpack-task-conflict") do |cwd|
      first = run_cli(["accounts#upgrade", "--task", "", "--task-file", "missing.md"], cwd: cwd)
      second = run_cli(["packet", "--task-file", "-", "--task", "work", "accounts#upgrade"], cwd: cwd)

      [first, second].each do |result|
        assert_equal 1, result.status
        assert_includes result.stderr, "--task cannot be combined with --task-file"
        refute_includes result.stderr, "searched upward"
        refute_includes result.stderr, "could not read"
        assert_equal "", result.stdout
      end
    end
  end

  def test_task_file_path_is_invocation_relative_and_removes_one_final_crlf
    with_cli_app do |app_root|
      nested = File.join(app_root, "app", "controllers")
      File.binwrite(File.join(nested, "task.md"), "First\r\nSecond\r\n\r\n")

      result = run_cli(["accounts#upgrade", "--task-file", "task.md", "--out", "packet.md"], cwd: nested)

      assert_equal 0, result.status
      assert_includes File.binread(File.join(app_root, "packet.md")), "## Task\n\n> First\n> Second\n\n"
    end
  end

  def test_missing_and_directory_task_files_fail_concisely_without_usage
    with_cli_app do |app_root|
      missing = run_cli(["accounts#upgrade", "--task-file", "notes/missing.md"], cwd: app_root)
      directory = run_cli(["accounts#upgrade", "--task-file", "app"], cwd: app_root)

      assert_equal 1, missing.status
      assert_includes missing.stderr, "could not read task file notes/missing.md"
      refute_includes missing.stderr, "Usage:"
      assert_equal "", missing.stdout
      assert_equal 1, directory.status
      assert_includes directory.stderr, "could not read task file app"
      refute_includes directory.stderr, "Usage:"
      assert_equal "", directory.stdout
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_unreadable_task_file_fails_concisely
    with_cli_app do |app_root|
      path = File.join(app_root, "task.md")
      File.write(path, "secret")
      File.chmod(0o000, path)

      result = run_cli(["accounts#upgrade", "--task-file", "task.md"], cwd: app_root)

      assert_equal 1, result.status
      assert_includes result.stderr, "could not read task file task.md: Permission denied"
      refute_includes result.stderr, "Usage:"
      assert_equal "", result.stdout
    ensure
      File.chmod(0o600, path) if path && File.exist?(path)
    end
  end

  def test_injected_stdin_read_failure_is_concise_and_does_not_create_output
    with_cli_app do |app_root|
      stdout = StringIO.new
      stderr = StringIO.new
      stdin = Object.new
      stdin.define_singleton_method(:read) { raise IOError, "stream closed" }

      status = Ctxpack::CLI.new(
        stdin: stdin,
        stdout: stdout,
        stderr: stderr,
        cwd: app_root,
        clock: -> { Time.utc(2026, 5, 27, 14, 30, 15) }
      ).run(["accounts#upgrade", "--task-file", "-"])

      assert_equal 1, status
      assert_equal "", stdout.string
      assert_equal "ctxpack: could not read task from stdin: stream closed\n", stderr.string
      refute_includes stderr.string, "Usage:"
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_help_wins_over_conflicts_and_malformed_rails_inputs_in_any_position
    Dir.mktmpdir("ctxpack-help-wins") do |cwd|
      result = run_cli(["packet", "POST", "/accounts/:id/upgrade", "--stdout", "--manifest", "--help"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_equal "", result.stderr
    end
  end

  def test_stdout_emits_only_rendered_markdown_without_creating_artifacts
    with_cli_app do |app_root|
      result = run_cli(["accounts#upgrade", "--task", "Ship it", "--stdout"], cwd: app_root)
      explicit = run_cli(["accounts#upgrade", "--task", "Ship it", "--stdout=markdown"], cwd: app_root)

      assert_equal 0, result.status
      expected = Ctxpack.render_markdown(Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade", task: "Ship it"))
      assert_equal expected, result.stdout
      assert_equal "", result.stderr
      assert_equal 0, explicit.status
      assert_equal expected, explicit.stdout
      assert_equal "", explicit.stderr
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_stdout_json_emits_only_rendered_manifest_without_creating_artifacts
    with_cli_app do |app_root|
      result = run_cli(["accounts#upgrade", "--task", "Ship it", "--stdout=json"], cwd: app_root)

      assert_equal 0, result.status
      expected = Ctxpack.render_manifest(Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade", task: "Ship it"))
      assert_equal expected, result.stdout
      assert_equal 2, JSON.parse(result.stdout).fetch("version")
      assert_equal "", result.stderr
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_stdout_rejects_unknown_format_before_root_discovery
    Dir.mktmpdir("ctxpack-stdout-format") do |cwd|
      result = run_cli(["accounts#upgrade", "--stdout=yaml"], cwd: cwd)

      assert_equal 1, result.status
      assert_includes result.stderr, "invalid argument: --stdout=yaml"
      refute_includes result.stderr, "searched upward"
      assert_equal "", result.stdout
    end
  end

  def test_stdout_json_rejects_artifact_options_before_task_reads_or_root_discovery
    Dir.mktmpdir("ctxpack-stdout-json-conflict") do |cwd|
      result = run_cli(
        ["accounts#upgrade", "--stdout=json", "--task-file", "missing.md", "--manifest"],
        cwd: cwd
      )

      assert_equal 1, result.status
      assert_includes result.stderr, "--stdout cannot be combined with --manifest"
      refute_includes result.stderr, "could not read task file"
      refute_includes result.stderr, "searched upward"
      assert_equal "", result.stdout
    end
  end

  def test_task_file_stdin_and_stdout_compose_to_exact_rendered_markdown
    with_cli_app do |app_root|
      task_input = "First line\nSecond line\n"
      expected = Ctxpack.render_markdown(
        Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade", task: "First line\nSecond line")
      )

      result = run_cli(
        ["accounts#upgrade", "--task-file", "-", "--stdout"],
        cwd: app_root,
        stdin: task_input
      )

      assert_equal 0, result.status
      assert_equal expected, result.stdout
      assert_equal "", result.stderr
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_stdout_rejects_every_artifact_option_before_task_reads_or_root_discovery
    Dir.mktmpdir("ctxpack-stdout-conflicts") do |cwd|
      {
        "--dir" => ["--dir", "docs"],
        "--out" => ["--out", "packet.md"],
        "--name" => ["--name", "packet"],
        "--force" => ["--force"],
        "--manifest" => ["--manifest"]
      }.each do |flag, arguments|
        result = run_cli(["accounts#upgrade", "--stdout", "--task-file", "missing.md", *arguments], cwd: cwd)

        assert_equal 1, result.status
        assert_includes result.stderr, "--stdout cannot be combined with #{flag}"
        refute_includes result.stderr, "could not read task file"
        refute_includes result.stderr, "searched upward"
        assert_equal "", result.stdout
      end
    end
  end

  def test_stdout_rejects_short_artifact_aliases_before_discovery
    Dir.mktmpdir("ctxpack-stdout-short-conflicts") do |cwd|
      [
        ["--dir", ["-d", "docs"]],
        ["--out", ["-o", "packet.md"]],
        ["--force", ["-f"]]
      ].each do |canonical_flag, arguments|
        result = run_cli(["accounts#upgrade", "--stdout", *arguments], cwd: cwd)

        assert_equal 1, result.status
        assert_includes result.stderr, "--stdout cannot be combined with #{canonical_flag}"
        refute_includes result.stderr, "searched upward"
        assert_equal "", result.stdout
      end
    end
  end

  def test_stdout_stays_empty_when_compilation_fails
    with_cli_app do |app_root|
      result = run_cli(["missing_accounts#upgrade", "--stdout"], cwd: app_root)

      assert_equal 1, result.status
      assert_equal "", result.stdout
      assert_includes result.stderr, "expected controller file does not exist"
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_packet_prints_paths_relative_to_the_invocation_directory
    with_cli_app do |app_root|
      nested_cwd = File.join(app_root, "app", "controllers")

      result = run_cli(
        ["packet", "accounts#upgrade", "--name", "billing_upgrade"],
        cwd: nested_cwd,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      assert_equal 0, result.status
      printed_path = result.stdout.lines.fetch(0).chomp
      assert_equal "../../.ctxpack/20260527143015_billing_upgrade.md", printed_path
      assert_equal(
        File.join(app_root, ".ctxpack", "20260527143015_billing_upgrade.md"),
        File.expand_path(printed_path, nested_cwd)
      )
    end
  end

  def test_packet_normalizes_explicit_camel_case_name
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--name", "BillingUpgrade"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      assert_equal 0, result.status
      assert File.file?(File.join(app_root, ".ctxpack", "20260527143015_billing_upgrade.md"))
      assert_includes result.stdout, ".ctxpack/20260527143015_billing_upgrade.md"
    end
  end

  def test_packet_rejects_invalid_explicit_name
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--name", "billing-upgrade"],
        cwd: app_root
      )

      assert_equal 1, result.status
      assert_includes result.stderr, "--name must contain only letters, numbers, and underscores"
      refute Dir.exist?(File.join(app_root, ".ctxpack"))
    end
  end

  def test_packet_caps_derived_name_at_80_characters_without_losing_anchor
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--task", "a" * 100],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      expected_name = "#{"a" * 63}_accounts_upgrade"
      assert_equal 0, result.status
      assert_equal 80, expected_name.length
      assert File.file?(File.join(app_root, ".ctxpack", "20260527143015_#{expected_name}.md"))
    end
  end

  def test_packet_trims_separator_runs_at_truncated_task_boundary
    with_cli_app do |app_root|
      task = "#{"a" * 62} #{"b" * 10}"
      result = run_cli(
        ["packet", "accounts#upgrade", "--task", task],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      expected_name = "#{"a" * 62}_accounts_upgrade"
      assert_equal 0, result.status
      assert File.file?(File.join(app_root, ".ctxpack", "20260527143015_#{expected_name}.md"))
    end
  end

  def test_packet_keeps_trailing_80_characters_when_anchor_exceeds_name_limit
    with_cli_app do |app_root|
      action = "upgrade_#{"x" * 85}"
      controller_path = File.join(app_root, "app", "controllers", "accounts_controller.rb")
      source = File.read(controller_path)
      File.write(controller_path, source.sub(/\nend\n\z/, "\n  def #{action}\n    head :accepted\n  end\nend\n"))

      result = run_cli(
        ["packet", "accounts##{action}"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      expected_name = "accounts_#{action}".chars.last(80).join
      assert_equal 0, result.status
      assert_equal 80, expected_name.length
      assert File.file?(File.join(app_root, ".ctxpack", "20260527143015_#{expected_name}.md"))
    end
  end

  def test_packet_derives_name_from_namespaced_anchor_when_task_is_omitted
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "admin/accounts#upgrade"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      artifact = File.join(app_root, ".ctxpack", "20260527143015_admin_accounts_upgrade.md")
      assert_equal 0, result.status
      assert File.file?(artifact), "expected #{artifact} to be written"
      assert_includes result.stdout, ".ctxpack/20260527143015_admin_accounts_upgrade.md"
      assert_includes File.read(artifact), "## Task\n\n> No task was provided.\n\n"
    end
  end

  def test_packet_writes_manifest_next_to_markdown_and_prints_both_paths
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--name", "BillingUpgrade", "-d", "docs/ctxpack", "--manifest"],
        cwd: File.join(app_root, "app", "controllers"),
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      markdown_path = File.join(app_root, "docs", "ctxpack", "20260527143015_billing_upgrade.md")
      manifest_path = File.join(app_root, "docs", "ctxpack", "20260527143015_billing_upgrade.json")
      assert_equal 0, result.status
      assert File.file?(markdown_path)
      assert File.file?(manifest_path)
      assert_equal [
        "../../docs/ctxpack/20260527143015_billing_upgrade.md",
        "../../docs/ctxpack/20260527143015_billing_upgrade.json"
      ], result.stdout.lines.map(&:chomp)
      assert_equal "accounts#upgrade", JSON.parse(File.read(manifest_path)).fetch("anchor")
    end
  end

  def test_packet_rejects_manifest_when_out_path_would_collide_with_markdown
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--out", "tmp/packet.json", "--manifest"],
        cwd: app_root
      )

      assert_equal 1, result.status
      assert_includes result.stderr, "manifest path would overwrite the Markdown artifact"
      refute File.exist?(File.join(app_root, "tmp", "packet.json"))
      assert_equal "", result.stdout
    end
  end

  def test_packet_rejects_manifest_collision_regardless_of_extension_case
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--out", "tmp/packet.JSON", "--manifest"],
        cwd: app_root
      )

      assert_equal 1, result.status
      assert_includes result.stderr, "manifest path would overwrite the Markdown artifact"
      refute File.exist?(File.join(app_root, "tmp", "packet.JSON"))
      refute File.exist?(File.join(app_root, "tmp", "packet.json"))
    end
  end

  def test_manifest_refuses_partial_overwrite_when_sibling_json_exists
    with_cli_app do |app_root|
      markdown_path = File.join(app_root, "tmp", "packet.md")
      manifest_path = File.join(app_root, "tmp", "packet.json")
      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(manifest_path, "old manifest")

      result = run_cli(
        ["accounts#upgrade", "--out", "tmp/packet.md", "--manifest"],
        cwd: app_root
      )

      assert_equal 1, result.status
      refute File.exist?(markdown_path)
      assert_equal "old manifest", File.read(manifest_path)
      assert_equal "", result.stdout
      assert_includes result.stderr, "output already exists: tmp/packet.json"
    end
  end

  def test_force_rejects_non_file_manifest_destination_before_writing_markdown
    with_cli_app do |app_root|
      markdown_path = File.join(app_root, "tmp", "packet.md")
      manifest_path = File.join(app_root, "tmp", "packet.json")
      FileUtils.mkdir_p(manifest_path)

      result = run_cli(
        ["accounts#upgrade", "--out", "tmp/packet.md", "--manifest", "--force"],
        cwd: app_root
      )

      assert_equal 1, result.status
      refute File.exist?(markdown_path)
      assert Dir.exist?(manifest_path)
      assert_equal "", result.stdout
      assert_equal "ctxpack: output destination is not a file: tmp/packet.json\n", result.stderr
    end
  end

  def test_out_rejects_explicit_dir_or_name_before_rails_root_discovery
    Dir.mktmpdir("ctxpack-output-options") do |cwd|
      with_dir = run_cli(["accounts#upgrade", "--out", "packet.md", "--dir", "docs/ctxpack"], cwd: cwd)
      with_name = run_cli(["accounts#upgrade", "--out", "packet.md", "--name", "billing_upgrade"], cwd: cwd)

      assert_equal 1, with_dir.status
      assert_includes with_dir.stderr, "--out cannot be combined with --dir"
      refute_includes with_dir.stderr, "searched upward"
      assert_equal "", with_dir.stdout

      assert_equal 1, with_name.status
      assert_includes with_name.stderr, "--out cannot be combined with --name"
      refute_includes with_name.stderr, "searched upward"
      assert_equal "", with_name.stdout
    end
  end

  def test_packet_suppresses_reminder_when_default_directory_is_gitignored
    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")
      File.write(File.join(app_root, ".gitignore"), ".ctxpack/\n")
      first = run_cli(
        ["packet", "accounts#upgrade", "--name", "first"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )
      second = run_cli(
        ["packet", "accounts#upgrade", "--name", "second"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 16)
      )

      assert_equal 0, first.status
      assert_equal [".ctxpack/20260527143015_first.md"], first.stdout.lines.map(&:chomp)
      assert_equal "", first.stderr
      assert_equal 0, second.status
      refute_includes second.stdout, "Reminder: add .ctxpack/ to .gitignore"
      refute_includes second.stderr, "Reminder: add .ctxpack/ to .gitignore"
      assert_equal ".ctxpack/\n", File.read(File.join(app_root, ".gitignore"))
    end
  end

  def test_packet_does_not_remind_for_an_explicit_directory_inside_ctxpack
    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")
      result = run_cli(
        ["packet", "accounts#upgrade", "--dir", ".ctxpack/sub"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      assert_equal 0, result.status
      assert Dir.exist?(File.join(app_root, ".ctxpack"))
      assert File.file?(File.join(app_root, ".ctxpack", "sub", "20260527143015_accounts_upgrade.md"))
      assert_equal "", result.stderr
      refute_includes result.stdout, "Reminder: add .ctxpack/ to .gitignore"
    end
  end

  def test_packet_does_not_remind_when_default_directory_already_exists
    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")
      FileUtils.mkdir_p(File.join(app_root, ".ctxpack"))

      result = run_cli(["accounts#upgrade"], cwd: app_root)

      assert_equal 0, result.status
      assert_equal "", result.stderr
    end
  end

  def test_packet_reminds_only_when_git_reports_the_new_default_directory_unignored
    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")

      result = run_cli(["accounts#upgrade"], cwd: app_root)

      assert_equal 0, result.status
      assert_equal "ctxpack: .ctxpack/ is not ignored; add `.ctxpack/` to .gitignore\n", result.stderr
    end
  end

  def test_packet_honors_git_info_exclude_and_configured_global_excludes
    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")
      File.write(File.join(app_root, ".git", "info", "exclude"), ".ctxpack/\n")
      info_exclude = run_cli(["accounts#upgrade", "--name", "info"], cwd: app_root)
      assert_equal "", info_exclude.stderr
    end

    with_cli_app do |app_root|
      git!(app_root, "init", "--quiet")
      excludes_file = File.join(app_root, "global-ignore")
      File.write(excludes_file, ".ctxpack/\n")
      git!(app_root, "config", "core.excludesFile", excludes_file)
      global_exclude = run_cli(["accounts#upgrade", "--name", "global"], cwd: app_root)
      assert_equal "", global_exclude.stderr
    end
  end

  def test_packet_suppresses_reminder_outside_git_and_on_git_operational_failure
    with_cli_app do |app_root|
      non_git = run_cli(["accounts#upgrade"], cwd: app_root)
      assert_equal "", non_git.stderr
    end

    with_cli_app do |app_root|
      File.write(File.join(app_root, ".git"), "gitdir: missing-git-directory\n")
      broken_git = run_cli(["accounts#upgrade"], cwd: app_root)
      assert_equal "", broken_git.stderr
    end
  end

  def test_packet_refuses_to_overwrite_default_artifact_unless_forced
    with_cli_app do |app_root|
      args = ["packet", "accounts#upgrade", "--name", "billing_upgrade"]
      time = Time.utc(2026, 5, 27, 14, 30, 15)

      assert_equal 0, run_cli(args, cwd: app_root, at: time).status
      blocked = run_cli(args, cwd: app_root, at: time)
      forced = run_cli(args + ["--force"], cwd: app_root, at: time)

      assert_equal 1, blocked.status
      assert_includes blocked.stderr, "output already exists"
      assert_includes blocked.stderr, "--force"
      assert_equal 0, forced.status
    end
  end

  def test_packet_out_path_refuses_to_overwrite_without_force_and_uses_invocation_relative_path
    with_cli_app do |app_root|
      out_path = File.join(app_root, "tmp", "packet.md")
      FileUtils.mkdir_p(File.dirname(out_path))
      File.write(out_path, "old")

      result = run_cli(
        ["packet", "accounts#upgrade", "--out", "tmp/packet.md"],
        cwd: File.join(app_root, "app", "controllers")
      )

      assert_equal 1, result.status
      assert_equal "old", File.read(out_path)
      assert_equal "", result.stdout
      assert_includes result.stderr, "output already exists: ../../tmp/packet.md"
      assert_includes result.stderr, "--force"
      refute_includes result.stderr, app_root
    end
  end

  def test_fresh_explicit_out_path_succeeds_without_force
    with_cli_app do |app_root|
      result = run_cli(
        ["accounts#upgrade", "--out", "tmp/packet.md"],
        cwd: app_root
      )

      assert_equal 0, result.status
      assert File.file?(File.join(app_root, "tmp", "packet.md"))
      assert_equal ["tmp/packet.md"], result.stdout.lines.map(&:chomp)
    end
  end

  def test_short_out_and_force_flags_overwrite_an_existing_explicit_path
    with_cli_app do |app_root|
      out_path = File.join(app_root, "tmp", "packet.md")
      FileUtils.mkdir_p(File.dirname(out_path))
      File.write(out_path, "old")

      result = run_cli(
        ["accounts#upgrade", "-o", "tmp/packet.md", "-f"],
        cwd: app_root
      )

      assert_equal 0, result.status
      assert_includes File.read(out_path), "# ctxpack context packet"
      assert_equal ["tmp/packet.md"], result.stdout.lines.map(&:chomp)
    end
  end

  def test_packet_fails_clearly_outside_rails_app_root
    Dir.mktmpdir("ctxpack-no-root") do |tmpdir|
      result = run_cli(["packet", "accounts#upgrade"], cwd: tmpdir)

      assert_equal 1, result.status
      assert_includes result.stderr, "searched upward"
      assert_includes result.stderr, "config/application.rb"
      assert_includes result.stderr, "found none"
    end
  end

  def test_write_filesystem_error_returns_a_concise_injected_failure
    with_cli_app do |app_root|
      out_path = File.join(app_root, "tmp", "packet.md")
      FileUtils.mkdir_p(File.dirname(out_path))
      File.write(out_path, "read only")
      File.chmod(0o444, out_path)
      result = run_cli(
        ["accounts#upgrade", "--out", "tmp/packet.md", "--force"],
        cwd: app_root
      )

      assert_equal 1, result.status
      assert_equal "", result.stdout
      assert_equal(
        "ctxpack: could not write tmp/packet.md: Permission denied\n",
        result.stderr
      )
    end
  end

  def test_parent_directory_creation_error_returns_a_concise_injected_failure
    with_cli_app do |app_root|
      File.write(File.join(app_root, "blocker"), "not a directory")
      result = run_cli(
        ["accounts#upgrade", "--out", "blocker/packet.md"],
        cwd: app_root
      )

      assert_equal 1, result.status
      assert_equal "", result.stdout
      assert_equal(
        "ctxpack: could not create directory blocker: File exists\n",
        result.stderr
      )
    end
  end

  def test_packet_maps_compilation_errors_to_nonzero_status_and_routes_hint
    with_cli_app do |app_root|
      result = run_cli(["packet", "missing_accounts#upgrade"], cwd: app_root)

      assert_equal 1, result.status
      assert_includes result.stderr, "expected controller file does not exist"
      assert_includes result.stderr, "app/controllers/missing_accounts_controller.rb"
      assert_includes result.stderr, "bin/rails routes -g upgrade"
      assert_includes result.stderr, "bin/rails routes -c missing_accounts"
      assert_equal "", result.stdout
    end
  end

  def test_packet_uses_generic_route_hint_for_malformed_anchor_tokens
    with_cli_app do |app_root|
      result = run_cli(["packet", "accounts#upgrade;rm"], cwd: app_root)

      assert_equal 1, result.status
      assert_includes result.stderr, "bin/rails routes -g ACTION"
      assert_includes result.stderr, "bin/rails routes -c CONTROLLER"
      refute_includes result.stderr, "routes -g upgrade;rm"
    end
  end

  def test_packet_uses_generic_route_hint_for_shell_sensitive_action_name
    with_cli_app do |app_root|
      result = run_cli(["packet", "accounts#missing?"], cwd: app_root)

      assert_equal 1, result.status
      assert_includes result.stderr, "bin/rails routes -g ACTION"
      assert_includes result.stderr, "bin/rails routes -c CONTROLLER"
      refute_includes result.stderr, "routes -g missing?"
    end
  end

  def test_packet_rejects_route_helper_input_and_routes_command
    with_cli_app do |app_root|
      helper_result = run_cli(["packet", "upgrade_account"], cwd: app_root)
      routes_result = run_cli(["routes"], cwd: app_root)
      limit_result = run_cli(["packet", "accounts#upgrade", "--max-files", "1"], cwd: app_root)

      assert_equal 1, helper_result.status
      assert_includes helper_result.stderr, "looks like a Rails route helper"
      assert_equal 1, routes_result.status
      assert_includes routes_result.stderr, "unknown command"
      refute_includes routes_result.stderr, "Did you mean"
      assert_equal 1, limit_result.status
      assert_includes limit_result.stderr, "invalid option: --max-files"
    end
  end

  def test_route_helper_input_gets_a_safe_rails_aware_diagnostic_before_root_discovery
    Dir.mktmpdir("ctxpack-anchor-diagnostic") do |cwd|
      direct = run_cli(["upgrade_account"], cwd: cwd)
      compatible = run_cli(["packet", "upgrade_account"], cwd: cwd)

      [direct, compatible].each do |result|
        assert_equal 1, result.status
        assert_includes result.stderr, '"upgrade_account" looks like a Rails route helper, not a controller#action anchor'
        assert_includes result.stderr, "bin/rails routes -g upgrade_account"
        refute_includes result.stderr, "searched upward"
        assert_equal "", result.stdout
      end
    end
  end

  def test_other_common_rails_input_shapes_get_tailored_diagnostics_without_discovery
    Dir.mktmpdir("ctxpack-anchor-diagnostics") do |cwd|
      class_style = run_cli(["AccountsController#upgrade"], cwd: cwd)
      quoted_route = run_cli(["POST /accounts/:id/upgrade"], cwd: cwd)
      split_route = run_cli(["packet", "POST", "/accounts/:id/upgrade"], cwd: cwd)
      slash_anchor = run_cli(["admin/accounts/upgrade"], cwd: cwd)

      assert_includes class_style.stderr, "Ruby controller class reference"
      assert_includes class_style.stderr, "accounts#upgrade"
      assert_includes class_style.stderr, "bin/rails routes -g upgrade"
      [quoted_route, split_route].each do |result|
        assert_includes result.stderr, "Rails route strings are not supported"
        assert_includes result.stderr, "bin/rails routes -g upgrade"
      end
      assert_includes slash_anchor.stderr, "final separator"
      assert_includes slash_anchor.stderr, "admin/accounts#upgrade"
      [class_style, quoted_route, split_route, slash_anchor].each do |result|
        assert_equal 1, result.status
        refute_includes result.stderr, "searched upward"
        assert_equal "", result.stdout
      end
    end
  end

  def test_packet_command_typo_suggests_the_supported_command
    Dir.mktmpdir("ctxpack-command") do |cwd|
      result = run_cli(["packets"], cwd: cwd)

      assert_equal 1, result.status
      assert_includes result.stderr, "unknown command \"packets\""
      assert_includes result.stderr, "Did you mean `ctxpack packet`?"
      assert_equal "", result.stdout
    end
  end

  private

  Result = Struct.new(:status, :stdout, :stderr, keyword_init: true)

  def with_cli_app
    Dir.mktmpdir("ctxpack-cli") do |tmpdir|
      app_root = File.join(tmpdir, "sample_app")
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app("minitest_basic"), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# test Rails marker\n")
      yield app_root
    end
  end

  def git!(root, *arguments)
    _stdout, stderr, status = Open3.capture3("git", "-C", root, *arguments)
    raise "git failed: #{stderr}" unless status.success?
  end

  def run_cli(args, cwd:, at: Time.utc(2026, 5, 27, 14, 30, 15), stdin: "")
    stdout = StringIO.new
    stderr = StringIO.new
    clock = -> { at }
    status = Ctxpack::CLI.new(stdout: stdout, stderr: stderr, stdin: StringIO.new(stdin), cwd: cwd, clock: clock).run(args)

    Result.new(status: status, stdout: stdout.string, stderr: stderr.string)
  end
end
