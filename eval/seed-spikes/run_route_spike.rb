#!/usr/bin/env ruby
# frozen_string_literal: true

# Route-seed viability spike (double gate). Pre-registration:
# eval/seed-spikes/route/PREREGISTRATION.md — do not change scoring here
# without amending that file first (frozen 2026-07-14).
#
# Optional path groups `( ... )` are treated as absent on BOTH sides
# (evidence generation and spec matching) — the natural extension of the
# pre-registered "optional-format suffix dropped", fixed before scoring.

require "json"
require "fileutils"

APPS = %w[mastodon discourse zammad].freeze
STUB = "spike_stub_"
SAMPLE_CAP = 25

def clean?(*fields)
  fields.compact.none? { |f| f.include?(STUB) }
end

def strip_optional_groups(spec)
  spec = spec.dup
  spec = spec.gsub(/\([^()]*\)/, "") while spec.match?(/\([^()]*\)/)
  spec.empty? ? "/" : spec
end

def spec_segments(spec)
  strip_optional_groups(spec).split("/").reject(&:empty?)
end

def concrete_path(spec)
  segs = spec_segments(spec).map do |seg|
    case seg
    when /\A:/ then "1"
    when /\A\*/ then "x"
    else seg
    end
  end
  "/" + segs.join("/")
end

def last_static_segment(spec)
  spec_segments(spec).reverse_each do |seg|
    return seg unless seg.start_with?(":", "*")
  end
  "/"
end

def match_path?(spec, concrete)
  pattern = spec_segments(spec)
  actual = concrete.split("/").reject(&:empty?)
  return false if actual.size < pattern.count { |s| !s.start_with?("*") }

  i = 0
  pattern.each_with_index do |seg, idx|
    if seg.start_with?("*")
      # glob consumes the non-empty remainder unless it's the only way to
      # run out; everything after a glob must be static-matched from the end.
      rest = pattern[(idx + 1)..]
      return false if (actual.size - i - rest.size) < 1

      tail = actual.last(rest.size)
      return rest.zip(tail).all? { |p, a| p.start_with?(":") ? !a.nil? : p == a }
    end
    return false if actual[i].nil?
    return false if !seg.start_with?(":") && seg != actual[i]

    i += 1
  end
  i == actual.size
end

def verb_match?(row_verb, verb)
  row_verb.split("|").map(&:strip).include?(verb)
end

# Symmetric arm-success predicate: candidates non-empty AND all map to pair.
def arm_result(candidates, pair)
  return "no_match" if candidates.empty?

  pairs = candidates.map { |r| r["pair"] }.uniq
  if pairs == [pair]
    candidates.size == 1 ? "resolved_unique" : "resolved_convergent"
  elsif candidates.size == 1
    "wrong_match"
  else
    "ambiguous_multi"
  end
end

SUCCESS = %w[resolved_unique resolved_convergent].freeze

out_dir = ARGV[0] || "eval/seed-spikes/route/results"
FileUtils.mkdir_p(out_dir)

