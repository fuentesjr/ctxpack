# Tier 0 spike: extract an app's route table WITHOUT booting the app.
#
# Method (documented fallback per eval-plan.md "Tier 0"): load the app's own
# pinned actionpack version via bundler/inline, then eval config/routes.rb
# against a real ActionDispatch::Routing::RouteSet with a fake `Rails` module
# and a permissive const_missing stub standing in for app constants,
# constraints, and mounted engines. Real Rails code expands resources/
# namespace/scope/concerns/member/collection, so the controller#action
# denominator is high-fidelity.
#
# Known limitations (report alongside results):
# - Mounted engines are stubbed rack apps: their internal routes never enter
#   the table. Mount calls are recorded separately. Raw rate therefore equals
#   the engine-excluded rate by construction.
# - Env-conditional routes are drawn as production (env.production? == true).
# - Anything the fake Rails can't satisfy raises; failures are loud, not
#   silently dropped.
#
# Usage: GEM_HOME=<isolated> ruby extract_routes.rb <app_root> <actionpack_version> <out.json>

require "json"
require "pathname"

app_root = Pathname.new(File.expand_path(ARGV.fetch(0)))
actionpack_version = ARGV.fetch(1)
out_path = ARGV.fetch(2)

require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "actionpack", actionpack_version
end

require "active_support"
require "active_support/core_ext" # a booted Rails would have all of these
require "action_dispatch"
require "action_dispatch/routing/route_set"

# --- permissive stub world -------------------------------------------------

# Instances stand in for constraint objects, config values, etc. Classes are
# supplied by Module#const_missing below. `call` makes a stub mountable as a
# rack app; `matches?` makes it usable as a routing constraint.
class SpikeStub
  # Route names (`as:`) must be unique, so every stringification is fresh.
  @counter = 0
  def self.next_name = "spike_stub_#{@counter += 1}"

  def self.const_missing(_name) = SpikeStub
  def self.method_missing(*, **, &) = SpikeStub.new
  def self.respond_to_missing?(*) = true
  def self.to_s = next_name
  def self.to_str = next_name
  def self.to_ary = [next_name]
  def self.to_a = [next_name]

  def initialize(*, **, &) = nil
  def method_missing(*, **, &) = self
  def respond_to_missing?(*) = true

  # Apps don't all draw via `Rails.application` (e.g. Discourse uses
  # `Discourse::Application.routes.draw`); route any stubbed `.routes.draw`
  # to the real route set.
  def draw(&block) = ROUTE_SET.draw(&block)
  def self.draw(&block) = ROUTE_SET.draw(&block)
  def matches?(*) = true
  def call(*) = [404, {}, []]
  def to_s = SpikeStub.next_name
  def to_str = to_s

  # Zammad-style `match api_path + '/tickets', to: ...` must yield a real
  # String: Mapper#map_match groups paths by exact class and silently drops
  # anything that is neither String nor Symbol.
  def +(other) = other.is_a?(String) ? to_s + other : self
  def to_ary = [to_s]
  def to_a = [to_s]
  def to_proc = proc { true }
end

class Module
  def const_missing(_name)
    SpikeStub
  end
end

# Missing gem requires inside routes files (e.g. `require "sidekiq/web"`)
# should not abort extraction.
module Kernel
  alias_method :__spike_orig_require, :require
  def require(name)
    __spike_orig_require(name)
  rescue LoadError
    warn "spike: stubbed missing require #{name.inspect}"
    true
  end
end

class SpikeEnv < String
  def production? = true
  def development? = false
  def test? = false
  def local? = false
end

ROUTE_SET = ActionDispatch::Routing::RouteSet.new
if ROUTE_SET.respond_to?(:draw_paths)
  ROUTE_SET.draw_paths = [app_root.join("config/routes")]
end
# Apps may call .draw more than once; without this each draw clears the last.
ROUTE_SET.disable_clear_and_finalize = true

module Rails
  class SpikeApplication
    def routes = ROUTE_SET
    def method_missing(*, **, &) = SpikeStub.new
    def respond_to_missing?(*) = true
  end

  def self.root = @root

  def self.root=(value)
    @root = value
  end
  def self.env = SpikeEnv.new("production")
  def self.application = @application ||= SpikeApplication.new
  def self.method_missing(*, **, &) = SpikeStub.new
  def self.respond_to_missing?(*) = true
end

Rails.root = app_root

# Stub-derived route names (e.g. from mounted stub engines) can collide;
# uniquify instead of raising so no real route is lost. Real apps cannot have
# genuine duplicates — a real boot would raise on them too.
class ActionDispatch::Routing::RouteSet
  alias_method :__spike_add_route, :add_route
  def add_route(mapping, name)
    if name && !name.to_s.match?(/\A[_a-z]\w*\z/i)
      name = SpikeStub.next_name # stub-path-derived names; helpers are unused here
    end
    if name && named_routes[name.to_sym]
      name = :"#{name}_#{SpikeStub.next_name}"
    end
    __spike_add_route(mapping, name)
  end
end

# Gem routing DSLs (Devise, Doorkeeper, ...) aren't loaded, so shim them on
# the Mapper. Block-taking wrappers pass through so the routes inside them are
# still drawn (the auth constraint itself is irrelevant at draw time).
# Route-GENERATING gem calls can't be expanded without the gem; they are
# recorded and reported as an extraction limitation.
GEM_DSL_CALLS = []

class ActionDispatch::Routing::Mapper
  def authenticate(*, **)
    yield if block_given?
  end

  def authenticated(*, **)
    yield if block_given?
  end

  def unauthenticated(*, **)
    yield if block_given?
  end

  def devise_scope(*, **)
    yield if block_given?
  end

  def devise_for(*resources, **)
    GEM_DSL_CALLS << "devise_for #{resources.map(&:to_s).join(", ")}"
  end

  def use_doorkeeper(*, **, &)
    GEM_DSL_CALLS << "use_doorkeeper"
  end
end

# --- draw ------------------------------------------------------------------

routes_rb = app_root.join("config/routes.rb")
eval(File.read(routes_rb), TOPLEVEL_BINDING, routes_rb.to_s) # rubocop:disable Security/Eval
ROUTE_SET.finalize!

# --- harvest ---------------------------------------------------------------

pairs = Hash.new(0)
mounts = []
skipped = Hash.new(0)

ROUTE_SET.routes.each do |route|
  controller = route.defaults[:controller]
  action = route.defaults[:action]
  inner = route.app
  inner = inner.app if inner.is_a?(ActionDispatch::Routing::Mapper::Constraints)

  if controller && action
    if controller.to_s.include?(":") || action.to_s.include?(":")
      skipped[:dynamic_segment] += 1
    else
      pairs["#{controller}##{action}"] += 1
    end
  elsif inner.is_a?(ActionDispatch::Routing::Redirect)
    skipped[:redirect] += 1
  else
    # Mounted rack apps (stubbed engines) arrive as dispatchers without
    # controller defaults; anything else is recorded for manual review.
    mounts << route.path.spec.to_s
  end
end

File.write(out_path, JSON.pretty_generate(
  app: app_root.basename.to_s,
  actionpack_version: ActionPack::VERSION::STRING,
  route_count: ROUTE_SET.routes.size,
  pairs: pairs.keys.sort.to_h { |pair| [pair, pairs[pair]] },
  mounts: mounts.sort,
  gem_dsl_calls: GEM_DSL_CALLS,
  skipped: skipped
))

warn "spike: #{pairs.size} unique pairs, #{mounts.size} mounts, skipped #{skipped.values.sum} (#{app_root.basename})"
