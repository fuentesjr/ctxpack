require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class RepoStampTest < Minitest::Test
  def test_fmt_10_11_12_repo_stamp_uses_git_discovery_and_dirty_status
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade"
    )

    commit, commit_status = Open3.capture2("git", "-C", fixture_app("minitest_basic"), "rev-parse", "HEAD", err: File::NULL)
    status_output, = Open3.capture2("git", "-C", fixture_app("minitest_basic"), "status", "--porcelain", err: File::NULL)

    assert commit_status.success?
    assert_equal commit.strip, packet.repo.commit
    assert_equal !status_output.empty?, packet.repo.dirty
  end

  def test_fmt_11_man_2_repo_stamp_is_nil_outside_git
    Dir.mktmpdir("ctxpack-outside-git") do |app_root|
      FileUtils.mkdir_p(File.join(app_root, "app", "controllers"))
      File.write(
        File.join(app_root, "app", "controllers", "accounts_controller.rb"),
        <<~RUBY
          class AccountsController < ApplicationController
            def upgrade
              head :ok
            end
          end
        RUBY
      )

      packet = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade")

      assert_nil packet.repo.commit
      refute packet.repo.dirty
    end
  end
end
