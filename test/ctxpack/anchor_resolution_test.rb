require "test_helper"
require "fileutils"
require "stringio"
require "tmpdir"

class AnchorResolutionTest < Minitest::Test
  def test_anch_1_2_accepts_namespaced_anchor_and_maps_by_convention
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "admin/accounts#upgrade"
    )

    assert_equal "app/controllers/admin/accounts_controller.rb", packet.entrypoint.file
    assert_equal "Admin::AccountsController", packet.entrypoint.controller
    assert_equal "upgrade", packet.entrypoint.action
  end

  def test_anch_3_visibility_is_ignored_for_direct_action_methods
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "private_actions#upgrade"
    )

    assert_equal "app/controllers/private_actions_controller.rb", packet.entrypoint.file
    assert_equal [[4, 6]], packet.file("app/controllers/private_actions_controller.rb").evidence_for("controller_action").first.snippet_ranges
  end

  def test_anch_3_inline_visibility_modifier_action_is_a_direct_action_method
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "private_actions#inline_upgrade"
    )

    assert_equal "app/controllers/private_actions_controller.rb", packet.entrypoint.file
    assert_equal [[8, 10]], packet.file("app/controllers/private_actions_controller.rb").evidence_for("controller_action").first.snippet_ranges
  end

  def test_anch_4_6_missing_controller_file_fails_exactly
    error = assert_raises(Ctxpack::Error) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), anchor: "missing_accounts#upgrade")
    end

    assert_includes error.message, "app/controllers/missing_accounts_controller.rb"
  end

  def test_anch_5_7_missing_direct_action_fails_without_guessing
    error = assert_raises(Ctxpack::Error) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), anchor: "accounts#inherited_upgrade")
    end

    assert_includes error.message, "action inherited_upgrade was not directly defined"
    assert_includes error.message, "inherited, concern-defined, and metaprogrammed actions are unsupported in v0"
  end

  def test_anch_1_rejects_non_snake_case_anchor_tokens
    error = assert_raises(Ctxpack::Error) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), anchor: "Accounts#upgrade")
    end

    assert_includes error.message, "invalid anchor"
  end

  def test_anch_1_accepts_action_with_trailing_question_mark
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "oddities#merged?"
    )

    assert_equal "app/controllers/oddities_controller.rb", packet.entrypoint.file
    assert_equal "merged?", packet.entrypoint.action
  end

  def test_anch_1_accepts_action_with_leading_underscore
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "oddities#_show_secure_deprecated"
    )

    assert_equal "app/controllers/oddities_controller.rb", packet.entrypoint.file
    assert_equal "_show_secure_deprecated", packet.entrypoint.action
  end

  def test_anch_2_matches_acronym_class_defined_in_resolved_file
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "ai_text_tools#index"
    )

    assert_equal "app/controllers/ai_text_tools_controller.rb", packet.entrypoint.file
    assert_equal "AITextToolsController", packet.entrypoint.controller
    assert_equal "index", packet.entrypoint.action
  end

  def test_anch_2_4_file_without_matching_controller_class_fails_exactly
    error = assert_raises(Ctxpack::Error) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), anchor: "mismatched#show")
    end

    assert_includes error.message, "app/controllers/mismatched_controller.rb"
    assert_includes error.message, "no controller class matching mismatched"
  end

  def test_root_1_anchor_controller_symlinked_outside_root_fails_without_reading
    Dir.mktmpdir("ctxpack-root-1") do |tmpdir|
      app_root = File.join(tmpdir, "app_root")
      FileUtils.cp_r(fixture_app("minitest_basic"), app_root)
      outside = File.join(tmpdir, "outside_controller.rb")
      File.write(outside, "class AccountsController\n  def upgrade\n    SECRET_OUTSIDE_ROOT\n  end\nend\n")
      controller = File.join(app_root, "app/controllers/accounts_controller.rb")
      FileUtils.rm(controller)
      File.symlink(outside, controller)

      error = assert_raises(Ctxpack::Error) do
        Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")
      end
      assert_includes error.message, "app/controllers/accounts_controller.rb"
      assert_includes error.message, "resolves outside the application root"
      refute_includes error.message, "SECRET_OUTSIDE_ROOT"

      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# marker\n")
      require "ctxpack/cli"
      stdout = StringIO.new
      stderr = StringIO.new
      status = Ctxpack::CLI.new(stdout: stdout, stderr: stderr, cwd: app_root, history_provider: UnavailableHistoryProvider.new)
        .run(["accounts#upgrade", "--stdout"])
      refute_equal 0, status
      assert_includes stderr.string, "app/controllers/accounts_controller.rb"
      assert_includes stderr.string, "resolves outside the application root"
      refute_includes stdout.string + stderr.string, "SECRET_OUTSIDE_ROOT"
    end
  end

  def test_root_1_anchor_controller_symlinked_inside_root_still_resolves
    Dir.mktmpdir("ctxpack-root-1") do |tmpdir|
      app_root = File.join(tmpdir, "app_root")
      FileUtils.cp_r(fixture_app("minitest_basic"), app_root)
      real = File.join(app_root, "app/controllers/accounts_controller.rb")
      moved = File.join(app_root, "app/accounts_real.rb")
      FileUtils.mv(real, moved)
      File.symlink("../accounts_real.rb", real)

      packet = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")
      assert_equal "app/controllers/accounts_controller.rb", packet.entrypoint.file
    end
  end
end
