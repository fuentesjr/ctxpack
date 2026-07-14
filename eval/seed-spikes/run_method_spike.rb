#!/usr/bin/env ruby
# frozen_string_literal: true

# Method-seed viability spike. Pre-registration:
# eval/seed-spikes/method/PREREGISTRATION.md — do not change scoring here
# without amending that file first (frozen 2026-07-14).

require "json"
require "pathname"
require "fileutils"
require "prism"

APPS = {
  "mastodon" => "tmp/tier0-rescan/mastodon",
  "discourse" => "tmp/tier0-rescan/discourse",
  "zammad" => "tmp/tier0-rescan/zammad"
}.freeze

EXCLUDE_PARTS = %w[plugins engines vendor node_modules .git].freeze
EXCLUDED_APP_DIRS = %w[assets javascript views].freeze
SAMPLE_CAP = 50

def excluded?(rel)
  parts = rel.split("/")
  return true if parts.first(2) == %w[app controllers]
  return true if parts.first(2) == %w[app views]

  EXCLUDE_PARTS.any? { |p| parts.include?(p) }
end

# Same inflection as the shipped DefaultConstantResolver.
def underscore(constant_name)
  constant_name
    .gsub("::", "/")
    .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .tr("-", "_")
    .downcase
end

# → [parts, rooted]
def constant_parts(node)
  case node
  when Prism::ConstantReadNode
    [[node.name.to_s], false]
  when Prism::ConstantPathNode
    if node.parent.nil?
      [[node.name.to_s], true]
    else
      parent_parts, rooted = constant_parts(node.parent)
      [parent_parts + [node.name.to_s], rooted]
    end
  else
    [[], false]
  end
end

# Collect [fqn, method_name] for plain instance defs, tracking lexical nesting.
# Skips singleton-class scopes and def-self; descends into blocks (symmetric
# for extraction and verification).
def collect_defs(node, stack, out)
  return if node.nil?

  case node
  when Prism::ClassNode, Prism::ModuleNode
    parts, rooted = constant_parts(node.constant_path)
    new_stack = rooted ? parts : stack + parts
    collect_defs(node.body, new_stack, out)
  when Prism::SingletonClassNode
    nil
  when Prism::DefNode
    out << [stack.join("::"), node.name.to_s, node] if node.receiver.nil? && !stack.empty?
  else
    node.compact_child_nodes.each { |child| collect_defs(child, stack, out) }
  end
end

def parse_defs(path)
  @def_cache ||= {}
  @def_cache[path] ||= begin
    result = Prism.parse_file(path)
    out = []
    collect_defs(result.value, [], out)
    out
  end
end

def app_subdirectories(app_root)
  app_dir = File.join(app_root, "app")
  return [] unless Dir.exist?(app_dir)

  Dir.children(app_dir)
     .select { |entry| File.directory?(File.join(app_dir, entry)) }
     .reject { |entry| EXCLUDED_APP_DIRS.include?(entry) }
     .sort
end

# CONST-2b probe: lexicographic app/ subdirs, first existing file wins.
# No segment trimming: the evidence constant is exact.
def resolve_constant(app_root, fqn, subdirs)
  rel = underscore(fqn) + ".rb"
  subdirs.each do |sub|
    candidate = File.join(app_root, "app", sub, rel)
    return "app/#{sub}/#{rel}" if File.file?(candidate)
  end
  nil
end

def classify_pair(app_root, fqn, method_name, defining_file, subdirs)
  resolved = resolve_constant(app_root, fqn, subdirs)
  unless resolved
    label = defining_file.match?(%r{\Aapp/[^/]+/concerns/}) ? "no_file_concern" : "no_file"
    return { "label" => label, "surface" => nil }
  end

  defs = parse_defs(File.join(app_root, resolved))
  if defs.any? { |d_fqn, d_name, _| d_fqn == fqn && d_name == method_name }
    { "label" => "resolved_direct", "surface" => resolved }
  elsif defs.any? { |_, d_name, _| d_name == method_name }
    { "label" => "nesting_mismatch", "surface" => resolved }
  else
    { "label" => "file_no_def", "surface" => resolved }
  end
end

# Report-only fan-out: same-constant same-file callee BFS + constant refs.
def fan_out(app_root, resolved_rel, fqn, method_name)
  defs = parse_defs(File.join(app_root, resolved_rel))
  scope = defs.select { |d_fqn, _, _| d_fqn == fqn }
  by_name = {}
  scope.each { |_, d_name, node| by_name[d_name] ||= node }
  target = by_name[method_name]
  return nil unless target

  visited = [method_name]
  queue = [target]
  constants = []
  until queue.empty?
    node = queue.shift
    calls_and_constants(node.body, calls = [], constants)
    calls.each do |name|
      next if visited.include?(name) || !by_name.key?(name)

      visited << name
      queue << by_name[name]
    end
  end
  { "callees" => visited.size - 1, "constants" => constants.uniq.size }
end

def calls_and_constants(node, calls, constants)
  return if node.nil?

  case node
  when Prism::CallNode
    calls << node.name.to_s if node.receiver.nil? || node.receiver.is_a?(Prism::SelfNode)
    node.compact_child_nodes.each { |c| calls_and_constants(c, calls, constants) }
  when Prism::ConstantReadNode
    constants << node.name.to_s
  when Prism::ConstantPathNode
    constants << node.full_name rescue constants << node.name.to_s
  else
    node.compact_child_nodes.each { |c| calls_and_constants(c, calls, constants) }
  end
