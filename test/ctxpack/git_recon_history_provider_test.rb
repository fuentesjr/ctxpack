require "test_helper"
require "fileutils"
require "json"
require "tmpdir"

class GitReconHistoryProviderTest < Minitest::Test
  RunnerResult = Struct.new(
    :exit_status,
    :signaled,
    :stdout,
    :stderr,
    :timed_out,
    :oversized,
    :spawn_error,
    keyword_init: true
  )

  class RecordingRunner
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = []
    end

    def call(**arguments)
      @calls << arguments
      @result
    end
  end

  def test_v1_success_is_rebased_ranked_and_bounded_as_typed_history
    Dir.mktmpdir("ctxpack-history-provider") do |tmpdir|
      executable = make_executable(tmpdir)
      repo_root = File.join(tmpdir, "repo")
      app_root = File.join(repo_root, "apps", "shop")
      FileUtils.mkdir_p(app_root)
      revision = "a" * 40
      response = {
        "v" => 1,
        "at" => revision,
        "path" => "apps/shop/app/controllers/accounts_controller.rb",
        "since" => 1_700_000_000,
        "commits" => [
          ["b" * 40, 1_800_000_000, "Fix heading # one"],
          ["c" * 40, 1_799_999_999, "Fix `fence` two"],
          ["d" * 40, 1_799_999_998, "Fix three"],
          ["e" * 40, 1_799_999_997, "Recent heading ## four"],
          ["f" * 40, 1_799_999_996, "Recent five"],
          ["1" * 40, 1_799_999_995, "Support one"],
          ["2" * 40, 1_799_999_994, "Support two"],
          ["3" * 40, 1_799_999_993, "Support three"]
        ],
        "recent" => [0, 3, 4],
        "repairs" => [0, 1, 2],
        "coupled" => [
          ["apps/shop/app/models/account.rb", 9, [5]],
          ["apps/shop/lib/`billing`.rb", 8, [6]],
          ["apps/shop/config/# heading.yml", 7, [7]],
          ["shared/outside.rb", 6, [0]]
        ],
        "origins" => []
      }
      runner = RecordingRunner.new(success_result(response))
      provider = Ctxpack::GitReconHistoryProvider.new(
        limits: Ctxpack::Compiler::LIMITS,
        runner: runner,
        env: { "PATH" => File.dirname(executable) }
      )

      history = provider.fetch(
        app_root: app_root,
        repo_root: repo_root,
        path: "app/controllers/accounts_controller.rb",
        revision: revision
      )

      assert_equal "included", history.status
      assert_equal "app/controllers/accounts_controller.rb", history.path
      assert_equal 5, history.facts.length
      assert_equal 3, history.truncated_count
      assert_equal(
        [
          ["coupled_path", "app/models/account.rb", 9, "1" * 40],
          ["commit", "b" * 40, "Fix heading # one", %w[repair recent]],
          ["commit", "e" * 40, "Recent heading ## four", ["recent"]],
          ["coupled_path", "lib/`billing`.rb", 8, "2" * 40],
          ["commit", "c" * 40, "Fix `fence` two", ["repair"]]
        ],
        history.facts.map do |fact|
          if fact.type == "coupled_path"
            [fact.type, fact.path, fact.count, fact.support_oid]
          else
            [fact.type, fact.oid, fact.subject, fact.roles]
          end
        end
      )
      assert_equal 1, runner.calls.length
      assert_equal(
        [executable, "facts", "--format=json", "--at", revision, "--", "apps/shop/app/controllers/accounts_controller.rb"],
        runner.calls.first.fetch(:argv)
      )
      assert_equal repo_root, runner.calls.first.fetch(:chdir)
      assert_equal 20, runner.calls.first.fetch(:timeout_seconds)
      assert_equal 16_384, runner.calls.first.fetch(:max_output_bytes)
    end
  end

  def test_absence_and_typed_provider_failures_become_coarse_omissions
    revision = "a" * 40
    request = {
      app_root: "/repo",
      repo_root: "/repo",
      path: "app/models/account.rb",
      revision: revision
    }
    absent = Ctxpack::GitReconHistoryProvider.new(
      limits: Ctxpack::Compiler::LIMITS,
      runner: RecordingRunner.new(success_result(base_response(revision: revision))),
      env: { "PATH" => "" }
    ).fetch(**request)
    assert_equal ["omitted", "executable_unavailable"], [absent.status, absent.reason]

    with_provider_result(success_result(base_response(revision: revision))) do |provider|
      invalid = provider.fetch(**request.merge(path: "../outside.rb"))
      assert_equal ["omitted", "invalid_request"], [invalid.status, invalid.reason]
    end

    {
      "not_repository" => "repository_unavailable",
      "shallow_repository" => "shallow_repository",
      "invalid_path" => "invalid_path",
      "invalid_revision" => "invalid_request",
      "git_failure" => "provider_failed"
    }.each do |code, reason|
      with_provider_result(error_result(code)) do |provider|
        history = provider.fetch(**request)
        assert_equal ["omitted", reason], [history.status, history.reason], code
      end
    end
  end

  def test_timeout_signal_spawn_failure_and_oversize_become_typed_omissions
    revision = "a" * 40
    request = {
      app_root: "/repo",
      repo_root: "/repo",
      path: "app/models/account.rb",
      revision: revision
    }
    cases = {
      "timed_out" => RunnerResult.new(timed_out: true, oversized: false, signaled: false),
      "provider_failed" => RunnerResult.new(timed_out: false, oversized: false, signaled: true),
      "executable_unavailable" => RunnerResult.new(timed_out: false, oversized: false, signaled: false, spawn_error: "unavailable"),
      "response_too_large" => RunnerResult.new(timed_out: false, oversized: true, signaled: false)
    }

    cases.each do |reason, result|
      with_provider_result(result) do |provider|
        history = provider.fetch(**request)
        assert_equal ["omitted", reason], [history.status, history.reason], reason
      end
    end
  end

  def test_malformed_unsupported_mismatched_and_invalid_v1_responses_are_rejected
    revision = "a" * 40
    request = {
      app_root: "/repo",
      repo_root: "/repo",
      path: "app/models/account.rb",
      revision: revision
    }
    valid = base_response(revision: revision)
    cases = {
      "malformed" => ["{", "invalid_response"],
      "wrong version" => [mutate(valid) { |value| value["v"] = 2 }, "unsupported_response"],
      "wrong path" => [mutate(valid) { |value| value["path"] = "app/models/other.rb" }, "mismatched_response"],
      "wrong revision" => [mutate(valid) { |value| value["at"] = "b" * 40 }, "mismatched_response"],
      "bad index" => [mutate(valid) { |value| value["recent"] = [4] }, "invalid_response"],
      "bad oid" => [mutate(valid) { |value| value["commits"][0][0] = "short" }, "invalid_response"],
      "control subject" => [mutate(valid) { |value| value["commits"][0][2] = "bad\nsubject" }, "invalid_response"],
      "control path" => [mutate(valid) { |value| value["coupled"][0][0] = "bad\tpath.rb" }, "invalid_response"],
      "traversing path" => [mutate(valid) { |value| value["coupled"][0][0] = "../outside.rb" }, "invalid_response"],
      "Windows path" => [mutate(valid) { |value| value["coupled"][0][0] = "C:\\outside.rb" }, "invalid_response"],
      "origins without range" => [mutate(valid) { |value| value["origins"] = [[0, 1, 1]] }, "invalid_response"],
      "extra field" => [mutate(valid) { |value| value["author"] = "private" }, "invalid_response"]
    }

    cases.each do |label, (body, reason)|
      result = body.is_a?(String) ? raw_result(body) : success_result(body)
      with_provider_result(result) do |provider|
        history = provider.fetch(**request)
        assert_equal ["omitted", reason], [history.status, history.reason], label
      end
    end
  end

  def test_payload_budget_stops_at_the_first_whole_fact_that_does_not_fit
    Dir.mktmpdir("ctxpack-history-provider") do |tmpdir|
      executable = make_executable(tmpdir)
      revision = "a" * 40
      response = base_response(revision: revision)
      response["coupled"] = [
        ["x" * 2_100, 2, [0]],
        ["small.rb", 1, [0]]
      ]
      runner = RecordingRunner.new(success_result(response))
      provider = Ctxpack::GitReconHistoryProvider.new(
        limits: Ctxpack::Compiler::LIMITS,
        runner: runner,
        env: { "PATH" => File.dirname(executable) }
      )

      history = provider.fetch(
        app_root: tmpdir,
        repo_root: tmpdir,
        path: "app/models/account.rb",
        revision: revision
      )

      assert_empty history.facts
      assert_equal 3, history.truncated_count
      payload = JSON.generate(history.facts.map(&:manifest_hash))
      assert_operator payload.bytesize, :<=, Ctxpack::Compiler::LIMITS.fetch(:max_history_payload_bytes)
    end
  end

  def test_process_runner_caps_combined_output_and_reaps_the_process_group
    Dir.mktmpdir("ctxpack-history-runner") do |tmpdir|
      output_script = write_script(
        tmpdir,
        "oversize",
        <<~SH
          i=0
          while [ "$i" -lt 20000 ]; do
            printf x
            i=$((i + 1))
          done
          sleep 30
        SH
      )
      runner = Ctxpack::GitReconHistoryProvider::ProcessRunner.new
      oversized = runner.call(
        argv: [output_script],
        chdir: tmpdir,
        timeout_seconds: 5,
        max_output_bytes: 1024
      )
      assert oversized.oversized
      assert_operator oversized.stdout.bytesize + oversized.stderr.bytesize, :<=, 1024

      pid_path = File.join(tmpdir, "child.pid")
      timeout_script = write_script(
        tmpdir,
        "timeout",
        <<~SH
          sleep 30 &
          child=$!
          printf '%s' "$child" > #{pid_path}
          wait "$child"
        SH
      )
      timed_out = runner.call(
        argv: [timeout_script],
        chdir: tmpdir,
        timeout_seconds: 1,
        max_output_bytes: 1024
      )
      assert timed_out.timed_out
      child_pid = File.read(pid_path).to_i
      assert process_eventually_gone?(child_pid), "expected timed-out child process #{child_pid} to be reaped"
    end
  end

  def test_process_runner_kills_a_timed_out_process_after_it_closes_output_pipes
    Dir.mktmpdir("ctxpack-history-runner") do |tmpdir|
      script = write_script(
        tmpdir,
        "closed-pipes",
        <<~SH
          trap '' TERM
          exec 1>&- 2>&-
          sleep 30
        SH
      )
      runner = Ctxpack::GitReconHistoryProvider::ProcessRunner.new
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = runner.call(
        argv: [script],
        chdir: tmpdir,
        timeout_seconds: 0.1,
        max_output_bytes: 1024
      )

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert result.timed_out
      assert_operator elapsed, :<, 2
    end
  end

  def test_unexpected_runner_defects_are_not_normalized_as_provider_omissions
    runner = Object.new
    runner.define_singleton_method(:call) { |**| raise RuntimeError, "implementation defect" }

    Dir.mktmpdir("ctxpack-history-provider") do |tmpdir|
      executable = make_executable(tmpdir)
      provider = Ctxpack::GitReconHistoryProvider.new(
        limits: Ctxpack::Compiler::LIMITS,
        runner: runner,
        env: { "PATH" => File.dirname(executable) }
      )

      error = assert_raises(RuntimeError) do
        provider.fetch(
          app_root: "/repo",
          repo_root: "/repo",
          path: "app/models/account.rb",
          revision: "a" * 40
        )
      end
      assert_equal "implementation defect", error.message
    end
  end

  private

  def make_executable(tmpdir)
    bin = File.join(tmpdir, "bin")
    FileUtils.mkdir_p(bin)
    path = File.join(bin, "git-recon")
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
    path
  end

  def success_result(response)
    RunnerResult.new(
      exit_status: 0,
      signaled: false,
      stdout: JSON.generate(response) + "\n",
      stderr: "",
      timed_out: false,
      oversized: false,
      spawn_error: nil
    )
  end

  def base_response(revision:, path: "app/models/account.rb")
    {
      "v" => 1,
      "at" => revision,
      "path" => path,
      "since" => 1_700_000_000,
      "commits" => [["b" * 40, 1_800_000_000, "Fix account"]],
      "recent" => [0],
      "repairs" => [0],
      "coupled" => [["app/services/account_sync.rb", 2, [0]]],
      "origins" => []
    }
  end

  def error_result(code)
    RunnerResult.new(
      exit_status: 1,
      signaled: false,
      stdout: JSON.generate("v" => 1, "error" => { "code" => code, "message" => "ignored upstream detail" }),
      stderr: "",
      timed_out: false,
      oversized: false,
      spawn_error: nil
    )
  end

  def raw_result(body)
    RunnerResult.new(
      exit_status: 0,
      signaled: false,
      stdout: body,
      stderr: "",
      timed_out: false,
      oversized: false,
      spawn_error: nil
    )
  end

  def with_provider_result(result)
    Dir.mktmpdir("ctxpack-history-provider") do |tmpdir|
      executable = make_executable(tmpdir)
      runner = RecordingRunner.new(result)
      provider = Ctxpack::GitReconHistoryProvider.new(
        limits: Ctxpack::Compiler::LIMITS,
        runner: runner,
        env: { "PATH" => File.dirname(executable) }
      )
      yield provider
    end
  end

  def mutate(value)
    copy = Marshal.load(Marshal.dump(value))
    yield copy
    copy
  end

  def write_script(tmpdir, name, body)
    path = File.join(tmpdir, name)
    File.write(path, "#!/bin/sh\n#{body}")
    File.chmod(0o755, path)
    path
  end

  def process_eventually_gone?(pid)
    100.times do
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        return true
      end
      sleep(0.01)
    end
    false
  end
end
