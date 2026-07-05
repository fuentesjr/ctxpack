require "test_helper"

class CallbacksTest < Minitest::Test
  def test_cb_1_cb_2_cb_2a_cb_4_callback_applicability_and_uncertainty
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "callback_edges#upgrade"
    )

    controller = packet.file("app/controllers/callback_edges_controller.rb")
    callback_subjects = controller.evidence_for("before_action_callback").map(&:subject)

    assert_equal ["literal_callback", "single_symbol_callback", "dynamic_skip_callback"], callback_subjects
    refute_includes callback_subjects, "skipped_callback"
    refute_includes callback_subjects, "symbol_skipped_callback"
    refute(packet.uncertainty.any? { |note| note.code == "dynamic_callback_args" && note.subject == "single_symbol_callback" })
    refute(packet.uncertainty.any? { |note| note.code == "dynamic_callback_args" && note.subject == "symbol_skipped_callback" })
    refute_includes callback_subjects, "after_callback"
    refute_includes callback_subjects, "around_callback"

    assert(packet.uncertainty.any? { |note| note.code == "dynamic_callback_args" && note.subject == "dynamic_skip_callback" })
    assert(packet.uncertainty.any? { |note| note.code == "dynamic_callback_args" && note.subject == "before_action" })
    assert(packet.uncertainty.any? { |note| note.code == "unresolved_external_callbacks" && note.subject == "external_callback" })
    assert(packet.uncertainty.any? { |note| note.code == "around_callback_present" && note.subject == "around_callback" })
    assert(packet.uncertainty.any? { |note| note.code == "block_callback_present" })
  end
end
