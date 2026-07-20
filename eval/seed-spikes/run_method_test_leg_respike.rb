# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "prism"
require "ctxpack/compiler"
require "ctxpack/default_constant_resolver"
require_relative "../lib/spike_harness"

module MethodTestLegRespike
  APPS = {
    "redmine" => {
      path: "tmp/tier2/template",
      sha: "3386d9595767b3d0c455ace9281e056e9f61bd56",
      framework: "minitest"
    },
    "campfire" => {
      path: "tmp/tier2-expansion/campfire/template",
      sha: "71ffeeea789599a334311f28bcb6816863985488",
      framework: "minitest"
    },
    "lobsters" => {
      path: "tmp/tier2-expansion/lobsters/template",
      sha: "430d864b0d7bf1b30913ee42e6cca3d9fbddcaa4",
      framework: "rspec"
    }
  }.freeze

  PRECISION_GATE = 0.70
  PER_APP_PRECISION_GATE = 0.60
  COVERAGE_GATE = 0.05
  CANDIDATE_YIELD_GATE = 25
  SAMPLE_CAP = 50

  module_function

  def evaluate_app(name, path:, sha:, framework:)
    verify_checkout!(name, path: path, sha: sha)
    resolver = Ctxpack::DefaultConstantResolver.new(app_root: path)
    taxonomy = SpikeHarness::Taxonomy.new(sample_cap: SAMPLE_CAP)
    pairs = extract_pairs(path)
    resolved = 0
    covered_pairs = 0
    candidate_pairs = 0
    strict_relevant = 0
    candidate_count_by_rule = Hash.new(0)
    candidate_path_counts = Hash.new(0)
    source_cache = {}

    pairs.each do |(constant_name, method_name), defining_path|
      resolution = resolver.resolve_exact(constant_name)
      unless exact_method?(path, resolution&.path, constant_name, method_name)
        taxonomy.record("resolution_failed", pair_sample(constant_name, method_name, defining_path))
        next
      end

      resolved += 1
      candidates = candidate_records(
        app_root: path,
        production_path: resolution.path,
        framework: framework,
        limit: Ctxpack::Compiler::LIMITS.fetch(:max_test_files)
      )
      if candidates.empty?
        taxonomy.record("resolved_no_mirror", pair_sample(constant_name, method_name, resolution.path))
        next
      end

      covered_pairs += 1
      candidates.each do |candidate|
        candidate_pairs += 1
        candidate_count_by_rule[candidate.fetch(:rule)] += 1
        candidate_path_counts[candidate.fetch(:path)] += 1
        source = source_cache[candidate.fetch(:path)] ||= File.read(
          File.join(path, candidate.fetch(:path)),
          encoding: "UTF-8"
        )
        classification = classify_candidate(
          source: source,
          constant_name: constant_name,
          method_name: method_name
        )
        strict_relevant += 1 if classification.fetch(:strict)
        taxonomy.record(
          classification.fetch(:label),
          pair_sample(constant_name, method_name, candidate.fetch(:path)).merge("rule" => candidate.fetch(:rule))
        )
      rescue StandardError => e
        taxonomy.record(
          "crash",
          pair_sample(constant_name, method_name, candidate.fetch(:path)).merge("error" => e.message)
        )
      end
    end

    relevant = taxonomy.counts.fetch("mirror_relevant", 0)
    {
      "app" => name,
      "sha" => sha,
      "framework" => framework,
      "population" => pairs.length,
      "resolved" => resolved,
      "resolution_rate" => rate(resolved, pairs.length),
      "covered_pairs" => covered_pairs,
      "candidate_pairs" => candidate_pairs,
      "precision" => rate(relevant, candidate_pairs),
      "strict_precision" => rate(strict_relevant, candidate_pairs),
      "coverage" => rate(covered_pairs, resolved),
      "duplicate_candidate_path_pairs" => candidate_path_counts.values.sum { |count| [count - 1, 0].max },
      "candidate_count_by_rule" => candidate_count_by_rule,
      "source_parse_failures" => taxonomy.counts.fetch("candidate_parse_failure", 0),
      "by_label" => taxonomy.counts,
      "label_samples" => taxonomy.samples
    }
  end

  def classify_candidate(source:, constant_name:, method_name:)
    result = Prism.parse(source)
    return { label: "candidate_parse_failure", strict: false } unless result.success?

    full_constant = exact_constant_token?(source, constant_name)
    demodulized_constant = exact_constant_token?(source, constant_name.split("::").last)
    constant_evidence = full_constant || demodulized_constant
    method_call = ast_contains?(result.value) do |node|
      node.is_a?(Prism::CallNode) && node.name.to_s == method_name
    end
    method_literal = ast_contains?(result.value) do |node|
      case node
      when Prism::SymbolNode, Prism::StringNode
        node.unescaped == method_name
      else
        false
      end
    end
    method_evidence = method_call || method_literal
    label =
      if constant_evidence && method_evidence
        "mirror_relevant"
      elsif constant_evidence
        "mirror_constant_only"
      elsif method_evidence
        "mirror_method_only"
      else
        "mirror_neither"
      end

    { label: label, strict: full_constant && method_call }
  end

  def verdict(app_metrics)
    precisions = app_metrics.map { |app| app["precision"] }
    coverages = app_metrics.map { |app| app["coverage"] }
    candidate_yields = app_metrics.map { |app| app["candidate_pairs"] }
    mean_precision = SpikeHarness.average(precisions)
    precision_floor = precisions.any?(&:nil?) ? nil : precisions.min
    mean_coverage = SpikeHarness.average(coverages)
    yield_floor = candidate_yields.min
    gates = {
      "mean_precision" => gate(mean_precision, PRECISION_GATE),
      "per_app_precision" => gate(precision_floor, PER_APP_PRECISION_GATE),
      "mean_coverage" => gate(mean_coverage, COVERAGE_GATE),
      "per_app_candidate_yield" => gate(yield_floor, CANDIDATE_YIELD_GATE)
    }
    precision_pass = gates.fetch("mean_precision").fetch(:pass) && gates.fetch("per_app_precision").fetch(:pass)
    coverage_pass = gates.fetch("mean_coverage").fetch(:pass) && gates.fetch("per_app_candidate_yield").fetch(:pass)
    outcome = if !precision_pass
                "DROP"
              elsif !coverage_pass
                "DEFER"
              else
                "PROCEED"
              end

    { "outcome" => outcome, "gates" => gates }
  end

  def run(out_dir, apps: APPS, stdout: $stdout)
    summaries = apps.map do |name, config|
      payload = evaluate_app(name, **config)
      stdout.puts(
        "#{name}: population=#{payload.fetch('population')} resolved=#{payload.fetch('resolved')} " \
        "candidates=#{payload.fetch('candidate_pairs')} precision=#{payload.fetch('precision')&.round(4)} " \
        "coverage=#{payload.fetch('coverage')&.round(4)}"
      )
      [name, SpikeHarness.write_app_payload(out_dir, name, payload)]
    end.to_h

    decision = verdict(summaries.values)
    summary = SpikeHarness.write_summary(out_dir, summaries, decision.fetch("gates"))
    summary["outcome"] = decision.fetch("outcome")
    File.write(File.join(out_dir, "summary.json"), JSON.pretty_generate(summary))
    stdout.puts("outcome=#{summary.fetch('outcome')}")
    summary
  end

  def candidate_records(app_root:, production_path:, framework:, limit:)
    match = production_path.match(%r{\Aapp/([^/]+)/(.+)\.rb\z})
    return [] unless match

    family = match[1]
    relative = match[2]
    candidates =
      if framework == "rspec"
        [{ path: "spec/#{family}/#{relative}_spec.rb", rule: "rspec_mirror" }]
      else
        records = [{ path: "test/#{family}/#{relative}_test.rb", rule: "minitest_mirror" }]
        records << { path: "test/unit/#{relative}_test.rb", rule: "minitest_legacy_unit" } if family == "models"
        records
      end
    candidates.select { |candidate| File.file?(File.join(app_root, candidate.fetch(:path))) }.first(limit)
  end
  private_class_method :candidate_records

  def extract_pairs(app_root)
    pairs = {}
    Dir.glob(File.join(app_root, "app/**/*.rb")).sort.each do |absolute_path|
      relative_path = Pathname(absolute_path).relative_path_from(Pathname(app_root)).to_s
      next if relative_path.start_with?("app/controllers/", "app/views/")
      next if SpikeHarness.excluded_path?(relative_path)

      parse_defs(absolute_path).each do |constant_name, method_name, _node|
        pairs[[constant_name, method_name]] ||= relative_path
      end
    end
    pairs
  end
  private_class_method :extract_pairs

  def exact_method?(app_root, relative_path, constant_name, method_name)
    return false unless relative_path

    parse_defs(File.join(app_root, relative_path)).any? do |found_constant, found_method, _node|
      found_constant == constant_name && found_method == method_name
    end
  rescue StandardError
    false
  end
  private_class_method :exact_method?

  def parse_defs(path)
    @definition_cache ||= {}
    @definition_cache[path] ||= begin
      definitions = []
      collect_defs(Prism.parse_file(path).value, [], definitions)
      definitions
    end
  rescue StandardError => e
    raise "#{path}: #{e.class}: #{e.message}"
  end
  private_class_method :parse_defs

  def collect_defs(node, namespace, definitions)
    return if node.nil?

    case node
    when Prism::ClassNode, Prism::ModuleNode
      parts, rooted = constant_parts(node.constant_path)
      collect_defs(node.body, rooted ? parts : namespace + parts, definitions)
    when Prism::SingletonClassNode
      nil
    when Prism::DefNode
      definitions << [namespace.join("::"), node.name.to_s, node] if node.receiver.nil? && !namespace.empty?
    else
      node.compact_child_nodes.each { |child| collect_defs(child, namespace, definitions) }
    end
  end
  private_class_method :collect_defs

  def constant_parts(node)
    case node
    when Prism::ConstantReadNode
      [[node.name.to_s], false]
    when Prism::ConstantPathNode
      return [[node.name.to_s], true] if node.parent.nil?

      parent_parts, rooted = constant_parts(node.parent)
      [parent_parts + [node.name.to_s], rooted]
    else
      [[], false]
    end
  end
  private_class_method :constant_parts

  def ast_contains?(node, &predicate)
    return true if predicate.call(node)

    node.compact_child_nodes.any? { |child| ast_contains?(child, &predicate) }
  end
  private_class_method :ast_contains?

  def exact_constant_token?(source, token)
    source.match?(/(?<![A-Za-z0-9_:])#{Regexp.escape(token)}(?![A-Za-z0-9_:])/)
  end
  private_class_method :exact_constant_token?

  def verify_checkout!(name, path:, sha:)
    SpikeHarness.verify_pinned_checkouts!(name => { path: path, sha: sha })
    stdout, stderr, status = Open3.capture3(
      "git", "-C", path, "diff", "--name-only", "HEAD", "--", "app", "test", "spec"
    )
    raise "#{name}: source-tree verification failed: #{stderr.strip}" unless status.success?
    raise "#{name}: source trees differ from pinned commit: #{stdout.lines(chomp: true).join(', ')}" unless stdout.empty?
  end
  private_class_method :verify_checkout!

  def pair_sample(constant_name, method_name, path)
    { "constant" => constant_name, "method" => method_name, "path" => path }
  end
  private_class_method :pair_sample

  def rate(numerator, denominator)
    return nil if denominator.zero?

    numerator.to_f / denominator
  end
  private_class_method :rate

  def gate(value, threshold)
    { value: value, threshold: threshold, pass: !value.nil? && value >= threshold }
  end
  private_class_method :gate
end

if $PROGRAM_NAME == __FILE__
  output_dir = ARGV.shift
  abort "usage: #{File.basename($PROGRAM_NAME)} OUTPUT_DIR" unless output_dir && ARGV.empty?

  MethodTestLegRespike.run(output_dir)
end
