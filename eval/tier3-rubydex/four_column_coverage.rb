# frozen_string_literal: true

# Offline four-column packet file-set coverage for the Tier 3 Rubydex probe.
#
# Metric definitions match eval/tier2-expansion/packet_coverage.rb:
# - recall = |packet_files & diff_files| / |diff_files|
# - precision = |packet_files & diff_files| / |packet_files|
# - production-only removes top-level test/ and spec/ paths from both sets.

require "json"
require "fileutils"
require "rubydex"

ROOT = File.expand_path("../..", __dir__)
TIER2_DIR = File.join(ROOT, "eval/tier2-expansion")
TIER3_DIR = File.join(ROOT, "eval/tier3-rubydex")
COVERAGE_DIR = File.join(TIER3_DIR, "coverage")
BASELINE_PATH = File.join(TIER2_DIR, "coverage", "coverage_by_session.json")
TEMPLATE_ROOT = File.join(ROOT, "tmp/tier2-expansion")

APPS = %w[campfire lobsters publify].freeze
TASKS = %w[1 2 3 4].freeze
ARMS = %w[control treatment].freeze
VARIANTS = %w[convention view rubydex both].freeze
TASK_KIND = {
  "1" => "feature",
  "2" => "feature",
  "3" => "bug",
  "4" => "behavior"
}.freeze
EXPECTED_DIFFS_PER_APP = 24
EXPECTED_ROUNDS_PER_CELL = 3
FLOAT_EPSILON = 1e-12

def read_json(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError => e
  abort "#{path}: invalid JSON: #{e.message}"
end

def read_file_budget
  path = File.join(ROOT, "lib/ctxpack/compiler.rb")
  source = File.read(path)
  match = source.match(/^\s+max_total_files:\s+([0-9]+),\s*$/)
  abort "#{path}: could not read Ctxpack::Compiler::LIMITS[:max_total_files]" unless match

  Integer(match[1])
end

FILE_BUDGET = read_file_budget

def packet_data(app, task)
  path = File.join(TIER2_DIR, app, "packets", "task#{task}.json")
  abort "#{path}: missing packet JSON" unless File.file?(path)

  data = read_json(path)
  anchor = data.fetch("anchor") do
    abort "#{path}: missing top-level anchor"
  end
  abort "#{path}: anchor must be a non-empty string" unless anchor.is_a?(String) && !anchor.empty?

  entrypoint = data.fetch("entrypoint") do
    abort "#{path}: missing top-level entrypoint"
  end
  unless entrypoint.is_a?(Hash) &&
         entrypoint["file"].is_a?(String) &&
         entrypoint["controller"].is_a?(String) &&
         entrypoint["action"].is_a?(String)
    abort "#{path}: entrypoint must contain file, controller, and action strings"
  end

  files = data.fetch("files") do
    abort "#{path}: missing top-level files array"
  end
  abort "#{path}: files must be an array" unless files.is_a?(Array)

  packet_files = files.each_with_index.map do |entry, index|
    unless entry.is_a?(Hash) && entry["path"].is_a?(String) && !entry["path"].empty?
      abort "#{path}: files[#{index}] must contain a non-empty path string"
    end

    entry.fetch("path")
  end.uniq.sort

  controller_path, action = anchor.split("#", 2)
  unless controller_path && action && !controller_path.empty? && !action.empty?
    abort "#{path}: anchor must be controller#action"
  end

  {
    "anchor" => anchor,
    "controller_path" => controller_path,
    "action" => action,
    "entrypoint" => entrypoint,
    "files" => packet_files
  }
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
    "packet_files" => packet_files,
    "diff_files" => diff_files,
    "inter" => inter,
    "recall" => diff_files.empty? ? nil : inter.size.to_f / diff_files.size,
    "precision" => packet_files.empty? ? nil : inter.size.to_f / packet_files.size
  }
end

def variant_metrics(packet_files, diff_files)
  production_packet = production_files(packet_files)
  production_diff = production_files(diff_files)

  {
    "all_files" => metrics(packet_files, diff_files),
    "production_only" => metrics(production_packet, production_diff)
  }
end

def rel(loc, root)
  return nil unless loc.uri.to_s.start_with?("file://")

  loc.to_file_path.sub(root + "/", "")
end

