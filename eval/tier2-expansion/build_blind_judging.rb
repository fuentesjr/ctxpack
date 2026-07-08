# frozen_string_literal: true

# Build the blind-judging bundle for the Tier 2 expansion grid, mirroring the
# opaque-code scheme used for the original Tier 2 apps under
# tmp/tier2/judging/ (see mapping.json / scores.json there). The orchestrator
# scoring the diffs must stay blind to which opaque code maps to which
# session/arm, so the mapping is written to disk but never surfaced in this
# script's stdout.
#
# Determinism: each app's 24 grid diffs (pilot diffs excluded) are shuffled
# with a Random PRNG seeded from that app's pinned SHA (eval/tier2-expansion/
# <app>/anchors.json "app_sha"), so re-running this script reproduces
# identical codes, groups, and mapping every time.
#
# Usage:
#   ruby eval/tier2-expansion/build_blind_judging.rb

require "json"
require "digest"
require "fileutils"

APPS = {
  "campfire" => "C",
  "lobsters" => "L",
  "publify" => "P"
}.freeze

ROOT = File.expand_path("../..", __dir__)
OUT_DIR = File.join(ROOT, "tmp/tier2-expansion/judging")
PATCHES_DIR = File.join(OUT_DIR, "patches")

FileUtils.rm_rf(PATCHES_DIR)
FileUtils.mkdir_p(PATCHES_DIR)

groups_by_app = {}
mapping = {}
summary = []

APPS.each do |app, prefix|
  app_dir = File.join(ROOT, "eval/tier2-expansion", app)
  anchors = JSON.parse(File.read(File.join(app_dir, "anchors.json")))
  app_sha = anchors.fetch("app_sha")
  seed_int = Integer(app_sha[0, 15], 16)
  rng = Random.new(seed_int)

  diff_paths = Dir.glob(File.join(app_dir, "diffs", "*.patch"))
                   .reject { |path| File.basename(path).end_with?("-pilot.patch") }
                   .sort

  abort "#{app}: expected 24 non-pilot diffs, found #{diff_paths.size}" unless diff_paths.size == 24

  shuffled = diff_paths.shuffle(random: rng)

  codes_by_sha256 = Hash.new { |h, k| h[k] = [] }

  shuffled.each_with_index do |path, index|
    code = format("%s%02d", prefix, index + 1)
    bytes = File.binread(path)
    sha256 = Digest::SHA256.hexdigest(bytes)

    File.binwrite(File.join(PATCHES_DIR, "#{code}.patch"), bytes)

    session = File.basename(path, ".patch")
    mapping[code] = { "session" => session, "app" => app, "sha256" => sha256 }
    codes_by_sha256[sha256] << code
  end

  groups = codes_by_sha256.values.map(&:sort).sort_by(&:first)
  groups_by_app[app] = groups

  summary << {
    app: app,
    patch_count: diff_paths.size,
    group_count: groups.size
  }
end

representatives = groups_by_app.values.flatten(1).map(&:first)

groups_json = groups_by_app.merge("representatives" => representatives)

File.write(File.join(OUT_DIR, "groups.json"), JSON.pretty_generate(groups_json) + "\n")
File.write(File.join(OUT_DIR, "mapping.json"), JSON.pretty_generate(mapping) + "\n")

puts "Tier 2 expansion blind judging build:"
summary.each do |row|
  puts "  #{row[:app]}: #{row[:patch_count]} patches, #{row[:group_count]} unique byte-content groups"
end
puts "  total representatives: #{representatives.size}"
puts "  patches dir: #{PATCHES_DIR}"
puts "  groups.json: #{File.join(OUT_DIR, 'groups.json')}"
puts "  mapping.json: #{File.join(OUT_DIR, 'mapping.json')} (sealed — do not read until scoring is committed)"
