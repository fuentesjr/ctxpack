require "test_helper"

class MethodSeedTest < Minitest::Test
  def test_seed_factory_identity_from_const_hash_method
    seed = Ctxpack::Seed.method("Billing::Subscriptions#upgrade!")
    assert_equal "method", seed.kind
    assert_equal "Billing::Subscriptions#upgrade!", seed.evidence
    assert_equal "billing_subscriptions_upgrade", seed.identity
    assert_predicate seed, :method?
  end

  def test_happy_path_includes_primary_with_method_snippet
    packet = compile_method("Billing::Subscriptions#upgrade!")
    entry = packet.file("app/services/billing/subscriptions.rb")
    refute_nil entry
    assert_includes entry.reason_codes, "method_seed_primary"
    item = entry.evidence_items.find { |e| e.reason_code == "method_seed_primary" }
    refute_nil item
    assert_equal "upgrade!", item.subject
    assert_equal [[7, 9]], item.snippet_ranges
    assert_equal [], packet.tests
  end

  def test_compact_class_nesting_resolves_fqn
    packet = compile_method("Admin::CompactReport#summarize")
    entry = packet.file("app/models/admin/compact_report.rb")
    refute_nil entry
    assert_includes entry.reason_codes, "method_seed_primary"
    assert packet.file("app/models/report_audit.rb")
  end

  def test_no_segment_trimming_on_evidence_constant
    error = assert_raises(Ctxpack::Error) do
      compile_method("Billing::Subscriptions::Missing#run")
    end
    assert_match(/Billing::Subscriptions::Missing/, error.message)
    assert_match(/no conventional file|could not resolve/i, error.message)
    refute_match(/subscriptions\.rb/, error.message)
  end

  def test_fail_closed_when_constant_file_missing
    error = assert_raises(Ctxpack::Error) do
      compile_method("Billing::DoesNotExist#call")
    end
    assert_match(/Billing::DoesNotExist/, error.message)
    assert_match(/no conventional file|could not resolve/i, error.message)
  end

  def test_fail_closed_when_instance_def_missing
    error = assert_raises(Ctxpack::Error) do
      compile_method("Billing::Subscriptions#not_a_real_method")
    end
    assert_match(/not_a_real_method/, error.message)
    assert_match(/Billing::Subscriptions/, error.message)
    assert_match(/app\/services\/billing\/subscriptions\.rb/, error.message)
  end

  def test_def_self_does_not_match_instance_evidence
    error = assert_raises(Ctxpack::Error) do
      compile_method("Billing::UpgradeService#bulk_call")
    end
    assert_match(/bulk_call/, error.message)
    assert_match(/instance def/i, error.message)
  end

  def test_same_file_bfs_constants_append_last_no_eviction
    packet = compile_method("Billing::UpgradeService#call")
    assert packet.file("app/services/billing/upgrade_service.rb")
    assert_equal(
      %w[
        app/services/billing/upgrade_service.rb
        app/models/direct_alpha.rb
        app/models/direct_beta.rb
        app/models/direct_gamma.rb
        app/models/direct_delta.rb
      ],
      packet.files.map(&:path)
    )
    assert_nil packet.file("app/models/transitive_epsilon.rb")
    assert(
      packet.omitted_candidates.any? { |o|
        o.subject == "TransitiveEpsilon" && o.category == "constant_files"
      }
    )
  end

  def test_markdown_renders_method_seed_primary_inventory
    packet = compile_method("Billing::Subscriptions#upgrade!")
    markdown = Ctxpack.render_markdown(packet)
    assert_includes markdown, "method_seed_primary"
    assert_includes markdown, "Billing::Subscriptions#upgrade!"
    assert_includes markdown, "app/services/billing/subscriptions.rb"
  end

  def test_cli_from_method_flag_compiles
    with_method_cli_app do |app_root|
      result = run_cli(
        ["--from-method", "Billing::Subscriptions#upgrade!", "--stdout", "--task", "Inspect"],
        cwd: app_root
      )
      assert_equal 0, result.status, result.stderr
      assert_includes result.stdout, "method_seed_primary"
      assert_includes result.stdout, "app/services/billing/subscriptions.rb"
    end
  end

  def test_cli_positional_method_sugar_dispatches
    with_method_cli_app do |app_root|
      result = run_cli(
        ["Billing::Subscriptions#upgrade!", "--stdout", "--task", "Inspect"],
        cwd: app_root
      )
      assert_equal 0, result.status, result.stderr
      assert_includes result.stdout, "method_seed_primary"
    end
  end

  def test_cli_controller_hash_still_suggest_only_not_method
    with_method_cli_app do |app_root|
      result = run_cli(["AccountsController#upgrade"], cwd: app_root)
      assert_equal 1, result.status
      assert_includes result.stderr, "Ruby controller class reference"
      refute_includes result.stderr, "method seed"
    end
  end

  private

  def compile_method(evidence, task: "method seed test")
    Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.method(evidence)],
      task: task
    )
  end

  def with_method_cli_app
    require "tmpdir"
    require "fileutils"
    require "stringio"
    Dir.mktmpdir("ctxpack-method-seed") do |tmpdir|
      app_root = File.join(tmpdir, "sample_app")
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app("minitest_basic"), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# test Rails marker\n")
      yield app_root
    end
  end

  def run_cli(args, cwd:)
    require "ctxpack/cli"
    stdout = StringIO.new
    stderr = StringIO.new
    status = Ctxpack::CLI.new(
      stdout: stdout,
      stderr: stderr,
      cwd: cwd,
      history_provider: UnavailableHistoryProvider.new
    ).run(args)
    Struct.new(:status, :stdout, :stderr, keyword_init: true).new(
      status: status,
      stdout: stdout.string,
      stderr: stderr.string
    )
  end
end
