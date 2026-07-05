module Ctxpack
  RepoStamp = Struct.new(:commit, :dirty, keyword_init: true)
  Entrypoint = Struct.new(:file, :controller, :action, keyword_init: true)

  EvidenceItem = Struct.new(
    :reason_code,
    :subject,
    :why,
    :snippet_ranges,
    :truncated,
    keyword_init: true
  )

  class FileEntry
    attr_reader :path, :evidence_items

    def initialize(path:)
      @path = path
      @evidence_items = []
    end

    def add_evidence(item)
      @evidence_items << item
    end

    def reason_codes
      @evidence_items.map(&:reason_code).uniq
    end

    def evidence_for(reason_code)
      @evidence_items.select { |item| item.reason_code == reason_code }
    end
  end

  TestCandidate = Struct.new(:path, :command, :reason_code, :why, :rule, keyword_init: true)
  Uncertainty = Struct.new(:code, :subject, :message, keyword_init: true)
  OmittedCandidate = Struct.new(:category, :subject, :reason, keyword_init: true)

  class Packet
    attr_reader :version,
                :anchor,
                :task,
                :repo,
                :entrypoint,
                :files,
                :tests,
                :uncertainty,
                :omitted_candidates,
                :convention_constant_matches

    attr_accessor :no_test_candidates

    def initialize(anchor:, task:, repo:, entrypoint:)
      @version = 1
      @anchor = anchor
      @task = task
      @repo = repo
      @entrypoint = entrypoint
      @files = []
      @tests = []
      @uncertainty = []
      @omitted_candidates = []
      @convention_constant_matches = []
      @no_test_candidates = false
    end

    def file(path)
      @files.find { |entry| entry.path == path }
    end

    def files_with_reason(reason_code)
      @files.select { |entry| entry.reason_codes.include?(reason_code) }
    end

    def add_file(path)
      existing = file(path)
      return existing if existing

      entry = FileEntry.new(path: path)
      @files << entry
      entry
    end

    def add_uncertainty(code:, subject: nil, message:)
      return if @uncertainty.any? { |item| item.code == code && item.subject == subject }

      @uncertainty << Uncertainty.new(code: code, subject: subject, message: message)
    end

    def to_h
      {
        "version" => version,
        "anchor" => anchor,
        "repo" => {
          "commit" => repo.commit,
          "dirty" => repo.dirty
        },
        "entrypoint" => {
          "file" => entrypoint.file,
          "controller" => entrypoint.controller,
          "action" => entrypoint.action
        },
        "files" => files.flat_map { |entry| manifest_file_entries(entry) },
        "tests" => tests.map do |test|
          {
            "command" => test.command,
            "reason_code" => test.reason_code
          }
        end,
        "uncertainty" => uncertainty.map { |note| { "code" => note.code } }
      }
    end

    private

    def manifest_file_entries(entry)
      entry.evidence_items.map do |item|
        {
          "path" => entry.path,
          "reason_code" => item.reason_code,
          "snippet_ranges" => item.snippet_ranges
        }
      end
    end
  end
end
