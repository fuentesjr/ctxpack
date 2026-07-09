require "ctxpack/compiler"

module Ctxpack
  class MarkdownRenderer
    def initialize(packet)
      @packet = packet
    end

    def render
      lines = []
      append_title(lines)
      append_task(lines)
      append_anchor(lines)
      append_files(lines)
      append_tests(lines)
      append_uncertainty(lines)
      append_omitted_candidates(lines) if packet.omitted_candidates.any?
      append_retrieve_more(lines)

      lines.join("\n") + "\n"
    end

    private

    attr_reader :packet

    def append_title(lines)
      lines << "# ctxpack context packet"
      lines << ""
    end

    def append_task(lines)
      lines << "## Task"
      lines << (packet.task.nil? ? "No task was provided." : packet.task)
      lines << ""
    end

    def append_anchor(lines)
      lines << "## Anchor"
      lines << "- Anchor: `#{packet.anchor}`"
      lines << "- Controller: `#{packet.entrypoint.controller}`"
      lines << "- Action: `#{packet.entrypoint.action}`"
      lines << "- File: `#{packet.entrypoint.file}`"
      lines << "- Generated from: #{repo_stamp}"
      lines << ""
    end

    def repo_stamp
      return "unknown (not a git repository)" unless packet.repo.commit

      "#{packet.repo.commit[0, 7]} (#{packet.repo.dirty ? "dirty" : "clean"})"
    end

    def append_files(lines)
      lines << "## Files to inspect first"
      lines << ""

      packet.files.each do |entry|
        lines << "### `#{entry.path}`"
        lines << ""
        entry.evidence_items.each do |item|
          lines << "Why: #{why_text(item)}"
          lines << "Reason code: `#{item.reason_code}`"
          append_snippet(lines, entry.path, item) if item.snippet_ranges.any?
          lines << ""
        end
      end
    end

    def why_text(item)
      case item.reason_code
      when "controller_action"
        "controller action for requested anchor."
      when "before_action_callback"
        "callback `#{item.subject}` applies to the requested action."
      when "referenced_constant"
        "constant `#{item.subject}` was referenced by the action, an applicable callback, or a same-file method transitively called from the action."
      when "view_candidate"
        "Conventional view template for `#{packet.anchor}`."
      when "minitest_candidate", "rspec_candidate"
        test_candidate_why(item)
      else
        "#{item.why}."
      end
    end

    def test_candidate_why(item)
      case item.why
      when "matched conventional controller test path"
        "test file matched the conventional controller test path."
      when "matched integration test path tokens"
        "test file matched integration path tokens for the anchor."
      when "matched conventional controller spec path"
        "test file matched the conventional controller spec path."
      when "matched request spec path tokens"
        "test file matched request spec path tokens for the anchor."
      else
        "#{item.why}."
      end
    end

    def append_snippet(lines, path, item)
      lines << ""
      lines << "```ruby"
      item.snippet_ranges.each do |range|
        snippet_lines(path, range).each { |line| lines << line }
      end
      lines << truncation_marker if item.truncated
      lines << "```"
    end

    def truncation_marker
      line_count = Compiler::LIMITS.fetch(:max_snippet_lines_per_file)
      "# … truncated by ctxpack at #{line_count} lines"
    end

    def snippet_lines(path, range)
      raise Error, "packet app_root is required to render snippets" unless packet.app_root

      all_lines = File.readlines(File.join(packet.app_root, path), chomp: true)
      all_lines[(range.first - 1)..(range.last - 1)] || []
    end

    def append_tests(lines)
      lines << "## Tests to run"
      if packet.tests.any?
        packet.tests.each { |test| lines << "- `#{test.command}`" }
      else
        lines << "No #{test_framework_label} candidates were found by ctxpack's path rules."
      end
      lines << ""
    end

    def append_uncertainty(lines)
      lines << "## Uncertainty"
      uncertainty_notes.each { |note| lines << "- #{note}" }
      lines << ""
    end

    def uncertainty_notes
      notes = packet.uncertainty.map { |item| uncertainty_text(item) }
      notes << "Callbacks declared outside this controller file, including superclasses and concerns, were not resolved."
      notes << "Route discovery is delegated to Rails; run `bin/rails routes -g #{packet.entrypoint.action}` if the exact endpoint matters."
      notes.concat(packet.convention_constant_matches.map { |match| convention_constant_text(match) })
      notes
    end

    def uncertainty_text(item)
      case item.code
      when "test_inferred_by_path"
        "Test file `#{item.subject}` was inferred by path and should be verified."
      when "dynamic_callback_args"
        "Callback declaration `#{item.subject}` used dynamic callback arguments and was not resolved precisely."
      when "unresolved_external_callbacks"
        "Callback `#{item.subject}` applies but was not defined in this controller file."
      when "around_callback_present"
        "`around_action` callback `#{item.subject}` applies and is not snippeted in v0."
      when "block_callback_present"
        "Inline `#{item.subject}` callback block applies and has no method snippet."
      when "view_inferred_by_convention"
        "Included view template(s) were matched by action->template convention and not confirmed against the action's actual render target."
      else
        "#{item.code}: #{item.message}"
      end
    end

    def convention_constant_text(match)
      "Convention-only constant match `#{match.constant_name}` resolved to `#{match.path}`; verify it if the task depends on that behavior."
    end

    def append_omitted_candidates(lines)
      lines << "## Omitted candidates"
      packet.omitted_candidates.each { |candidate| lines << "- #{omitted_candidate_text(candidate)}" }
      lines << ""
    end

    def omitted_candidate_text(candidate)
      case candidate.category
      when "constant_files"
        "Constant `#{candidate.subject}` was omitted because #{candidate.reason}."
      when "test_files"
        "Test file `#{candidate.subject}` was omitted because #{candidate.reason}."
      when "view_files"
        "View `#{candidate.subject}` was omitted because #{candidate.reason}."
      when "snippets"
        "Snippet `#{candidate.subject}` was omitted because #{candidate.reason}."
      else
        "#{candidate.category} `#{candidate.subject}` was omitted because #{candidate.reason}."
      end
    end

    def append_retrieve_more(lines)
      suggestions = retrieval_suggestions
      return if suggestions.empty?

      lines << "## Retrieve more only if needed"
      suggestions.each { |suggestion| lines << "- #{suggestion}" }
      lines << ""
    end

    def retrieval_suggestions
      suggestions = uncertainty_suggestions + omission_suggestions
      suggestions << "Search `#{test_search_root}` by hand if the task needs test coverage." if packet.no_test_candidates
      suggestions
    end

    def uncertainty_suggestions
      by_code = packet.uncertainty.group_by(&:code)
      packet.uncertainty.map(&:code).uniq.map do |code|
        items = by_code.fetch(code)
        subjects = items.map(&:subject).compact

        case code
        when "test_inferred_by_path"
          if subjects.length == 1
            "Inspect test file `#{subjects.first}` to confirm the path-inferred #{test_framework_label} candidate covers the task."
          else
            "Inspect path-inferred #{test_framework_label} candidates: #{inline_list(subjects)}."
          end
        when "dynamic_callback_args"
          "Inspect callback declarations with dynamic callback arguments: #{inline_list(subjects)}."
        when "unresolved_external_callbacks"
          if subjects.length == 1
            "Inspect the superclass or concerns for callback `#{subjects.first}`."
          else
            "Inspect the superclass or concerns for callbacks: #{inline_list(subjects)}."
          end
        when "around_callback_present"
          if subjects.length == 1
            "Inspect applicable `around_action` behavior for `#{subjects.first}` if it affects the task."
          else
            "Inspect applicable `around_action` behavior for: #{inline_list(subjects)}."
          end
        when "block_callback_present"
          if subjects.length == 1
            "Inspect inline callback block behavior for `#{subjects.first}` if it affects the task."
          else
            "Inspect inline callback block behavior for: #{inline_list(subjects)}."
          end
        when "view_inferred_by_convention"
          "Confirm the action renders the included view template(s); it may redirect or render another."
        end
      end.compact
    end

    def omission_suggestions
      by_category = packet.omitted_candidates.group_by(&:category)
      packet.omitted_candidates.map(&:category).uniq.map do |category|
        subjects = by_category.fetch(category).map(&:subject)

        case category
        when "constant_files"
          subjects.length == 1 ? "Inspect omitted constant `#{subjects.first}` manually." : "Inspect omitted constants manually: #{inline_list(subjects)}."
        when "test_files"
          subjects.length == 1 ? "Inspect omitted test file `#{subjects.first}` manually." : "Inspect omitted test files manually: #{inline_list(subjects)}."
        when "view_files"
          "Inspect omitted view file(s) manually: #{inline_list(subjects)}."
        when "snippets"
          subjects.length == 1 ? "Inspect omitted snippet `#{subjects.first}` manually." : "Inspect omitted snippets manually: #{inline_list(subjects)}."
        end
      end.compact
    end

    def inline_list(values)
      values.map { |value| "`#{value}`" }.join(", ")
    end

    def test_framework_label
      packet.test_framework == "rspec" ? "RSpec" : "Minitest"
    end

    def test_search_root
      packet.test_framework == "rspec" ? "spec/" : "test/"
    end
  end
end
