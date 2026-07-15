# frozen_string_literal: true

# Shared spine for viability-spike scripts (extracted 2026-07-14 after six
# spike scripts duplicated it — see eval/README.md "Authoring rule").
#
# Scope: plumbing only. Per-spike SCORING (populations, heuristics, ground
# truth, gates) stays in the spike's own script, frozen by its
# PREREGISTRATION.md. Applies to FUTURE spikes; already-measured spike
# scripts are historical artifacts and must not be retrofitted.

require "json"
require "fileutils"

module SpikeHarness
  # Pinned Tier 0 sample apps (same SHAs as eval/tier0/RESULTS.md).
  APPS = {
    "mastodon" => { path: "tmp/tier0-rescan/mastodon",
                    sha: "163f96cee4dea23365bff9b433871e68d20d9ee7" },
    "discourse" => { path: "tmp/tier0-rescan/discourse",
                     sha: "28b003a38d82c354ffc49bac23b655de9664e478" },
    "zammad" => { path: "tmp/tier0-rescan/zammad",
                  sha: "50384f4c390e8abed07694897956c2f8e176208d" }
  }.freeze

  EXCLUDE_PARTS = %w[plugins engines vendor node_modules .git].freeze

  module_function

  # Path-segment exclusion shared by every spike population walk.
  def excluded_path?(rel)
    parts = rel.split("/")
    EXCLUDE_PARTS.any? { |p| parts.include?(p) }
  end

  # Verify each checkout exists at its pinned SHA before measuring; raises
  # rather than silently measuring the wrong tree.
  def verify_pinned_checkouts!(apps = APPS)
    apps.each do |name, cfg|
      head = `git -C #{cfg[:path]} rev-parse HEAD 2>/dev/null`.strip
      raise "#{name}: checkout missing or wrong SHA (#{head.inspect}, want #{cfg[:sha]})" unless head == cfg[:sha]
    end
  end

  # Nearest-rank percentile over a pre-sorted array (the shape every spike
  # reported); returns nil on empty.
  def percentile(sorted, pct)
    return nil if sorted.empty?

    sorted[[(sorted.size * pct).ceil - 1, 0].max]
  end

  # Count labels and keep at most `cap` sample rows per label.
  class Taxonomy
    attr_reader :counts, :samples

    def initialize(sample_cap: 50)
      @cap = sample_cap
      @counts = Hash.new(0)
      @samples = Hash.new { |h, k| h[k] = [] }
    end

    def record(label, sample = nil)
      @counts[label] += 1
      @samples[label] << sample if sample && @samples[label].size < @cap
    end
  end

  # Write per-app payload JSON; returns the payload minus heavy sample keys
  # for the cross-app summary (mirrors every spike's output shape).
  def write_app_payload(out_dir, app, payload, strip: %w[label_samples samples results])
    FileUtils.mkdir_p(out_dir)
    File.write(File.join(out_dir, "#{app}.json"), JSON.pretty_generate(payload))
    payload.reject { |k, _| strip.include?(k) }
  end

  # Unweighted average of per-app rates (the standing 3-app convention);
  # nil-safe: apps without a rate are excluded, empty set → nil.
  def average(rates)
    present = rates.compact
    present.empty? ? nil : present.sum / present.size
  end

  # Write summary.json with named gates. gates: {name => {value:, threshold:,
  # pass:}}. Adds an overall "ship" only when every gate has a pass value.
  def write_summary(out_dir, apps_summary, gates)
    FileUtils.mkdir_p(out_dir)
    doc = { "apps" => apps_summary }
    gates.each do |name, g|
      doc["#{name}_value"] = g[:value]
      doc["#{name}_gate"] = g[:threshold]
      doc["#{name}_pass"] = g[:pass]
    end
    doc["ship"] = gates.values.all? { |g| g[:pass] } if gates.values.none? { |g| g[:pass].nil? }
    File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(doc))
    doc
  end
end
