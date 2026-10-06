require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# ROOT-1 coverage for candidate kinds beyond the diff-primary and anchor spec tests.
class RootConfinementTest < Minitest::Test
  SECRET = "SECRET_OUTSIDE_ROOT"
  REASON = "path resolves outside the application root"

  def test_root_1_test_and_constant_candidates_symlinked_outside_root_are_omitted
    with_outside_app do |app_root, outside|
      link_outside(app_root, "test/controllers/accounts_controller_test.rb", outside)
      link_outside(app_root, "app/services/billing/subscriptions.rb", outside)

      packet = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")

      %w[test/controllers/accounts_controller_test.rb app/services/billing/subscriptions.rb].each do |path|
        assert_nil packet.file(path), "#{path} must not be included"
        omission = packet.omitted_candidates.find { |o| o.subject == path }
        assert omission, "expected ROOT-1 omission for #{path}"
        assert_equal REASON, omission.reason
        assert_nil omission.limit_key
      end
      refute(packet.tests.any? { |t| t.path == "test/controllers/accounts_controller_test.rb" })
      refute(packet.convention_constant_matches.any? { |m| m.path == "app/services/billing/subscriptions.rb" })
      assert_packet_free_of_secret(packet)
      assert_includes Ctxpack.render_markdown(packet),
        "Inspect omitted `test/controllers/accounts_controller_test.rb`; #{REASON}."
    end
  end

  def test_root_1_method_seed_primary_symlinked_outside_root_is_omitted_without_reading
    with_outside_app do |app_root, outside|
      link_outside(app_root, "app/services/billing/subscriptions.rb", outside)

      packet = Ctxpack.compile(
        app_root: app_root,
        seeds: [Ctxpack::Seed.method("Billing::Subscriptions#upgrade!")],
        task: "root confinement"
      )

      assert_nil packet.file("app/services/billing/subscriptions.rb")
      omission = packet.omitted_candidates.find { |o| o.subject == "app/services/billing/subscriptions.rb" }
      assert omission
      assert_equal REASON, omission.reason
      assert_nil omission.limit_key
      assert_packet_free_of_secret(packet)
    end
  end

  def test_root_1_renderer_refuses_to_read_snippet_outside_root
    with_outside_app do |app_root, outside|
      packet = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")
      link_outside(app_root, "app/controllers/accounts_controller.rb", outside)

      error = assert_raises(Ctxpack::Error) { Ctxpack.render_markdown(packet) }
      assert_includes error.message, "app/controllers/accounts_controller.rb"
      assert_includes error.message, "resolves outside the application root"
      refute_includes error.message, SECRET
    end
  end

  def test_root_1_diff_range_symlinked_directory_outside_root_gets_root_reason
    with_outside_app do |app_root, _outside|
      outside_dir = File.join(File.dirname(app_root), "outside_services")
      FileUtils.mkdir_p(outside_dir)
      File.write(File.join(outside_dir, "leak.rb"), "#{SECRET}\n")
      git!(app_root, "init")
      git!(app_root, "config", "user.email", "ctxpack@example.com")
      git!(app_root, "config", "user.name", "ctxpack")
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "baseline")
      FileUtils.rm_rf(File.join(app_root, "app/services"))
      File.symlink(outside_dir, File.join(app_root, "app/services"))
      git!(app_root, "add", "-A")
      git!(app_root, "commit", "-m", "services become an outside symlink")

      packet = Ctxpack.compile(app_root: app_root, seeds: [Ctxpack::Seed.diff("HEAD~1")], task: "root confinement")

      omission = packet.omitted_candidates.find { |o| o.subject == "app/services" }
      assert omission, "expected omission for the symlinked directory path"
      assert_equal REASON, omission.reason
      assert_nil omission.limit_key
      assert_packet_free_of_secret(packet)
    end
  end

  def test_root_1_constant_candidate_under_symlinked_directory_outside_root_is_omitted
    with_outside_app do |app_root, _outside|
      outside_dir = File.join(File.dirname(app_root), "outside_billing")
      FileUtils.mv(File.join(app_root, "app/services/billing"), outside_dir)
      File.write(File.join(outside_dir, "subscriptions.rb"), File.read(File.join(outside_dir, "subscriptions.rb")) + "# #{SECRET}\n")
      File.symlink(outside_dir, File.join(app_root, "app/services/billing"))

      packet = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")

      path = "app/services/billing/subscriptions.rb"
      assert_nil packet.file(path)
      omission = packet.omitted_candidates.find { |o| o.subject == path }
      assert omission, "expected ROOT-1 omission for constant under symlinked directory"
      assert_equal REASON, omission.reason
      assert_nil omission.limit_key
      assert_packet_free_of_secret(packet)
    end
  end

  private

  def with_outside_app
    Dir.mktmpdir("ctxpack-root-1") do |tmpdir|
      app_root = File.join(tmpdir, "app_root")
      FileUtils.cp_r(fixture_app("minitest_basic"), app_root)
      outside = File.join(tmpdir, "outside.rb")
      File.write(outside, "class Billing::Subscriptions\n  def upgrade!(plan:)\n    #{SECRET}\n  end\nend\n")
      yield app_root, outside
    end
  end

  def link_outside(app_root, relative_path, outside)
    path = File.join(app_root, relative_path)
    FileUtils.rm(path)
    File.symlink(outside, path)
  end

  def git!(root, *arguments)
    _stdout, stderr, status = Open3.capture3("git", "-C", root, *arguments)
    raise "git failed: #{stderr}" unless status.success?
  end

  def assert_packet_free_of_secret(packet)
    refute_includes Ctxpack.render_markdown(packet), SECRET
    refute_includes Ctxpack.render_manifest(packet), SECRET
    JSON.parse(Ctxpack.render_manifest(packet)).fetch("omitted_candidates").each do |entry|
      assert entry.key?("limit_key")
    end
  end
end
