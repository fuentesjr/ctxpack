require "json"
require "open3"
require "pathname"
require "ctxpack/packet"

module Ctxpack
  class GitReconHistoryProvider
    OID_PATTERN = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/
    CONTROL_PATTERN = /[\u0000-\u001f\u007f]/
    ERROR_CODES = %w[
      not_repository
      shallow_repository
      invalid_revision
      invalid_path
      invalid_range
      unsupported_format
      invalid_arguments
      unsupported_path_encoding
      git_failure
    ].freeze

    ResponseError = Class.new(StandardError) do
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason)
      end
    end
    private_constant :ResponseError

    class ProcessRunner
      Result = Struct.new(
        :exit_status,
        :signaled,
        :stdout,
        :stderr,
        :timed_out,
        :oversized,
        :spawn_error,
        keyword_init: true
      )

      def call(argv:, chdir:, timeout_seconds:, max_output_bytes:)
        stdout_buffer = +"".b
        stderr_buffer = +"".b
        mutex = Mutex.new
        total_bytes = 0
        oversized = false
        timed_out = false

        stdin, stdout, stderr, wait_thread = Open3.popen3(*argv, chdir: chdir, pgroup: true)
        stdin.close
        readers = [
          read_stream(stdout, stdout_buffer, mutex, max_output_bytes) do |size|
            total_bytes += size
            oversized = true if total_bytes > max_output_bytes
            [total_bytes, oversized]
          end,
          read_stream(stderr, stderr_buffer, mutex, max_output_bytes) do |size|
            total_bytes += size
            oversized = true if total_bytes > max_output_bytes
            [total_bytes, oversized]
          end
        ]

        deadline = monotonic_time + timeout_seconds
        loop do
          break unless wait_thread.alive? || readers.any?(&:alive?)
          break if mutex.synchronize { oversized }
          if monotonic_time < deadline
            sleep(0.01)
            next
          end

          timed_out = true
          break
        end

        if timed_out || mutex.synchronize { oversized }
          terminate_process_group(wait_thread.pid, wait_thread, readers)
        end

        readers.each(&:join)
        status = wait_thread.value
        Result.new(
          exit_status: status.exitstatus,
          signaled: status.signaled?,
          stdout: stdout_buffer,
          stderr: stderr_buffer,
          timed_out: timed_out,
          oversized: mutex.synchronize { oversized },
          spawn_error: nil
        )
      rescue Errno::ENOENT, Errno::EACCES
        Result.new(
          exit_status: nil,
          signaled: false,
          stdout: "",
          stderr: "",
          timed_out: false,
          oversized: false,
          spawn_error: "unavailable"
        )
      end

      private

      def read_stream(io, buffer, mutex, max_output_bytes, &account)
        Thread.new do
          loop do
            chunk = io.readpartial(4096)
            should_stop = mutex.synchronize do
              total, oversized = account.call(chunk.bytesize)
              remaining = [max_output_bytes - (total - chunk.bytesize), 0].max
              buffer << chunk.byteslice(0, remaining) if remaining.positive?
              oversized
            end
            break if should_stop
          end
        rescue EOFError, IOError, Errno::EIO
          nil
        ensure
          io.close unless io.closed?
        end
      end

      def terminate_process_group(pid, wait_thread, readers)
        Process.kill("TERM", -pid)
        deadline = monotonic_time + 0.2
        while (wait_thread.alive? || readers.any?(&:alive?)) && monotonic_time < deadline
          sleep(0.01)
        end

        Process.kill("KILL", -pid) if wait_thread.alive? || readers.any?(&:alive?)
        wait_thread.join
      rescue Errno::ESRCH
        wait_thread.join
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    def initialize(limits:, runner: ProcessRunner.new, env: ENV)
      @limits = limits
      @runner = runner
      @env = env
    end

    def fetch(app_root:, repo_root:, path:, revision:)
      executable = discover_executable
      return History.omitted(path: path, reason: "executable_unavailable") unless executable

      app_root = File.expand_path(app_root)
      repo_root = File.expand_path(repo_root)
      repo_path = translate_request_path(
        app_root: app_root,
        repo_root: repo_root,
        path: path
      )
      result = @runner.call(
        argv: [executable, "facts", "--format=json", "--at", revision, "--", repo_path],
        chdir: repo_root,
        timeout_seconds: @limits.fetch(:max_history_seconds),
        max_output_bytes: @limits.fetch(:max_history_response_bytes)
      )
      return History.omitted(path: path, reason: "response_too_large") if result.oversized
      return History.omitted(path: path, reason: "timed_out") if result.timed_out
      return History.omitted(path: path, reason: "executable_unavailable") if result.spawn_error
      return History.omitted(path: path, reason: "provider_failed") if result.signaled
      return History.omitted(path: path, reason: "provider_failed") unless result.stderr.to_s.empty?

      response = parse_response(result.stdout)
      if response.key?("error")
        validate_error_response!(response)
        raise ResponseError, "invalid_response" if result.exit_status == 0
        return History.omitted(path: path, reason: error_reason(response.dig("error", "code")))
      end

      raise ResponseError, "provider_failed" unless result.exit_status == 0

      validate_success_response!(response, revision: revision, repo_path: repo_path)
      facts = semantic_facts(response, app_root: app_root, repo_root: repo_root)
      selected = select_facts(facts)
      History.included(
        path: path,
        facts: selected,
        truncated_count: facts.length - selected.length
      )
    rescue JSON::ParserError
      History.omitted(path: path, reason: "invalid_response")
    rescue ResponseError => error
      History.omitted(path: path, reason: error.reason)
    end

    private

    def discover_executable
      @env.fetch("PATH", "").split(File::PATH_SEPARATOR).filter_map do |directory|
        next if directory.empty?

        candidate = File.expand_path("git-recon", directory)
        candidate if File.file?(candidate) && File.executable?(candidate)
      end.first
    end

    def parse_response(output)
      text = output.to_s.dup.force_encoding(Encoding::UTF_8)
      raise ResponseError, "invalid_response" unless text.valid_encoding?

      response = JSON.parse(text)
      raise ResponseError, "invalid_response" unless response.is_a?(Hash)

      response
    end

    def translate_request_path(app_root:, repo_root:, path:)
      validate_request_path!(path)
      prefix = app_prefix(app_root: app_root, repo_root: repo_root)
      repo_path = prefix == "." ? path : "#{prefix}/#{path}"
      validate_path!(repo_path)
      repo_path
    end

    def validate_request_path!(path)
      validate_path!(path)
    rescue ResponseError
      raise ResponseError, "invalid_request"
    end

    def app_prefix(app_root:, repo_root:)
      relative = Pathname.new(app_root).relative_path_from(Pathname.new(repo_root)).to_s
      if relative == ".." || relative.start_with?("../")
        raise ResponseError, "invalid_request"
      end

      relative.tr(File::SEPARATOR, "/")
    rescue ArgumentError
      raise ResponseError, "invalid_request"
    end

    def validate_success_response!(response, revision:, repo_path:)
      required = %w[v at path since commits recent repairs coupled origins]
      raise ResponseError, "invalid_response" unless response.keys.sort == required.sort
      raise ResponseError, "unsupported_response" unless response["v"] == 1
      validate_oid!(response["at"])
      raise ResponseError, "mismatched_response" unless response["at"] == revision
      validate_path!(response["path"])
      raise ResponseError, "mismatched_response" unless response["path"] == repo_path
      raise ResponseError, "invalid_response" unless response["since"].is_a?(Integer)

      commits = response["commits"]
      raise ResponseError, "invalid_response" unless commits.is_a?(Array) && commits.length <= 20
      commits.each { |row| validate_commit!(row) }
      oids = commits.map(&:first)
      raise ResponseError, "invalid_response" unless oids.uniq.length == oids.length

      recent = validate_indexes!(response["recent"], commits)
      repairs = validate_indexes!(response["repairs"], commits)
      validate_rank!(recent, commits)
      validate_rank!(repairs, commits)
      validate_coupled!(response["coupled"], commits)
      raise ResponseError, "invalid_response" unless response["origins"] == []
    end

    def validate_error_response!(response)
      raise ResponseError, "invalid_response" unless response.keys.sort == %w[error v]
      raise ResponseError, "unsupported_response" unless response["v"] == 1
      error = response["error"]
      unless error.is_a?(Hash) && error.keys.sort == %w[code message] &&
             ERROR_CODES.include?(error["code"]) &&
             error["message"].is_a?(String) && !error["message"].empty?
        raise ResponseError, "invalid_response"
      end
    end

    def validate_commit!(row)
      unless row.is_a?(Array) && row.length == 3 && row[1].is_a?(Integer) && row[1] >= 0 && row[2].is_a?(String)
        raise ResponseError, "invalid_response"
      end
      validate_oid!(row[0])
      subject = row[2]
      unless subject.valid_encoding? && subject.bytesize <= 160 && !subject.match?(CONTROL_PATTERN)
        raise ResponseError, "invalid_response"
      end
    end

    def validate_indexes!(indexes, commits)
      unless indexes.is_a?(Array) && indexes.length <= 5 && indexes.uniq.length == indexes.length &&
             indexes.all? { |index| index.is_a?(Integer) && index >= 0 && index < commits.length }
        raise ResponseError, "invalid_response"
      end

      indexes
    end

    def validate_rank!(indexes, commits)
      ranked = indexes.sort_by { |index| [-commits[index][1], commits[index][0]] }
      raise ResponseError, "invalid_response" unless indexes == ranked
    end

    def validate_coupled!(rows, commits)
      unless rows.is_a?(Array) && rows.length <= 5
        raise ResponseError, "invalid_response"
      end

      rows.each do |row|
        unless row.is_a?(Array) && row.length == 3 && row[1].is_a?(Integer) && row[1].positive?
          raise ResponseError, "invalid_response"
        end
        validate_path!(row[0])
        indexes = row[2]
        unless indexes.is_a?(Array) && indexes.length.between?(1, 5) && indexes.uniq.length == indexes.length &&
               indexes.all? { |index| index.is_a?(Integer) && index >= 0 && index < commits.length }
          raise ResponseError, "invalid_response"
        end
      end

      ranked = rows.sort_by { |row| [-row[1], row[0]] }
      raise ResponseError, "invalid_response" unless rows == ranked
    end

    def validate_oid!(oid)
      raise ResponseError, "invalid_response" unless oid.is_a?(String) && oid.match?(OID_PATTERN)
    end

    def validate_path!(path)
      unless path.is_a?(String) && path.valid_encoding? && !path.empty? &&
             !path.match?(CONTROL_PATTERN) && !Pathname.new(path).absolute? &&
             !path.match?(/\A[A-Za-z]:[\\\/]/) && !path.include?("\\") &&
             path != ".." && !path.start_with?("../") &&
             Pathname.new(path).cleanpath.to_s == path && path != "."
        raise ResponseError, "invalid_response"
      end
    end

    def semantic_facts(response, app_root:, repo_root:)
      commits = response.fetch("commits")
      recent = response.fetch("recent")
      repairs = response.fetch("repairs")
      repair_set = repairs.to_h { |index| [index, true] }
      recent_set = recent.to_h { |index| [index, true] }

      coupled = response.fetch("coupled").filter_map do |row|
        path = rebase_coupled_path(row[0], app_root: app_root, repo_root: repo_root)
        next unless path

        HistoryFact.new(
          type: "coupled_path",
          path: path,
          count: row[1],
          support_oid: commits.fetch(row[2].first).fetch(0)
        )
      end
      repair_facts = repairs.map do |index|
        commit_fact(
          commits.fetch(index),
          roles: ["repair", ("recent" if recent_set[index])].compact
        )
      end
      recent_only = recent.reject { |index| repair_set[index] }.map do |index|
        commit_fact(commits.fetch(index), roles: ["recent"])
      end

      round_robin(coupled, repair_facts, recent_only)
    end

    def rebase_coupled_path(repo_path, app_root:, repo_root:)
      prefix = app_prefix(app_root: app_root, repo_root: repo_root)
      return repo_path if prefix == "."
      return nil unless repo_path.start_with?(prefix + "/")

      repo_path.delete_prefix(prefix + "/")
    end

    def commit_fact(row, roles:)
      HistoryFact.new(
        type: "commit",
        oid: row[0],
        subject: row[2],
        roles: roles
      )
    end

    def round_robin(*groups)
      facts = []
      index = 0
      loop do
        added = false
        groups.each do |group|
          fact = group[index]
          next unless fact

          facts << fact
          added = true
        end
        break unless added

        index += 1
      end
      facts
    end

    def select_facts(facts)
      selected = []
      facts.each do |fact|
        break if selected.length >= @limits.fetch(:max_history_facts)

        candidate = selected + [fact]
        payload_bytes = JSON.generate(candidate.map(&:manifest_hash)).bytesize
        break if payload_bytes > @limits.fetch(:max_history_payload_bytes)

        selected << fact
      end
      selected
    end

    def error_reason(code)
      case code
      when "not_repository" then "repository_unavailable"
      when "shallow_repository" then "shallow_repository"
      when "invalid_path" then "invalid_path"
      when "invalid_revision", "invalid_range", "unsupported_format", "invalid_arguments", "unsupported_path_encoding"
        "invalid_request"
      else
        "provider_failed"
      end
    end
  end
end