def rubydex_reached_files_by_controller(app_template_abs, controller_rels)
  controller_set = controller_rels.uniq
  reached = controller_set.to_h { |controller_rel| [controller_rel, []] }

  # Rubydex's constant resolution depends on the process working directory, not
  # just workspace_path: run from ctxpack root with only workspace_path set and
  # sibling-model refs (User, Current, ...) stay UNRESOLVED — only superclasses
  # resolve. chdir into the app root so resolution matches an in-tree run.
  Dir.chdir(app_template_abs) do
    g = Rubydex::Graph.new
    g.workspace_path = app_template_abs
    g.index_workspace
    g.resolve

    g.constant_references.each do |r|
      next unless r.is_a?(Rubydex::ResolvedConstantReference)

      loc_rel = rel(r.location, app_template_abs)
      next unless controller_set.include?(loc_rel)

      r.declaration.definitions.each do |d|
        f = rel(d.location, app_template_abs)
        reached.fetch(loc_rel) << f if f
      end
    end
  end

  reached.transform_values(&:uniq)
end

def under_template_file?(app_template_abs, rel_path)
  absolute = File.expand_path(File.join(app_template_abs, rel_path))
  absolute.start_with?(app_template_abs + File::SEPARATOR) && File.file?(absolute)
end

def rubydex_candidate_files(app_template_abs, controller_rel, reached_files)
  reached_files.select do |path|
    path.start_with?("app/", "lib/") &&
      path != controller_rel &&
      !path.start_with?("test/", "spec/") &&
      under_template_file?(app_template_abs, path)
  end.uniq.sort
end

def view_candidate_files(app_template_abs, controller_path, action)
  view_dir_rel = File.join("app/views", controller_path).tr(File::SEPARATOR, "/")
  view_dir_abs = File.join(app_template_abs, view_dir_rel)
  return [] unless Dir.exist?(view_dir_abs)

  Dir.children(view_dir_abs)
     .select { |name| name.start_with?("#{action}.") }
     .map { |name| File.join(view_dir_rel, name).tr(File::SEPARATOR, "/") }
     .select { |path| under_template_file?(app_template_abs, path) }
     .uniq
     .sort
end

def capped_variant(convention_files, added_files, label)
  if convention_files.size > FILE_BUDGET
    abort "#{label}: convention has #{convention_files.size} files, exceeds budget #{FILE_BUDGET}"
  end

  selected = convention_files.dup
  capped = []

  (added_files - convention_files).uniq.sort.each do |path|
    if selected.size < FILE_BUDGET
      selected << path
    else
      capped << path
    end
  end

  selected = selected.uniq.sort
  {
    "packet_files" => selected,
    "added_files" => (selected - convention_files).sort,
    "capped" => capped.sort
  }
end

def session_key(record)
  [
    record.fetch("app"),
    record.fetch("task").to_i,
    record.fetch("arm"),
    record.fetch("round").to_i,
    record.fetch("patch")
  ].join("|")
end

def floats_equal?(left, right)
  return true if left.nil? && right.nil?
  return false if left.nil? || right.nil?

  (left - right).abs <= FLOAT_EPSILON
end

def assert_array_equal(label, left, right)
  return if left == right

  abort "#{label}: expected #{right.inspect}, got #{left.inspect}"
end

def assert_float_equal(label, left, right)
  return if floats_equal?(left, right)

  abort "#{label}: expected #{right.inspect}, got #{left.inspect}"
end

def self_check_convention!(sessions)
  baseline = read_json(BASELINE_PATH)
  abort "#{BASELINE_PATH}: expected array" unless baseline.is_a?(Array)
  abort "#{BASELINE_PATH}: expected #{sessions.size} sessions, found #{baseline.size}" unless baseline.size == sessions.size

  baseline_by_key = baseline.to_h { |record| [session_key(record), record] }
  abort "#{BASELINE_PATH}: duplicate session keys" unless baseline_by_key.size == baseline.size

  sessions.each do |session|
    key = session_key(session)
    expected = baseline_by_key.fetch(key) do
      abort "#{BASELINE_PATH}: missing baseline session #{key}"
    end
    actual = session.fetch("variants").fetch("convention")

    assert_array_equal("#{key} convention all_files packet_files",
                       actual.fetch("all_files").fetch("packet_files"),
                       expected.fetch("packet_files"))
    assert_array_equal("#{key} convention all_files diff_files",
                       actual.fetch("all_files").fetch("diff_files"),
                       expected.fetch("diff_files"))
    assert_array_equal("#{key} convention all_files inter",
                       actual.fetch("all_files").fetch("inter"),
                       expected.fetch("inter"))
    assert_float_equal("#{key} convention all_files recall",
                       actual.fetch("all_files").fetch("recall"),
                       expected.fetch("all_files").fetch("recall"))
    assert_float_equal("#{key} convention all_files precision",
                       actual.fetch("all_files").fetch("precision"),
                       expected.fetch("all_files").fetch("precision"))

    expected_production = expected.fetch("production_only")
    actual_production = actual.fetch("production_only")
    assert_array_equal("#{key} convention production_only packet_files",
                       actual_production.fetch("packet_files"),
                       expected_production.fetch("packet_files"))
    assert_array_equal("#{key} convention production_only diff_files",
                       actual_production.fetch("diff_files"),
                       expected_production.fetch("diff_files"))
    assert_array_equal("#{key} convention production_only inter",
                       actual_production.fetch("inter"),
                       expected_production.fetch("inter"))
    assert_float_equal("#{key} convention production_only recall",
                       actual_production.fetch("recall"),
                       expected_production.fetch("recall"))
    assert_float_equal("#{key} convention production_only precision",
                       actual_production.fetch("precision"),
                       expected_production.fetch("precision"))
  end
