require "test_helper"
require "ctxpack/cli"
require "fileutils"
require "json"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  def test_top_level_help_uses_injected_stdout_and_returns_success
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["--help"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "        --manifest\n"
      assert_equal "", result.stderr
    end
  end

  def test_top_level_short_help_returns_success
    Dir.mktmpdir("ctxpack-help") do |cwd|
      result = run_cli(["-h"], cwd: cwd)

      assert_equal 0, result.status
      assert_includes result.stdout, Ctxpack::CLI::USAGE
      assert_includes result.stdout, "        --manifest\n"
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
      assert_includes result.stdout, "        --task TASK\n"
      assert_includes result.stdout, "        --manifest\n"
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
      assert_includes result.stdout, "        --manifest\n"
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
      assert_includes File.read(artifact), "## Task\nImplement billing upgrade\n\n"
      refute_includes File.read(artifact), "20260527143015"
      assert_includes result.stdout, ".ctxpack/20260527143015_implement_billing_upgrade_accounts_upgrade.md"
      assert_includes result.stderr, "Reminder: add .ctxpack/ to .gitignore"
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
      assert_includes File.read(artifact), "## Task\nNo task was provided.\n\n"
    end
  end

  def test_packet_writes_manifest_next_to_markdown_and_prints_both_paths
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--name", "BillingUpgrade", "--dir", "docs/ctxpack", "--manifest"],
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

  def test_packet_prints_gitignore_reminder_only_when_creating_default_ctxpack_dir
    with_cli_app do |app_root|
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
      assert_includes first.stderr, "Reminder: add .ctxpack/ to .gitignore"
      assert_equal 0, second.status
      refute_includes second.stdout, "Reminder: add .ctxpack/ to .gitignore"
      refute_includes second.stderr, "Reminder: add .ctxpack/ to .gitignore"
      refute File.exist?(File.join(app_root, ".gitignore"))
    end
  end

  def test_packet_prints_gitignore_reminder_when_ctxpack_dir_is_created_as_parent
    with_cli_app do |app_root|
      result = run_cli(
        ["packet", "accounts#upgrade", "--dir", ".ctxpack/sub"],
        cwd: app_root,
        at: Time.utc(2026, 5, 27, 14, 30, 15)
      )

      assert_equal 0, result.status
      assert Dir.exist?(File.join(app_root, ".ctxpack"))
      assert File.file?(File.join(app_root, ".ctxpack", "sub", "20260527143015_accounts_upgrade.md"))
      assert_includes result.stderr, "Reminder: add .ctxpack/ to .gitignore"
      refute_includes result.stdout, "Reminder: add .ctxpack/ to .gitignore"
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

  def test_packet_out_path_overwrites_without_force_and_takes_precedence_over_dir
    with_cli_app do |app_root|
      out_path = File.join(app_root, "tmp", "packet.md")
      FileUtils.mkdir_p(File.dirname(out_path))
      File.write(out_path, "old")

      result = run_cli(
        ["packet", "accounts#upgrade", "--dir", "docs/ctxpack", "--out", "tmp/packet.md"],
        cwd: File.join(app_root, "app", "controllers")
      )

      assert_equal 0, result.status
      assert_includes File.read(out_path), "# ctxpack context packet"
      refute Dir.exist?(File.join(app_root, "docs"))
      assert_includes result.stdout, "tmp/packet.md"
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
      assert_includes helper_result.stderr, "invalid anchor"
      assert_equal 1, routes_result.status
      assert_includes routes_result.stderr, "unknown command"
      assert_equal 1, limit_result.status
      assert_includes limit_result.stderr, "invalid option: --max-files"
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

  def run_cli(args, cwd:, at: Time.utc(2026, 5, 27, 14, 30, 15))
    stdout = StringIO.new
    stderr = StringIO.new
    clock = -> { at }
    status = Ctxpack::CLI.new(stdout: stdout, stderr: stderr, cwd: cwd, clock: clock).run(args)

    Result.new(status: status, stdout: stdout.string, stderr: stderr.string)
  end
end
