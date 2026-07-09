require "test_helper"

class LimitsTest < Minitest::Test
  def test_lim_1_v0_limits_are_internal_constants
    assert_equal({
      max_total_files: 8,
      max_constant_files: 4,
      max_view_files: 2,
      max_test_files: 2,
      max_snippet_lines_per_file: 120
    }, Ctxpack::Compiler::LIMITS)
  end

  def test_const_4_lim_1_lim_2_truncates_constant_files_in_first_reference_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "constant_limits#show"
    )

    assert_equal [
      "app/models/alpha_one.rb",
      "app/models/beta_two.rb",
      "app/models/gamma_three.rb",
      "app/models/delta_four.rb"
    ], packet.files_with_reason("referenced_constant").map(&:path)
    assert(packet.omitted_candidates.any? do |candidate|
      candidate.category == "constant_files" && candidate.subject == "EpsilonFive"
    end)
  end

  def test_lim_4_truncates_long_action_and_names_dropped_callback_snippets
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "long_snippets#show"
    )

    controller = packet.file("app/controllers/long_snippets_controller.rb")
    action_evidence = controller.evidence_for("controller_action").first

    assert action_evidence.truncated
    assert_equal 120, action_evidence.snippet_ranges.first.last - action_evidence.snippet_ranges.first.first + 1
    assert_empty controller.evidence_for("before_action_callback")
    assert(packet.omitted_candidates.any? { |candidate| candidate.category == "snippets" && candidate.subject == "show" })
    assert(packet.omitted_candidates.any? { |candidate| candidate.category == "snippets" && candidate.subject == "short_callback" })
  end
end