end

def summarize_metric(values)
  present = values.compact
  {
    "mean" => present.empty? ? nil : present.sum.to_f / present.size,
    "n" => present.size,
    "nulls" => values.size - present.size
  }
end

def summarize_variant(records, column, metric_variant)
  values = records.map { |record| record.fetch("variants").fetch(column).fetch(metric_variant) }
  {
    "recall" => summarize_metric(values.map { |metric| metric.fetch("recall") }),
    "precision" => summarize_metric(values.map { |metric| metric.fetch("precision") })
  }
end

def aggregate(records)
  variant_summaries = VARIANTS.each_with_object({}) do |column, variants|
    variants[column] = {
      "all_files" => summarize_variant(records, column, "all_files"),
      "production_only" => summarize_variant(records, column, "production_only")
    }
  end

  {
    "sessions" => records.size,
    "variants" => variant_summaries
  }
end

def metric_mean(aggregate, column, metric_variant, metric)
  aggregate.fetch("variants").fetch(column).fetch(metric_variant).fetch(metric).fetch("mean")
end

def fmt_number(value)
  value.nil? ? "null" : format("%.3f", value)
end

def fmt_pair(aggregate, column, metric_variant)
  "R #{fmt_number(metric_mean(aggregate, column, metric_variant, 'recall'))} / " \
    "P #{fmt_number(metric_mean(aggregate, column, metric_variant, 'precision'))}"
end

def print_four_column_row(label_values, aggregate, metric_variant)
  puts "%-9s %-4s %-9s %-23s %-23s %-23s %-23s" %
       [*label_values,
        fmt_pair(aggregate, "convention", metric_variant),
        fmt_pair(aggregate, "view", metric_variant),
        fmt_pair(aggregate, "rubydex", metric_variant),
        fmt_pair(aggregate, "both", metric_variant)]
end

def print_table(summary)
  puts "Tier 3 Rubydex/view - four-column packet file-set coverage against subject diffs"
  puts "Processed #{summary.fetch('session_count')} sessions; production-only excludes top-level test/ and spec/."
  puts "File budget: #{summary.fetch('file_budget')}."
  puts
  puts "Per app x task (control arm means over 3 rounds, production-only)"
  puts "%-9s %-4s %-9s %-23s %-23s %-23s %-23s" %
       ["app", "task", "kind", "conv R/P", "+view R/P", "+rubydex R/P", "+both R/P"]
  puts "-" * 142

  APPS.each do |app|
    TASKS.each do |task|
      cell = summary.fetch("by_app_task_arm").fetch(app).fetch(task).fetch("control")
      print_four_column_row([app, task, TASK_KIND.fetch(task)], cell, "production_only")
    end
  end

  puts "-" * 142
  puts
  puts "Overall by arm (production-only)"
  puts "%-9s %-4s %-9s %-23s %-23s %-23s %-23s" %
       ["arm", "n", "", "conv R/P", "+view R/P", "+rubydex R/P", "+both R/P"]
  puts "-" * 142
  ARMS.each do |arm|
    cell = summary.fetch("overall_by_arm").fetch(arm)
    print_four_column_row([arm, cell.fetch("sessions"), ""], cell, "production_only")
  end

  puts
  puts "By task kind (task 1,2=feature; task 3=bug; task 4=behavior; production-only)"
  puts "%-9s %-4s %-9s %-23s %-23s %-23s %-23s" %
       ["kind", "arm", "", "conv R/P", "+view R/P", "+rubydex R/P", "+both R/P"]
  puts "-" * 142
  %w[feature bug behavior].each do |kind|
    ARMS.each do |arm|
      cell = summary.fetch("by_task_kind").fetch(kind).fetch(arm)
      print_four_column_row([kind, arm, ""], cell, "production_only")
    end
  end
