#!/usr/bin/env ruby
# frozen_string_literal: true

# Files-seed neighbor-rule spike. Pre-registration:
# eval/seed-spikes/files/PREREGISTRATION.md

require "json"
require "pathname"
require "fileutils"

APPS = {
  "mastodon" => "tmp/tier0-rescan/mastodon",
  "discourse" => "tmp/tier0-rescan/discourse",
  "zammad" => "tmp/tier0-rescan/zammad"
}.freeze

EXCLUDE_PARTS = %w[plugins engines vendor node_modules .git].freeze
SAMPLE_CAP = 80

def excluded?(rel)
  parts = rel.split("/")
  EXCLUDE_PARTS.any? { |p| parts.include?(p) }
end

def list_rel(app_root, glob)
  root = Pathname(app_root)
  Dir.glob(root.join(glob).to_s)
    .map { |abs| Pathname(abs).relative_path_from(root).to_s }
    .reject { |rel| excluded?(rel) }
    .sort
end

def sample(paths, cap = SAMPLE_CAP)
  return paths if paths.size <= cap
  k = (paths.size.to_f / cap).ceil
  paths.each_slice(k).map(&:first).first(cap)
end

def exists?(app_root, rel)
  File.file?(File.join(app_root, rel))
end

def dir_has_files?(app_root, rel_dir)
  Dir.glob(File.join(app_root, rel_dir, "*")).any? { |p| File.file?(p) }
end

def neighbors(app_root, primary)
  hits = []
  if primary =~ %r{\Aapp/controllers/(.+)_controller\.rb\z}
    path = $1
    [
      "test/controllers/#{path}_controller_test.rb",
      "spec/controllers/#{path}_controller_spec.rb"
    ].each do |cand|
      hits << ["has_controller_test", cand] if exists?(app_root, cand)
    end

    token = File.basename(path)
    %w[test/integration spec/requests].each do |dir|
      Dir.glob(File.join(app_root, dir, "**/*#{token}*")).each do |abs|
        next unless File.file?(abs)
        rel = Pathname(abs).relative_path_from(Pathname(app_root)).to_s
        hits << ["has_request_test", rel]
      end
    end

    view_dir = "app/views/#{path}"
    hits << ["has_views", view_dir] if dir_has_files?(app_root, view_dir)
  else
    base = File.basename(primary, ".rb")
    %w[test spec].each do |dir|
      next unless File.directory?(File.join(app_root, dir))
      Dir.glob(File.join(app_root, dir, "**/*#{base}*")).each do |abs|
        next unless File.file?(abs)
        rel = Pathname(abs).relative_path_from(Pathname(app_root)).to_s
        hits << ["has_basename_test", rel]
        break
      end
      break if hits.any?
    end
  end
  hits.uniq
end

out_dir = ARGV[0] || "eval/seed-spikes/files/results"
FileUtils.mkdir_p(out_dir)

summary = {}
APPS.each do |name, root|
  unless File.directory?(root)
    warn "missing #{root}"
    next
  end

  controllers = list_rel(root, "app/controllers/**/*_controller.rb")
  sampled = sample(controllers)
  if sampled.size < 40
    models = list_rel(root, "app/models/**/*.rb")
    services = list_rel(root, "app/services/**/*.rb")
    pad = sample(models + services, 40 - sampled.size)
    sampled = (sampled + pad).uniq
  end

  rows = sampled.map do |rel|
    hits = neighbors(root, rel)
    labels = hits.map(&:first).uniq
    {
      "path" => rel,
      "controller" => rel.include?("/controllers/") && rel.end_with?("_controller.rb"),
      "labels" => labels.empty? ? ["no_neighbor"] : labels,
      "neighbors" => hits.map { |l, p| { "label" => l, "path" => p } }
    }
  end

  controller_rows = rows.select { |r| r["controller"] }
  hit = controller_rows.count { |r| !r["labels"].include?("no_neighbor") }
  rate = controller_rows.empty? ? nil : hit.to_f / controller_rows.size
  payload = {
    "app" => name,
    "sampled_total" => rows.size,
    "controller_primaries" => controller_rows.size,
    "controller_neighbor_hits" => hit,
    "controller_neighbor_rate" => rate,
    "results" => rows
  }
  File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate(payload))
  summary[name] = {
    "controller_primaries" => controller_rows.size,
    "controller_neighbor_hits" => hit,
    "rate" => rate
  }
  puts "#{name}: controllers=#{controller_rows.size} hits=#{hit} rate=#{rate.inspect}"
end

rates = summary.values.map { |s| s["rate"] }.compact
avg = rates.empty? ? nil : rates.sum / rates.size
File.write(
  File.join(out_dir, "summary.json"),
  JSON.pretty_generate("apps" => summary, "average_controller_neighbor_rate" => avg, "gate" => 0.40, "pass" => avg && avg >= 0.40)
)
puts "average_controller_neighbor_rate=#{avg.inspect} gate_pass=#{avg && avg >= 0.40}"