summary = {}
APPS.each do |app|
  data = JSON.parse(File.read("eval/seed-spikes/route/rows_#{app}.json"))
  rows = data.fetch("rows")
  usable = rows.select { |r| clean?(r["pair"]) }

  helper_pop = usable.select { |r| r["helper"] && !r["helper"].empty? && clean?(r["helper"]) }
  path_pop = usable.select { |r| clean?(r["path_spec"]) }
  verb_pop = path_pop.select { |r| !r["verb"].to_s.empty? }

  helper_index = Hash.new { |h, k| h[k] = [] }
  helper_pop.each { |r| helper_index[r["helper"]] << r }
  rendered = usable.map { |r| [r, "#{r["helper"]} #{r["verb"]} #{r["path_spec"]} #{r["pair"]}"] }

  per_variant = {}
  taxonomy = Hash.new(0)
  ritual_dist = Hash.new(0)
  samples = Hash.new { |h, k| h[k] = [] }

  score = lambda do |variant, pop, resolve, token_for|
    res_ok = 0
    rit_ok = 0
    pop.each do |row|
      begin
        r_label = arm_result(resolve.call(row), row["pair"])
        taxonomy["#{variant}:#{r_label}"] += 1
        res_ok += 1 if SUCCESS.include?(r_label)
        unless SUCCESS.include?(r_label)
          samples["#{variant}:#{r_label}"] << { "pair" => row["pair"], "spec" => row["path_spec"], "helper" => row["helper"] } if samples["#{variant}:#{r_label}"].size < SAMPLE_CAP
        end

        token = token_for.call(row)
        hits = rendered.select { |_, line| line.include?(token) }.map(&:first)
        h_label = arm_result(hits, row["pair"])
        rit_ok += 1 if SUCCESS.include?(h_label)
        key = if hits.empty? then "zero_hit"
              elsif hits.size == 1 && !SUCCESS.include?(h_label) then "wrong_unique"
              elsif hits.size > 1 && hits.any? { |r| r["pair"] == row["pair"] } && !SUCCESS.include?(h_label) then "multi_with_correct"
              else "other_#{h_label}"
              end
        ritual_dist["#{variant}:#{key}"] += 1
      rescue StandardError => e
        taxonomy["#{variant}:crash"] += 1
        samples["#{variant}:crash"] << { "pair" => row["pair"], "error" => e.message } if samples["#{variant}:crash"].size < SAMPLE_CAP
      end
    end
    per_variant[variant] = {
      "n" => pop.size,
      "resolver_rate" => pop.empty? ? nil : res_ok.to_f / pop.size,
      "ritual_rate" => pop.empty? ? nil : rit_ok.to_f / pop.size,
      "resolver_ok" => res_ok, "ritual_ok" => rit_ok
    }
  end

  score.call("helper", helper_pop,
             ->(row) { helper_index[row["helper"]] },
             ->(row) { row["helper"] })
  score.call("verb_path", verb_pop,
             lambda { |row|
               verb = row["verb"].split("|").first.strip
               concrete = concrete_path(row["path_spec"])
               path_pop.select { |r| verb_match?(r["verb"], verb) && match_path?(r["path_spec"], concrete) }
             },
             ->(row) { last_static_segment(row["path_spec"]) })
  score.call("path", path_pop,
             lambda { |row|
               concrete = concrete_path(row["path_spec"])
               path_pop.select { |r| match_path?(r["path_spec"], concrete) }
             },
             ->(row) { last_static_segment(row["path_spec"]) })

  # Gated resolution: path + verb_path only (helper is ~1.0 by construction).
  gate_n = per_variant["path"]["n"] + per_variant["verb_path"]["n"]
  gate_ok = per_variant["path"]["resolver_ok"] + per_variant["verb_path"]["resolver_ok"]
  resolution_rate = gate_n.zero? ? nil : gate_ok.to_f / gate_n

  # Margin: pooled over all three variants, same population both arms.
  all_n = per_variant.values.sum { |v| v["n"] }
  margin = if all_n.zero?
             nil
           else
             (per_variant.values.sum { |v| v["resolver_ok"] }.to_f -
              per_variant.values.sum { |v| v["ritual_ok"] }) / all_n
           end

  payload = {
    "app" => app,
    "rows_total" => rows.size,
    "excluded_stub_pair" => rows.size - usable.size,
    "excluded_stub_helper" => usable.count { |r| r["helper"] && !r["helper"].empty? } - helper_pop.size,
    "excluded_stub_path" => usable.size - path_pop.size,
    "per_variant" => per_variant,
    "resolution_rate_gated" => resolution_rate,
    "front_b_margin" => margin,
    "taxonomy" => taxonomy,
    "ritual_distribution" => ritual_dist,
    "samples" => samples
  }
  File.write(File.join(out_dir, "#{app}.json"), JSON.pretty_generate(payload))
  summary[app] = payload.reject { |k, _| k == "samples" }
  puts "#{app}: gated_resolution=#{resolution_rate&.round(4)} margin=#{margin&.round(4)} helper=#{per_variant["helper"]["resolver_rate"]&.round(4)} " \
       "n(path/verb/helper)=#{per_variant["path"]["n"]}/#{per_variant["verb_path"]["n"]}/#{per_variant["helper"]["n"]}"
end

res_rates = summary.values.map { |s| s["resolution_rate_gated"] }.compact
margins = summary.values.map { |s| s["front_b_margin"] }.compact
avg_res = res_rates.empty? ? nil : res_rates.sum / res_rates.size
avg_margin = margins.empty? ? nil : margins.sum / margins.size
res_pass = avg_res && avg_res >= 0.70
margin_pass = avg_margin && avg_margin >= 0.10
File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(
  "apps" => summary,
  "average_resolution_gated" => avg_res, "resolution_gate" => 0.70, "resolution_pass" => res_pass,
  "average_front_b_margin" => avg_margin, "margin_gate" => 0.10, "margin_pass" => margin_pass,
  "ship" => res_pass && margin_pass
))
puts "avg_resolution=#{avg_res&.round(4)} (pass=#{res_pass}) avg_margin=#{avg_margin&.round(4)} (pass=#{margin_pass}) SHIP=#{res_pass && margin_pass}"
