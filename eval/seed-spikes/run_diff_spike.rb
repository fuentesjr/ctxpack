#!/usr/bin/env ruby
# frozen_string_literal: true

# Diff-seed viability spike. Pre-registration:
# eval/seed-spikes/diff/PREREGISTRATION.md — do not change scoring here
# without amending that file first (frozen 2026-07-14).

require "json"
require "fileutils"
require "open3"
require "prism"

APPS = {
  "mastodon" => "tmp/tier0-rescan/mastodon",
  "discourse" => "tmp/tier0-rescan/discourse",
  # Zammad history lives in a separate depth-601 fetch at the pinned SHA
  # (in-place --deepen kept failing on connection resets; same window).
  "zammad" => "tmp/seed-history/zammad"
}.freeze

EXCLUDE_RE = %r{(?:\A|/)(?:plugins|engines|vendor|node_modules)/}
CAP = 200

def git(dir, *args)
  out, status = Open3.capture2("git", "-C", dir, *args)
  raise "git #{args.first} failed in #{dir}" unless status.success?

  out
end

def git?(dir, *args)
  _, status = Open3.capture2e("git", "-C", dir, *args)
  status.success?
end

def prod_file?(path)
  path.match?(%r{\Aapp/.+\.rb\z}) && !path.match?(EXCLUDE_RE) &&
    !path.start_with?("app/views/")
end

def test_file?(path)
  path.match?(%r{\A(?:test|spec)/.+_(?:test|spec)\.rb\z}) && !path.match?(EXCLUDE_RE)
end

# name-status rows → [{status:, old:, new:}]
def changed_entries(dir, sha)
  git(dir, "show", "--format=", "--name-status", "-M", sha).lines.filter_map do |line|
    cols = line.chomp.split("\t")
    next if cols.empty?

    status = cols[0][0]
    case status
    when "R", "C" then { status: status, old: cols[1], new: cols[2] }
    when "D" then { status: status, old: cols[1], new: nil }
    else { status: status, old: nil, new: cols[1] }
    end
  end
end

# Distinct production paths touched (rename counted once, by new path).
def prod_paths(entries)
  entries.filter_map do |e|
    path = e[:new] || e[:old]
    path if prod_file?(e[:new].to_s) || prod_file?(e[:old].to_s)
  end.uniq
end

def touched_tests(entries)
  entries.flat_map { |e| [e[:old], e[:new]].compact }.select { |p| test_file?(p) }.uniq
end

def mirror_candidates(path)
  cands = []
  if (m = path.match(%r{\Aapp/controllers/(.+)_controller\.rb\z}))
    p = m[1]
    cands += ["test/controllers/#{p}_controller_test.rb",
              "spec/controllers/#{p}_controller_spec.rb",
              "spec/requests/#{p}_spec.rb",
              "spec/requests/#{p}_controller_spec.rb"]
  end
  if (m = path.match(%r{\Aapp/([^/]+)/(.+)\.rb\z}))
    dir, p = m[1], m[2]
    cands += ["test/#{dir}/#{p}_test.rb", "spec/#{dir}/#{p}_spec.rb"]
  end
  if (m = path.match(%r{\Alib/(.+)\.rb\z}))
    cands += ["test/lib/#{m[1]}_test.rb", "spec/lib/#{m[1]}_spec.rb"]
  end
  cands.uniq
end

def related_dir?(prod_path, test_paths)
  prod_seg = prod_path[%r{\Aapp/([^/]+)/}, 1]
  return false unless prod_seg

  test_paths.any? do |t|
    seg = t[%r{\A(?:test|spec)/([^/]+)/}, 1]
    seg == prod_seg || (prod_seg == "controllers" && %w[requests integration].include?(seg))
  end
end

def def_ranges(source)
  result = Prism.parse(source)
  ranges = []
  collect = lambda do |node|
    return if node.nil?

    ranges << (node.location.start_line..node.location.end_line) if node.is_a?(Prism::DefNode)
    node.compact_child_nodes.each { |c| collect.call(c) }
  end
  collect.call(result.value)
  ranges
end

# Post-image changed line ranges per file from unified=0 hunk headers.
def hunks(dir, sha, path)
  out = git(dir, "show", "--format=", "--unified=0", sha, "--", path)
  out.scan(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/).map do |start, count|
    n = (count || "1").to_i
    [start.to_i, n]
  end
end

out_dir = ARGV[0] || "eval/seed-spikes/diff/results"
FileUtils.mkdir_p(out_dir)

