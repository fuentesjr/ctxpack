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

      assert_equal expected.fetch("entrypoint").fetch("file"), packet.entrypoint.file
      assert_equal expected.fetch("entrypoint").fetch("action"), packet.entrypoint.action

      expected.fetch("include").each do |file|
        packet_file = packet.file(file.fetch("path"))
        refute_nil packet_file, "expected #{file.fetch("path")} to be included"
        assert_includes packet_file.reason_codes, file.fetch("reason_code")
      end

      expected.fetch("exclude").each do |path|
        assert_nil packet.file(path), "expected #{path} to be absent"
      end

      expected.fetch("tests").each do |command|
        assert_includes packet.tests.map(&:command), command
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
    Ctxpack.compile(
      app_root: fixture_app(eval_case.app),
      anchor: eval_case.command.fetch("anchor"),
      task: eval_case.command.fetch("task")
    )
  end

  def assert_packet_within_limits(packet)
    limits = Ctxpack::Compiler::LIMITS

    assert_operator packet.files.length, :<=, limits.fetch(:max_total_files)
    assert_operator packet.files_with_reason("referenced_constant").length, :<=, limits.fetch(:max_constant_files)
    assert_operator packet.tests.length, :<=, limits.fetch(:max_test_files)

    packet.files.each do |entry|
      snippet_lines = entry.evidence_items.flat_map(&:snippet_ranges).sum do |range|
        range.last - range.first + 1
      end
      assert_operator snippet_lines, :<=, limits.fetch(:max_snippet_lines_per_file)
    end
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
    args = ["packet", eval_case.command.fetch("anchor"), "--out", out_path, "--manifest"]
    task = eval_case.command["task"]
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
