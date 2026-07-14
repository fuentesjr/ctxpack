require "test_helper"
require "ctxpack/cli"
require "digest"
require "fileutils"
require "stringio"
require "tmpdir"
require "yaml"

class FixtureEvalsTest < Minitest::Test
  Case = Struct.new(:path, :name, :app, :command, :expectation, keyword_init: true)
  Result = Struct.new(:status, :stdout, :stderr, keyword_init: true)

  CASES_DIR = File.expand_path("../fixtures/evals", __dir__)
  CASE_FILES = Dir.glob(File.join(CASES_DIR, "*.yml")).sort.freeze
  raise "expected at least one fixture eval case in #{CASES_DIR}" if CASE_FILES.empty?

  CASES = CASE_FILES.map do |path|
    data = YAML.safe_load_file(path, aliases: false)
    Case.new(
      path: path,
      name: data.fetch("name"),
      app: data.fetch("app", "minitest_basic"),
      command: data.fetch("command"),
      expectation: data.fetch("expect")
    )
  end.freeze

  CASES.each do |eval_case|
    define_method("test_eval_#{eval_case.name}_packet_expectations") do
      packet = compile_case(eval_case)
      expected = eval_case.expectation

      if expected["entrypoint"]
        assert_equal expected.fetch("entrypoint").fetch("file"), packet.entrypoint.file
        assert_equal expected.fetch("entrypoint").fetch("action"), packet.entrypoint.action
      end

      expected.fetch("include").each do |file|
        packet_file = packet.file(file.fetch("path"))
        refute_nil packet_file, "expected #{file.fetch("path")} to be included"
        assert_includes packet_file.reason_codes, file.fetch("reason_code")
      end

      expected.fetch("exclude").each do |path|
        assert_nil packet.file(path), "expected #{path} to be absent"
      end

      if expected["file_order"]
        assert_equal expected.fetch("file_order"), packet.files.map(&:path)
      end

      expected.fetch("omitted", []).each do |omitted|
        assert(packet.omitted_candidates.any? { |candidate| omitted_candidate_matches?(candidate, omitted) },
               "expected omitted candidate #{omitted.inspect}")
      end

      expected.fetch("tests").each do |command|
        assert_includes packet.tests.map(&:command), command
      end

      if expected["manifest"]
        manifest = packet.to_h
        expected.fetch("manifest").each do |key, value|
          assert_equal value, manifest.fetch(key), "expected manifest #{key.inspect} to match"
        end
      end

      assert_operator packet.files.length, :<=, expected.fetch("max_files")
      assert_packet_within_limits(packet)
    end

    define_method("test_eval_#{eval_case.name}_cli_output_is_deterministic") do
      with_cli_app(eval_case) do |app_root|
        out_path = File.join(app_root, "tmp", "#{eval_case.name}.md")
        manifest_path = File.join(app_root, "tmp", "#{eval_case.name}.json")
        args = cli_args(eval_case, out_path)

        first = run_cli(args, cwd: app_root)
        assert_equal 0, first.status, first.stderr
        assert File.file?(out_path), "expected #{out_path} to be written"
        assert File.file?(manifest_path), "expected #{manifest_path} to be written"
        first_markdown_hash = Digest::SHA256.file(out_path).hexdigest
        first_manifest_hash = Digest::SHA256.file(manifest_path).hexdigest

        second = run_cli(args, cwd: app_root)
        assert_equal 0, second.status, second.stderr
        assert File.file?(out_path), "expected #{out_path} to be written"
        assert File.file?(manifest_path), "expected #{manifest_path} to be written"
        second_markdown_hash = Digest::SHA256.file(out_path).hexdigest
        second_manifest_hash = Digest::SHA256.file(manifest_path).hexdigest

        assert_equal first_markdown_hash, second_markdown_hash
        assert_equal first_manifest_hash, second_manifest_hash
      end
    end
  end

  private

  def compile_case(eval_case)
    command = eval_case.command
    kwargs = {
      app_root: fixture_app(eval_case.app),
      task: command.fetch("task")
    }
    if command["seeds"]
      kwargs[:seeds] = command.fetch("seeds").map { |s| seed_from_yaml(s) }
    elsif command["from_test"]
      kwargs[:seeds] = [Ctxpack::Seed.test(command.fetch("from_test"))]
    elsif command["from_files"]
      kwargs[:seeds] = [Ctxpack::Seed.files(Array(command.fetch("from_files")))]
    else
      kwargs[:anchor] = command.fetch("anchor")
    end
    Ctxpack.compile(**kwargs)
  end

  def seed_from_yaml(spec)
    case spec.fetch("kind")
    when "anchor" then Ctxpack::Seed.anchor(spec.fetch("evidence"))
    when "test" then Ctxpack::Seed.test(spec.fetch("evidence"))
    when "files" then Ctxpack::Seed.files(Array(spec.fetch("evidence")))
    when "error" then Ctxpack::Seed.error(Array(spec.fetch("evidence")))
    when "method" then Ctxpack::Seed.method(spec.fetch("evidence"))
    else
      raise "unknown seed kind #{spec.fetch("kind")}"
    end
  end

  def assert_packet_within_limits(packet)
    limits = Ctxpack::Compiler::LIMITS

    assert_operator packet.files.length, :<=, limits.fetch(:max_total_files)
    assert_operator packet.files_with_reason("referenced_constant").length, :<=, limits.fetch(:max_constant_files)
    assert_operator packet.files_with_reason("view_candidate").length, :<=, limits.fetch(:max_view_files)
    assert_operator packet.tests.length, :<=, limits.fetch(:max_test_files)

    packet.files.each do |entry|
      snippet_lines = entry.evidence_items.flat_map(&:snippet_ranges).sum do |range|
        range.last - range.first + 1
      end
      assert_operator snippet_lines, :<=, limits.fetch(:max_snippet_lines_per_file)
    end
  end

  def omitted_candidate_matches?(candidate, expected)
    candidate.category == expected.fetch("category") &&
      candidate.subject == expected.fetch("subject") &&
      (!expected.key?("reason") || candidate.reason == expected.fetch("reason"))
  end

  def with_cli_app(eval_case)
    Dir.mktmpdir("ctxpack-fixture-eval") do |tmpdir|
      app_root = File.join(tmpdir, eval_case.app)
      FileUtils.mkdir_p(app_root)
      FileUtils.cp_r(Dir.glob(File.join(fixture_app(eval_case.app), "*")), app_root)
      FileUtils.mkdir_p(File.join(app_root, "config"))
      File.write(File.join(app_root, "config", "application.rb"), "# test Rails marker\n")
      yield app_root
    end
  end

  def cli_args(eval_case, out_path)
    command = eval_case.command
    args =
      if command["seeds"]
        # Multi-seed / error cases: compile-only via API determinism still
        # covered by packet expectations; CLI determinism uses primary seed.
        primary = command.fetch("seeds").first
        case primary.fetch("kind")
        when "anchor"
          ["packet", primary.fetch("evidence"), "--out", out_path, "--force", "--manifest"]
        when "test"
          ["--from-test", primary.fetch("evidence"), "--out", out_path, "--force", "--manifest"]
        when "files"
          ["--from-files", Array(primary.fetch("evidence")).join(","), "--out", out_path, "--force", "--manifest"]
        when "error"
          # CLI needs paste; use --from-files of the frame path as a stand-in for
          # artifact determinism (error paste identity is hash-stable separately).
          frame_path = Array(primary.fetch("evidence")).first.split(":", 2).first
          ["--from-files", frame_path, "--out", out_path, "--force", "--manifest"]
        when "method"
          ["--from-method", primary.fetch("evidence"), "--out", out_path, "--force", "--manifest"]
        else
          raise "unsupported seed for CLI eval #{primary.fetch("kind")}"
        end
      elsif command["from_test"]
        ["--from-test", command.fetch("from_test"), "--out", out_path, "--force", "--manifest"]
      elsif command["from_files"]
        files = Array(command.fetch("from_files")).join(",")
        ["--from-files", files, "--out", out_path, "--force", "--manifest"]
      else
        ["packet", command.fetch("anchor"), "--out", out_path, "--force", "--manifest"]
      end
    task = command["task"]
    args.concat(["--task", task]) if task
    args
  end

  def run_cli(args, cwd:)
    stdout = StringIO.new
    stderr = StringIO.new
    status = Ctxpack::CLI.new(stdout: stdout, stderr: stderr, cwd: cwd).run(args)

    Result.new(status: status, stdout: stdout.string, stderr: stderr.string)
  end
end
