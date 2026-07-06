# frozen_string_literal: true

# Tier 2 harness — executes the frozen pre-registration in PREREGISTRATION.md.
#
# Subcommands:
#   ruby eval/tier2/harness.rb setup            # idempotent grid setup
#   ruby eval/tier2/harness.rb run [N]          # run up to N pending sessions (default: all)
#   ruby eval/tier2/harness.rb status           # tuple completion state
#
# Contract (decision log 2026-07-05): re-runnable, scripted arms, serial
# pre-registered order, resumable via runs.jsonl (skip status:"complete"
# tuples), one JSONL run record per session. All thresholds, prompts, and
# metric definitions are frozen in PREREGISTRATION.md — this file only
# mechanizes them.

require "json"
require "digest"
require "fileutils"
require "open3"
require "time"

module Tier2
  TIER2_DIR   = __dir__
  ROOT        = File.expand_path("../..", __dir__)
  WORK        = File.join(ROOT, "tmp/tier2")
  TEMPLATE    = File.join(WORK, "template")
  WS_DIR      = File.join(WORK, "workspaces")
  SCORE_LOGS  = File.join(WORK, "scoring-logs")
  CONFIG_DIR  = File.join(WORK, "claude-config")
  RUNS_PATH   = File.join(TIER2_DIR, "runs.jsonl")
  PACKETS_DIR = File.join(TIER2_DIR, "packets")
  PACKETS_META = File.join(PACKETS_DIR, "packets.json")

  APP_SHA   = "3386d9595767b3d0c455ace9281e056e9f61bd56"
  MODEL     = "claude-sonnet-5"
  TIMEOUT_S = 30 * 60

  ANCHORS = {1 => "twofa#deactivate_init", 2 => "my#show_api_key", 3 => "roles#create"}.freeze

  # Untracked files prepared once in the template and copied into every
  # fresh checkout (Redmine gitignores all three).
  PREPARED_FILES = ["config/database.yml", "Gemfile.lock", "db/redmine_test.sqlite3"].freeze

  WRAPPER = <<~PROMPT
    You are working in a Redmine checkout at the current working directory.

    Task anchor (controller#action): {anchor}

    {task_description}

    {context_block}

    Rules:
    - Make the smallest correct change consistent with this codebase's
      conventions.
    - Leave your final changes uncommitted in the working tree.
    - Work autonomously; do not ask questions.
  PROMPT

  CONTEXT_BLOCK = <<~BLOCK
    ## Context packet

    The following context packet was generated for this task's anchor by a
    static analysis tool. It may help you locate relevant code.

    {packet_markdown}
  BLOCK

  module_function

  def sh!(*cmd, chdir: nil, env: {})
    opts = chdir ? {chdir: chdir} : {}
    out, err, st = Open3.capture3(env, *cmd, **opts)
    raise "command failed (#{st.exitstatus}): #{cmd.join(' ')}\n#{out}#{err}" unless st.success?

    out
  end

  # --- setup ---------------------------------------------------------------

  def setup
    verify_template
    prepare_config_dir
    capture_task2_failing_output
    generate_packets
    puts "setup complete"
  end

  def verify_template
    head = sh!("git", "rev-parse", "HEAD", chdir: TEMPLATE).strip
    raise "template not at pinned SHA (#{head})" unless head == APP_SHA

    PREPARED_FILES.each do |f|
      path = File.join(TEMPLATE, f)
      raise "template missing prepared file #{f}" unless File.exist?(path)
    end
    seed = File.join(TIER2_DIR, "tasks/task2_seed.patch")
    sh!("git", "apply", "--check", seed, chdir: TEMPLATE)
    puts "template ok @ #{APP_SHA[0, 8]}"
  end

  def prepare_config_dir
    FileUtils.mkdir_p(CONFIG_DIR)
    settings = File.join(CONFIG_DIR, "settings.json")
    File.write(settings, "{}\n") unless File.exist?(settings)
    puts "config dir ok (settings sha256 #{settings_sha256[0, 12]}…)"
  end

  def settings_sha256
    Digest::SHA256.hexdigest(File.read(File.join(CONFIG_DIR, "settings.json")))
  end

  # Captured once, verbatim, used identically in both arms (PREREGISTRATION,
  # Tasks). Committed alongside the frozen task prompt.
  def capture_task2_failing_output
    out_path = File.join(TIER2_DIR, "tasks/task2_failing_output.txt")
    return puts "task2 failing output ok (cached)" if File.exist?(out_path)

    ws = make_workspace(File.join(WORK, "seedcheck"), seeded: true)
    out, _st = Open3.capture2e(
      {"RAILS_ENV" => "test"},
      "bin/rails", "test", "test/functional/my_controller_test.rb", "-n", "test_show_api_key",
      chdir: ws
    )
    raise "seeded test unexpectedly passed" unless out.match?(/1 failures|1 errors/)

    File.write(out_path, out)
    FileUtils.rm_rf(ws)
    puts "task2 failing output captured (#{out.bytesize} bytes)"
  end

  def generate_packets
    FileUtils.mkdir_p(PACKETS_DIR)
    return puts "packets ok (cached)" if File.exist?(PACKETS_META)

    dirty = sh!("git", "status", "--porcelain", "lib", "exe", chdir: ROOT)
    raise "ctxpack lib/exe dirty; commit before generating packets" unless dirty.empty?

    ctxpack_sha = sh!("git", "rev-parse", "HEAD", chdir: ROOT).strip
    meta = {"ctxpack_sha" => ctxpack_sha, "packets" => {}}
    ANCHORS.each do |task, anchor|
      out = File.join(PACKETS_DIR, "task#{task}.md")
      # Task 2's packet must be generated from the seeded (buggy) tree — the
      # realistic input for a bug-fix task, and generating from the pristine
      # tree would inline the pre-bug line, leaking the fix to the treatment
      # arm. Tasks 1/3 generate from the pinned template directly.
      src = task == 2 ? make_workspace(File.join(WORK, "packetgen"), seeded: true) : TEMPLATE
      sh!(RbConfig.ruby, "-I", File.join(ROOT, "lib"), File.join(ROOT, "exe/ctxpack"),
          "packet", anchor, "--out", out, "--force", chdir: src)
      FileUtils.rm_rf(src) unless src == TEMPLATE
      meta["packets"][task.to_s] = {
        "anchor" => anchor,
        "path" => "packets/task#{task}.md",
        "sha256" => Digest::SHA256.hexdigest(File.read(out))
      }
    end
    File.write(PACKETS_META, JSON.pretty_generate(meta) + "\n")
    puts "packets generated @ ctxpack #{ctxpack_sha[0, 8]}"
  end

  # --- workspaces ----------------------------------------------------------

  def make_workspace(dest, seeded:)
    FileUtils.rm_rf(dest)
    FileUtils.mkdir_p(File.dirname(dest))
    sh!("git", "clone", "-q", "--local", TEMPLATE, dest)
    PREPARED_FILES.each do |f|
      FileUtils.mkdir_p(File.dirname(File.join(dest, f)))
      FileUtils.cp(File.join(TEMPLATE, f), File.join(dest, f))
    end
    if seeded
      sh!("git", "apply", "--index", File.join(TIER2_DIR, "tasks/task2_seed.patch"), chdir: dest)
      sh!("git", "-c", "user.email=tier2@ctxpack", "-c", "user.name=tier2",
          "commit", "-qm", "tier2 task2 seed", chdir: dest)
    end
    dest
  end

  # --- schedule ------------------------------------------------------------

  def schedule
    tuples = []
    %w[control treatment].each do |arm|
      tuples << {task: 2, arm: arm, run_index: 1, pilot: true}
    end
    (1..3).each do |round|
      arms = round.odd? ? %w[control treatment] : %w[treatment control]
      [1, 2, 3].each do |task|
        arms.each { |arm| tuples << {task: task, arm: arm, run_index: round, pilot: false} }
      end
    end
    tuples
  end

  def completed_keys
    return [] unless File.exist?(RUNS_PATH)

    File.readlines(RUNS_PATH).filter_map do |line|
      r = JSON.parse(line)
      [r["task"], r["arm"], r["run_index"], r["pilot"]] if r["status"] == "complete"
    end
  end

  def pending
    done = completed_keys
    schedule.reject { |t| done.include?([t[:task], t[:arm], t[:run_index], t[:pilot]]) }
  end

  def run_id(t)
    "t2-#{t[:task]}-#{t[:arm]}-#{t[:run_index]}#{t[:pilot] ? '-pilot' : ''}"
  end

  # --- prompt --------------------------------------------------------------

  def build_prompt(task, arm)
    desc = File.read(File.join(TIER2_DIR, "tasks/task#{task}_prompt.md"))
    if task == 2
      failing = File.read(File.join(TIER2_DIR, "tasks/task2_failing_output.txt"))
      desc = desc.sub("{failing_test_output}") { failing.strip.gsub("\n", "\n    ") }
      desc = desc.sub(/^<!--.*?-->\n?/m, "") # harness note, not agent-facing
    end
    block =
      if arm == "treatment"
        packet = File.read(File.join(PACKETS_DIR, "task#{task}.md"))
        CONTEXT_BLOCK.sub("{packet_markdown}") { packet }
      else
        ""
      end
    WRAPPER
      .sub("{anchor}") { ANCHORS.fetch(task) }
      .sub("{task_description}") { desc.strip }
      .sub("{context_block}") { block.strip }
      .gsub(/\n{3,}/, "\n\n")
  end

  # --- session execution ---------------------------------------------------

  def run(max_sessions = nil)
    queue = pending
    queue = queue.first(max_sessions) if max_sessions
    abort "nothing pending" if queue.empty?

    packets_meta = JSON.parse(File.read(PACKETS_META))
    cli_version = `claude --version`.strip

    queue.each do |t|
      id = run_id(t)
      puts "=== #{id} (#{Time.now.strftime('%H:%M:%S')}) ==="
      record = run_session(t, id, packets_meta, cli_version)
      File.open(RUNS_PATH, "a") { |f| f.puts(JSON.generate(record)) }
      puts "    -> #{record['status']}" \
           "#{record['metrics'] ? " success=#{record['metrics']['task_success']}" : ''}"
      if record["status"] == "aborted"
        puts "aborted (likely usage window) — stopping; re-run harness to resume"
        break
      end
    end
  end

  def run_session(t, id, packets_meta, cli_version)
    ws = make_workspace(File.join(WS_DIR, id), seeded: t[:task] == 2)
    transcript = File.join(TIER2_DIR, "transcripts", "#{id}.jsonl")
    diff_path = File.join(TIER2_DIR, "diffs", "#{id}.patch")
    FileUtils.mkdir_p(File.dirname(transcript))
    FileUtils.mkdir_p(File.dirname(diff_path))

    prompt = build_prompt(t[:task], t[:arm])
    started = Time.now
    status = invoke_claude(prompt, ws, transcript)
    ended = Time.now

    # Final diff: stage everything (captures new untracked files) and take
    # the staged diff. The workspace is discarded afterwards.
    sh!("git", "add", "-A", chdir: ws)
    diff = sh!("git", "diff", "--cached", "--binary", chdir: ws)
    File.write(diff_path, diff)
    diff_files = sh!("git", "diff", "--cached", "--name-only", chdir: ws).split("\n")

    record = {
      "run_id" => id,
      "pilot" => t[:pilot],
      "task" => t[:task],
      "arm" => t[:arm],
      "run_index" => t[:run_index],
      "status" => status,
      "started_at" => started.utc.iso8601,
      "ended_at" => ended.utc.iso8601,
      "app_sha" => APP_SHA,
      "ctxpack_sha" => packets_meta.fetch("ctxpack_sha"),
      "packet_sha256" => t[:arm] == "treatment" ? packets_meta.dig("packets", t[:task].to_s, "sha256") : nil,
      "agent" => {"cli_version" => cli_version, "model" => MODEL, "settings_sha256" => settings_sha256},
      "usage" => nil,
      "metrics" => nil,
      "transcript_path" => "transcripts/#{id}.jsonl",
      "workspace_diff_path" => "diffs/#{id}.patch",
      "notes" => ""
    }

    if status != "aborted"
      usage, metrics = analyze_transcript(transcript, ws, diff_files)
      metrics["wall_time_s"] = (ended - started).round
      metrics["task_success"] = status == "timeout" ? false : score(t[:task], id, diff_path, diff_files)
      record["usage"] = usage
      record["metrics"] = metrics
    end
    FileUtils.rm_rf(ws)
    record
  end

  # Returns "complete" | "aborted" | "timeout" per the frozen rules: a clean
  # exit with a success result event is complete; exceeding TIMEOUT_S is
  # timeout (metrics kept, task_success false); anything else — usage-limit
  # kill, crash, network — is aborted (metrics discarded, tuple re-run).
  def invoke_claude(prompt, workspace, transcript_path)
    env = {"CLAUDE_CONFIG_DIR" => CONFIG_DIR}
    cmd = ["claude", "-p", "--model", MODEL, "--output-format", "stream-json",
           "--verbose", "--dangerously-skip-permissions"]
    timed_out = false
    stderr_dir = File.join(WORK, "stderr")
    FileUtils.mkdir_p(stderr_dir)
    stderr_path = File.join(stderr_dir, "#{File.basename(transcript_path, '.jsonl')}.log")
    File.open(transcript_path, "w") do |out|
      r, w = IO.pipe
      pid = Process.spawn(env, *cmd, chdir: workspace, in: r, out: out, err: [stderr_path, "w"])
      r.close
      w.write(prompt)
      w.close
      deadline = Time.now + TIMEOUT_S
      st = nil
      loop do
        _, st = Process.waitpid2(pid, Process::WNOHANG)
        break if st
        if Time.now > deadline
          timed_out = true
          Process.kill("TERM", pid)
          sleep 5
          begin
            Process.kill("KILL", pid)
          rescue Errno::ESRCH
            nil # already exited
          end
          Process.waitpid2(pid)
          break
        end
        sleep 2
      end
      return "timeout" if timed_out
      return "aborted" unless st.exitstatus == 0
    end
    result = last_result_event(transcript_path)
    result && result["subtype"] == "success" && !result["is_error"] ? "complete" : "aborted"
  end

  def last_result_event(transcript_path)
    File.readlines(transcript_path).reverse_each do |line|
      obj = JSON.parse(line) rescue next
      return obj if obj["type"] == "result"
    end
    nil
  end

  # --- metrics (definitions frozen in PREREGISTRATION.md, Metrics) ---------

  def analyze_transcript(transcript_path, workspace, diff_files)
    tool_uses = []
    result = nil
    File.foreach(transcript_path) do |line|
      obj = JSON.parse(line) rescue next
      case obj["type"]
      when "assistant"
        Array(obj.dig("message", "content")).each do |item|
          tool_uses << item if item.is_a?(Hash) && item["type"] == "tool_use"
        end
      when "result"
        result = obj
      end
    end

    rel = ->(path) { path.to_s.delete_prefix("#{workspace}/") }
    reads = []
    edits = []
    first_load_bearing = nil
    tool_uses.each_with_index do |tu, i|
      case tu["name"]
      when "Read"
        file = rel.call(tu.dig("input", "file_path"))
        reads << file
        first_load_bearing ||= i + 1 if diff_files.include?(file)
      when "Edit", "Write"
        edits << rel.call(tu.dig("input", "file_path"))
      end
    end

    u = result&.fetch("usage", nil) || {}
    usage = {
      "input_tokens" => u["input_tokens"].to_i,
      "output_tokens" => u["output_tokens"].to_i,
      "cache_read_tokens" => u["cache_read_input_tokens"].to_i,
      "cache_creation_tokens" => u["cache_creation_input_tokens"].to_i
    }
    metrics = {
      "task_success" => nil,
      "calls_to_first_load_bearing_read" => first_load_bearing,
      "distraction_reads" => (reads.uniq - edits.uniq - diff_files).size,
      "discarded_edits" => (edits.uniq - diff_files).size,
      "total_tool_calls" => tool_uses.size,
      "total_tokens" => usage.values.sum,
      "wall_time_s" => nil
    }
    [usage, metrics]
  end

  # --- scoring -------------------------------------------------------------

  ACCEPTANCE = {
    1 => "test/functional/tier2_task1_acceptance_test.rb",
    3 => "test/functional/tier2_task3_acceptance_test.rb"
  }.freeze

  def score(task, id, diff_path, diff_files)
    # Task 2 extra check (frozen): no file under test/ modified.
    return false if task == 2 && diff_files.any? { |f| f.start_with?("test/") }

    ws = make_workspace(File.join(WORK, "scoring"), seeded: task == 2)
    if File.size(diff_path) > 0
      apply = Open3.capture2e("git", "apply", "--whitespace=nowarn", diff_path, chdir: ws)
      unless apply[1].success?
        log_scoring(id, "git apply failed:\n#{apply[0]}")
        return false
      end
    end

    test_target =
      if task == 2
        "test/functional/my_controller_test.rb"
      else
        src = File.join(TIER2_DIR, "tasks/task#{task}_acceptance_test.rb")
        FileUtils.cp(src, File.join(ws, ACCEPTANCE.fetch(task)))
        ACCEPTANCE.fetch(task)
      end

    out, st = Open3.capture2e({"RAILS_ENV" => "test"}, "bin/rails", "test", test_target, chdir: ws)
    log_scoring(id, out)
    FileUtils.rm_rf(ws)
    st.success?
  end

  def log_scoring(id, text)
    FileUtils.mkdir_p(SCORE_LOGS)
    File.write(File.join(SCORE_LOGS, "#{id}.log"), text)
  end

  # --- status --------------------------------------------------------------

  def status
    done = completed_keys
    schedule.each do |t|
      mark = done.include?([t[:task], t[:arm], t[:run_index], t[:pilot]]) ? "done   " : "pending"
      puts "#{mark} #{run_id(t)}"
    end
    puts "#{done.size}/#{schedule.size} complete"
  end
end

if __FILE__ == $PROGRAM_NAME
  case ARGV[0]
  when "setup"  then Tier2.setup
  when "run"    then Tier2.run(ARGV[1]&.to_i)
  when "status" then Tier2.status
  else abort "usage: harness.rb setup|run [N]|status"
  end
end
