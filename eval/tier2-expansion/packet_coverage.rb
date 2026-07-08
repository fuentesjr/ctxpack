# frozen_string_literal: true

# Offline packet file-set coverage for the Tier 2 expansion grid.
#
# Metric definitions, per session:
# - packet_files: files[].path from eval/tier2-expansion/<app>/packets/task<N>.json.
# - diff_files: repo-relative paths from each patch's "diff --git a/<path> b/<path>"
#   headers, using the b/ path with the leading prefix stripped.
# - inter: packet_files & diff_files.
# - recall: |inter| / |diff_files|, or null when diff_files is empty.
# - precision: |inter| / |packet_files|, or null when packet_files is empty.
#
# Two variants are computed:
# - all-files: packet_files and diff_files as read.
# - production-only: remove paths under top-level test/ or spec/ from both sets.
#   This is the headline variant because self-authored tests are noise.
#
# Control vs treatment interpretation:
# The packet is per-task and identical across arms. Control agents never saw it,
# so packet-vs-control-diffs is the unbiased read of whether the packet's small
# file budget actually captures what the task needs. Packet-vs-treatment-diffs
# shows how much the packeted agent stayed within packet files: a steering read.

require "json"

ROOT = File.expand_path("../..", __dir__)
BASE_DIR = File.join(ROOT, "eval/tier2-expansion")
COVERAGE_DIR = File.join(BASE_DIR, "coverage")

APPS = %w[campfire lobsters publify].freeze
TASKS = %w[1 2 3 4].freeze
ARMS = %w[control treatment].freeze
TASK_KIND = {
  "1" => "feature",
  "2" => "feature",
  "3" => "bug",
  "4" => "behavior"
}.freeze
EXPECTED_DIFFS_PER_APP = 24
EXPECTED_ROUNDS_PER_CELL = 3

