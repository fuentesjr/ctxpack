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

  def test_patch_file_path_produces_snippets_for_changed_ruby
    with_diff_repo do |app_root|
      patch_path = write_patch_for_accounts(app_root)
      packet = compile_diff(patch_path, app_root: app_root)
      item = packet.file("app/controllers/accounts_controller.rb")
        .evidence_items.find { |e| e.reason_code == "diff_seed_primary" }
      refute_empty item.snippet_ranges, "patch hunks should yield snippet ranges"
      assert(item.snippet_ranges.any? { |s, e| s <= 10 && e >= 10 })
      assert_includes Ctxpack.render_markdown(packet), "### `app/controllers/accounts_controller.rb`"
    end
  end

  def test_patch_mode_is_independent_of_process_cwd
    with_diff_repo do |app_root|
      patch_path = write_patch_for_accounts(app_root)
      packet = Dir.chdir(File.join(app_root, "app", "models")) do
        compile_diff(patch_path, app_root: app_root)
      end
      refute_nil packet.file("app/controllers/accounts_controller.rb")
    end
  end

  def test_range_in_monorepo_subdirectory_app_root
    with_diff_repo(app_subdir: "apps/sample_app") do |app_root|
      packet = compile_diff("HEAD~1", app_root: app_root)
      paths = packet.files_with_reason("diff_seed_primary").map(&:path)
      assert_equal ["app/controllers/accounts_controller.rb", "app/models/order.rb"], paths
      item = packet.file("app/controllers/accounts_controller.rb")
        .evidence_items.find { |e| e.reason_code == "diff_seed_primary" }
      refute_empty item.snippet_ranges
    end
  end

  def test_patch_in_monorepo_subdirectory_app_root
    with_diff_repo(app_subdir: "apps/sample_app") do |app_root|
      patch_path = write_patch_for_accounts(app_root)
      packet = compile_diff(patch_path, app_root: app_root)
      item = packet.file("app/controllers/accounts_controller.rb")
        &.evidence_items&.find { |e| e.reason_code == "diff_seed_primary" }
      refute_nil item, "enclosing repo must not filter app-relative patch paths"
      refute_empty item.snippet_ranges
    end
  end

  def test_changed_path_with_invalid_utf8_is_omitted_not_fatal
    with_diff_repo do |app_root|
      blob, _err, _status = Open3.capture3("git", "-C", app_root, "hash-object", "-w", "--stdin", stdin_data: "class B\nend\n")
      git!(app_root, "update-index", "--add", "--cacheinfo", "100644,#{blob.strip},app/models/b\xFF.rb".b)
      git!(app_root, "commit", "-m", "add non-utf8 path")

      packet = compile_diff("HEAD~1..HEAD", app_root: app_root)
      subjects = packet.omitted_candidates.map(&:subject)
      assert(subjects.any? { |s| s.start_with?("app/models/b") }, subjects.inspect)
      assert(subjects.all?(&:valid_encoding?))
      Ctxpack.render_markdown(packet)
    end
  end

  def test_non_ascii_changed_path_is_a_primary
    with_diff_repo do |app_root|
      path = "app/models/café.rb"
      File.write(File.join(app_root, path), "class Cafe\n  def brew\n    :espresso\n  end\nend\n")
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "add cafe")

      packet = compile_diff("HEAD~1", app_root: app_root)
      assert_equal [path], packet.files_with_reason("diff_seed_primary").map(&:path)
    end
  end

  def test_renamed_path_with_non_ascii_names
    with_diff_repo do |app_root|
      git!(app_root, "mv", "app/models/order.rb", "app/models/pedido_ñ.rb")
      git!(app_root, "commit", "-m", "rename order")

      packet = compile_diff("HEAD~1", app_root: app_root)
      assert_equal ["app/models/pedido_ñ.rb"], packet.files_with_reason("diff_seed_primary").map(&:path)
      assert(packet.omitted_candidates.any? { |o| o.subject == "app/models/order.rb" })
    end
  end

  def test_syntax_error_in_changed_ruby_falls_back_to_window_snippet
    with_diff_repo do |app_root|
      path = "app/models/broken.rb"
      File.write(File.join(app_root, path), "class Broken\n  def oops(\nend\n")
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "add broken")

      packet = compile_diff("HEAD~1", app_root: app_root)
      item = packet.file(path).evidence_items.find { |e| e.reason_code == "diff_seed_primary" }
      assert_equal [[1, 3]], item.snippet_ranges
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

  def test_cli_rejects_option_shaped_diff_evidence_without_side_effects
    with_diff_repo do |app_root|
      target = File.join(File.dirname(app_root), "injected_output.txt")
      result = run_cli(
        ["--from-diff=--output=#{target}", "--stdout", "--task", "Review diff"],
        cwd: app_root
      )
      refute_equal 0, result.status
      refute File.exist?(target), "git must never receive user evidence as an option"
      assert_match(/diff seed evidence must not begin with "-"/, result.stderr)
    end
  end

  def test_seed_factory_rejects_option_shaped_evidence
    error = assert_raises(ArgumentError) { Ctxpack::Seed.diff("--output=/tmp/x") }
    assert_match(/must not begin with "-"/, error.message)
  end

  def test_compiler_never_passes_option_shaped_range_to_git
    with_diff_repo do |app_root|
      target = File.join(File.dirname(app_root), "compiler_injected.txt")
      seed = Ctxpack::Seed.new(kind: "diff", evidence: "--output=#{target}", identity: "x")
      assert_raises(Ctxpack::Error) do
        Ctxpack.compile(app_root: app_root, seeds: [seed], task: "t")
      end
      refute File.exist?(target), "range must follow --end-of-options"
    end
  end

  def test_cli_absolute_patch_path_is_stored_app_relative
    with_diff_repo do |app_root|
      patch_rel = write_patch_for_accounts(app_root)
      result = run_cli(
        ["--from-diff", File.join(app_root, patch_rel), "--stdout", "--task", "Review patch"],
        cwd: app_root
      )
      assert_equal 0, result.status, result.stderr
      assert_includes result.stdout, patch_rel
      refute_includes result.stdout, app_root
      refute_includes result.stdout, File.dirname(app_root)
    end
  end

  def test_cli_accepts_absolute_patch_path_through_symlinked_app_root
    with_diff_repo do |app_root|
      patch_rel = write_patch_for_accounts(app_root)
      link = File.join(File.dirname(app_root), "linked_app")
      File.symlink(app_root, link)
      [File.join(link, patch_rel), File.join(File.realpath(app_root), patch_rel)].each do |evidence|
        result = run_cli(["--from-diff", evidence, "--stdout", "--task", "Review patch"], cwd: link)
        assert_equal 0, result.status, result.stderr
        assert_includes result.stdout, "diff: `#{patch_rel}`"
      end
    end
  end

  def test_cli_rejects_in_root_symlink_to_patch_outside_app_root
    with_diff_repo do |app_root|
      outside = File.join(File.dirname(app_root), "outside.patch")
      File.write(outside, File.read(File.join(app_root, write_patch_for_accounts(app_root))))
      File.symlink(outside, File.join(app_root, "patches", "linked.patch"))
      result = run_cli(["--from-diff", "patches/linked.patch", "--stdout", "--task", "Review patch"], cwd: app_root)
      refute_equal 0, result.status
      assert_match(/diff seed patch path escapes the application root/, result.stderr)
    end
  end

  def test_cli_rejects_patch_path_outside_app_root
    with_diff_repo do |app_root|
      outside = File.join(File.dirname(app_root), "outside.patch")
      File.write(outside, File.read(File.join(app_root, write_patch_for_accounts(app_root))))
      [outside, "../outside.patch"].each do |evidence|
        result = run_cli(["--from-diff", evidence, "--stdout", "--task", "Review patch"], cwd: app_root)
        refute_equal 0, result.status, evidence
        assert_match(/diff seed patch path escapes the application root/, result.stderr)
      end
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

  def with_diff_repo(app_subdir: nil)
    Dir.mktmpdir("ctxpack-diff-seed") do |tmpdir|
      repo_root = app_subdir ? File.join(tmpdir, "mono") : File.join(tmpdir, "sample_app")
      app_root = app_subdir ? File.join(repo_root, app_subdir) : repo_root
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app("minitest_basic"), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# test Rails marker\n")

      git!(repo_root, "init")
      git!(repo_root, "config", "core.quotePath", "true")
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
