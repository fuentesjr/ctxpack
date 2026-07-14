#!/usr/bin/env ruby
# frozen_string_literal: true

# Test-seed viability spike. Pre-registration:
# eval/seed-spikes/test/PREREGISTRATION.md — do not change scoring here
# without amending that file first.

require "json"
require "pathname"
require "fileutils"

APPS = {
  "mastodon" => "tmp/tier0-rescan/mastodon",
  "discourse" => "tmp/tier0-rescan/discourse",
  "zammad" => "tmp/tier0-rescan/zammad"
}.freeze

EXCLUDE_PARTS = %w[plugins engines vendor node_modules .git].freeze

def excluded?(rel)
  parts = rel.split("/")
  EXCLUDE_PARTS.any? { |p| parts.include?(p) }
end

def population(app_root)
  root = Pathname(app_root)
  patterns = [
    "spec/controllers/**/*_spec.rb",
    "test/controllers/**/*_test.rb",
    "spec/requests/**/*_spec.rb",
    "test/integration/**/*_test.rb"
  ]
  paths = patterns.flat_map { |g| Dir.glob(root.join(g).to_s) }
  paths
    .map { |abs| Pathname(abs).relative_path_from(root).to_s }
    .reject { |rel| excluded?(rel) }
    .sort
end

def existing_app_file(app_root, rel)
  return nil if rel.nil? || rel.empty?
  abs = File.join(app_root, rel)
  return rel.tr("\\", "/") if File.file?(abs) && rel.start_with?("app/")

  nil
end

def heuristic_controller_path(rel)
  case rel
  when %r{\Aspec/controllers/(.+)_controller_spec\.rb\z}
    "app/controllers/#{$1}_controller.rb"
  when %r{\Atest/controllers/(.+)_controller_test\.rb\z}
    "app/controllers/#{$1}_controller.rb"
  end
end

def heuristic_request_token(app_root, rel)
  return nil unless rel.match?(%r{\A(?:spec/requests|test/integration)/})

  base = File.basename(rel).sub(/_(spec|test)\.rb\z/, "")
  # Try progressive path tokens from basename (e.g. settings_preferences_appearance)
  tokens = base.split("_")
  candidates = []
  tokens.size.times do |i|
    slice = tokens[i..].join("_")
    next if slice.empty?

    Dir.glob(File.join(app_root, "app/controllers/**/#{slice}_controller.rb")).each do |abs|
      candidates << Pathname(abs).relative_path_from(Pathname(app_root)).to_s
    end
  end
  # Also try full base as nested path with slashes from known request subdirs
  if rel =~ %r{\Aspec/requests/(.+)_spec\.rb\z}
    nested = $1
    candidates << "app/controllers/#{nested}_controller.rb"
    candidates << "app/controllers/#{File.dirname(nested)}/#{File.basename(nested)}_controller.rb" if nested.include?("/")
  end
  candidates.map { |c| existing_app_file(app_root, c) }.compact.first
end

def heuristic_constant(app_root, rel)
  path = File.join(app_root, rel)
  return nil unless File.file?(path)

  source = File.read(path, encoding: "UTF-8")
  const = source[/RSpec\.describe\s+([A-Z][A-Za-z0-9_:]*)/, 1]
  const ||= source[/class\s+([A-Z][A-Za-z0-9_:]*)\s*</, 1]
  return nil if const.nil?
  return nil if const.end_with?("Test", "Spec", "ControllerPolicy")

  # Zeitwerk-ish: Foo::BarBaz → app/**/foo/bar_baz.rb (search)
  parts = const.split("::")
  snake = parts.map { |p| p.gsub(/([a-z])([A-Z])/, '\1_\2').downcase }.join("/")
  candidates = [
    "app/models/#{snake}.rb",
    "app/services/#{snake}.rb",
    "app/controllers/#{snake}_controller.rb",
    "app/controllers/#{snake}.rb",
    "app/lib/#{snake}.rb",
    "app/#{snake}.rb"
  ]
  hit = candidates.map { |c| existing_app_file(app_root, c) }.compact.first
  return hit if hit

  # glob last segment
  last = snake.split("/").last
  Dir.glob(File.join(app_root, "app/**/#{last}.rb")).each do |abs|
    rel_path = Pathname(abs).relative_path_from(Pathname(app_root)).to_s
    return rel_path if rel_path.start_with?("app/")
  end
  nil
end

def classify(app_root, rel)
  if (path = existing_app_file(app_root, heuristic_controller_path(rel)))
    return { "label" => "resolved_controller_path", "surface" => path }
  end
  if (path = heuristic_request_token(app_root, rel))
    return { "label" => "resolved_request_token", "surface" => path }
  end
  if (path = heuristic_constant(app_root, rel))
    return { "label" => "resolved_constant", "surface" => path }
  end
  if rel.include?("policies/controllers")
    return { "label" => "policy_or_non_controller", "surface" => nil }
  end
  { "label" => "no_surface", "surface" => nil }
end

out_dir = ARGV[0] || "eval/seed-spikes/test/results"
FileUtils.mkdir_p(out_dir)

summary = {}
APPS.each do |name, root|
  unless File.directory?(root)
    warn "missing app root #{root}"
    next
  end
  pop = population(root)
  rows = pop.map do |rel|
    begin
      result = classify(root, rel)
      { "path" => rel }.merge(result)
    rescue StandardError => e
      { "path" => rel, "label" => "crash", "surface" => nil, "error" => e.message }
    end
  end
  success_labels = %w[resolved_controller_path resolved_request_token resolved_constant]
  success = rows.count { |r| success_labels.include?(r["label"]) }
  rate = pop.empty? ? nil : success.to_f / pop.size
  by_label = rows.group_by { |r| r["label"] }.transform_values(&:size)
  payload = {
    "app" => name,
    "population" => pop.size,
    "success" => success,
    "rate" => rate,
    "by_label" => by_label,
    "results" => rows
  }
  File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate(payload))
  summary[name] = { "population" => pop.size, "success" => success, "rate" => rate, "by_label" => by_label }
  puts "#{name}: n=#{pop.size} success=#{success} rate=#{rate.inspect} #{by_label.inspect}"
end

rates = summary.values.map { |s| s["rate"] }.compact
avg = rates.empty? ? nil : rates.sum / rates.size
File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate("apps" => summary, "average_rate" => avg, "gate" => 0.70, "pass" => avg && avg >= 0.70))
puts "average_rate=#{avg.inspect} gate_pass=#{avg && avg >= 0.70}"
