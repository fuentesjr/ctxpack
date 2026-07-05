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
