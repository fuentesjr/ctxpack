require "test_helper"

class CompileBasicTest < Minitest::Test
  def test_anch_cb_const_test_fmt_man_happy_path_packet_object
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    assert_equal "accounts#upgrade", packet.anchor
    assert_equal "Implement billing upgrade", packet.task
    assert_equal "app/controllers/accounts_controller.rb", packet.entrypoint.file
    assert_equal "AccountsController", packet.entrypoint.controller
    assert_equal "upgrade", packet.entrypoint.action

    controller_file = packet.file("app/controllers/accounts_controller.rb")
    assert controller_file.reason_codes.include?("controller_action")
    assert_equal [[10, 15]], controller_file.evidence_for("controller_action").first.snippet_ranges
    assert_equal ["set_account", "require_active_account", "audit_upgrade"],
                 controller_file.evidence_for("before_action_callback").map(&:subject)

    constant_paths = packet.files_with_reason("referenced_constant").map(&:path)
    assert_equal [
      "app/services/billing/subscriptions.rb",
      "app/jobs/sync_billing_account_job.rb"
    ], constant_paths

    assert_equal [
      "bin/rails test test/controllers/accounts_controller_test.rb",
      "bin/rails test test/integration/accounts_upgrade_test.rb"
    ], packet.tests.map(&:command)

    assert(packet.uncertainty.any? { |note| note.code == "around_callback_present" && note.subject == "with_billing_audit" })
    assert(packet.uncertainty.any? { |note| note.code == "block_callback_present" })
    assert(packet.uncertainty.any? { |note| note.code == "test_inferred_by_path" && note.subject == "test/integration/accounts_upgrade_test.rb" })

    refute_nil packet.repo.dirty
  end
end
