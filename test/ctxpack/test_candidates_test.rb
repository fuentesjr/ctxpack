require "test_helper"

class TestCandidatesTest < Minitest::Test
  def test_test_1_rule_2_requires_contiguous_action_tokens_and_excludes_negative_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#bulk_update"
    )

    assert_equal [
      "bin/rails test test/controllers/accounts_controller_test.rb",
      "bin/rails test test/integration/accounts_bulk_update_flow_test.rb"
    ], packet.tests.map(&:command)
    refute(packet.files.any? { |entry| entry.path == "test/integration/bulk_accounts_update_test.rb" })
    assert(packet.uncertainty.any? { |note| note.code == "test_inferred_by_path" && note.subject == "test/integration/accounts_bulk_update_flow_test.rb" })
  end

  def test_test_2_lim_2_truncates_test_candidates_and_records_omissions
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "search#bulk_update"
    )

    assert_equal [
      "test/integration/search_bulk_update_a_test.rb",
      "test/integration/search_bulk_update_b_test.rb"
    ], packet.tests.map(&:path)
    assert(packet.omitted_candidates.any? do |candidate|
      candidate.category == "test_files" &&
        candidate.subject == "test/integration/search_bulk_update_c_test.rb"
    end)
  end

  def test_test_4_5_path_rules_only_and_explicit_no_candidates_state
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "content_mentions#upgrade"
    )

    assert_empty packet.tests
    assert packet.no_test_candidates
    refute(packet.files.any? { |entry| entry.path == "test/integration/random_flow_test.rb" })
  end
end