summary = {}
APPS.each do |name, dir|
  abort "missing app root #{dir}" unless File.directory?(dir)

  shas = git(dir, "log", "--first-parent", "--no-merges", "--format=%H").split("\n")
  anchor_pop = []   # [sha, entries]
  gated_pop = []    # [sha, prod_path, touched_tests]
  ambiguous = 0

  shas.each do |sha|
    entries = changed_entries(dir, sha)
    prods = prod_paths(entries)
    tests = touched_tests(entries)
    anchor_pop << [sha, entries] if !prods.empty? && anchor_pop.size < CAP
    ambiguous += 1 if prods.size >= 2 && !tests.empty?
    gated_pop << [sha, prods.first, tests] if prods.size == 1 && !tests.empty? && gated_pop.size < CAP
    break if anchor_pop.size >= CAP && gated_pop.size >= CAP
  end

  # Gated metric: paired-test agreement.
  labels = Hash.new(0)
  samples = Hash.new { |h, k| h[k] = [] }
  nonempty = 0
  agree = 0
  gated_pop.each do |sha, prod, tests|
    begin
      pred = mirror_candidates(prod).select { |c| git?(dir, "cat-file", "-e", "#{sha}:#{c}") }
      if pred.empty?
        labels["no_prediction"] += 1
        next
      end
      nonempty += 1
      if (pred & tests).any?
        labels["agree_mirror"] += 1
        agree += 1
      else
        label = related_dir?(prod, tests) ? "disagree_related_dir" : "disagree_unrelated"
        labels[label] += 1
        samples[label] << { "sha" => sha[0, 10], "prod" => prod, "tests" => tests.first(3) } if samples[label].size < 25
      end
    rescue StandardError => e
      labels["crash"] += 1
      samples["crash"] << { "sha" => sha[0, 10], "error" => e.message } if samples["crash"].size < 25
    end
  end
  agreement = nonempty.zero? ? nil : agree.to_f / nonempty

  # Report-only: def-anchoring + file survival over the anchor population.
  hunks_total = 0
  hunks_anchored = 0
  survival_total = 0
  survival_exists = 0
  anchor_pop.each do |sha, entries|
    entries.each do |e|
      [e[:old], e[:new]].compact.uniq.each do |p|
        next unless prod_file?(p)

        survival_total += 1
        survival_exists += 1 if git?(dir, "cat-file", "-e", "#{sha}:#{p}")
      end
      post = e[:new]
      next unless post && prod_file?(post) && git?(dir, "cat-file", "-e", "#{sha}:#{post}")

      begin
        ranges = def_ranges(git(dir, "show", "#{sha}:#{post}"))
        hunks(dir, sha, post).each do |start, count|
          hunks_total += 1
          next if count.zero? # pure deletion: no post-image changed line

          lines = (start...(start + count))
          hunks_anchored += 1 if ranges.any? { |r| lines.any? { |l| r.cover?(l) } }
        end
      rescue StandardError
        next
      end
    end
  end

  payload = {
    "app" => name,
    "window_commits" => shas.size,
    "anchor_population" => anchor_pop.size,
    "gated_population" => gated_pop.size,
    "ambiguous_excluded" => ambiguous,
    "nonempty_predictions" => nonempty,
    "agreement" => agreement,
    "by_label" => labels,
    "def_anchoring" => { "hunks" => hunks_total, "anchored" => hunks_anchored,
                         "rate" => hunks_total.zero? ? nil : hunks_anchored.to_f / hunks_total },
    "file_survival" => { "paths" => survival_total, "exist_post_image" => survival_exists,
                         "rate" => survival_total.zero? ? nil : survival_exists.to_f / survival_total },
    "label_samples" => samples
  }
  File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate(payload))
  summary[name] = payload.reject { |k, _| k == "label_samples" }
  puts "#{name}: window=#{shas.size} gated_n=#{gated_pop.size} nonempty=#{nonempty} agreement=#{agreement&.round(4)} " \
       "def_anchor=#{payload.dig('def_anchoring', 'rate')&.round(4)} #{labels.inspect}"
end

agreements = summary.values.map { |s| s["agreement"] }.compact
avg = agreements.empty? ? nil : agreements.sum / agreements.size
pass = !agreements.empty? && avg >= 0.70
File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(
  "apps" => summary, "average_agreement" => avg, "gate" => 0.70, "pass" => pass
))
puts "average_agreement=#{avg&.round(4)} gate_pass=#{pass}"
