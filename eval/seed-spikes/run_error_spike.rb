#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "fileutils"

APPS = {
  "mastodon" => "tmp/tier0-rescan/mastodon",
  "discourse" => "tmp/tier0-rescan/discourse",
  "zammad" => "tmp/tier0-rescan/zammad"
}.freeze

DECOYS = [
  "/Users/x/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/actionpack-7.1.0/lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'",
  "/Users/x/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/railties-7.1.0/lib/rails/engine.rb:500:in `call'",
  "/Users/x/.local/share/mise/installs/ruby/3.3.0/lib/ruby/3.3.0/bundler/runtime.rb:44:in `block in require'",
  "/usr/lib/ruby/3.3.0/timeout.rb:45:in `timeout'"
].freeze

def sample_app_files(root, cap = 40)
  files = Dir.glob(File.join(root, "app/**/*.rb")).sort.reject { |p| p.include?("/plugins/") }
  return [] if files.empty?

  k = [1, (files.size.to_f / cap).ceil].max
  files.each_slice(k).map(&:first).first(cap)
end

def application_frame?(app_root, path)
  rel =
    if path.start_with?(app_root)
      path.delete_prefix(app_root).sub(%r{\A/+}, "")
    elsif path.start_with?("app/", "lib/", "config/")
      path
    else
      return false
    end
  return false if rel.split("/").any? { |s| %w[vendor node_modules gems bundler].include?(s) }
  return false if rel.include?("/ruby/")
  rel.match?(%r{\A(app|lib|config)/})
end

def extract_frames(text)
  frames = []
  text.each_line do |line|
    if (m = line.match(%r{(?:from\s+)?([^\s:]+?\.(?:rb|rake)):(\d+)}))
      frames << { "path" => m[1], "line" => m[2].to_i }
    elsif (m = line.match(/"file"\s*:\s*"([^"]+)"\s*,\s*"line"\s*:\s*(\d+)/))
      frames << { "path" => m[1], "line" => m[2].to_i }
    end
  end
  frames
end

def filter_app_frames(app_root, frames)
  frames.select { |f| application_frame?(app_root, f["path"]) }.map do |f|
    path = f["path"]
    rel = path.start_with?(app_root) ? path.delete_prefix(app_root).sub(%r{\A/+}, "") : path
    { "path" => rel, "line" => f["line"] }
  end
end

def build_trace(app_root, abs_path, format_id)
  rel = Pathname(abs_path).relative_path_from(Pathname(app_root)).to_s
  line = 10
  true_frames = [{ "path" => File.join(app_root, rel), "line" => line, "app" => true }]
  lines = []
  case format_id
  when 0
    DECOYS.each { |d| lines << "\tfrom #{d}" }
    lines << "\tfrom #{File.join(app_root, rel)}:#{line}:in `call'"
    DECOYS.each { |d| lines << "\tfrom #{d}" }
  when 1
    DECOYS.each { |d| lines << d }
    lines << "#{File.join(app_root, rel)}:#{line}:in `block in perform'"
    DECOYS.each { |d| lines << d }
  else
    payload = {
      "exception" => "RuntimeError",
      "backtrace" => DECOYS.map { |d| d.sub(/:in.*/, "") } + ["#{File.join(app_root, rel)}:#{line}"]
    }
    # encode as file/line pairs mixed with MRI lines
    lines << JSON.generate("file" => File.join(app_root, rel), "line" => line)
    DECOYS.each { |d| lines << d }
  end
  { "text" => lines.join("\n"), "truth" => true_frames }
end

out_dir = ARGV[0] || "eval/seed-spikes/error/results"
FileUtils.mkdir_p(out_dir)
summary = {}

APPS.each do |name, root|
  unless File.directory?(root)
    warn "missing #{root}"
    next
  end
  files = sample_app_files(root)
  rows = files.each_with_index.map do |abs, i|
    built = build_trace(root, abs, i % 3)
    extracted = extract_frames(built["text"])
    kept = filter_app_frames(root, extracted)
    truth_rels = built["truth"].map { |t| Pathname(t["path"]).relative_path_from(Pathname(root)).to_s }
    tp = kept.count { |k| truth_rels.include?(k["path"]) }
    fp = kept.size - tp
    fn = truth_rels.size - tp
    {
      "file" => Pathname(abs).relative_path_from(Pathname(root)).to_s,
      "format" => i % 3,
      "kept" => kept,
      "tp" => tp, "fp" => fp, "fn" => fn
    }
  end
  tp = rows.sum { |r| r["tp"] }
  fp = rows.sum { |r| r["fp"] }
  fn = rows.sum { |r| r["fn"] }
  precision = (tp + fp).zero? ? nil : tp.to_f / (tp + fp)
  recall = (tp + fn).zero? ? nil : tp.to_f / (tp + fn)
  summary[name] = { "n" => rows.size, "precision" => precision, "recall" => recall, "tp" => tp, "fp" => fp, "fn" => fn }
  File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate("app" => name, "rows" => rows, "summary" => summary[name]))
  puts "#{name}: n=#{rows.size} precision=#{precision} recall=#{recall}"
end

precs = summary.values.map { |s| s["precision"] }.compact
recs = summary.values.map { |s| s["recall"] }.compact
avg_p = precs.sum / precs.size
avg_r = recs.sum / recs.size
pass = avg_p >= 0.95 && avg_r >= 0.80
File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(
  "apps" => summary, "average_precision" => avg_p, "average_recall" => avg_r, "gate_pass" => pass
))
puts "avg_precision=#{avg_p} avg_recall=#{avg_r} gate_pass=#{pass}"