end

def percentile(sorted, pct)
  return nil if sorted.empty?

  sorted[[(sorted.size * pct).ceil - 1, 0].max]
end

def test_leg(app_root, resolved_fqns)
  test_files = Dir.glob(File.join(app_root, "{test,spec}/**/*_{test,spec}.rb"))
                  .map { |abs| Pathname(abs).relative_path_from(Pathname(app_root)).to_s }
                  .reject { |rel| excluded?(rel) }
                  .sort
  basenames = test_files.map { |rel| [rel, File.basename(rel, ".rb")] }
  source_cache = {}
  matched = 0
  lenient_true = 0
  strict_true = 0
  samples = []

  resolved_fqns.sort.each do |fqn|
    demod = fqn.split("::").last
    token = underscore(demod)
    hits = basenames.select { |_, base| base.include?(token) }
    hits.each do |rel, _|
      matched += 1
      source = source_cache[rel] ||= File.read(File.join(app_root, rel), encoding: "UTF-8")
      lenient = source.match?(/\b#{Regexp.escape(demod)}\b/) || source.include?(fqn)
      strict = source.include?(fqn)
      lenient_true += 1 if lenient
      strict_true += 1 if lenient && strict
      samples << { "constant" => fqn, "test" => rel, "lenient" => lenient } if !lenient && samples.size < SAMPLE_CAP
    end
  end

  {
    "matched" => matched,
    "lenient_true" => lenient_true,
    "strict_true" => strict_true,
    "precision" => matched.zero? ? nil : lenient_true.to_f / matched,
    "strict_share_of_true" => lenient_true.zero? ? nil : strict_true.to_f / lenient_true,
    "false_samples" => samples
  }
end

out_dir = ARGV[0] || "eval/seed-spikes/method/results"
FileUtils.mkdir_p(out_dir)

summary = {}
APPS.each do |name, root|
  abort "missing app root #{root}" unless File.directory?(root)

  @def_cache = {}
  subdirs = app_subdirectories(root)
  pairs = {}
  Dir.glob(File.join(root, "app/**/*.rb")).sort.each do |abs|
    rel = Pathname(abs).relative_path_from(Pathname(root)).to_s
    next if excluded?(rel)

    begin
      parse_defs(abs).each do |fqn, method_name, _|
        pairs[[fqn, method_name]] ||= rel
      end
    rescue StandardError
      next # unparseable population file: not a pair source
    end
  end

  labels = Hash.new(0)
  label_samples = Hash.new { |h, k| h[k] = [] }
  resolved_fqns = {}
  fan_callees = []
  fan_constants = []

  pairs.each do |(fqn, method_name), defining_file|
    result = begin
      classify_pair(root, fqn, method_name, defining_file, subdirs)
    rescue StandardError => e
      { "label" => "crash", "surface" => nil, "error" => e.message }
    end
    label = result["label"]
    labels[label] += 1
    label_samples[label] << { "constant" => fqn, "method" => method_name, "file" => defining_file } if label_samples[label].size < SAMPLE_CAP
    next unless label == "resolved_direct"

    resolved_fqns[fqn] = true
    if (fo = fan_out(root, result["surface"], fqn, method_name))
      fan_callees << fo["callees"]
      fan_constants << fo["constants"]
    end
  end

  population = pairs.size
  success = labels["resolved_direct"]
  rate = population.zero? ? nil : success.to_f / population
  tl = test_leg(root, resolved_fqns.keys)
  fan_callees.sort!
  fan_constants.sort!

  payload = {
    "app" => name,
    "population" => population,
    "success" => success,
    "rate" => rate,
    "by_label" => labels,
    "test_leg" => tl,
    "fan_out" => {
      "callees" => { "median" => percentile(fan_callees, 0.5), "p90" => percentile(fan_callees, 0.9), "max" => fan_callees.last },
      "constants" => { "median" => percentile(fan_constants, 0.5), "p90" => percentile(fan_constants, 0.9), "max" => fan_constants.last }
    },
    "label_samples" => label_samples
  }
  File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate(payload))
  summary[name] = payload.reject { |k, _| k == "label_samples" }
  puts "#{name}: n=#{population} resolved=#{success} rate=#{rate&.round(4)} test_leg_precision=#{tl['precision']&.round(4)} #{labels.inspect}"
end

rates = summary.values.map { |s| s["rate"] }.compact
avg_rate = rates.empty? ? nil : rates.sum / rates.size
precisions = summary.values.map { |s| s.dig("test_leg", "precision") }.compact
avg_precision = precisions.empty? ? nil : precisions.sum / precisions.size
test_leg_pass = !precisions.empty? && avg_precision >= 0.70

File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(
  "apps" => summary,
  "average_rate" => avg_rate,
  "resolution_gate" => 0.70,
  "resolution_pass" => avg_rate && avg_rate >= 0.70,
  "average_test_leg_precision" => avg_precision,
  "test_leg_gate" => 0.70,
  "test_leg_pass" => test_leg_pass
))
puts "average_rate=#{avg_rate&.round(4)} resolution_pass=#{avg_rate && avg_rate >= 0.70} " \
     "avg_test_leg_precision=#{avg_precision&.round(4)} test_leg_pass=#{test_leg_pass}"