end

packet_data_by_app_task = APPS.each_with_object({}) do |app, apps|
  apps[app] = TASKS.each_with_object({}) do |task, tasks|
    tasks[task] = packet_data(app, task)
  end
end

rubydex_by_app_controller = APPS.each_with_object({}) do |app, apps|
  app_template_abs = File.expand_path(File.join(TEMPLATE_ROOT, app, "template"))
  abort "#{app_template_abs}: missing app template checkout" unless Dir.exist?(app_template_abs)

  controller_rels = TASKS.map do |task|
    packet_data_by_app_task.fetch(app).fetch(task).fetch("entrypoint").fetch("file")
  end
  reached_by_controller = rubydex_reached_files_by_controller(app_template_abs, controller_rels)

  apps[app] = reached_by_controller.transform_values do |reached_files|
    # The per-controller filter depends on the controller path; apply it per task below.
    reached_files.uniq
  end
end

variant_files_by_app_task = APPS.each_with_object({}) do |app, apps|
  app_template_abs = File.expand_path(File.join(TEMPLATE_ROOT, app, "template"))

  apps[app] = TASKS.each_with_object({}) do |task, tasks|
    data = packet_data_by_app_task.fetch(app).fetch(task)
    convention = data.fetch("files")
    controller_rel = data.fetch("entrypoint").fetch("file")

    view_additions = view_candidate_files(
      app_template_abs,
      data.fetch("controller_path"),
      data.fetch("action")
    )
    rubydex_additions = rubydex_candidate_files(
      app_template_abs,
      controller_rel,
      rubydex_by_app_controller.fetch(app).fetch(controller_rel, [])
    )

    tasks[task] = {
      "convention" => capped_variant(convention, [], "#{app} task #{task} convention"),
      "view" => capped_variant(convention, view_additions, "#{app} task #{task} view"),
      "rubydex" => capped_variant(convention, rubydex_additions, "#{app} task #{task} rubydex"),
      "both" => capped_variant(convention, view_additions + rubydex_additions, "#{app} task #{task} both")
    }
  end
end

sessions = []

APPS.each do |app|
  app_dir = File.join(TIER2_DIR, app)
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
    diff = diff_files(path)

    variants = VARIANTS.each_with_object({}) do |variant, result|
      variant_data = variant_files_by_app_task.fetch(app).fetch(task).fetch(variant)
      packet_files = variant_data.fetch("packet_files")
      result[variant] = variant_metrics(packet_files, diff).merge(
        "added_files" => variant_data.fetch("added_files"),
        "capped" => variant_data.fetch("capped")
      )
    end

    sessions << {
      "session" => File.basename(path, ".patch"),
      "app" => app,
      "task" => task.to_i,
      "kind" => TASK_KIND.fetch(task),
      "arm" => arm,
      "round" => round.to_i,
      "patch" => path.delete_prefix("#{TIER2_DIR}/"),
      "variants" => variants
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

self_check_convention!(sessions)

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
  "file_budget" => FILE_BUDGET,
  "columns" => {
    "convention" => "packet files[].path, uniq+sort",
    "view" => "convention plus existing app/views/<controller_path>/<action>.* files",
    "rubydex" => "convention plus Rubydex-resolved app/lib Ruby files referenced from the controller",
    "both" => "convention plus view and Rubydex additions"
  },
  "metric_variants" => {
    "all_files" => "packet and diff file-sets as read",
    "production_only" => "top-level test/ and spec/ paths removed from both packet and diff file-sets"
  },
  "by_app_task_arm" => by_app_task_arm,
  "overall_by_arm" => overall_by_arm,
  "by_task_kind" => by_task_kind
}

abort "#{COVERAGE_DIR}: exists but is not a directory" if File.exist?(COVERAGE_DIR) && !Dir.exist?(COVERAGE_DIR)

FileUtils.mkdir_p(COVERAGE_DIR)
File.write(File.join(COVERAGE_DIR, "four_column_by_session.json"), JSON.pretty_generate(sessions) + "\n")
File.write(File.join(COVERAGE_DIR, "four_column_summary.json"), JSON.pretty_generate(summary) + "\n")

print_table(summary)
puts
puts "wrote #{File.join(COVERAGE_DIR, 'four_column_summary.json')}"
puts "wrote #{File.join(COVERAGE_DIR, 'four_column_by_session.json')}"
