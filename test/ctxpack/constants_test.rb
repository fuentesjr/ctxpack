require "test_helper"

class ConstantsTest < Minitest::Test
  def test_const_1_2a_2c_4_resolves_constants_in_action_and_callbacks_in_reference_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "admin/reports#show"
    )

    constant_evidence = packet.files_with_reason("referenced_constant").map do |entry|
      [entry.path, entry.evidence_for("referenced_constant").first.subject]
    end

    assert_equal [
      ["app/services/admin/subscriptions.rb", "Admin::Subscriptions"],
      ["app/models/order.rb", "Order"],
      ["app/models/report_audit.rb", "ReportAudit"]
    ], constant_evidence

    refute(packet.files.any? { |entry| entry.path == "app/services/subscriptions.rb" })
    refute(packet.files.any? { |entry| entry.path == "app/views/missing_thing.rb" })
    assert_equal ["Admin::Subscriptions", "Order", "ReportAudit"],
                 packet.convention_constant_matches.map(&:constant_name)
  end

  def test_const_2a_root_qualified_references_skip_lexical_walk
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "admin/accounts#upgrade"
    )

    assert_equal ["app/services/billing/subscriptions.rb"],
                 packet.files_with_reason("referenced_constant").map(&:path)
  end

  def test_parse_2_constant_resolution_uses_swappable_resolver_interface
    resolver = RecordingResolver.new

    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      constant_resolver: resolver
    )

    assert_equal [["Billing::Subscriptions", []]], resolver.calls.first(1)
    assert_equal "app/services/resolved_by_fake_resolver.rb",
                 packet.files_with_reason("referenced_constant").first.path
  end

  def test_const_1a_follows_same_file_helper_called_by_action
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "call_graph_constants#motivate"
    )

    assert_equal [
      ["app/models/call_graph_user.rb", "CallGraphUser"]
    ], referenced_constant_evidence(packet)
  end

  def test_const_1a_4_appends_transitive_constants_after_action_and_callbacks_under_cap
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "call_graph_constants#cap_pressure"
    )

    assert_equal [
      ["app/models/direct_alpha.rb", "DirectAlpha"],
      ["app/models/direct_beta.rb", "DirectBeta"],
      ["app/models/direct_gamma.rb", "DirectGamma"],
      ["app/models/direct_delta.rb", "DirectDelta"]
    ], referenced_constant_evidence(packet)

    assert_nil packet.file("app/models/transitive_epsilon.rb")
    assert(packet.omitted_candidates.any? do |candidate|
      candidate.category == "constant_files" &&
        candidate.subject == "TransitiveEpsilon" &&
        candidate.reason == "max constant files limit reached"
    end)
  end

  def test_const_1a_terminates_mutual_recursion_in_bfs_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "call_graph_constants#mutual"
    )

    assert_equal [
      ["app/models/mutual_first.rb", "MutualFirst"],
      ["app/models/mutual_second.rb", "MutualSecond"]
    ], referenced_constant_evidence(packet)
  end

  def test_const_1a_traverses_through_callback_that_is_also_a_callee
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "call_graph_constants#callback_callee"
    )

    assert_equal [
      ["app/models/shared_callback_constant.rb", "SharedCallbackConstant"],
      ["app/models/shared_deep_constant.rb", "SharedDeepConstant"]
    ], referenced_constant_evidence(packet)
    assert_equal 1, packet.files.count { |entry| entry.path == "app/models/shared_callback_constant.rb" }
  end

  def test_const_1a_ignores_dynamic_and_other_receiver_calls
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "call_graph_constants#ignored_calls"
    )

    assert_equal [
      ["app/models/literal_self_constant.rb", "LiteralSelfConstant"]
    ], referenced_constant_evidence(packet)
    assert_nil packet.file("app/models/ignored_receiver_constant.rb")
    assert_nil packet.file("app/models/ignored_dynamic_constant.rb")
  end

  private

  def referenced_constant_evidence(packet)
    packet.files_with_reason("referenced_constant").map do |entry|
      [entry.path, entry.evidence_for("referenced_constant").first.subject]
    end
  end

  class RecordingResolver
    attr_reader :calls

    def initialize
      @calls = []
    end

    def resolve(reference, lexical_namespace:)
      @calls << [reference.name, lexical_namespace]
      return unless @calls.length == 1

      Ctxpack::ConstantResolution.new(
        original_name: reference.name,
        constant_name: "ResolvedByFakeResolver",
        path: "app/services/resolved_by_fake_resolver.rb"
      )
    end
  end
end
