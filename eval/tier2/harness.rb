# frozen_string_literal: true

# Tier 2 harness — executes the frozen pre-registration in PREREGISTRATION.md.
#
# Subcommands:
#   ruby eval/tier2/harness.rb [app] setup       # idempotent grid setup
#   ruby eval/tier2/harness.rb [app] run [N]     # run up to N pending sessions
#   ruby eval/tier2/harness.rb [app] status      # tuple completion state
#   ruby eval/tier2/harness.rb [app] verify      # offline golden proof
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
require "rbconfig"
require "time"

require_relative "apps/config"

module Tier2
  MODEL     = "claude-sonnet-5"
  TIMEOUT_S = 30 * 60
  # Scoring must terminate: a subject diff can leave the app in a state where
  # the acceptance test never finishes (e.g. an unimplemented feature that
  # falls through to a code path that loops). A scoring run past this bound is
  # killed and counts as a failed task (task_success=false) — the correct
  # outcome — rather than wedging the serial grid. Generous vs. a normal
  # cold-boot scoring (~1-2 min).
  SCORE_TIMEOUT_S = 6 * 60

  WRAPPER = <<~PROMPT
    You are working in a {app_label} checkout at the current working directory.

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

  class VerificationError < StandardError; end

  module_function

  def sh!(*cmd, chdir: nil, env: {})
    opts = chdir ? {chdir: chdir} : {}
    out, err, st = Open3.capture3(env, *cmd, **opts)
    raise "command failed (#{st.exitstatus}): #{cmd.join(' ')}\n#{out}#{err}" unless st.success?

    out
  end

  # --- setup ---------------------------------------------------------------

  def setup(config)
    verify_template(config)
    prepare_config_dir(config)
    capture_failing_outputs(config)
    generate_packets(config)
    puts "setup complete"
  end

  def verify_template(config)
    head = sh!("git", "rev-parse", "HEAD", chdir: config.template_dir).strip
    raise "template not at pinned SHA (#{head})" unless head == config.repo_sha

    config.prepared_files.each do |f|
      path = File.join(config.template_dir, f)
      raise "template missing prepared file #{f}" unless File.exist?(path)
    end
    config.tasks.each do |task|
      next unless task.seeded && task.seed_patch

      sh!("git", "apply", "--check", task_file(config, task.seed_patch), chdir: config.template_dir)
    end
    puts "template ok @ #{config.repo_sha[0, 8]}"
  end

  def prepare_config_dir(config)
    FileUtils.mkdir_p(config.config_dir)
    settings = File.join(config.config_dir, "settings.json")
    File.write(settings, "{}\n") unless File.exist?(settings)
    puts "config dir ok (settings sha256 #{settings_sha256(config)[0, 12]}...)"
  end

  def settings_sha256(config)
    Digest::SHA256.hexdigest(File.read(File.join(config.config_dir, "settings.json")))
  end

  # Captured once, verbatim, used identically in both arms (PREREGISTRATION,
  # Tasks). Committed alongside the frozen task prompt.
  def capture_failing_outputs(config)
    config.tasks.each do |task|
      next unless task.failing_capture

      capture_failing_output(config, task)
    end
  end

  def capture_failing_output(config, task)
    capture = task.failing_capture
    out_path = artifact_file(config, capture.fetch(:output_file))
    return puts "task#{task.id} failing output ok (cached)" if File.exist?(out_path)

    ws = make_workspace(config, File.join(config.work_dir, "seedcheck"), task: task, seeded: task.seeded)
    command = config.test_command.call(capture.fetch(:test_target)) +
              config.test_name_filter.call(capture.fetch(:filter_name))
    out, _st = Open3.capture2e(config.test_env, *command, chdir: ws)
    raise "seeded test unexpectedly passed" unless out.match?(capture.fetch(:expect_pattern))

    FileUtils.mkdir_p(File.dirname(out_path))
    File.write(out_path, out)
    FileUtils.rm_rf(ws)
    puts "task#{task.id} failing output captured (#{out.bytesize} bytes)"
  end

  def generate_packets(config)
    FileUtils.mkdir_p(config.packets_dir)
    return puts "packets ok (cached)" if File.exist?(config.packets_meta)
    return puts "packets skipped (0 tasks)" if config.tasks.empty?

    dirty = sh!("git", "status", "--porcelain", "lib", "exe", chdir: ROOT)
    raise "ctxpack lib/exe dirty; commit before generating packets" unless dirty.empty?

    ctxpack_sha = sh!("git", "rev-parse", "HEAD", chdir: ROOT).strip
    meta = {"ctxpack_sha" => ctxpack_sha, "packets" => {}}
    config.tasks.each do |task|
      out = packet_file(config, task)
      src =
        if task.packet_from_seeded
          make_workspace(config, File.join(config.work_dir, "packetgen"), task: task, seeded: task.seeded)
        else
          config.template_dir
        end
      sh!(RbConfig.ruby, "-I", File.join(ROOT, "lib"), File.join(ROOT, "exe/ctxpack"),
          "packet", task.anchor, "--out", out, "--manifest", "--force", chdir: src)
      FileUtils.rm_rf(src) unless src == config.template_dir
      manifest = read_packet_manifest(out)
      tests = Array(manifest["tests"])
      meta["packets"][task.id.to_s] = {
        "anchor" => task.anchor,
        "path" => "packets/task#{task.id}.md",
        "sha256" => Digest::SHA256.hexdigest(File.read(out)),
        "had_test_candidate" => tests.any? { |t| t["reason_code"].to_s.match?(/candidate/) },
        "suggested_test_commands" => tests.filter_map { |t| t["command"] }
      }
    end
    File.write(config.packets_meta, JSON.pretty_generate(meta) + "\n")
    puts "packets generated @ ctxpack #{ctxpack_sha[0, 8]}"
  end

  def read_packet_manifest(markdown_path)
    json_path = markdown_path.sub(/\.[^\/.]+\z/, ".json")
    return {} unless File.exist?(json_path)

    JSON.parse(File.read(json_path))
  end

  # --- workspaces ----------------------------------------------------------

  def make_workspace(config, dest, task: nil, seeded:)
    FileUtils.rm_rf(dest)
    FileUtils.mkdir_p(File.dirname(dest))
    sh!("git", "clone", "-q", "--local", config.template_dir, dest)
    config.prepared_files.each do |f|
      FileUtils.mkdir_p(File.dirname(File.join(dest, f)))
      FileUtils.cp(File.join(config.template_dir, f), File.join(dest, f))
    end
    config.remove_files.each { |f| FileUtils.rm_f(File.join(dest, f)) }
    commit_workspace_baseline(config, dest)
    if seeded
      raise "seeded workspace requires a task with seed_patch" unless task&.seed_patch

      sh!("git", "apply", "--index", task_file(config, task.seed_patch), chdir: dest)
      sh!("git", "-c", "user.email=tier2@ctxpack", "-c", "user.name=tier2",
          "commit", "-qm", "tier2 task#{task.id} seed", chdir: dest)
    end
    dest
  end

  # Bake tracked prepared-file patches (e.g. a Gemfile.lock platform line) and
  # remove_files deletions into a baseline commit BEFORE the subject runs, so
  # they never appear in the subject's captured diff (git add -A) and cannot
  # break scoring's `git apply`. gitignored prepared files (database.yml, test
  # DBs) are not staged by `git add -A`, so this is a no-op for apps whose tree
  # stays clean after prep (Redmine, Campfire: verified porcelain-clean).
  def commit_workspace_baseline(config, dest)
    return if sh!("git", "status", "--porcelain", chdir: dest).empty?

    sh!("git", "add", "-A", chdir: dest)
    sh!("git", "-c", "user.email=tier2@ctxpack", "-c", "user.name=tier2",
        "commit", "-qm", "tier2 workspace baseline (prepared files, neutralized agent config)", chdir: dest)
  end

  # --- schedule ------------------------------------------------------------

  def schedule(config)
    tuples = []
    if config.pilot_task
      config.task(config.pilot_task)
      %w[control treatment].each do |arm|
        tuples << {task: config.pilot_task, arm: arm, run_index: 1, pilot: true}
      end
    end
    (1..config.rounds).each do |round|
      arms = round.odd? ? %w[control treatment] : %w[treatment control]
      config.tasks.each do |task|
        arms.each { |arm| tuples << {task: task.id, arm: arm, run_index: round, pilot: false} }
      end
    end
    tuples
  end

  def completed_keys(config)
    return [] unless File.exist?(config.runs_path)

    File.readlines(config.runs_path).filter_map do |line|
      r = JSON.parse(line)
      [r["task"], r["arm"], r["run_index"], r["pilot"]] if r["status"] == "complete"
    end
  end

  def pending(config)
    done = completed_keys(config)
    schedule(config).reject { |t| done.include?([t[:task], t[:arm], t[:run_index], t[:pilot]]) }
  end

  def run_id(t)
    "t2-#{t[:task]}-#{t[:arm]}-#{t[:run_index]}#{t[:pilot] ? '-pilot' : ''}"
  end

  # --- prompt --------------------------------------------------------------

  def build_prompt(config, task_id, arm)
    task = config.task(task_id)
    desc = File.read(task_file(config, task.prompt_file))
    if task.failing_capture
      capture = task.failing_capture
      failing = File.read(artifact_file(config, capture.fetch(:output_file)))
      desc = desc.sub(capture.fetch(:token)) { failing.strip.gsub("\n", "\n    ") }
      desc = desc.sub(/^<!--.*?-->\n?/m, "") # harness note, not agent-facing
    end
    block =
      if arm == "treatment"
        packet = File.read(packet_file(config, task))
        CONTEXT_BLOCK.sub("{packet_markdown}") { packet }
      else
        ""
      end
    WRAPPER
      .sub("{app_label}") { app_label(config) }
      .sub("{anchor}") { task.anchor }
      .sub("{task_description}") { desc.strip }
      .sub("{context_block}") { block.strip }
      .gsub(/\n{3,}/, "\n\n")
  end

  def app_label(config)
    config.name.split(/[_-]/).map(&:capitalize).join(" ")
  end

  # --- session execution ---------------------------------------------------

  def run(config, max_sessions = nil)
    queue = pending(config)
    queue = queue.first(max_sessions) if max_sessions
    abort "nothing pending" if queue.empty?

    packets_meta = JSON.parse(File.read(config.packets_meta))
    cli_version = `claude --version`.strip

    queue.each do |t|
      id = run_id(t)
      puts "=== #{id} (#{Time.now.strftime('%H:%M:%S')}) ==="
      record = run_session(config, t, id, packets_meta, cli_version)
      File.open(config.runs_path, "a") { |f| f.puts(JSON.generate(record)) }
      puts "    -> #{record['status']}" \
           "#{record['metrics'] ? " success=#{record['metrics']['task_success']}" : ''}"
      if record["status"] == "aborted"
        puts "aborted (likely usage window) — stopping; re-run harness to resume"
        break
      end
    end
  end

  def run_session(config, t, id, packets_meta, cli_version)
    task = config.task(t[:task])
    ws = make_workspace(config, File.join(config.workspaces_dir, id), task: task, seeded: task.seeded)
    transcript = File.join(config.artifact_dir, "transcripts", "#{id}.jsonl")
    diff_path = File.join(config.artifact_dir, "diffs", "#{id}.patch")
    FileUtils.mkdir_p(File.dirname(transcript))
    FileUtils.mkdir_p(File.dirname(diff_path))

    prompt = build_prompt(config, t[:task], t[:arm])
    started = Time.now
    status = invoke_claude(config, prompt, ws, transcript)
    ended = Time.now

    # Final diff: stage everything (captures new untracked files) and take
    # the staged diff. The workspace is discarded afterwards.
    sh!("git", "add", "-A", chdir: ws)
    diff = sh!("git", "diff", "--cached", "--binary", chdir: ws)
    File.write(diff_path, diff)
    diff_files = sh!("git", "diff", "--cached", "--name-only", chdir: ws).split("\n")

    record = {
      "run_id" => id,
      "app" => config.name,
      "pilot" => t[:pilot],
      "task" => t[:task],
      "arm" => t[:arm],
      "run_index" => t[:run_index],
      "status" => status,
      "started_at" => started.utc.iso8601,
      "ended_at" => ended.utc.iso8601,
      "app_sha" => config.repo_sha,
      "ctxpack_sha" => packets_meta.fetch("ctxpack_sha"),
      "packet_sha256" => t[:arm] == "treatment" ? packets_meta.dig("packets", t[:task].to_s, "sha256") : nil,
      "agent" => {"cli_version" => cli_version, "model" => MODEL, "settings_sha256" => settings_sha256(config)},
      "usage" => nil,
      "metrics" => nil,
      "transcript_path" => "transcripts/#{id}.jsonl",
      "workspace_diff_path" => "diffs/#{id}.patch",
      "notes" => ""
    }

    if status != "aborted"
      usage, metrics = analyze_transcript(config, transcript, ws, diff_files, t, packets_meta)
      metrics["wall_time_s"] = (ended - started).round
      metrics["task_success"] = status == "timeout" ? false : score(config, t[:task], id, diff_path, diff_files)
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
  def invoke_claude(config, prompt, workspace, transcript_path)
    env = {"CLAUDE_CONFIG_DIR" => config.config_dir}
    cmd = ["claude", "-p", "--model", MODEL, "--output-format", "stream-json",
           "--verbose", "--dangerously-skip-permissions"]
    timed_out = false
    FileUtils.mkdir_p(config.stderr_dir)
    stderr_path = File.join(config.stderr_dir, "#{File.basename(transcript_path, '.jsonl')}.log")
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

  def analyze_transcript(config, transcript_path, workspace, diff_files, t, packets_meta)
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
    test_runner_calls = []
    first_load_bearing_read = nil
    first_load_bearing_edit = nil
    tool_uses.each_with_index do |tu, i|
      case tu["name"]
      when "Read"
        file = rel.call(tu.dig("input", "file_path"))
        reads << file
        first_load_bearing_read ||= i + 1 if diff_files.include?(file)
      when "Edit", "Write"
        file = rel.call(tu.dig("input", "file_path"))
        edits << file
        first_load_bearing_edit ||= i + 1 if diff_files.include?(file)
      when "Bash"
        command = tu.dig("input", "command").to_s
        test_runner_calls << i + 1 if command.match?(config.test_runner_signature)
      end
    end

    packet_meta = packets_meta.fetch("packets", {}).fetch(t[:task].to_s, {})
    treatment = t[:arm] == "treatment"
    ran_test_before_edit =
      if treatment
        first_load_bearing_edit &&
          test_runner_calls.any? { |call_index| call_index < first_load_bearing_edit }
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
      "calls_to_first_load_bearing_read" => first_load_bearing_read,
      "distraction_reads" => (reads.uniq - edits.uniq - diff_files).size,
      "discarded_edits" => (edits.uniq - diff_files).size,
      "total_tool_calls" => tool_uses.size,
      "total_tokens" => usage.values.sum,
      "wall_time_s" => nil,
      "packet_had_test_candidate" => treatment ? !!packet_meta.fetch("had_test_candidate", false) : nil,
      "ran_suggested_test_before_first_edit" => treatment ? !!ran_test_before_edit : nil
    }
    [usage, metrics]
  end

  # --- scoring -------------------------------------------------------------

  def score(config, task_id, id, diff_path, diff_files)
    task = config.task(task_id)
    scoring = task.scoring
    forbidden = Array(scoring[:forbid_edits_under])
    return false if forbidden.any? { |prefix| diff_files.any? { |f| f.start_with?(prefix) } }

    ws = make_workspace(config, File.join(config.work_dir, "scoring"), task: task, seeded: task.seeded)
    begin
      if File.size(diff_path) > 0
        apply = Open3.capture2e("git", "apply", "--whitespace=nowarn", diff_path, chdir: ws)
        unless apply[1].success?
          log_scoring(config, id, "git apply failed:\n#{apply[0]}")
          return false
        end
      end

      if scoring[:acceptance_test]
        src = task_file(config, scoring[:acceptance_test].fetch(:source))
        dest = File.join(ws, scoring[:acceptance_test].fetch(:dest))
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src, dest)
      end

      out, success = run_test_with_timeout(config, config.test_command.call(scoring.fetch(:test_target)), ws)
      log_scoring(config, id, out)
      success
    ensure
      FileUtils.rm_rf(ws)
    end
  end

  # Run the acceptance test command, bounded by SCORE_TIMEOUT_S. Returns
  # [combined_output, success_bool]; a timeout kills the whole process group
  # (bundle -> rspec/rails children) and returns false. Output is drained on a
  # thread so a chatty runner can't deadlock on a full pipe.
  def run_test_with_timeout(config, cmd, ws)
    r, w = IO.pipe
    pid = Process.spawn(config.test_env, *cmd, chdir: ws, out: w, err: [:child, :out], pgroup: true)
    w.close
    reader = Thread.new { r.read }
    deadline = Time.now + SCORE_TIMEOUT_S
    st = nil
    loop do
      _, st = Process.waitpid2(pid, Process::WNOHANG)
      break if st
      if Time.now > deadline
        Process.kill("KILL", -pid)
        Process.waitpid2(pid)
        return ["#{reader.value}\n[tier2: scoring timed out after #{SCORE_TIMEOUT_S}s — treated as failure]", false]
      end
      sleep 1
    end
    [reader.value, st.success?]
  rescue Errno::ESRCH, Errno::ECHILD
    [reader&.value.to_s, false]
  end

  def log_scoring(config, id, text)
    FileUtils.mkdir_p(config.score_logs_dir)
    File.write(File.join(config.score_logs_dir, "#{id}.log"), text)
  end

  # --- status --------------------------------------------------------------

  def status(config)
    done = completed_keys(config)
    schedule(config).each do |t|
      mark = done.include?([t[:task], t[:arm], t[:run_index], t[:pilot]]) ? "done   " : "pending"
      puts "#{mark} #{run_id(t)}"
    end
    puts "#{done.size}/#{schedule(config).size} complete"
  end

  # --- verify --------------------------------------------------------------

  def verify(config)
    if config.tasks.empty?
      puts "#{config.name}: not yet authored (0 tasks)"
      return
    end

    verify_schedule(config)
    config.tasks.each do |task|
      %w[control treatment].each do |arm|
        verify_prompt(config, task, arm)
      end
    end
    verify_packet_shas(config) if File.exist?(config.packets_meta)
    puts "OK"
  rescue VerificationError => e
    warn e.message
    exit 1
  end

  def verify_schedule(config)
    path = File.join(config.golden_dir, "schedule.json")
    raise VerificationError, "#{config.name}: missing golden schedule #{path}" unless File.exist?(path)

    expected = JSON.parse(File.read(path))
    actual = schedule(config).map do |t|
      {"run_id" => run_id(t), "task" => t[:task], "arm" => t[:arm],
       "run_index" => t[:run_index], "pilot" => t[:pilot]}
    end
    verify_equal!("schedule", expected, actual)
  end

  def verify_prompt(config, task, arm)
    path = File.join(config.golden_dir, "prompt-#{task.id}-#{arm}.txt")
    raise VerificationError, "#{config.name}: missing golden prompt #{path}" unless File.exist?(path)

    first = build_prompt(config, task.id, arm)
    second = build_prompt(config, task.id, arm)
    verify_equal!("prompt-#{task.id}-#{arm} determinism", first, second)
    verify_equal!("prompt-#{task.id}-#{arm}", File.binread(path), first)
  end

  def verify_packet_shas(config)
    meta = JSON.parse(File.read(config.packets_meta))
    meta.fetch("packets", {}).each do |task_id, packet|
      path = File.join(config.artifact_dir, packet.fetch("path"))
      raise VerificationError, "packet #{task_id} missing at #{path}" unless File.exist?(path)

      actual = Digest::SHA256.hexdigest(File.binread(path))
      expected = packet.fetch("sha256")
      next if actual == expected

      raise VerificationError, "packet #{task_id} sha256 mismatch\nexpected: #{expected}\nactual:   #{actual}"
    end
  end

  def verify_equal!(label, expected, actual)
    return if expected == actual

    raise VerificationError, mismatch_message(label, expected, actual)
  end

  def mismatch_message(label, expected, actual)
    if expected.is_a?(String) && actual.is_a?(String)
      idx = first_mismatch_index(expected, actual)
      return "#{label} mismatch at byte #{idx}\n" \
             "expected sha256: #{Digest::SHA256.hexdigest(expected)} (#{expected.bytesize} bytes)\n" \
             "actual sha256:   #{Digest::SHA256.hexdigest(actual)} (#{actual.bytesize} bytes)"
    end

    "#{label} mismatch\nexpected:\n#{JSON.pretty_generate(expected)}\nactual:\n#{JSON.pretty_generate(actual)}"
  end

  def first_mismatch_index(expected, actual)
    limit = [expected.bytesize, actual.bytesize].min
    idx = 0
    idx += 1 while idx < limit && expected.getbyte(idx) == actual.getbyte(idx)
    idx
  end

  # --- paths ---------------------------------------------------------------

  def artifact_file(config, relative_path)
    File.join(config.artifact_dir, relative_path)
  end

  def task_file(config, basename)
    File.join(config.tasks_dir, basename)
  end

  def packet_file(config, task)
    File.join(config.packets_dir, "task#{task.id}.md")
  end

  # --- CLI -----------------------------------------------------------------

  def parse_cli(argv)
    args = argv.dup
    app_name =
      if args[0] && Apps.known?(args[0])
        args.shift
      else
        "redmine"
      end
    [Apps.load(app_name), args]
  end
end

if __FILE__ == $PROGRAM_NAME
  config, args = Tier2.parse_cli(ARGV)
  case args[0]
  when "setup"  then Tier2.setup(config)
  when "run"    then Tier2.run(config, args[1]&.to_i)
  when "status" then Tier2.status(config)
  when "verify" then Tier2.verify(config)
  else abort "usage: harness.rb [app] setup|run [N]|status|verify"
  end
end
