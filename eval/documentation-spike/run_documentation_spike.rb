# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "securerandom"
require "tmpdir"
require_relative "../lib/spike_harness"
require_relative "../tier2/apps/config"

module DocumentationSpike
  RevisionMismatch = Class.new(StandardError)
  LabelError = Class.new(StandardError)
  UncommittedRunner = Class.new(StandardError)
  CONVENTIONAL_BASENAMES = %w[README ARCHITECTURE DESIGN DEVELOPMENT CONTRIBUTING].freeze
  ANCESTOR_BASENAMES = %w[README ARCHITECTURE DESIGN DEVELOPMENT].freeze
  DOCUMENT_EXTENSIONS = %w[.md .markdown .mdown .rdoc .rst .adoc .txt].freeze
  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdown].freeze
  GOVERNING_BASENAMES = %w[agents.md claude.md codex.md gemini.md].freeze
  EXCLUDED_SEGMENTS = %w[.git vendor node_modules tmp log coverage _site site].freeze
  LABELS = %w[
    relevant_unique relevant_redundant repository_background unrelated
    stale_or_conflicting governing_instruction
  ].freeze
  RECIPE_NAMES = %w[
    forward_exact_reference reverse_exact_link mirrored_path ancestor_conventional
  ].freeze
  MEASUREMENT_RESTARTS = [
    {
      "failed_runner_commit" => "cea6534bccc9ef4b39742fab98899bd7f5de4a3c",
      "environment" => {"locale" => "C", "timezone" => "UTC"},
      "failure" => "forward-reference tokenizer passed an empty punctuation token to File.extname",
      "artifact_disposition" => "no candidate artifact was written; restart all three replays from zero"
    },
    {
      "failed_runner_commit" => "76b42957b1179eda6bb4cadf98c0119dbe6212d4",
      "environment" => {"locale" => "C", "timezone" => "UTC"},
      "failure" => "Git stdout inherited US-ASCII and rejected valid UTF-8 source bytes",
      "artifact_disposition" => "no candidate artifact was written; restart all three replays from zero"
    }
  ].freeze
  StudyTask = Data.define(
    :app,
    :id,
    :repo_root,
    :revision,
    :focus_paths,
    :rotated_focus_paths,
    :prompt_path,
    :focus_artifact_path,
    :reference_diff_path
  )
  StudyRun = Data.define(:bundle, :timings)

  module_function

  def retrieve(repo_root:, revision:, focus_paths:)
    repository = Repository.new(repo_root, revision)
    omissions = repository.document_omissions
    recipe_candidates = {
      "forward_exact_reference" => forward_reference_candidates(repository, focus_paths, omissions),
      "reverse_exact_link" => reverse_link_candidates(repository, focus_paths),
      "mirrored_path" => mirrored_path_candidates(repository, focus_paths),
      "ancestor_conventional" => ancestor_candidates(repository, focus_paths)
    }
    recipe_candidates.transform_values! { |items| unique_candidates(items) }
    candidates = bounded_candidates(recipe_candidates.values.flatten)

    {
      "revision" => revision,
      "focus_paths" => focus_paths.dup,
      "candidates" => candidates,
      "recipe_candidates" => recipe_candidates,
      "omissions" => omissions,
      "governing_instruction_count" => repository.paths.count do |path|
        governing_instruction_path?(path)
      end
    }
  end

  def inventory(repo_root:, revision:)
    repository = Repository.new(repo_root, revision)
    omissions = repository.document_omissions
    documentary_paths = repository.paths.count { |path| eligible_documentary_path?(path) }
    {
      "revision" => revision,
      "documentary_paths" => documentary_paths,
      "readable_documents" => documentary_paths - omissions.length,
      "governing_instruction_count" => repository.paths.count do |path|
        governing_instruction_path?(path)
      end,
      "omissions" => omissions
    }
  end

  def bounded_candidates(candidates)
    selected = unique_candidates(candidates).first(3)
    remaining_bytes = 2_048
    selected.filter_map do |candidate|
      bounded = bound_candidate(candidate, remaining_bytes)
      next unless bounded

      remaining_bytes -= bounded.fetch("excerpt").bytesize
      bounded
    end
  end
  private_class_method :bounded_candidates

  def unique_candidates(candidates)
    candidates.uniq do |candidate|
      candidate.values_at("document_path", "start_line", "end_line")
    end
  end
  private_class_method :unique_candidates

  def canonical_json(value)
    JSON.generate(canonical_value(value)) << "\n"
  end

  def canonical_value(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, canonical_value(value.fetch(key))] }
    when Array
      value.map { |item| canonical_value(item) }
    else
      value
    end
  end
  private_class_method :canonical_value

  def forward_reference_candidates(repository, focus_paths, omissions)
    focus_paths.flat_map do |focus_path|
      next [] unless File.extname(focus_path).downcase == ".rb"

      content = repository.read(focus_path)
      content.lines.flat_map do |line|
        next [] unless line.match?(/\A\s*#/)

        comment_document_tokens(line).filter_map do |token|
          path, fragment = token.split("#", 2)
          document_path = resolve_document_reference(repository, focus_path, path)
          unless document_path
            omissions << {
              "reason" => "broken_reference",
              "focus_path" => focus_path,
              "reference" => token
            }
            next
          end
          next unless repository.readable_document?(document_path)

          document = repository.read(document_path)
          excerpt, start_line, end_line = if fragment && markdown_path?(document_path)
                                            section_by_fragment(document, fragment)
                                          else
                                            intro, finish = introduction(document, document_path)
                                            [intro, 1, finish]
                                          end
          unless excerpt
            omissions << {
              "reason" => "broken_reference",
              "focus_path" => focus_path,
              "reference" => token
            }
            next
          end

          candidate(
            recipe: "forward_exact_reference",
            focus_paths: focus_paths,
            document_path: document_path,
            start_line: start_line,
            end_line: end_line,
            excerpt: excerpt,
            resolved_reference: token
          )
        end
      end.sort_by { |item| item.values_at("document_path", "start_line") }
    end
  end
  private_class_method :forward_reference_candidates

  def reverse_link_candidates(repository, focus_paths)
    targets = focus_targets(focus_paths)
    repository.paths.flat_map do |document_path|
      next [] unless eligible_documentary_path?(document_path)
      next [] unless markdown_path?(document_path)
      next [] unless repository.readable_document?(document_path)

      content = repository.read(document_path)
      match_lines = content.lines.each_index.select do |line_index|
        line = content.lines[line_index]
        inline_link_targets(line).any? do |target|
          resolved = resolve_relative_path(document_path, target)
          resolved && targets.include?(resolved)
        end
      end
      match_lines.map do |match_line|
        excerpt, start_line, end_line = containing_section(content, match_line)
        candidate(
          recipe: "reverse_exact_link",
          focus_paths: focus_paths,
          document_path: document_path,
          start_line: start_line,
          end_line: end_line,
          excerpt: excerpt,
          resolved_reference: document_path
        )
      end
    end
  end
  private_class_method :reverse_link_candidates

  def mirrored_path_candidates(repository, focus_paths)
    focus_paths.flat_map do |focus_path|
      stem = focus_path.delete_suffix(File.extname(focus_path))
      paths = DOCUMENT_EXTENSIONS.flat_map do |extension|
        ["doc/#{stem}#{extension}", "docs/#{stem}#{extension}", "#{stem}#{extension}"]
      end.sort
      paths.filter_map do |document_path|
        next unless repository.paths.include?(document_path)
        next unless eligible_documentary_path?(document_path)
        next unless repository.readable_document?(document_path)

        excerpt, end_line = introduction(repository.read(document_path), document_path)
        candidate(
          recipe: "mirrored_path",
          focus_paths: focus_paths,
          document_path: document_path,
          start_line: 1,
          end_line: end_line,
          excerpt: excerpt
        )
      end
    end
  end
  private_class_method :mirrored_path_candidates

  def ancestor_candidates(repository, focus_paths)
    paths = repository.paths
    focus_paths.flat_map do |focus_path|
      ancestor_directories(File.dirname(focus_path)).flat_map do |directory|
        conventional_paths_in(paths, directory).filter_map do |document_path|
          next unless eligible_documentary_path?(document_path)
          next unless repository.readable_document?(document_path)

          excerpt, end_line = introduction(repository.read(document_path), document_path)
          candidate(
            recipe: "ancestor_conventional",
            focus_paths: focus_paths,
            document_path: document_path,
            start_line: 1,
            end_line: end_line,
            excerpt: excerpt
          )
        end
      end
    end
  end
  private_class_method :ancestor_candidates

  def candidate(recipe:, focus_paths:, document_path:, start_line:, end_line:, excerpt:,
                resolved_reference: nil)
    bounded_excerpt = truncate_whole_lines(excerpt, 1_024)
    record = {
      "recipe" => recipe,
      "focus_paths" => focus_paths.dup,
      "document_path" => document_path,
      "start_line" => start_line,
      "end_line" => start_line + bounded_excerpt.lines.length - 1,
      "excerpt" => bounded_excerpt,
      "excerpt_sha256" => Digest::SHA256.hexdigest(bounded_excerpt),
      "truncated" => bounded_excerpt != excerpt
    }
    record["resolved_reference"] = resolved_reference if resolved_reference
    record
  end
  private_class_method :candidate

  def bound_candidate(candidate, max_bytes)
    excerpt = truncate_whole_lines(candidate.fetch("excerpt"), max_bytes)
    return if excerpt.empty?

    bounded = candidate.merge(
      "end_line" => candidate.fetch("start_line") + excerpt.lines.length - 1,
      "excerpt" => excerpt,
      "excerpt_sha256" => Digest::SHA256.hexdigest(excerpt),
      "truncated" => candidate.fetch("truncated") || excerpt != candidate.fetch("excerpt")
    )
    bounded
  end
  private_class_method :bound_candidate

  def truncate_whole_lines(content, max_bytes)
    bytes = 0
    content.lines.take_while do |line|
      fits = bytes + line.bytesize <= max_bytes
      bytes += line.bytesize if fits
      fits
    end.join
  end
  private_class_method :truncate_whole_lines

  def comment_document_tokens(line)
    line.scan(/[^\s"'`]+/).filter_map do |raw|
      token = raw.gsub(/\A[<(\[]+|[>,.;:)\]]+\z/, "")
      next if token.empty?

      path = token.split("#", 2).first
      token if documentary_path?(path) || conventional_document_path?(path)
    end
  end
  private_class_method :comment_document_tokens

  def conventional_document_path?(path)
    CONVENTIONAL_BASENAMES.include?(File.basename(path).upcase)
  end
  private_class_method :conventional_document_path?

  def resolve_document_reference(repository, focus_path, path)
    relative = clean_repo_path(File.join(File.dirname(focus_path), path))
    root_relative = clean_repo_path(path)
    [relative, root_relative].compact.find do |candidate_path|
      repository.paths.include?(candidate_path) && eligible_documentary_path?(candidate_path)
    end
  end
  private_class_method :resolve_document_reference

  def clean_repo_path(path)
    return if Pathname.new(path).absolute?

    clean = Pathname.new(path).cleanpath.to_s
    return if clean == ".." || clean.start_with?("../")

    clean
  end
  private_class_method :clean_repo_path

  def section_by_fragment(content, fragment)
    slug_counts = Hash.new(0)
    heading = content.lines.each_with_index.find do |line, index|
      match = line.match(/\A\#{1,6}\s+(.+?)\s*#*\s*\z/)
      next false unless match

      base = heading_slug(match[1])
      count = slug_counts[base]
      slug_counts[base] += 1
      slug = count.zero? ? base : "#{base}-#{count}"
      slug == fragment.downcase && index >= 0
    end
    return unless heading

    containing_section(content, heading[1])
  end
  private_class_method :section_by_fragment

  def heading_slug(heading)
    heading.downcase.encode("ASCII", invalid: :replace, undef: :replace, replace: "")
           .gsub(/[^a-z0-9\s-]/, "")
           .strip
           .gsub(/\s+/, "-")
  end
  private_class_method :heading_slug

  def focus_targets(focus_paths)
    focus_paths.flat_map do |focus_path|
      [focus_path] + ancestor_directories(File.dirname(focus_path)).reject { |path| path == "." }
    end.uniq
  end
  private_class_method :focus_targets

  def documentary_path?(path)
    DOCUMENT_EXTENSIONS.include?(File.extname(path).downcase)
  end
  private_class_method :documentary_path?

  def markdown_path?(path)
    MARKDOWN_EXTENSIONS.include?(File.extname(path).downcase)
  end
  private_class_method :markdown_path?

  def eligible_documentary_path?(path)
    return false unless documentary_path?(path) || conventional_document_path?(path)
    return false if governing_instruction_path?(path)
    return false if SpikeHarness.excluded_path?(path, excluded_parts: EXCLUDED_SEGMENTS)

    (path.split("/") & EXCLUDED_SEGMENTS).empty?
  end
  private_class_method :eligible_documentary_path?

  def governing_instruction_path?(path)
    downcase = path.downcase
    return true if GOVERNING_BASENAMES.include?(File.basename(downcase))
    return true if downcase == ".github/copilot-instructions.md" || downcase == ".cursorrules"

    downcase.start_with?(".github/instructions/")
  end
  private_class_method :governing_instruction_path?

  def inline_link_targets(line)
    line.scan(/(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)/).flatten
  end
  private_class_method :inline_link_targets

  def resolve_relative_path(document_path, target)
    return if target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+.-]*:/i)

    path = target.split("#", 2).first
    return if path.nil? || path.empty? || path.start_with?("/")

    resolved = Pathname.new(File.join(File.dirname(document_path), path)).cleanpath.to_s
    return if resolved == ".." || resolved.start_with?("../")

    resolved
  end
  private_class_method :resolve_relative_path

  def containing_section(content, line_index)
    lines = content.lines
    headings = lines.each_index.filter_map do |index|
      match = lines[index].match(/\A(\#{1,6})\s/)
      [index, match[1].length] if match
    end
    start_heading = headings.reverse.find { |index, _level| index <= line_index }
    start_index, level = start_heading || [0, 0]
    finish_heading = headings.find do |index, candidate_level|
      index > start_index && (level.zero? || candidate_level <= level)
    end
    finish_index = finish_heading ? finish_heading.first : lines.length
    [lines[start_index...finish_index].join, start_index + 1, finish_index]
  end
  private_class_method :containing_section

  def ancestor_directories(directory)
    directories = []
    current = directory
    loop do
      directories << current
      break if current == "."

      current = File.dirname(current)
    end
    directories
  end
  private_class_method :ancestor_directories

  def conventional_paths_in(paths, directory)
    paths.select do |path|
      next false unless File.dirname(path) == directory

      extension = File.extname(path)
      stem = File.basename(path, extension).upcase
      ANCESTOR_BASENAMES.include?(stem) &&
        (extension.empty? || DOCUMENT_EXTENSIONS.include?(extension.downcase))
    end.sort
  end
  private_class_method :conventional_paths_in

  def introduction(content, document_path)
    lines = content.lines
    return [content, lines.length] unless markdown_path?(document_path)

    boundary = lines.each_index.select { |index| lines[index].match?(/^\#{1,2}\s/) }[1]
    selected = boundary ? lines.first(boundary) : lines
    [selected.join, selected.length]
  end
  private_class_method :introduction

  class Repository
    def initialize(root, revision)
      @root = File.expand_path(root)
      @revision = revision
      SpikeHarness.verify_pinned_checkouts!("repository" => {path: @root, sha: @revision})
    rescue RuntimeError => error
      raise RevisionMismatch, error.message
    end

    def paths
      entries.keys
    end

    def read(path)
      git("show", "#{@revision}:#{path}")
    end

    def readable_document?(path)
      document_omissions unless defined?(@readable_documents)
      @readable_documents.include?(path)
    end

    def document_omissions
      return @document_omissions if defined?(@document_omissions)

      @readable_documents = []
      @document_omissions = entries.filter_map do |path, entry|
        next unless DocumentationSpike.send(:eligible_documentary_path?, path)

        reason = unavailable_reason(path, entry)
        if reason
          {"reason" => reason, "document_path" => path}
        else
          @readable_documents << path
          nil
        end
      end
      @document_omissions
    end

    private

    def entries
      @entries ||= git("ls-tree", "-r", "-l", "-z", @revision).split("\0").to_h do |record|
        metadata, path = record.split("\t", 2)
        mode, type, oid, size = metadata.split(/\s+/, 4)
        [path, {mode: mode, type: type, oid: oid, size: size == "-" ? nil : Integer(size)}]
      end
    end

    def unavailable_reason(path, entry)
      return "symlink_document" if entry.fetch(:mode) == "120000"
      return "submodule_document" if entry.fetch(:type) == "commit"
      return "oversized_document" if entry.fetch(:size) && entry.fetch(:size) > 256 * 1_024

      content = read(path)
      return "invalid_utf8" unless content.valid_encoding?
      return "binary_document" if content.include?("\0")
    end

    def git(*args)
      stdout, stderr, status = Open3.capture3("git", "-C", @root, *args)
      raise stderr unless status.success?

      stdout.force_encoding(Encoding::UTF_8)
    end
  end

  module Study
    APP_NAMES = %w[redmine campfire lobsters publify].freeze

    module_function

    def generate(tasks:, runner_commit:)
      records = []
      timings = []
      retrievals = []
      inventories = tasks.group_by { |task| [task.app, task.repo_root, task.revision] }.map do |(_key, app_tasks)|
        task = app_tasks.first
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = DocumentationSpike.inventory(repo_root: task.repo_root, revision: task.revision)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        timings << {
          "kind" => "inventory",
          "app" => task.app,
          "elapsed_ms" => (elapsed * 1_000).round(3)
        }
        result.merge("app" => task.app)
      end
      task_rows = tasks.map do |task|
        oracle_hashes = {
          "prompt_sha256" => Digest::SHA256.file(task.prompt_path).hexdigest,
          "focus_artifact_sha256" => Digest::SHA256.file(task.focus_artifact_path).hexdigest,
          "reference_diff_sha256" => Digest::SHA256.file(task.reference_diff_path).hexdigest
        }

        {"real" => task.focus_paths, "rotated" => task.rotated_focus_paths}.each do |arm, focus_paths|
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = DocumentationSpike.retrieve(
            repo_root: task.repo_root,
            revision: task.revision,
            focus_paths: focus_paths
          )
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          raise "#{task.app} task #{task.id}: primary focus changed" unless result.fetch("focus_paths") == focus_paths

          timings << {
            "kind" => "retrieval",
            "app" => task.app,
            "task" => task.id,
            "arm" => arm,
            "elapsed_ms" => (elapsed * 1_000).round(3)
          }
          retrievals << {
            "app" => task.app,
            "task" => task.id,
            "arm" => arm,
            "revision" => task.revision,
            "focus_paths" => focus_paths,
            "primary_preserved" => true,
            "governing_instruction_count" => result.fetch("governing_instruction_count"),
            "omissions" => result.fetch("omissions"),
            "selected_candidates" => result.fetch("candidates").length,
            "selected_excerpt_bytes" => result.fetch("candidates").sum do |candidate|
              candidate.fetch("excerpt").bytesize
            end
          }
          records.concat(candidate_records(task, arm, result, oracle_hashes))
        end

        {
          "app" => task.app,
          "task" => task.id,
          "revision" => task.revision,
          "oracle_hashes" => oracle_hashes
        }
      end

      records.sort_by! { |record| candidate_sort_key(record) }
      label_sheet = records.sort_by { |record| record.fetch("id") }.map do |record|
        record.slice(
          "id", "app", "task", "revision", "focus_paths", "document_path",
          "start_line", "end_line", "excerpt", "excerpt_sha256", "oracle_hashes"
        )
      end
      StudyRun.new(
        bundle: {
          "runner_commit" => runner_commit,
          "tasks" => task_rows,
          "inventories" => inventories,
          "retrievals" => retrievals,
          "candidates" => records,
          "label_sheet" => label_sheet
        },
        timings: timings
      )
    end

    def score(bundle:, labels:, timings:, replays:, synthetic_controls:)
      candidates = bundle.fetch("candidates")
      retrievals = bundle.fetch("retrievals")
      candidate_ids = candidates.map { |candidate| candidate.fetch("id") }.sort
      label_ids = labels.keys.sort
      unless candidate_ids == label_ids
        raise LabelError, "labels must match every candidate exactly"
      end
      labels.each do |id, label|
        valid = LABELS.include?(label["label"]) &&
                label["rationale"].is_a?(String) && !label["rationale"].empty? &&
                [true, false].include?(label["truncation_hid_context"])
        raise LabelError, "invalid label for #{id}" unless valid
      end

      task_count = bundle.fetch("tasks").length
      raise "expected 15 tasks, got #{task_count}" unless task_count == 15

      real_combined = candidates.select do |candidate|
        candidate.fetch("arm") == "real" && candidate.fetch("selected_combined")
      end
      rotated_combined = candidates.select do |candidate|
        candidate.fetch("arm") == "rotated" && candidate.fetch("selected_combined")
      end
      combined = population_metrics(real_combined, labels, task_count)
      rotated = population_metrics(rotated_combined, labels, task_count)
      combined["rotated_focus_lift"] =
        combined.fetch("incremental_task_hit_rate") - rotated.fetch("incremental_task_hit_rate")

      app_task_counts = bundle.fetch("tasks").group_by { |task| task.fetch("app") }.transform_values(&:length)
      per_app = app_task_counts.to_h do |app, app_task_count|
        items = real_combined.select { |candidate| candidate.fetch("app") == app }
        [app, population_metrics(items, labels, app_task_count)]
      end
      rotated_per_app = app_task_counts.to_h do |app, app_task_count|
        items = rotated_combined.select { |candidate| candidate.fetch("app") == app }
        [app, population_metrics(items, labels, app_task_count)]
      end
      real_recipe_candidates = candidates.select do |candidate|
        candidate.fetch("arm") == "real" && candidate.fetch("population") == "recipe"
      end
      rotated_recipe_candidates = candidates.select do |candidate|
        candidate.fetch("arm") == "rotated" && candidate.fetch("population") == "recipe"
      end
      per_recipe = RECIPE_NAMES.to_h do |recipe|
        items = real_recipe_candidates.select { |candidate| candidate.fetch("recipe") == recipe }
        [recipe, population_metrics(items, labels, task_count)]
      end
      rotated_per_recipe = RECIPE_NAMES.to_h do |recipe|
        items = rotated_recipe_candidates.select { |candidate| candidate.fetch("recipe") == recipe }
        [recipe, population_metrics(items, labels, task_count)]
      end

      safety_labels = labels.values.map { |label| label.fetch("label") }
      stale_count = safety_labels.count("stale_or_conflicting")
      governing_count = safety_labels.count("governing_instruction")
      primary_changes = retrievals.count { |retrieval| !retrieval.fetch("primary_preserved") }
      omission_taxonomy = SpikeHarness::Taxonomy.new
      retrievals.each do |retrieval|
        retrieval.fetch("omissions").each do |omission|
          omission_taxonomy.record(
            omission.fetch("reason"),
            omission.merge(
              "app" => retrieval.fetch("app"),
              "task" => retrieval.fetch("task"),
              "arm" => retrieval.fetch("arm")
            )
          )
        end
      end
      budget_pass = candidates.select { |candidate| candidate.fetch("selected_combined") }
                              .group_by { |candidate| [candidate.fetch("app"), candidate.fetch("task"), candidate.fetch("arm")] }
                              .values.all? do |items|
        items.length <= 3 && items.sum { |item| item.fetch("excerpt").bytesize } <= 2_048
      end
      retrieval_timings = timings.select { |timing| timing["kind"] != "inventory" }
      elapsed = retrieval_timings.map { |timing| timing.fetch("elapsed_ms") }.sort
      inventory_elapsed = timings.select { |timing| timing["kind"] == "inventory" }
                                 .map { |timing| timing.fetch("elapsed_ms") }.sort
      p95 = SpikeHarness.percentile(elapsed, 0.95)
      maximum = elapsed.max
      real_retrievals = retrievals.select { |retrieval| retrieval.fetch("arm") == "real" }
      selected_counts = real_retrievals.map { |retrieval| retrieval.fetch("selected_candidates") }.sort
      selected_bytes = real_retrievals.map { |retrieval| retrieval.fetch("selected_excerpt_bytes") }.sort
      latency = {
        "median_ms" => SpikeHarness.percentile(elapsed, 0.50),
        "p95_ms" => p95,
        "max_ms" => maximum,
        "inventory_median_ms" => SpikeHarness.percentile(inventory_elapsed, 0.50),
        "inventory_p95_ms" => SpikeHarness.percentile(inventory_elapsed, 0.95),
        "inventory_max_ms" => inventory_elapsed.max
      }
      budget = {
        "selected_candidates" => distribution(selected_counts),
        "selected_excerpt_bytes" => distribution(selected_bytes),
        "truncations" => real_combined.count { |candidate| candidate.fetch("truncated") },
        "omissions" => real_retrievals.sum { |retrieval| retrieval.fetch("omissions").length }
      }
      safety = {
        "stale_or_conflicting" => stale_count,
        "governing_instruction" => governing_count,
        "broken_reference_candidates" => 0,
        "primary_changes" => primary_changes
      }
      safety_count = safety.values.sum
      provenance = candidates.empty? ? nil :
        candidates.count { |candidate| provenance_complete?(candidate) }.to_f / candidates.length
      scored_bundle = bundle.reject { |key, _value| key == "label_sheet" }
      bundle_hash = Digest::SHA256.hexdigest(DocumentationSpike.canonical_json(scored_bundle))

      gates = {
        "combined_precision" => gate(
          value: {"overall" => combined.fetch("precision"),
                  "per_app" => per_app.transform_values { |metrics| metrics.fetch("precision") }},
          threshold: "overall >= 0.70 and each emitting app >= 0.50",
          pass: combined.fetch("precision") && combined.fetch("precision") >= 0.70 &&
            per_app.values.filter_map { |metrics| metrics.fetch("precision") }
                   .all? { |precision| precision >= 0.50 }
        ),
        "incremental_task_hit_rate" => gate(
          value: combined.fetch("incremental_task_hit_rate"),
          threshold: ">= 5/15",
          pass: combined.fetch("incremental_task_hits") >= 5
        ),
        "rotated_focus_lift" => gate(
          value: combined.fetch("rotated_focus_lift"),
          threshold: ">= 0.20",
          pass: combined.fetch("rotated_focus_lift") >= 0.20
        ),
        "byte_weighted_distraction" => gate(
          value: combined.fetch("byte_weighted_distraction"),
          threshold: "<= 0.25",
          pass: combined.fetch("byte_weighted_distraction") &&
            combined.fetch("byte_weighted_distraction") <= 0.25
        ),
        "safety" => gate(value: safety_count, threshold: "0", pass: safety_count.zero?),
        "budget" => gate(value: budget_pass, threshold: "<= 3 candidates and 2048 bytes", pass: budget_pass),
        "latency" => gate(
          value: latency,
          threshold: "p95 <= 500 ms and max <= 1000 ms",
          pass: p95 && maximum && p95 <= 500 && maximum <= 1_000
        ),
        "determinism" => gate(
          value: replays,
          threshold: "3 distinct prescribed replays with byte-identical candidates",
          pass: valid_replays?(replays, bundle_hash, bundle.fetch("runner_commit"))
        ),
        "provenance" => gate(value: provenance, threshold: "1.0", pass: provenance == 1.0),
        "synthetic_controls" => gate(
          value: synthetic_controls,
          threshold: "every predeclared control passes",
          pass: synthetic_controls.fetch("pass")
        )
      }

      verdict = if gates.values.all? { |item| item.fetch("pass") }
                  "proceed"
                elsif combined.fetch("precision").nil? || combined.fetch("precision") < 0.50 ||
                      combined.fetch("incremental_task_hits").zero?
                  "drop"
                else
                  "defer"
                end

      {
        "metrics" => {
          "combined" => combined,
          "rotated" => rotated,
          "per_app" => per_app,
          "per_recipe" => per_recipe,
          "rotated_per_app" => rotated_per_app,
          "rotated_per_recipe" => rotated_per_recipe,
          "safety" => safety,
          "budget" => budget,
          "latency" => latency,
          "availability" => {
            "counts" => omission_taxonomy.counts,
            "samples" => omission_taxonomy.samples,
            "synthetic_controls" => synthetic_controls.fetch("controls")
          }
        },
        "gates" => gates,
        "measurement_restarts" => MEASUREMENT_RESTARTS,
        "verdict" => verdict
      }
    end

    def population_metrics(candidates, labels, task_count)
      relevant = %w[relevant_unique relevant_redundant]
      distraction = %w[repository_background unrelated]
      candidate_labels = candidates.map { |candidate| labels.fetch(candidate.fetch("id")).fetch("label") }
      relevant_count = candidate_labels.count { |label| relevant.include?(label) }
      unique_count = candidate_labels.count { |label| label == "relevant_unique" }
      unique_tasks = candidates.filter_map do |candidate|
        label = labels.fetch(candidate.fetch("id")).fetch("label")
        [candidate.fetch("app"), candidate.fetch("task")] if label == "relevant_unique"
      end.uniq
      hit_tasks = candidates.filter_map do |candidate|
        label = labels.fetch(candidate.fetch("id")).fetch("label")
        [candidate.fetch("app"), candidate.fetch("task")] if relevant.include?(label)
      end.uniq
      total_bytes = candidates.sum { |candidate| candidate.fetch("excerpt").bytesize }
      distraction_bytes = candidates.sum do |candidate|
        label = labels.fetch(candidate.fetch("id")).fetch("label")
        distraction.include?(label) ? candidate.fetch("excerpt").bytesize : 0
      end

      {
        "candidates" => candidates.length,
        "precision" => candidates.empty? ? nil : relevant_count.to_f / candidates.length,
        "incremental_precision" => candidates.empty? ? nil : unique_count.to_f / candidates.length,
        "task_hits" => hit_tasks.length,
        "task_hit_rate" => hit_tasks.length.to_f / task_count,
        "incremental_task_hits" => unique_tasks.length,
        "incremental_task_hit_rate" => unique_tasks.length.to_f / task_count,
        "distraction_rate" => candidates.empty? ? nil :
          candidate_labels.count { |label| distraction.include?(label) }.to_f / candidates.length,
        "byte_weighted_distraction" => total_bytes.zero? ? nil : distraction_bytes.to_f / total_bytes
      }
    end
    private_class_method :population_metrics

    def distribution(sorted)
      {
        "median" => SpikeHarness.percentile(sorted, 0.50),
        "p95" => SpikeHarness.percentile(sorted, 0.95),
        "maximum" => sorted.max
      }
    end
    private_class_method :distribution

    def valid_replays?(replays, bundle_hash, runner_commit)
      return false unless replays.length == 3
      return false unless replays.map { |replay| replay["invocation_id"] }.compact.uniq.length == 3
      return false unless replays.all? { |replay| replay["candidate_sha256"] == bundle_hash }
      return false unless replays.all? { |replay| replay["runner_commit"] == runner_commit }

      first, utf8, third = replays
      first["locale"] == "C" && first["timezone"] == "UTC" &&
        utf8["locale"].to_s.match?(/utf-?8/i) && utf8["timezone"] == "America/Los_Angeles" &&
        third.values_at("locale", "timezone") == first.values_at("locale", "timezone")
    end
    private_class_method :valid_replays?

    def self_check(fixtures_root:)
      controls = {
        "no_candidates" => synthetic_control(fixtures_root, "no_candidates") do |result|
          result.fetch("candidates").empty? && result.fetch("omissions").empty?
        end,
        "broken_reference" => synthetic_control(fixtures_root, "broken_reference") do |result|
          result.fetch("candidates").empty? &&
            result.fetch("omissions").map { |item| item.fetch("reason") } == ["broken_reference"]
        end,
        "unavailable_documents" => synthetic_control(
          fixtures_root,
          "unavailable_documents",
          prepare: method(:prepare_unavailable_documents)
        ) do |result|
          result.fetch("omissions").map { |item| item.fetch("reason") }.sort ==
            %w[invalid_utf8 oversized_document]
        end,
        "governing_instruction_excluded" => synthetic_control(fixtures_root, "governing_instructions") do |result|
          result.fetch("candidates").empty? && result.fetch("governing_instruction_count") == 2
        end,
        "candidate_and_byte_caps" => synthetic_control(
          fixtures_root,
          "candidate_cap",
          prepare: method(:prepare_candidate_cap)
        ) do |result|
          result.dig("recipe_candidates", "reverse_exact_link").length == 2 &&
            result.fetch("recipe_candidates").values.flatten.length > 3 &&
            result.fetch("candidates").length == 3 &&
            result.fetch("candidates").sum { |candidate| candidate.fetch("excerpt").bytesize } <= 2_048 &&
            result.fetch("candidates").any? { |candidate| candidate.fetch("truncated") }
        end
      }
      {"pass" => controls.values.all? { |control| control.fetch("pass") }, "controls" => controls}
    end

    def synthetic_control(fixtures_root, name, prepare: nil)
      Dir.mktmpdir("ctxpack-documentation-control-") do |repo|
        FileUtils.cp_r(File.join(fixtures_root, name, "."), repo)
        prepare&.call(repo)
        git!(repo, "init", "--quiet")
        git!(repo, "add", ".")
        git!(repo, "-c", "user.name=ctxpack", "-c", "user.email=ctxpack@example.invalid",
             "commit", "--quiet", "-m", "fixture")
        revision = git!(repo, "rev-parse", "HEAD").strip
        result = DocumentationSpike.retrieve(
          repo_root: repo,
          revision: revision,
          focus_paths: ["app/models/user.rb"]
        )
        {"pass" => !!yield(result), "omission_reasons" => result.fetch("omissions").map { |item| item.fetch("reason") }}
      end
    rescue StandardError => error
      {"pass" => false, "error" => "#{error.class}: #{error.message}"}
    end
    private_class_method :synthetic_control

    def prepare_unavailable_documents(repo)
      File.binwrite(File.join(repo, "docs/large.md"), "x" * (256 * 1_024 + 1))
      File.binwrite(File.join(repo, "docs/invalid.md"), "# Invalid\n\xFF\n".b)
    end
    private_class_method :prepare_unavailable_documents

    def prepare_candidate_cap(repo)
      body = (1..9).map { |index| "line-#{index}-#{"x" * 80}\n" }.join
      File.write(File.join(repo, "docs/forward.md"), "# Forward\n\n#{body}")
      File.write(
        File.join(repo, "docs/reverse.md"),
        "# Reverse one\n\n[User](../app/models/user.rb) and [User again](../app/models/user.rb)\n#{body}" \
        "## Reverse two\n\n[User](../app/models/user.rb)\n#{body}"
      )
      File.write(File.join(repo, "docs/app/models/user.md"), "# Mirrored\n\n#{body}")
    end
    private_class_method :prepare_candidate_cap

    def git!(repo, *args)
      stdout, stderr, status = Open3.capture3("git", "-C", repo, *args)
      raise stderr unless status.success?

      stdout
    end
    private_class_method :git!

    def provenance_complete?(candidate)
      required = %w[
        id app task revision population recipe focus_paths retrieval_focus_paths
        document_path start_line end_line excerpt excerpt_sha256 selected_combined
        oracle_hashes
      ]
      return false unless required.all? { |key| candidate.key?(key) }
      return false if %w[forward_exact_reference reverse_exact_link].include?(candidate.fetch("recipe")) &&
                      !candidate.key?("resolved_reference")

      true
    end
    private_class_method :provenance_complete?

    def gate(value:, threshold:, pass:)
      {"value" => value, "threshold" => threshold, "pass" => !!pass}
    end
    private_class_method :gate

    def preflight(tasks:, runner_commit:)
      tasks.group_by { |task| [task.app, task.repo_root, task.revision] }.each_value do |app_tasks|
        task = app_tasks.first
        SpikeHarness.verify_pinned_checkouts!(task.app => {path: task.repo_root, sha: task.revision})
      end
      {
        "runner_commit" => runner_commit,
        "task_count" => tasks.length,
        "apps" => tasks.group_by(&:app).transform_values do |app_tasks|
          {"revision" => app_tasks.first.revision, "tasks" => app_tasks.map(&:id)}
        end
      }
    end

    def committed_runner_revision!(ctxpack_root:)
      root = File.expand_path(ctxpack_root)
      sources = %w[
        eval/documentation-spike/PREREGISTRATION.md
        eval/documentation-spike/run_documentation_spike.rb
        eval/documentation-spike/fixtures
        eval/lib/spike_harness.rb
        eval/tier2
        eval/tier2-expansion
      ]
      stdout, stderr, status = Open3.capture3(
        "git", "-C", root, "status", "--porcelain=v1", "--untracked-files=all", "--", *sources
      )
      raise stderr unless status.success?
      raise UncommittedRunner, "runner sources must match HEAD before measurement" unless stdout.empty?

      revision, revision_error, revision_status = Open3.capture3("git", "-C", root, "rev-parse", "HEAD")
      raise revision_error unless revision_status.success?

      revision.strip
    end

    def write_run(output_dir:, run:)
      FileUtils.mkdir_p(output_dir)
      bundle = run.bundle.dup
      label_sheet = bundle.delete("label_sheet")
      candidate_json = DocumentationSpike.canonical_json(bundle)
      File.write(File.join(output_dir, "candidates.json"), candidate_json)
      File.write(File.join(output_dir, "label-sheet.json"), DocumentationSpike.canonical_json(label_sheet))
      File.write(File.join(output_dir, "timings.json"), DocumentationSpike.canonical_json(run.timings))
      File.write(
        File.join(output_dir, "replay.json"),
        DocumentationSpike.canonical_json(
          "invocation_id" => SecureRandom.uuid,
          "runner_commit" => bundle.fetch("runner_commit"),
          "candidate_sha256" => Digest::SHA256.hexdigest(candidate_json),
          "locale" => ENV["LC_ALL"] || ENV["LANG"] || "unset",
          "timezone" => ENV["TZ"] || "system",
          "ruby" => RUBY_VERSION
        )
      )
    end

    def write_results(output_dir:, result:)
      results_dir = File.join(output_dir, "results")
      apps = result.dig("metrics", "per_app").to_h do |app, metrics|
        payload = {
          "app" => app,
          "metrics" => {
            "real_combined" => metrics,
            "rotated_combined" => result.dig("metrics", "rotated_per_app", app)
          }
        }
        [app, SpikeHarness.write_app_payload(results_dir, app, payload)]
      end
      gates = result.fetch("gates").transform_values do |gate_record|
        {
          value: gate_record.fetch("value"),
          threshold: gate_record.fetch("threshold"),
          pass: gate_record.fetch("pass")
        }
      end
      SpikeHarness.write_summary(results_dir, apps, gates)
      File.write(File.join(results_dir, "result.json"), DocumentationSpike.canonical_json(result))
      File.write(File.join(output_dir, "RESULTS.md"), results_markdown(result))
    end

    def results_markdown(result)
      gate_rows = result.fetch("gates").map do |name, gate_record|
        value = gate_record.fetch("value")
        rendered_value = value.is_a?(Hash) || value.is_a?(Array) ? "`#{JSON.generate(value)}`" : value.inspect
        "| `#{name}` | #{rendered_value} | #{gate_record.fetch("threshold")} | #{gate_record.fetch("pass") ? "pass" : "fail"} |"
      end
      restart_rows = result.fetch("measurement_restarts").each_with_index.map do |restart, index|
        environment = restart.fetch("environment")
        "#{index + 1}. Runner commit `#{restart.fetch("failed_runner_commit")}` under " \
          "`LC_ALL=#{environment.fetch("locale")}`, `TZ=#{environment.fetch("timezone")}` failed: " \
          "#{restart.fetch("failure")}. Recorded disposition: #{restart.fetch("artifact_disposition")}."
      end
      <<~MARKDOWN
        # Repository-documentation retrieval spike — results

        **Verdict: #{result.fetch("verdict").upcase}**

        This verdict covers deterministic offline retrieval viability only. It
        does not authorize product implementation or establish an agent-outcome
        benefit.

        ## Frozen gates

        | Gate | Value | Threshold | Result |
        |---|---|---|---|
        #{gate_rows.join("\n")}

        ## Recorded metrics and availability

        The canonical aggregate record is `results/result.json`; per-app metrics
        and the shared gate summary are in `results/`. Candidate, task,
        provenance, omission, budget, latency, and synthetic-control evidence
        remain in the raw JSON artifacts.

        ```json
        #{JSON.pretty_generate(
          "availability" => result.dig("metrics", "availability"),
          "safety" => result.dig("metrics", "safety"),
          "budget" => result.dig("metrics", "budget"),
          "latency" => result.dig("metrics", "latency")
        )}
        ```

        ## Measurement restart

        #{restart_rows.join("\n")}

        Every failed attempt was invalidated. All three measurement legs restarted
        from zero under the final repaired runner before labeling or scoring.

        ## Limitations

        One author defined the oracle and labels the candidates. Opaque ordering
        reduces recipe/arm cueing but cannot remove author bias. This offline
        study measures retrieval relevance, not task success, code quality, or
        exploration cost.

        ## Unmeasured source families

        Git history; repository contracts and configuration; build and ownership
        metadata; external issues and pull requests; CI; telemetry; and runtime
        traces remain unmeasured follow-ups. They did not affect this verdict.
      MARKDOWN
    end
    private_class_method :results_markdown

    def candidate_records(task, arm, result, oracle_hashes)
      recipe_records = result.fetch("recipe_candidates").values.flatten.map do |candidate|
        study_candidate_record(task, arm, "recipe", candidate, oracle_hashes, selected_combined: false)
      end
      combined_records = result.fetch("candidates").map do |candidate|
        study_candidate_record(task, arm, "combined", candidate, oracle_hashes, selected_combined: true)
      end
      recipe_records + combined_records
    end
    private_class_method :candidate_records

    def candidate_sort_key(record)
      [
        APP_NAMES.index(record.fetch("app")) || APP_NAMES.length,
        record.fetch("app"),
        record.fetch("task"),
        record.fetch("arm") == "real" ? 0 : 1,
        RECIPE_NAMES.index(record.fetch("recipe")),
        record.fetch("population") == "recipe" ? 0 : 1,
        record.fetch("document_path"),
        record.fetch("start_line"),
        record.fetch("end_line"),
        record.fetch("id")
      ]
    end
    private_class_method :candidate_sort_key

    def study_candidate_record(task, arm, population, candidate, oracle_hashes, selected_combined:)
        identity = [
          task.app,
          task.id,
          arm,
          population,
          candidate.fetch("recipe"),
          candidate.fetch("document_path"),
          candidate.fetch("start_line"),
          candidate.fetch("end_line"),
          candidate.fetch("excerpt_sha256")
        ].join("\0")
        candidate.merge(
          "id" => Digest::SHA256.hexdigest(identity),
          "app" => task.app,
          "task" => task.id,
          "arm" => arm,
          "population" => population,
          "revision" => task.revision,
          "focus_paths" => task.focus_paths,
          "retrieval_focus_paths" => result_focus_paths(task, arm),
          "selected_combined" => selected_combined,
          "oracle_hashes" => oracle_hashes
        )
    end
    private_class_method :study_candidate_record

    def result_focus_paths(task, arm)
      arm == "real" ? task.focus_paths : task.rotated_focus_paths
    end
    private_class_method :result_focus_paths

    def tasks(ctxpack_root:)
      root = File.expand_path(ctxpack_root)
      tasks = APP_NAMES.flat_map do |name|
        app = Tier2::Apps.load(name)
        app.tasks.map do |task|
          focus_artifact = focus_artifact_path(app, task.id)
          StudyTask.new(
            app: name,
            id: task.id,
            repo_root: app.template_dir,
            revision: app.repo_sha,
            focus_paths: focus_paths(focus_artifact),
            rotated_focus_paths: nil,
            prompt_path: File.join(app.tasks_dir, task.prompt_file),
            focus_artifact_path: focus_artifact,
            reference_diff_path: reference_diff_path(app, task.id)
          )
        end
      end

      tasks.group_by(&:app).values.flat_map do |app_tasks|
        app_tasks.each_with_index.map do |task, index|
          rotated = app_tasks.fetch((index + 1) % app_tasks.length)
          task.with(rotated_focus_paths: rotated.focus_paths)
        end
      end.tap do |result|
        raise "study root mismatch" unless result.all? { |task| task.prompt_path.start_with?(root) }
      end
    end

    def focus_artifact_path(app, task_id)
      if app.name == "redmine"
        File.join(app.packets_dir, "task#{task_id}.md")
      else
        File.join(app.packets_dir, "task#{task_id}.json")
      end
    end
    private_class_method :focus_artifact_path

    def focus_paths(path)
      if File.extname(path) == ".json"
        JSON.parse(File.read(path)).fetch("files").map { |item| item.fetch("path") }.uniq
      else
        File.read(path).scan(/^### `([^`]+)`$/).flatten.uniq
      end
    end
    private_class_method :focus_paths

    def reference_diff_path(app, task_id)
      row = File.readlines(app.runs_path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
                .select do |candidate|
                  candidate.fetch("task") == task_id &&
                    candidate.fetch("arm") == "treatment" &&
                    !candidate.fetch("pilot") &&
                    candidate.fetch("status") == "complete" &&
                    candidate.dig("metrics", "task_success")
                end
                .min_by { |candidate| candidate.fetch("run_index") }
      raise "#{app.name} task #{task_id}: no successful treatment diff" unless row

      File.join(app.artifact_dir, row.fetch("workspace_diff_path"))
    end
    private_class_method :reference_diff_path
  end

  module Runner
    CTXPACK_ROOT = File.expand_path("../..", __dir__)
    FIXTURES_ROOT = File.join(__dir__, "fixtures")

    module_function

    def run(argv, stdout: $stdout, stderr: $stderr, tasks_loader: nil, fixtures_root: FIXTURES_ROOT,
            runner_guard: nil)
      tasks_loader ||= -> { Study.tasks(ctxpack_root: CTXPACK_ROOT) }
      runner_guard ||= -> { Study.committed_runner_revision!(ctxpack_root: CTXPACK_ROOT) }
      command, *arguments = argv
      case command
      when "preflight"
        require_arguments!(arguments, 0)
        commit = runner_guard.call
        stdout.write(DocumentationSpike.canonical_json(Study.preflight(tasks: tasks_loader.call, runner_commit: commit)))
      when "self-check"
        require_arguments!(arguments, 0)
        result = Study.self_check(fixtures_root: fixtures_root)
        stdout.write(DocumentationSpike.canonical_json(result))
        return result.fetch("pass") ? 0 : 1
      when "generate"
        require_arguments!(arguments, 1)
        tasks = tasks_loader.call
        commit = runner_guard.call
        Study.preflight(tasks: tasks, runner_commit: commit)
        run = Study.generate(tasks: tasks, runner_commit: commit)
        Study.write_run(output_dir: arguments.first, run: run)
        stdout.puts("generated #{run.bundle.fetch("candidates").length} candidates")
      when "score"
        require_arguments!(arguments, 4)
        output_dir, *replay_paths = arguments
        bundle = JSON.parse(File.read(File.join(output_dir, "candidates.json")))
        commit = runner_guard.call
        raise UncommittedRunner, "candidate bundle runner commit does not match HEAD" unless bundle["runner_commit"] == commit
        labels = JSON.parse(File.read(File.join(output_dir, "labels.json")))
        timings = JSON.parse(File.read(File.join(output_dir, "timings.json")))
        resolved_replay_paths = replay_paths.map { |path| File.realpath(path) }
        raise ArgumentError, "replay directories must be distinct" unless resolved_replay_paths.uniq.length == 3
        replays = resolved_replay_paths.map do |path|
          candidate_path = File.join(path, "candidates.json")
          replay = JSON.parse(File.read(File.join(path, "replay.json")))
          actual_hash = Digest::SHA256.file(candidate_path).hexdigest
          raise "#{path}: replay hash does not match candidates.json" unless replay["candidate_sha256"] == actual_hash

          replay
        end
        controls = Study.self_check(fixtures_root: fixtures_root)
        result = Study.score(
          bundle: bundle,
          labels: labels,
          timings: timings,
          replays: replays,
          synthetic_controls: controls
        )
        Study.write_results(output_dir: output_dir, result: result)
        stdout.puts(result.fetch("verdict"))
      else
        raise ArgumentError, "usage: #{File.basename($PROGRAM_NAME)} preflight|self-check|generate OUTPUT_DIR|score OUTPUT_DIR REPLAY_DIR1 REPLAY_DIR2 REPLAY_DIR3"
      end
      0
    rescue StandardError => error
      stderr.puts("#{error.class}: #{error.message}")
      1
    end

    def require_arguments!(arguments, count)
      return if arguments.length == count

      raise ArgumentError, "expected #{count} arguments, got #{arguments.length}"
    end
    private_class_method :require_arguments!
  end
end

exit DocumentationSpike::Runner.run(ARGV) if $PROGRAM_NAME == __FILE__
