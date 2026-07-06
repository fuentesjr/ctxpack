# frozen_string_literal: true

# Tier 2 anchor draw — deterministic, pre-registered (see PREREGISTRATION.md).
#
# Draws one anchor per task shape from the app's route table, BEFORE any
# packet is generated or inspected (eval-plan.md, Tier 2 "Anchor selection").
# The only per-anchor signals consulted are (a) the Tier 0 classifier's
# resolution boolean — a packet must exist for the treatment arm to be
# runnable — and (b) the mechanical shape filters below. Packet CONTENT is
# never read here.
#
# Usage:
#   ruby eval/tier2/draw_anchors.rb <app_root> <routes.json> <results.json> <seed>
#
# Order: pairs are sorted by SHA256("<seed>:<controller#action>") — a
# deterministic shuffle keyed to the app's pinned commit SHA.
#
# Assignment walks that order once per shape, tightest filter first
# (shape 2, then 3, then 1), skipping pairs already assigned and requiring
# distinct controllers across shapes. Every skip is printed with its reason.
#
# Shape filters (mechanical):
#   shape 2 (bug fix from failing Minitest test): resolved AND
#     test/functional/<controller_path>_controller_test.rb exists AND its
#     content matches /\b<action>\b/ (coverage proxy — a bug seeded at the
#     action must be able to fail an existing test).
#   shape 3 (small behavior change / side effect): resolved AND action is
#     one of create / update / destroy (unambiguous writes).
#   shape 1 (feature work from a controller action): resolved.

require "json"
require "digest"

app_root, routes_path, results_path, seed = ARGV
abort "usage: draw_anchors.rb <app_root> <routes.json> <results.json> <seed>" unless seed

pairs = JSON.parse(File.read(routes_path)).fetch("pairs").keys
resolved = JSON.parse(File.read(results_path)).fetch("results")
               .to_h { |r| [r.fetch("anchor"), r.fetch("result") == "resolved"] }

ordered = pairs.sort_by { |p| Digest::SHA256.hexdigest("#{seed}:#{p}") }

WRITE_ACTIONS = %w[create update destroy].freeze

shape2 = lambda do |controller, action|
  test_file = File.join(app_root, "test", "functional", "#{controller}_controller_test.rb")
  return "no functional test file" unless File.exist?(test_file)
  return "action not referenced in test file" unless File.read(test_file).match?(/\b#{Regexp.escape(action)}\b/)

  nil
end

shape3 = ->(_controller, action) { WRITE_ACTIONS.include?(action) ? nil : "not a write action (#{WRITE_ACTIONS.join('/')})" }
shape1 = ->(_controller, _action) { nil }

assigned = {} # shape => pair
used_controllers = []

[["shape2", shape2], ["shape3", shape3], ["shape1", shape1]].each do |name, filter|
  ordered.each do |pair|
    controller, action = pair.split("#", 2)
    if assigned.value?(pair)
      next
    elsif used_controllers.include?(controller)
      puts "#{name} skip #{pair}: controller already assigned to another shape"
      next
    elsif !resolved.fetch(pair, false)
      puts "#{name} skip #{pair}: anchor does not resolve (no packet possible)"
      next
    elsif (reason = filter.call(controller, action))
      puts "#{name} skip #{pair}: #{reason}"
      next
    end

    assigned[name] = pair
    used_controllers << controller
    break
  end
end

puts JSON.pretty_generate(assigned.sort.to_h)
