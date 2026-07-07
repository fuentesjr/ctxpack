# frozen_string_literal: true

# Build a Tier 2 route table for an expansion app from `bin/rails routes
# --expanded` output, in the same `pairs` schema the anchor draw and Tier 0
# classifier consume (see eval/tier2/routes/redmine.json).
#
# Why not eval/tier0/extract_routes.rb? That no-boot stub fetches the app's
# actionpack version from rubygems. Campfire (and any rails-edge app) pins an
# unpublished actionpack revision via git, which rubygems cannot serve. These
# apps boot cleanly for the pilot anyway, so `bin/rails routes` is the
# highest-fidelity, reproducible source. Determinism of the *draw* comes from
# the seeded sort in draw_anchors.rb, not from the extraction method.
#
# Framework/engine-internal controllers are excluded (matching Redmine's
# engine-excluded table): ctxpack resolves only app controllers, so these
# never draw anyway; excluding them keeps the denominator app-focused.
#
# Usage:
#   RAILS_ENV=test bin/rails routes --expanded | \
#     ruby eval/tier2-expansion/build_routes_from_rails.rb <app_name> <out.json>

require "json"

app_name = ARGV.fetch(0)
out_path = ARGV.fetch(1)

EXCLUDED_NAMESPACES = %w[
  active_storage action_cable action_mailbox rails turbo propshaft
].freeze

PAIR_GRAMMAR = %r{\A[a-z0-9_]+(/[a-z0-9_]+)*#[a-z0-9_?!]+\z}

pairs = Hash.new(0)
excluded = Hash.new(0)

STDIN.each_line do |line|
  next unless line.start_with?("Controller#Action |")

  value = line.split("|", 2).last.strip
  # Strip trailing route defaults, e.g. `users/profiles#show {user_id: "me"}`.
  value = value.sub(/\s+\{.*\}\z/, "")
  next unless value.match?(PAIR_GRAMMAR)

  namespace = value.split("/", 2).first
  if EXCLUDED_NAMESPACES.include?(namespace)
    excluded[value] += 1
    next
  end

  pairs[value] += 1
end

File.write(out_path, JSON.pretty_generate(
  app: app_name,
  method: "bin/rails routes --expanded (rails-edge app; extract_routes.rb stub cannot fetch unpublished actionpack)",
  route_count: pairs.values.sum,
  unique_pairs: pairs.size,
  excluded_framework_pairs: excluded.keys.sort,
  pairs: pairs.keys.sort.to_h { |pair| [pair, pairs[pair]] }
) + "\n")

warn "#{app_name}: #{pairs.size} unique app pairs " \
     "(#{pairs.values.sum} routes), excluded #{excluded.size} framework pairs"
