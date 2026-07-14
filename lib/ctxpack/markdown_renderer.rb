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
      append_how_to_use(lines)
      append_seeds(lines)
      append_anchor(lines) if packet.anchor
      append_inspect_first(lines)
      append_evidence(lines) if snippet_entries.any?
      append_run(lines)
      append_follow_ups(lines) if follow_up_lines.any?

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
      lines << ""
      task = packet.task.nil? ? "No task was provided." : packet.task
      task_lines = task.gsub(/\r\n?/, "\n").lines(chomp: true)
      task_lines = [""] if task_lines.empty?
      task_lines.each do |line|
        lines << (line.empty? ? ">" : "> #{line}")
      end
      lines << ""
    end

    def append_seeds(lines)
      lines << "## Seeds"
      lines << ""
      packet.seeds.each do |seed|
        lines << "- #{seed.kind}: `#{seed.evidence.to_s.split("\n").first}`"
      end
      unless packet.anchor
        lines << "- Generated from: #{repo_stamp}"
        lines << "- Format: #{packet.version}"
        lines << "- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack; expand from the listed seeds only."
      end
      lines << ""
    end

    def append_anchor(lines)
      lines << "## Anchor"
      lines << ""
      lines << "- Anchor: `#{packet.anchor}`"
      lines << "- Controller: `#{packet.entrypoint.controller}`"
      lines << "- Action: `#{packet.entrypoint.action}`"
      lines << "- File: `#{packet.entrypoint.file}`"
      lines << "- Generated from: #{repo_stamp}"
      lines << "- Format: #{packet.version}"
      lines << "- Scope: routes, superclass/concern callbacks, and locale files are not scanned by ctxpack v0; use `bin/rails routes -g #{packet.entrypoint.action}` for endpoints, and check `config/locales/` if the task touches user-facing copy."
      lines << ""
    end

    def append_how_to_use(lines)
      lines << "## How to use this packet"
      lines << ""
      lines << "- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list."
      start = packet.entrypoint&.file || packet.files.first&.path || "the listed focus files"
      lines << "- Otherwise, start with `#{start}` and open the other listed files only as the task touches them."
      lines << ""
    end

    def repo_stamp
      return "unknown (Git state unavailable)" unless packet.repo.commit

      "#{packet.repo.commit[0, 7]} (#{packet.repo.dirty ? "dirty" : "clean"})"
    end

    def append_inspect_first(lines)
      lines << "## Inspect first"
      lines << ""

      packet.files.each_with_index do |entry, index|
        lines << "#{index + 1}. `#{entry.path}` — `#{inventory_reason_code(entry)}`: #{inventory_text(entry)}"
      end
      lines << ""
    end

    def inventory_reason_code(entry)
      entry.evidence_items.first.reason_code
    end

    def inventory_text(entry)
      item = entry.evidence_items.first

      case item.reason_code
      when "controller_action"
        "action and applicable callbacks"
      when "referenced_constant"
        "`#{item.subject}`"
      when "view_candidate"
        "conventional template for `#{packet.anchor}`"
      when "minitest_candidate", "rspec_candidate"
        path_inferred_test?(item.subject) ? "path-inferred; verify coverage" : conventional_test_inventory_text(item)
      when "test_seed_primary"
        "user-named test seed"
      when "files_seed_primary"
        "user-named files seed"
      when "files_seed_neighbor"
        "neighbor of files seed"
      when "error_seed_frame"
        "application stack frame"
      when "method_seed_primary"
        "user-named method seed"
      else
        why_text(item)
      end
    end

    def conventional_test_inventory_text(item)
      item.reason_code == "rspec_candidate" ? "conventional controller spec path" : "conventional controller test path"
    end

    def append_evidence(lines)
      lines << "## Evidence"
      lines << ""

      snippet_entries.each do |entry|
        lines << "### `#{entry.path}`"
        lines << ""
        entry.evidence_items.select { |item| item.snippet_ranges.any? }.each do |item|
          lines << evidence_provenance(item)
          append_snippet(lines, entry.path, item)
          lines << ""
        end
      end
    end

    def snippet_entries
      packet.files.select { |entry| entry.evidence_items.any? { |item| item.snippet_ranges.any? } }
    end

    def evidence_provenance(item)
      subject = case item.reason_code
                when "controller_action"
                  "action `#{item.subject}`"
                when "before_action_callback"
                  "callback `#{item.subject}` applies"
                else
                  "`#{item.subject}`"
                end
      "`#{item.reason_code}` — #{subject}#{range_suffix(item)}"
    end

    def range_suffix(item)
      ranges = item.snippet_ranges.map { |range| "#{range.first}–#{range.last}" }.join(", ")
      " · lines #{ranges}"
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

    def append_run(lines)
      lines << "## Run"
      lines << ""
      if packet.tests.any?
        packet.tests.each do |test|
          suffix = path_inferred_test?(test.path) ? " — path-inferred; verify coverage" : ""
          lines << "- `#{test.command}`#{suffix}"
        end
      else
        lines << "No #{test_framework_label} candidates were found by ctxpack's path rules."
      end
      lines << ""
    end

    def path_inferred_test?(path)
      packet.uncertainty.any? do |item|
        item.code == "test_inferred_by_path" && item.subject == path
      end
    end

    def append_follow_ups(lines)
      lines << "## Follow-ups"
      lines << ""
      follow_up_lines.each { |line| lines << "- #{line}" }
      lines << ""
    end

    def follow_up_lines
      lines = packet.uncertainty.map { |item| uncertainty_follow_up(item) }
      lines.concat(packet.convention_constant_matches.map { |match| convention_constant_follow_up(match) })
      lines.concat(packet.omitted_candidates.map { |candidate| omission_follow_up(candidate) })
      lines << "Search `#{test_search_root}` by hand if the task needs test coverage." if packet.no_test_candidates
      lines.compact.uniq
    end

    def uncertainty_follow_up(item)
      case item.code
      when "test_inferred_by_path"
        "Inspect `#{item.subject}` to confirm the path-inferred candidate covers the task."
      when "dynamic_callback_args"
        "Inspect callback declaration `#{item.subject}`; dynamic callback arguments prevented precise resolution."
      when "unresolved_external_callbacks"
        "Inspect the superclass or concerns for callback `#{item.subject}`; it applies but is not defined in this controller file."
      when "around_callback_present"
        "Inspect `around_action` callback `#{item.subject}`; it applies but is not snippeted in v0."
      when "block_callback_present"
        "Inspect the inline `#{item.subject}` block; it applies but has no method snippet."
      when "view_inferred_by_convention"
        "Confirm the action renders `#{item.subject}`; it was matched by convention."
      else
        "Inspect `#{item.subject || item.code}`; #{item.message}."
      end
    end

    def convention_constant_follow_up(match)
      "Verify convention-only constant match `#{match.constant_name}` → `#{match.path}` if the task depends on it."
    end

    def omission_follow_up(candidate)
      subject = case candidate.category
      when "constant_files"
        "constant `#{candidate.subject}`"
      when "test_files"
        "test file `#{candidate.subject}`"
      when "view_files"
        "view file `#{candidate.subject}`"
      when "snippets"
        "snippet `#{candidate.subject}`"
      else
        "#{candidate.category} `#{candidate.subject}`"
      end
      "Inspect omitted #{subject}; #{omission_limit_text(candidate)}."
    end

    def omission_limit_text(candidate)
      value = Compiler::LIMITS.fetch(candidate.limit_key)
      label = case candidate.limit_key
              when :max_total_files then "file"
              when :max_constant_files then "constant"
              when :max_view_files then "view"
              when :max_test_files then "test"
              when :max_snippet_lines_per_file then "line per-file snippet"
              else raise Error, "unknown omission limit key: #{candidate.limit_key.inspect}"
              end
      "the #{value}-#{label} limit was reached"
    end

    def test_framework_label
      packet.test_framework == "rspec" ? "RSpec" : "Minitest"
    end

    def test_search_root
      packet.test_framework == "rspec" ? "spec/" : "test/"
    end
  end
end
