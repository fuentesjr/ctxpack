require "test_helper"
require "fileutils"
require "tmpdir"

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

  def test_test_1_rule_2_normalizes_action_tokens_from_extended_grammar
    merged = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "oddities#merged?"
    )
    deprecated = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "oddities#_show_secure_deprecated"
    )

    assert_equal ["test/integration/oddities_merged_test.rb"], merged.tests.map(&:path)
    assert_equal ["test/integration/oddities_show_secure_deprecated_test.rb"], deprecated.tests.map(&:path)
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

  def test_test_1_rspec_family_uses_controller_and_request_specs_only
    packet = Ctxpack.compile(
      app_root: fixture_app("rspec_basic"),
      anchor: "accounts#upgrade"
    )

    assert_equal [
      "bundle exec rspec spec/controllers/accounts_controller_spec.rb",
      "bundle exec rspec spec/requests/accounts_upgrade_spec.rb"
    ], packet.tests.map(&:command)
    assert_equal ["rspec_candidate"], packet.file("spec/controllers/accounts_controller_spec.rb").reason_codes
    assert_equal ["rspec_candidate"], packet.file("spec/requests/accounts_upgrade_spec.rb").reason_codes
    refute packet.file("spec/system/accounts_upgrade_spec.rb")
    refute packet.file("test/controllers/accounts_controller_test.rb")
    assert(packet.uncertainty.any? { |note| note.code == "test_inferred_by_path" && note.subject == "spec/requests/accounts_upgrade_spec.rb" })
  end

  def test_test_1_rspec_request_rule_uses_contiguous_action_tokens
    packet = Ctxpack.compile(
      app_root: fixture_app("rspec_basic"),
      anchor: "accounts#bulk_update"
    )

    assert_equal [
      "spec/controllers/accounts_controller_spec.rb",
      "spec/requests/accounts_bulk_update_flow_spec.rb"
    ], packet.tests.map(&:path)
    refute packet.file("spec/requests/bulk_accounts_update_spec.rb")
  end

  def test_test_1_rspec_framework_detection_accepts_rspec_rails_dependency
    Dir.mktmpdir("ctxpack-rspec-detection") do |dir|
      app_root = File.join(dir, "rspec_basic")
      FileUtils.cp_r(fixture_app("rspec_basic"), app_root)
      FileUtils.rm(File.join(app_root, "spec", "rails_helper.rb"))
      File.write(File.join(app_root, "Gemfile"), "source \"https://rubygems.org\"\ngem \"rspec-rails\"\n")

      packet = Ctxpack.compile(
        app_root: app_root,
        anchor: "accounts#upgrade"
      )

      assert_equal [
        "bundle exec rspec spec/controllers/accounts_controller_spec.rb",
        "bundle exec rspec spec/requests/accounts_upgrade_spec.rb"
      ], packet.tests.map(&:command)
    end
  end
end
