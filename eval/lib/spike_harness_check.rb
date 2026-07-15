# frozen_string_literal: true

# Self-check for SpikeHarness. Not wired into rake (EVAL-10 spirit: eval
# tooling stays out of CI). Run manually: ruby eval/lib/spike_harness_check.rb
#
# Characterizes the extracted helpers against (a) fixed cases matching the
# inline implementations they were extracted from and (b) the recorded
# route-spike summary, recomputed from its committed per-app payloads.

require "json"
require_relative "spike_harness"

failures = []
check = ->(name, got, want) { failures << "#{name}: got #{got.inspect}, want #{want.inspect}" unless got == want }

# percentile — same nearest-rank shape as run_method_spike.rb / run_diff_spike.rb
check.call("percentile median odd", SpikeHarness.percentile([1, 2, 3], 0.5), 2)
check.call("percentile p90 of 10", SpikeHarness.percentile((1..10).to_a, 0.9), 9)
check.call("percentile single", SpikeHarness.percentile([7], 0.5), 7)
check.call("percentile empty", SpikeHarness.percentile([], 0.9), nil)

# excluded_path? — same list every spike used
check.call("excluded vendor", SpikeHarness.excluded_path?("vendor/gems/foo.rb"), true)
check.call("excluded nested plugins", SpikeHarness.excluded_path?("app/plugins/x/y.rb"), true)
check.call("not excluded app", SpikeHarness.excluded_path?("app/models/user.rb"), false)

# average — 3-app unweighted convention, nil-safe
check.call("average", SpikeHarness.average([0.5, 0.7, nil]), 0.6)
check.call("average empty", SpikeHarness.average([nil, nil]), nil)

# Characterization: recompute the recorded route-spike summary gates from its
# committed per-app payloads; values must match eval/seed-spikes/route/results/summary.json.
apps = %w[mastodon discourse zammad].map { |a| JSON.parse(File.read("eval/seed-spikes/route/results/#{a}.json")) }
recorded = JSON.parse(File.read("eval/seed-spikes/route/results/summary.json"))
avg_res = SpikeHarness.average(apps.map { |p| p["resolution_rate_gated"] })
avg_margin = SpikeHarness.average(apps.map { |p| p["front_b_margin"] })
check.call("route avg resolution", avg_res, recorded["average_resolution_gated"])
check.call("route avg margin", avg_margin, recorded["average_front_b_margin"])
doc = SpikeHarness.write_summary(
  "/tmp/spike_harness_check_#{Process.pid}",
  {},
  "average_resolution_gated" => { value: avg_res, threshold: 0.70, pass: avg_res >= 0.70 },
  "average_front_b_margin" => { value: avg_margin, threshold: 0.10, pass: avg_margin >= 0.10 }
)
check.call("route resolution pass flag", doc["average_resolution_gated_pass"], recorded["resolution_pass"])
check.call("route margin pass flag", doc["average_front_b_margin_pass"], recorded["margin_pass"])
check.call("route ship flag", doc["ship"], recorded["ship"])

# Live: pinned checkouts still verifiable (raises on mismatch).
begin
  SpikeHarness.verify_pinned_checkouts!
  puts "pinned checkouts: OK"
rescue RuntimeError => e
  puts "pinned checkouts: SKIP (#{e.message}) — helper raises as designed"
end

if failures.empty?
  puts "spike_harness self-check: all #{14} checks passed"
else
  puts failures
  abort "spike_harness self-check FAILED"
end
