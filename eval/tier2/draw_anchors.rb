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
#   ruby eval/tier2/draw_anchors.rb <app_root> <routes.json> <results.json> <seed> \
#     [--test-glob TEMPLATE] [--features N]
#
# Order: pairs are sorted by SHA256("<seed>:<controller#action>") — a
# deterministic shuffle keyed to the app's pinned commit SHA.
#
# Assignment walks that order once per slot, tightest filter first
# (bug, then behavior, then feature slots), skipping pairs already assigned
# and requiring distinct controllers across slots. Every rejected candidate is
# printed to stderr with its reason and emitted in the JSON result.
#
# Shape filters (mechanical):
#   bug (bug fix from failing test): resolved AND the configured test path
#     exists (default: test/functional/<controller_path>_controller_test.rb) AND its
#     content matches /\b<action>\b/ (coverage proxy — a bug seeded at the
#     action must be able to fail an existing test).
#   behavior (small behavior change / side effect): resolved AND action is
#     one of create / update / destroy (unambiguous writes).
#   feature_N (feature work from a controller action): resolved.

require "json"
require "digest"

DEFAULT_TEST_GLOB = "test/functional/{controller}_controller_test.rb"
USAGE = "usage: draw_anchors.rb <app_root> <routes.json> <results.json> <seed> " \
        "[--test-glob TEMPLATE] [--features N]"

options = {
  test_glob: DEFAULT_TEST_GLOB,
  features: 1
}

positionals = []
args = ARGV.dup

until args.empty?
  arg = args.shift

  case arg
  when "--test-glob"
    abort "--test-glob requires a TEMPLATE\n#{USAGE}" if args.empty?

    options[:test_glob] = args.shift
  when /\A--test-glob=(.*)\z/
    options[:test_glob] = Regexp.last_match(1)
  when "--features"
    abort "--features requires N\n#{USAGE}" if args.empty?

    features = Integer(args.shift, exception: false)
    abort "--features must be a positive integer\n#{USAGE}" unless features&.positive?

    options[:features] = features
  when /\A--features=(.*)\z/
    features = Integer(Regexp.last_match(1), exception: false)
    abort "--features must be a positive integer\n#{USAGE}" unless features&.positive?

    options[:features] = features
  else
    abort "unknown option: #{arg}\n#{USAGE}" if arg.start_with?("--")

    positionals << arg
  end
end

abort USAGE unless positionals.size == 4
abort "--test-glob must contain literal {controller}\n#{USAGE}" unless options[:test_glob].include?("{controller}")

app_root, routes_path, results_path, seed = positionals

pairs = JSON.parse(File.read(routes_path)).fetch("pairs").keys
resolved = JSON.parse(File.read(results_path)).fetch("results")
               .to_h { |r| [r.fetch("anchor"), r.fetch("result") == "resolved"] }

ordered = pairs.sort_by { |p| Digest::SHA256.hexdigest("#{seed}:#{p}") }

WRITE_ACTIONS = %w[create update destroy].freeze

bug_filter = lambda do |controller, action|
  relative_test_path = options[:test_glob].gsub("{controller}", controller)
  test_file = File.join(app_root, relative_test_path)

  return "no test file" unless File.exist?(test_file)
  return "action not referenced in test file" unless File.read(test_file).match?(/\b#{Regexp.escape(action)}\b/)

  nil
end

behavior_filter = ->(_controller, action) { WRITE_ACTIONS.include?(action) ? nil : "not a write action (#{WRITE_ACTIONS.join('/')})" }
feature_filter = ->(_controller, _action) { nil }

assigned = {} # slot => pair
skips = []
used_controllers = []

slots = [
  ["bug", bug_filter],
  ["behavior", behavior_filter]
] + (1..options[:features]).map { |index| ["feature_#{index}", feature_filter] }

slots.each do |slot, filter|
  ordered.each do |pair|
    controller, action = pair.split("#", 2)
    if assigned.value?(pair)
      next
    elsif used_controllers.include?(controller)
      reason = "controller already assigned to another slot"
      skips << { "slot" => slot, "pair" => pair, "reason" => reason }
      warn "#{slot} skip #{pair}: #{reason}"
      next
    elsif !resolved.fetch(pair, false)
      reason = "anchor does not resolve (no packet possible)"
      skips << { "slot" => slot, "pair" => pair, "reason" => reason }
      warn "#{slot} skip #{pair}: #{reason}"
      next
    elsif (reason = filter.call(controller, action))
      skips << { "slot" => slot, "pair" => pair, "reason" => reason }
      warn "#{slot} skip #{pair}: #{reason}"
      next
    end

    assigned[slot] = pair
    used_controllers << controller
    break
  end
end

puts JSON.pretty_generate({ "assigned" => assigned, "skips" => skips })
