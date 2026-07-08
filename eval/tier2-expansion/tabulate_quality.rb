# frozen_string_literal: true

# Reveal + tabulate the blind diff-quality scores for the Tier 2 expansion.
#
# Joins the sealed mapping (opaque code -> session/app) with the judge's
# blind scores (one representative scored per byte-identical group; all codes
# in a group inherit that score) and aggregates to per app x task x arm means
# plus an overall control-vs-treatment comparison, matching the Tier 2
# diff-quality table (eval/tier2/RESULTS.md).
#
# Inputs live under a judging dir (default: committed eval/tier2-expansion/
# judging/, falling back to tmp/tier2-expansion/judging/ if that is where
# build_blind_judging.rb last wrote them):
#   mapping.json  code -> {session, app, sha256}   (SEALED during scoring)
#   scores.json   representative code -> sub-scores + comment
#   groups.json   per app: byte-identical code groups + representatives
#
# Usage:
#   ruby eval/tier2-expansion/tabulate_quality.rb [judging_dir]

require "json"

ROOT = File.expand_path("../..", __dir__)
DEFAULT_DIRS = [
  File.join(ROOT, "eval/tier2-expansion/judging"),
  File.join(ROOT, "tmp/tier2-expansion/judging")
].freeze

dir = ARGV[0] || DEFAULT_DIRS.find { |d| File.exist?(File.join(d, "mapping.json")) }
abort "no judging dir with mapping.json found" unless dir && File.exist?(File.join(dir, "mapping.json"))

mapping = JSON.parse(File.read(File.join(dir, "mapping.json")))
scores  = JSON.parse(File.read(File.join(dir, "scores.json")))["scores"]
groups  = JSON.parse(File.read(File.join(dir, "groups.json")))

APPS = %w[campfire lobsters publify].freeze
TASK_KIND = { "1" => "feature", "2" => "feature", "3" => "bug", "4" => "behavior" }.freeze

# code -> representative code (lowest code in its byte-identical group)
rep_of = {}
APPS.each do |app|
  groups[app].each do |grp|
    rep = grp.min
    grp.each { |code| rep_of[code] = rep }
  end
end

def sum(sub)
  %w[correct minimal conventions no_unrelated].sum { |k| sub.fetch(k) }
end

# app -> task -> arm -> [scores...]
cells = Hash.new { |h, a| h[a] = Hash.new { |h2, t| h2[t] = Hash.new { |h3, arm| h3[arm] = [] } } }
overall = Hash.new { |h, arm| h[arm] = [] }
by_kind = Hash.new { |h, k| h[k] = Hash.new { |h2, arm| h2[arm] = [] } }

mapping.each do |code, info|
  session = info.fetch("session")   # e.g. t2-3-treatment-2
  app = info.fetch("app")
  m = session.match(/\At2-(\d)-(control|treatment)-(\d+)\z/)
  abort "unparseable session #{session.inspect}" unless m
  task, arm = m[1], m[2]
  s = sum(scores.fetch(rep_of.fetch(code)))
  cells[app][task][arm] << s
  overall[arm] << s
  by_kind[TASK_KIND.fetch(task)][arm] << s
end

def mean(xs)
  xs.empty? ? nil : (xs.sum.to_f / xs.size)
end

def fmt(xs)
  return "—" if xs.empty?
  "#{xs.sort.join(',')} → #{format('%.2f', mean(xs))}"
end

puts "Tier 2 expansion — blind diff-quality (0–8), per app × task × arm"
puts "(scores over the 3 grid rounds; task 1,2=feature 3=bug 4=behavior)"
puts
puts "%-9s %-5s %-9s %-22s %-22s" % %w[app task kind control treatment]
puts "-" * 72
APPS.each do |app|
  %w[1 2 3 4].each do |task|
    c = cells[app][task]["control"]
    t = cells[app][task]["treatment"]
    puts "%-9s %-5s %-9s %-22s %-22s" % [app, task, TASK_KIND[task], fmt(c), fmt(t)]
  end
end
puts "-" * 72
puts "%-9s %-5s %-9s control mean %.3f (n=%d)   treatment mean %.3f (n=%d)" %
     ["OVERALL", "", "", mean(overall["control"]), overall["control"].size,
      mean(overall["treatment"]), overall["treatment"].size]
puts
puts "By task kind (pooled across apps):"
%w[feature bug behavior].each do |kind|
  c = by_kind[kind]["control"]
  t = by_kind[kind]["treatment"]
  puts "  %-9s control %.3f (n=%d)   treatment %.3f (n=%d)" %
       [kind, mean(c), c.size, mean(t), t.size]
end

# machine-readable summary for the record
summary = {
  "overall" => {
    "control" => { "mean" => mean(overall["control"]), "n" => overall["control"].size, "scores" => overall["control"].sort },
    "treatment" => { "mean" => mean(overall["treatment"]), "n" => overall["treatment"].size, "scores" => overall["treatment"].sort }
  },
  "by_app_task" => APPS.each_with_object({}) do |app, acc|
    acc[app] = %w[1 2 3 4].each_with_object({}) do |task, ta|
      ta[task] = {
        "kind" => TASK_KIND[task],
        "control" => { "mean" => mean(cells[app][task]["control"]), "scores" => cells[app][task]["control"].sort },
        "treatment" => { "mean" => mean(cells[app][task]["treatment"]), "scores" => cells[app][task]["treatment"].sort }
      }
    end
  end,
  "by_kind" => %w[feature bug behavior].each_with_object({}) do |kind, acc|
    acc[kind] = {
      "control" => { "mean" => mean(by_kind[kind]["control"]), "n" => by_kind[kind]["control"].size },
      "treatment" => { "mean" => mean(by_kind[kind]["treatment"]), "n" => by_kind[kind]["treatment"].size }
    }
  end
}
out = File.join(dir, "quality_summary.json")
File.write(out, JSON.pretty_generate(summary) + "\n")
puts
puts "wrote #{out}"
