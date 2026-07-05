require "test_helper"

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
end
