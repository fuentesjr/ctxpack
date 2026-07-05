# Tier 0 spike: attempt v0 anchor resolution for every controller#action pair
# and classify failures per the pre-registered taxonomy in eval-plan.md:
#
#   file_not_found      conventional controller path does not exist
#   inherited_action    action defined in a superclass
#   concern_action      action defined in an included concern
#   engine_route        route belongs to a mounted engine (never appears here:
#                       extraction stubs engines, so their routes are absent;
#                       mounts are reported separately by extract_routes.rb)
#   other               metaprogramming, unconventional layout, etc.
#
# Success = Ctxpack.compile returns a packet. A crash AFTER anchor resolution
# (neither ANCH-6 nor ANCH-7 message) counts as resolved for the anchor rate
# but is recorded under compile_crash — free stress-test signal, kept out of
# the viability measurement.
#
# The inherited/concern chase is a spike heuristic, deliberately more lenient
# than ctxpack itself: superclass constants and include'd concern names are
# mapped to files by Zeitwerk-style underscoring with a lexical namespace
# walk, and a `def <action>` anywhere in the candidate file counts. Custom
# inflections (e.g. Mastodon's ActivityPub) or non-literal definitions fall
# through to `other`, with detail recorded for manual review.
#
# Usage: ruby classify_anchors.rb <app_root> <routes.json> <out.json>

require "json"
require "prism"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "ctxpack"

APP_ROOT = File.expand_path(ARGV.fetch(0))
routes = JSON.parse(File.read(ARGV.fetch(1)))
out_path = ARGV.fetch(2)

CHASE_DEPTH_LIMIT = 5

def underscore(name)
  name.gsub("::", "/")
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
end

def camelize(value)
  value.split("_").map { |part| part[0].upcase + part[1..] }.join
end

def expected_class_name(controller_path)
  segments = controller_path.split("/")
  (segments[0...-1].map { |s| camelize(s) } << "#{camelize(segments.last)}Controller").join("::")
end

# All class/module definitions in a parsed file, with qualified-ish names,
# superclass constant text, include'd constant texts, and direct def names.
def scan_ruby(node, namespace = [], found = [])
  case node
  when Prism::ClassNode, Prism::ModuleNode
    name = [*namespace, node.constant_path.slice].join("::")
    info = { name: name, superclass: nil, includes: [], defs: [] }
    info[:superclass] = node.superclass&.slice if node.is_a?(Prism::ClassNode)
    collect_body(node.child_nodes, info)
    found << info
    node.child_nodes.compact.each { |child| scan_ruby(child, [*namespace, node.constant_path.slice], found) }
  else
    node&.child_nodes&.compact&.each { |child| scan_ruby(child, namespace, found) }
  end
  found
end

def collect_body(nodes, info)
  nodes.compact.each do |child|
    case child
    when Prism::DefNode
      info[:defs] << child.name.to_s
    when Prism::CallNode
      if child.name == :include && child.receiver.nil?
        child.arguments&.arguments&.each do |arg|
          info[:includes] << arg.slice if arg.is_a?(Prism::ConstantReadNode) || arg.is_a?(Prism::ConstantPathNode)
        end
      end
    when Prism::StatementsNode, Prism::BeginNode
      collect_body(child.child_nodes, info)
    end
  end
end

def parse_file(path)
  @parse_cache ||= {}
  @parse_cache[path] ||= begin
    result = Prism.parse(File.read(path))
    result.failure? ? [] : scan_ruby(result.value)
  end
end

# Lexical candidates for a constant referenced from inside `from_namespace`,
# e.g. BaseController inside Api::V1 tries Api::V1::BaseController,
# Api::BaseController, BaseController.
def lexical_candidates(const_name, from_namespace)
  return [const_name.delete_prefix("::")] if const_name.start_with?("::")

  parts = from_namespace.split("::")[0...-1]
  candidates = []
  parts.length.downto(0) { |i| candidates << [*parts[0...i], const_name].join("::") }
  candidates
end

# Find the file conventionally hosting a constant, searching app/controllers
# then app/controllers/concerns then the other autoload roots ctxpack uses.
SEARCH_DIRS = ["app/controllers", "app/controllers/concerns", "app/models", "app/models/concerns"].freeze

