require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "../../eval/seed-spikes/run_method_test_leg_respike"

class MethodTestLegRespikeTest < Minitest::Test
  def test_evaluates_mirror_candidates_per_constant_method_pair
    with_repository do |root, revision|
      write(root, "app/models/billing/account.rb", <<~RUBY)
        module Billing
          class Account
            def upgrade
            end

            def cancel
            end
          end
        end
      RUBY
      write(root, "test/models/billing/account_test.rb", <<~RUBY)
        class Billing::AccountTest
          def test_upgrade
            Billing::Account.new.upgrade
          end
        end
      RUBY
      commit_all(root)
      revision = git(root, "rev-parse", "HEAD")

      payload = MethodTestLegRespike.evaluate_app(
        "fixture",
        path: root,
        sha: revision,
        framework: "minitest"
      )

      assert_equal 2, payload.fetch("population")
      assert_equal 2, payload.fetch("resolved")
      assert_equal 2, payload.fetch("candidate_pairs")
      assert_equal 2, payload.fetch("covered_pairs")
      assert_equal 0.5, payload.fetch("precision")
      assert_equal 1.0, payload.fetch("coverage")
      assert_equal 1, payload.fetch("by_label").fetch("mirror_relevant")
      assert_equal 1, payload.fetch("by_label").fetch("mirror_constant_only")
      assert_equal revision, payload.fetch("sha")
    end
  end

  def test_evaluate_app_uses_only_frozen_framework_mirrors
    with_repository do |root, _revision|
      write(root, "app/models/billing/account.rb", <<~RUBY)
        module Billing
          class Account
            def upgrade
            end
          end
        end
      RUBY
      modern = "test/models/billing/account_test.rb"
      legacy = "test/unit/billing/account_test.rb"
      rspec = "spec/models/billing/account_spec.rb"
      source = "Billing::Account.new.upgrade\n"
      [modern, legacy, rspec].each { |path| write(root, path, source) }
      commit_all(root)
      revision = git(root, "rev-parse", "HEAD")

      minitest = MethodTestLegRespike.evaluate_app(
        "fixture",
        path: root,
        sha: revision,
        framework: "minitest"
      )
      assert_equal 2, minitest.fetch("candidate_pairs")
      assert_equal(
        %w[minitest_mirror minitest_legacy_unit],
        minitest.fetch("candidate_count_by_rule").keys
      )

      rspec_payload = MethodTestLegRespike.evaluate_app(
        "fixture",
        path: root,
        sha: revision,
        framework: "rspec"
      )
      assert_equal 1, rspec_payload.fetch("candidate_pairs")
      assert_equal({ "rspec_mirror" => 1 }, rspec_payload.fetch("candidate_count_by_rule"))
    end
  end

  def test_verdict_applies_frozen_gate_precedence
    passing = [
      app_metrics(precision: 0.8, coverage: 0.1, candidates: 30),
      app_metrics(precision: 0.7, coverage: 0.05, candidates: 25),
      app_metrics(precision: 0.75, coverage: 0.08, candidates: 40)
    ]
    assert_equal "PROCEED", MethodTestLegRespike.verdict(passing).fetch("outcome")

    precision_failure = passing.map(&:dup)
    precision_failure.first["precision"] = 0.5
    assert_equal "DROP", MethodTestLegRespike.verdict(precision_failure).fetch("outcome")

    coverage_failure = passing.map(&:dup)
    coverage_failure.first["coverage"] = 0.0
    coverage_failure[1]["coverage"] = 0.0
    assert_equal "DEFER", MethodTestLegRespike.verdict(coverage_failure).fetch("outcome")
  end

  private

  def app_metrics(precision:, coverage:, candidates:)
    {
      "precision" => precision,
      "coverage" => coverage,
      "candidate_pairs" => candidates
    }
  end

  def with_repository
    Dir.mktmpdir("method-test-leg-repo") do |root|
      git(root, "init", "--quiet")
      write(root, "README.md", "fixture\n")
      commit_all(root)
      yield root, git(root, "rev-parse", "HEAD")
    end
  end

  def commit_all(root)
    git(root, "add", ".")
    git(
      root,
      "-c", "user.name=Fixture",
      "-c", "user.email=fixture@example.test",
      "commit", "--quiet", "-m", "fixture"
    )
  end

  def write(root, relative_path, content)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def git(root, *arguments)
    stdout, stderr, status = Open3.capture3("git", "-C", root, *arguments)
    raise stderr unless status.success?

    stdout.strip
  end
end
