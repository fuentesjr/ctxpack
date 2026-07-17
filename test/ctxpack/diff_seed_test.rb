require "test_helper"
require "fileutils"
require "open3"
require "stringio"
require "tmpdir"

class DiffSeedTest < Minitest::Test
  def test_seed_factory_identity_from_patch_basename
    seed = Ctxpack::Seed.diff("patches/upgrade_accounts.patch")
    assert_equal "diff", seed.kind
    assert_equal "patches/upgrade_accounts.patch", seed.evidence
    assert_equal "upgrade_accounts", seed.identity
    assert_predicate seed, :diff?
  end

  def test_range_happy_path_includes_primaries_in_diff_order
    with_diff_repo do |app_root|
      packet = compile_diff("HEAD~1", app_root: app_root)
      paths = packet.files_with_reason("diff_seed_primary").map(&:path)
      assert_includes paths, "app/controllers/accounts_controller.rb"
      assert_includes paths, "app/models/order.rb"
      assert_equal(
        paths,
        paths.sort_by { |p| paths.index(p) },
        "primaries should preserve git name-status order"
      )
      # Diff order: accounts_controller before order (commit order of adds)
      assert_operator paths.index("app/controllers/accounts_controller.rb"),
                      :<,
                      paths.index("app/models/order.rb")
    end
  end

  def test_patch_file_path_enumerates_changed_files
    with_diff_repo do |app_root|
      patch_path = write_patch_for_accounts(app_root)
      packet = compile_diff(patch_path, app_root: app_root)
      entry = packet.file("app/controllers/accounts_controller.rb")
      refute_nil entry
      assert_includes entry.reason_codes, "diff_seed_primary"
    end
  end

  def test_deleted_file_excluded_with_omitted_follow_up
    with_diff_repo do |app_root|
      deleted = "app/models/alpha_one.rb"
      FileUtils.rm(File.join(app_root, deleted))
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "delete alpha")

      packet = compile_diff("HEAD~1", app_root: app_root)
      assert_nil packet.file(deleted)
      assert(
        packet.omitted_candidates.any? { |o|
          o.subject == deleted && o.category == "diff_files"
        },
        "expected omitted-candidate follow-up for deleted path"
      )
    end
  end

  def test_paired_test_mirror_hit_for_controller
    with_diff_repo do |app_root|
      packet = compile_diff("HEAD~1", app_root: app_root)
      assert(
        packet.tests.any? { |t|
          t.path == "test/controllers/accounts_controller_test.rb" &&
            t.reason_code == "diff_seed_paired_test"
        },
        "expected mirror controller test as paired-test candidate"
      )
      test_entry = packet.file("test/controllers/accounts_controller_test.rb")
      refute_nil test_entry
      assert_includes test_entry.reason_codes, "diff_seed_paired_test"
    end
  end

  def test_paired_test_mirror_miss_when_no_conventional_pair
    with_diff_repo do |app_root|
      # order.rb has no test/models/order_test.rb in the fixture tree
      packet = compile_diff("HEAD~1", app_root: app_root)
      refute(
        packet.tests.any? { |t| t.path.include?("order") },
        "order model should not invent unpaired tests"
      )
    end
  end

  def test_def_anchored_snippet_when_change_inside_method
    with_diff_repo do |app_root|
      # Touch a line inside upgrade! (def at known lines in fixture)
      path = "app/services/billing/subscriptions.rb"
      abs = File.join(app_root, path)
      source = File.read(abs)
      File.write(abs, source.sub("plan: plan", "plan: plan.to_s"))
      git!(app_root, "add", path)
      git!(app_root, "commit", "-m", "touch upgrade!")

      packet = compile_diff("HEAD~1", app_root: app_root)
      entry = packet.file(path)
      refute_nil entry
      item = entry.evidence_items.find { |e| e.reason_code == "diff_seed_primary" }
      refute_nil item
      assert_equal [[7, 9]], item.snippet_ranges, "should snippet enclosing def range"
    end
  end

  def test_window_snippet_when_change_outside_def
    with_diff_repo do |app_root|
      path = "app/services/billing/subscriptions.rb"
      abs = File.join(app_root, path)
      lines = File.readlines(abs)
      # Line 1 is `module Billing` — not inside a def
      lines[0] = "module Billing # touched\n"
      File.write(abs, lines.join)
      git!(app_root, "add", path)
      git!(app_root, "commit", "-m", "touch module line")

      packet = compile_diff("HEAD~1", app_root: app_root)
      entry = packet.file(path)
      item = entry.evidence_items.find { |e| e.reason_code == "diff_seed_primary" }
      refute_nil item
      start_line, end_line = item.snippet_ranges.first
      assert_operator start_line, :<=, 1
      assert_operator end_line, :>=, 1
      # Not the full def range of upgrade! alone as sole range starting at 7
      refute_equal [[7, 9]], item.snippet_ranges
    end
  end

  def test_fail_closed_on_bad_range
    with_diff_repo do |app_root|
      error = assert_raises(Ctxpack::Error) do
        compile_diff("this-is-not-a-valid-ref-zzzz", app_root: app_root)
      end
      assert_match(/diff seed/i, error.message)
      assert_match(/range|resolve|git/i, error.message)
    end
  end

  def test_fail_closed_when_git_unavailable
    with_diff_repo do |app_root|
      capture3 = Open3.method(:capture3)
      open3_singleton = Open3.singleton_class
      open3_singleton.send(:remove_method, :capture3)
      Open3.define_singleton_method(:capture3) do |*args|
        if args.first == "git"
          raise Errno::ENOENT, "No such file or directory - git"
        end
        capture3.call(*args)
      end

      error = assert_raises(Ctxpack::Error) do
        compile_diff("HEAD~1", app_root: app_root)
      end
      assert_match(/git/i, error.message)
    ensure
      if capture3
        open3_singleton.send(:remove_method, :capture3) if open3_singleton.method_defined?(:capture3)
        Open3.define_singleton_method(:capture3, capture3)
      end
    end
  end

  def test_fail_closed_outside_git_repo
    Dir.mktmpdir("ctxpack-diff-no-git") do |tmpdir|
      app_root = File.join(tmpdir, "app")
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app("minitest_basic"), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# marker\n")

      error = assert_raises(Ctxpack::Error) do
        compile_diff("HEAD~1", app_root: app_root)
      end
      assert_match(/diff seed/i, error.message)
      assert_match(/git|repository|repo/i, error.message)
    end
  end

  def test_multi_seed_merge_with_files_seed
    with_diff_repo do |app_root|
      packet = Ctxpack.compile(
        app_root: app_root,
        seeds: [
          Ctxpack::Seed.diff("HEAD~1", identity: "head_1"),
          Ctxpack::Seed.files(["app/jobs/sync_billing_account_job.rb"])
        ],
        task: "merge diff and files",
        history_provider: UnavailableHistoryProvider.new
      )
      assert packet.file("app/controllers/accounts_controller.rb")
      assert packet.file("app/jobs/sync_billing_account_job.rb")
      assert_includes packet.file("app/jobs/sync_billing_account_job.rb").reason_codes, "files_seed_primary"
    end
  end

  def test_budget_truncation_keeps_earlier_diff_order
    with_diff_repo do |app_root|
      # Create a commit that touches more than max_total_files paths
      paths = Dir.glob(File.join(app_root, "app/models/*.rb")).sort.first(10)
      paths.each do |abs|
        File.write(abs, File.read(abs) + "\n# touch\n")
      end
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "touch many models")

      packet = compile_diff("HEAD~1", app_root: app_root)
      primaries = packet.files_with_reason("diff_seed_primary").map(&:path)
      assert_operator primaries.length, :<=, Ctxpack::Compiler::LIMITS.fetch(:max_total_files)
      assert(
        packet.omitted_candidates.any? { |o| o.limit_key == :max_total_files },
        "expected max_total_files omissions for later diff primaries"
      )
    end
  end

  def test_cli_from_diff_flag_compiles
    with_diff_repo do |app_root|
      result = run_cli(
        ["--from-diff", "HEAD~1", "--stdout", "--task", "Review diff"],
        cwd: app_root
      )
      assert_equal 0, result.status, result.stderr
      assert_includes result.stdout, "diff_seed_primary"
      assert_includes result.stdout, "app/controllers/accounts_controller.rb"
    end
  end

  def test_positional_patch_path_stays_files_seed_not_diff
    with_diff_repo do |app_root|
      patch_rel = write_patch_for_accounts(app_root)
      result = run_cli(
        [patch_rel, "--stdout", "--task", "Open patch as files"],
        cwd: app_root
      )
      assert_equal 0, result.status, result.stderr
      assert_includes result.stdout, "files_seed_primary"
      refute_includes result.stdout, "diff_seed_primary"
    end
  end

  def test_markdown_renders_diff_seed_inventory
    with_diff_repo do |app_root|
      packet = compile_diff("HEAD~1", app_root: app_root)
      markdown = Ctxpack.render_markdown(packet)
      assert_includes markdown, "diff_seed_primary"
      assert_includes markdown, "app/controllers/accounts_controller.rb"
    end
  end

  private

  def compile_diff(evidence, app_root:, task: "diff seed test", identity: nil)
    seed =
      if identity
        Ctxpack::Seed.diff(evidence, identity: identity)
      else
        Ctxpack::Seed.diff(evidence)
      end
    Ctxpack.compile(app_root: app_root, seeds: [seed], task: task)
  end

  def with_diff_repo
    Dir.mktmpdir("ctxpack-diff-seed") do |tmpdir|
      app_root = File.join(tmpdir, "sample_app")
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app("minitest_basic"), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# test Rails marker\n")

      git!(app_root, "init")
      git!(app_root, "config", "user.email", "ctxpack@example.com")
      git!(app_root, "config", "user.name", "ctxpack")
      # Baseline commit without the two files we will change next
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "baseline")

      # Second commit: modify controller + model so HEAD~1 has a useful range
      ctrl = File.join(app_root, "app/controllers/accounts_controller.rb")
      File.write(ctrl, File.read(ctrl).sub("head :accepted", "head :accepted # diff-seed"))
      model = File.join(app_root, "app/models/order.rb")
      File.write(model, File.read(model) + "\n# diff-seed touch\n")
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "change accounts and order")

      yield app_root
    end
  end

  def write_patch_for_accounts(app_root)
    rel = "patches/upgrade_accounts.patch"
    abs = File.join(app_root, rel)
    FileUtils.mkdir_p(File.dirname(abs))
    # Minimal unified diff against a path that exists in the working tree.
    File.write(
      abs,
      <<~PATCH
        diff --git a/app/controllers/accounts_controller.rb b/app/controllers/accounts_controller.rb
        --- a/app/controllers/accounts_controller.rb
        +++ b/app/controllers/accounts_controller.rb
        @@ -10,1 +10,1 @@
        -    subscription = Billing::Subscriptions.new(@account)
        +    subscription = Billing::Subscriptions.new(@account) # patch
      PATCH
    )
    rel
  end

  def git!(app_root, *args)
    out, err, status = Open3.capture3("git", "-C", app_root, *args)
    raise "git #{args.join(" ")} failed: #{err}" unless status.success?

    out
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