def read_json(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError => e
  abort "#{path}: invalid JSON: #{e.message}"
end

def packet_files(app, task)
  path = File.join(BASE_DIR, app, "packets", "task#{task}.json")
  abort "#{path}: missing packet JSON" unless File.file?(path)

  data = read_json(path)
  files = data.fetch("files") do
    abort "#{path}: missing top-level files array"
  end
  abort "#{path}: files must be an array" unless files.is_a?(Array)

  files.each_with_index.map do |entry, index|
    unless entry.is_a?(Hash) && entry["path"].is_a?(String) && !entry["path"].empty?
      abort "#{path}: files[#{index}] must contain a non-empty path string"
    end

    entry.fetch("path")
  end.uniq.sort
end

def b_path_from_diff_header(line)
  match = line.match(/\Adiff --git a\/(.+) b\/(.+)\z/)
  return match[2] if match

  nil
end

def diff_files(path)
  files = []

  File.foreach(path).with_index(1) do |line, line_number|
    line = line.chomp
    next unless line.start_with?("diff --git ")

    b_path = b_path_from_diff_header(line)
    abort "#{path}:#{line_number}: unparseable diff --git header: #{line}" unless b_path

    files << b_path
  end

  abort "#{path}: no diff --git headers found" if files.empty?

  files.uniq.sort
end

def production_files(files)
  files.reject { |path| path.start_with?("test/", "spec/") }
end

def metrics(packet_files, diff_files)
  inter = (packet_files & diff_files).sort
  {
    "inter" => inter,
    "recall" => diff_files.empty? ? nil : inter.size.to_f / diff_files.size,
    "precision" => packet_files.empty? ? nil : inter.size.to_f / packet_files.size
  }
end

def summarize_metric(values)
  present = values.compact
  {
    "mean" => present.empty? ? nil : present.sum.to_f / present.size,
    "n" => present.size,
    "nulls" => values.size - present.size
  }
end

def summarize_variant(records, variant)
  values = records.map { |record| record.fetch(variant) }
  {
    "recall" => summarize_metric(values.map { |metric| metric.fetch("recall") }),
    "precision" => summarize_metric(values.map { |metric| metric.fetch("precision") })
  }
end

def aggregate(records)
  {
    "sessions" => records.size,
    "all_files" => summarize_variant(records, "all_files"),
    "production_only" => summarize_variant(records, "production_only")
  }
end

def metric_mean(aggregate, variant, metric)
  aggregate.fetch(variant).fetch(metric).fetch("mean")
end

def fmt_number(value)
  value.nil? ? "null" : format("%.3f", value)
end

def fmt_pair(aggregate, variant)
  "R #{fmt_number(metric_mean(aggregate, variant, 'recall'))} / " \
    "P #{fmt_number(metric_mean(aggregate, variant, 'precision'))}"
end

def print_table(summary)
  puts "Tier 2 expansion - packet file-set coverage against subject diffs"
  puts "Processed #{summary.fetch('session_count')} sessions; production-only excludes top-level test/ and spec/."
  puts
  puts "Per app x task x arm (means over 3 rounds)"
  puts "%-9s %-4s %-9s %-10s %-23s %-23s" %
       ["app", "task", "kind", "arm", "prod-only R/P", "all-files R/P"]
  puts "-" * 84

  APPS.each do |app|
    TASKS.each do |task|
      ARMS.each do |arm|
        cell = summary.fetch("by_app_task_arm").fetch(app).fetch(task).fetch(arm)
        puts "%-9s %-4s %-9s %-10s %-23s %-23s" %
             [app, task, TASK_KIND.fetch(task), arm,
              fmt_pair(cell, "production_only"), fmt_pair(cell, "all_files")]
      end
    end
  end

  puts "-" * 84
  puts
  puts "Overall by arm"
  ARMS.each do |arm|
    cell = summary.fetch("overall_by_arm").fetch(arm)
    puts "%-10s %-23s %-23s n=%d" %
         [arm, fmt_pair(cell, "production_only"), fmt_pair(cell, "all_files"), cell.fetch("sessions")]
  end

  puts
  puts "By task kind (task 1,2=feature; task 3=bug; task 4=behavior)"
  puts "%-9s %-10s %-23s %-23s" %
       ["kind", "arm", "prod-only R/P", "all-files R/P"]
  puts "-" * 70
  %w[feature bug behavior].each do |kind|
    ARMS.each do |arm|
      cell = summary.fetch("by_task_kind").fetch(kind).fetch(arm)
      puts "%-9s %-10s %-23s %-23s" %
           [kind, arm, fmt_pair(cell, "production_only"), fmt_pair(cell, "all_files")]
    end
  end
end

packet_files_by_app_task = APPS.each_with_object({}) do |app, apps|
  apps[app] = TASKS.each_with_object({}) do |task, tasks|
    tasks[task] = packet_files(app, task)
  end
end

sessions = []

APPS.each do |app|
  app_dir = File.join(BASE_DIR, app)
  diff_paths = Dir.glob(File.join(app_dir, "diffs", "*.patch"))
                  .reject { |path| File.basename(path).end_with?("-pilot.patch") }
                  .sort

  unless diff_paths.size == EXPECTED_DIFFS_PER_APP
    abort "#{app}: expected #{EXPECTED_DIFFS_PER_APP} non-pilot diffs, found #{diff_paths.size}"
  end

  diff_paths.each do |path|
    basename = File.basename(path)
    match = basename.match(/\At2-([1-4])-(control|treatment)-([0-9]+)\.patch\z/)
    abort "#{path}: unparseable Tier 2 expansion patch filename" unless match

    task, arm, round = match.captures
    packet = packet_files_by_app_task.fetch(app).fetch(task)
    diff = diff_files(path)

    all_files = metrics(packet, diff)
    production_packet = production_files(packet)
    production_diff = production_files(diff)
    production_only = metrics(production_packet, production_diff)

    sessions << {
      "session" => File.basename(path, ".patch"),
      "app" => app,
      "task" => task.to_i,
      "kind" => TASK_KIND.fetch(task),
      "arm" => arm,
      "round" => round.to_i,
      "patch" => path.delete_prefix("#{BASE_DIR}/"),
      "packet_files" => packet,
      "diff_files" => diff,
      "inter" => all_files.fetch("inter"),
      "all_files" => {
        "recall" => all_files.fetch("recall"),
        "precision" => all_files.fetch("precision")
      },
      "production_only" => {
        "packet_files" => production_packet,
        "diff_files" => production_diff,
        "inter" => production_only.fetch("inter"),
        "recall" => production_only.fetch("recall"),
        "precision" => production_only.fetch("precision")
      }
    }
  end
end

expected_total = APPS.size * EXPECTED_DIFFS_PER_APP
abort "expected #{expected_total} sessions, found #{sessions.size}" unless sessions.size == expected_total

APPS.each do |app|
  TASKS.each do |task|
    ARMS.each do |arm|
      count = sessions.count do |session|
        session.fetch("app") == app &&
          session.fetch("task") == task.to_i &&
          session.fetch("arm") == arm
      end
      next if count == EXPECTED_ROUNDS_PER_CELL

      abort "#{app} task #{task} #{arm}: expected #{EXPECTED_ROUNDS_PER_CELL} rounds, found #{count}"
    end
  end
end

by_app_task_arm = APPS.each_with_object({}) do |app, apps|
  apps[app] = TASKS.each_with_object({}) do |task, tasks|
    tasks[task] = {
      "kind" => TASK_KIND.fetch(task),
      "control" => aggregate(sessions.select do |session|
        session.fetch("app") == app &&
          session.fetch("task") == task.to_i &&
          session.fetch("arm") == "control"
      end),
      "treatment" => aggregate(sessions.select do |session|
        session.fetch("app") == app &&
          session.fetch("task") == task.to_i &&
          session.fetch("arm") == "treatment"
      end)
    }
  end
end

overall_by_arm = ARMS.each_with_object({}) do |arm, arms|
  arms[arm] = aggregate(sessions.select { |session| session.fetch("arm") == arm })
end

by_task_kind = %w[feature bug behavior].each_with_object({}) do |kind, kinds|
  kinds[kind] = ARMS.each_with_object({}) do |arm, arms|
    arms[arm] = aggregate(sessions.select do |session|
      session.fetch("kind") == kind && session.fetch("arm") == arm
    end)
  end
end

summary = {
  "session_count" => sessions.size,
  "apps" => APPS,
  "task_kind" => TASK_KIND,
  "variants" => {
    "all_files" => "packet and diff file-sets as read",
    "production_only" => "top-level test/ and spec/ paths removed from both packet and diff file-sets"
  },
  "by_app_task_arm" => by_app_task_arm,
  "overall_by_arm" => overall_by_arm,
  "by_task_kind" => by_task_kind
}

abort "#{COVERAGE_DIR}: exists but is not a directory" if File.exist?(COVERAGE_DIR) && !Dir.exist?(COVERAGE_DIR)

Dir.mkdir(COVERAGE_DIR) unless Dir.exist?(COVERAGE_DIR)
File.write(File.join(COVERAGE_DIR, "coverage_by_session.json"), JSON.pretty_generate(sessions) + "\n")
File.write(File.join(COVERAGE_DIR, "coverage_summary.json"), JSON.pretty_generate(summary) + "\n")

print_table(summary)
puts
puts "wrote #{File.join(COVERAGE_DIR, 'coverage_summary.json')}"
puts "wrote #{File.join(COVERAGE_DIR, 'coverage_by_session.json')}"
