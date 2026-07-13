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
  OmittedCandidate = Struct.new(:category, :subject, :reason, :limit_key, keyword_init: true)

  class Packet
    attr_reader :version,
                :app_root,
                :anchor,
                :task,
                :repo,
                :entrypoint,
                :files,
                :tests,
                :uncertainty,
                :omitted_candidates,
                :convention_constant_matches

    attr_accessor :no_test_candidates, :test_framework

    def initialize(anchor:, task:, repo:, entrypoint:, app_root: nil)
      @version = 2
      @app_root = app_root && File.expand_path(app_root)
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
      @test_framework = nil
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
        "task" => task,
        "anchor" => anchor,
        "repo" => {
          "available" => !repo.commit.nil?,
          "commit" => repo.commit,
          "dirty" => repo.dirty
        },
        "entrypoint" => {
          "file" => entrypoint.file,
          "controller" => entrypoint.controller,
          "action" => entrypoint.action
        },
        "files" => files.map { |entry| manifest_file_entry(entry) },
        "tests" => tests.map { |test| manifest_test(test) },
        "follow_ups" => manifest_follow_ups,
        "omitted_candidates" => omitted_candidates.map { |candidate| manifest_omitted_candidate(candidate) },
        "no_test_candidates" => no_test_candidates
      }
    end

    private

    def manifest_file_entry(entry)
      {
        "path" => entry.path,
        "evidence" => entry.evidence_items.map do |item|
          {
            "reason_code" => item.reason_code,
            "subject" => item.subject,
            "snippet_ranges" => item.snippet_ranges,
            "truncated" => item.truncated
          }
        end
      }
    end

    def manifest_test(test)
      {
        "path" => test.path,
        "command" => test.command,
        "reason_code" => test.reason_code,
        "rule" => test.rule
      }
    end

    def manifest_follow_ups
      facts = uncertainty.map do |item|
        {
          "code" => item.code,
          "subject" => item.subject
        }
      end

      facts.concat(convention_constant_matches.map do |match|
        {
          "code" => "convention_constant_match",
          "subject" => match.constant_name,
          "path" => match.path
        }
      end)

      facts.concat(omitted_candidates.map do |candidate|
        {
          "code" => "omitted_candidate",
          "subject" => candidate.subject,
          "category" => candidate.category,
          "limit_key" => candidate.limit_key.to_s
        }
      end)

      if no_test_candidates
        facts << {
          "code" => "no_test_candidates",
          "subject" => test_framework == "rspec" ? "spec/" : "test/"
        }
      end

      facts.uniq
    end

    def manifest_omitted_candidate(candidate)
      {
        "category" => candidate.category,
        "subject" => candidate.subject,
        "reason" => candidate.reason,
        "limit_key" => candidate.limit_key.to_s
      }
    end
  end
end
