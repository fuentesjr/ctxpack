require "test_helper"

class PacketObjectTest < Minitest::Test
  def test_man_2_det_2_packet_object_exposes_manifest_shape_and_file_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    assert_equal [
      "app/controllers/accounts_controller.rb",
      "app/services/billing/subscriptions.rb",
      "app/jobs/sync_billing_account_job.rb",
      "test/controllers/accounts_controller_test.rb",
      "test/integration/accounts_upgrade_test.rb"
    ], packet.files.map(&:path)

    manifest = packet.to_h
    assert_equal 1, manifest.fetch("version")
    assert_equal "accounts#upgrade", manifest.fetch("anchor")
    assert_equal({
      "file" => "app/controllers/accounts_controller.rb",
      "controller" => "AccountsController",
      "action" => "upgrade"
    }, manifest.fetch("entrypoint"))
    assert manifest.fetch("repo").key?("commit")
    assert manifest.fetch("repo").key?("dirty")
    assert(manifest.fetch("files").any? do |file|
      file.fetch("path") == "app/controllers/accounts_controller.rb" &&
        file.fetch("reason_code") == "controller_action" &&
        file.fetch("snippet_ranges") == [[10, 15]]
    end)
    assert_equal [
      "bin/rails test test/controllers/accounts_controller_test.rb",
      "bin/rails test test/integration/accounts_upgrade_test.rb"
    ], (manifest.fetch("tests").map { |test| test.fetch("command") })
    assert(manifest.fetch("uncertainty").any? { |note| note.fetch("code") == "test_inferred_by_path" })
  end
end