def const_file(const_name)
  SEARCH_DIRS.each do |dir|
    path = File.join(APP_ROOT, dir, "#{underscore(const_name)}.rb")
    return path if File.file?(path)
  end
  nil
end

# Walks superclasses and includes looking for `def action`. Returns
# [classification, detail] or nil when the chase exhausts.
def chase(class_name, file, action, depth = 0, via = :inherited)
  return nil if depth > CHASE_DEPTH_LIMIT || file.nil?

  infos = parse_file(file)
  info = infos.find { |i| i[:name] == class_name || i[:name].end_with?("::#{class_name}") || class_name.end_with?("::#{i[:name]}") }
  return nil unless info

  if depth.positive? && info[:defs].include?(action)
    kind = via == :concern ? "concern_action" : "inherited_action"
    return [kind, "def #{action} found in #{file.delete_prefix(APP_ROOT + "/")} (#{class_name})"]
  end

  info[:includes].each do |inc|
    lexical_candidates(inc, info[:name]).each do |candidate|
      inc_file = const_file(candidate)
      next unless inc_file

      hit = chase(candidate, inc_file, action, depth + 1, :concern)
      return hit if hit
      break
    end
  end

  if info[:superclass] && !info[:superclass].include?("ActionController")
    lexical_candidates(info[:superclass], info[:name]).each do |candidate|
      super_file = const_file(candidate)
      next unless super_file

      hit = chase(candidate, super_file, action, depth + 1, via)
      return hit if hit
      break
    end
  end

  nil
end

def classify_missing_def(controller_path, action, record)
  file = File.join(APP_ROOT, "app", "controllers", "#{controller_path}_controller.rb")
  expected = expected_class_name(controller_path)
  infos = parse_file(file)
  target = infos.find { |i| i[:name] == expected }

  unless target
    record["detail"] = "controller file exists but expected class #{expected} not found " \
                       "(custom inflection, metaprogrammed class, or unconventional nesting)"
    return "other"
  end

  hit = chase(expected, file, action)
  if hit
    record["detail"] = hit[1]
    hit[0]
  else
    record["detail"] = "no def #{action} found via superclass/concern chase (depth #{CHASE_DEPTH_LIMIT}); " \
                       "likely metaprogrammed or defined outside app/controllers conventions"
    "other"
  end
end

results = []
routes.fetch("pairs").each_key do |anchor|
  controller_path, action = anchor.split("#", 2)
  record = { "anchor" => anchor }
  begin
    Ctxpack.compile(app_root: APP_ROOT, anchor: anchor)
    record["result"] = "resolved"
  rescue Ctxpack::Error => e
    record["error"] = e.message
    record["result"] =
      case e.message
      when /\Aexpected controller file does not exist/
        "file_not_found"
      when /\Ainvalid anchor/
        record["detail"] = "anchor failed ctxpack's snake_case grammar"
        "other"
      when /\Ano controller class matching/
        record["detail"] = "controller file exists but no class matches the anchor path " \
                           "underscore-insensitively (metaprogrammed class or unconventional nesting)"
        "other"
      when /was not directly defined/
        classify_missing_def(controller_path, action, record)
      else
        record["detail"] = "unrecognized ctxpack error"
        "other"
      end
  rescue => e
    record["result"] = "resolved"
    record["compile_crash"] = "#{e.class}: #{e.message}"
  end
  results << record
end

summary = results.group_by { |r| r["result"] }.transform_values(&:count)
crashes = results.count { |r| r["compile_crash"] }
total = results.size
resolved = summary.fetch("resolved", 0)

File.write(out_path, JSON.pretty_generate(
  app: routes.fetch("app"),
  total_pairs: total,
  summary: summary,
  resolution_rate: (resolved.to_f / total).round(4),
  compile_crashes: crashes,
  results: results
))

warn "#{routes.fetch("app")}: #{resolved}/#{total} resolved (#{(100.0 * resolved / total).round(1)}%) " \
     "#{summary.reject { |k, _| k == "resolved" }.inspect} crashes=#{crashes}"
