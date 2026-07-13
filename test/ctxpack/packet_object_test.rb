require "test_helper"

class PacketObjectTest < Minitest::Test
  def test_man_2_omitted_candidates_carry_semantic_limit_keys_for_every_omission_path
    cases = {
      "long_snippets#show" => ["max_snippet_lines_per_file"],
      "view_budgets#index" => ["max_view_files"],
      "constant_limits#show" => ["max_constant_files"],
      "search#bulk_update" => ["max_test_files"],
      "saturation#show" => ["max_total_files"]
    }

    cases.each do |anchor, expected_limit_keys|
      packet = Ctxpack.compile(app_root: fixture_app("minitest_basic"), anchor: anchor)
      manifest_limit_keys = packet.to_h.fetch("omitted_candidates").map { |item| item.fetch("limit_key") }.uniq

      assert_equal expected_limit_keys, manifest_limit_keys, anchor
    end
  end

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
    assert_equal 2, manifest.fetch("version")
    assert_equal "Implement billing upgrade", manifest.fetch("task")
    assert_equal "accounts#upgrade", manifest.fetch("anchor")
    assert_equal({
      "file" => "app/controllers/accounts_controller.rb",
      "controller" => "AccountsController",
      "action" => "upgrade"
    }, manifest.fetch("entrypoint"))
    assert manifest.fetch("repo").key?("commit")
    assert manifest.fetch("repo").key?("dirty")
    assert manifest.fetch("repo").key?("available")
    assert(manifest.fetch("files").any? do |file|
      file.fetch("path") == "app/controllers/accounts_controller.rb" &&
        file.fetch("evidence").any? do |evidence|
          evidence.fetch("reason_code") == "controller_action" &&
            evidence.fetch("snippet_ranges") == [[10, 15]]
        end
    end)
    assert_equal [
      "bin/rails test test/controllers/accounts_controller_test.rb",
      "bin/rails test test/integration/accounts_upgrade_test.rb"
    ], (manifest.fetch("tests").map { |test| test.fetch("command") })
    assert(manifest.fetch("follow_ups").any? { |note| note.fetch("code") == "test_inferred_by_path" })
  end
end
