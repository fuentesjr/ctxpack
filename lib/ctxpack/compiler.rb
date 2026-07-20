require "ctxpack/default_constant_resolver"
require "ctxpack/git_recon_history_provider"
require "ctxpack/packet_file_budget"
require "ctxpack/repository_snapshot"
require "ctxpack/seed_compiler"

module Ctxpack
  class Compiler
    LIMITS = {
      max_total_files: 8,
      max_constant_files: 4,
      max_view_files: 2,
      max_test_files: 2,
      max_snippet_lines_per_file: 120,
      max_history_calls: 1,
      max_history_facts: 5,
      max_history_payload_bytes: 2048,
      max_history_response_bytes: 16_384,
      max_history_seconds: 20
    }.freeze

    def initialize(app_root:, task:, anchor: nil, seeds: nil, constant_resolver: nil, history_provider: nil)
      @app_root = File.expand_path(app_root)
      @task = task
      @seeds = normalize_seeds(anchor: anchor, seeds: seeds)
      @constant_resolver = constant_resolver || DefaultConstantResolver.new(app_root: @app_root)
      @history_provider = history_provider || GitReconHistoryProvider.new(limits: LIMITS)
      @repository = RepositorySnapshot.new(app_root: @app_root)
    end

    def compile
      seed_compiler = SeedCompiler.new(
        app_root: @app_root,
        task: @task,
        constant_resolver: @constant_resolver,
        repository: @repository,
        limits: LIMITS
      )
      packets = @seeds.map { |seed| seed_compiler.compile(seed) }
      packet = packets.length == 1 ? packets.first : merge_packets(packets, seed_compiler.test_framework)
      enrich_history(packet)

      packet
    end

    private

    def normalize_seeds(anchor:, seeds:)
      if seeds && anchor
        raise ArgumentError, "pass either anchor: or seeds:, not both"
      end

      list =
        if seeds
          Array(seeds).map { |seed| seed.is_a?(Seed) ? seed : raise(ArgumentError, "seeds must be Ctxpack::Seed instances") }
        elsif anchor
          [Seed.anchor(anchor)]
        else
          raise ArgumentError, "compile requires an anchor: or seeds: argument"
        end

      raise ArgumentError, "compile requires at least one seed" if list.empty?

      list.map do |seed|
        seed.files? ? Seed.files(seed.files_paths, app_root: @app_root) : seed
      end
    end

    def merge_packets(packets, fallback_test_framework)
      first = packets.first
      merged = Packet.new(
        anchor: packets.map(&:anchor).compact.first,
        seeds: @seeds,
        task: @task,
        repo: first.repo,
        app_root: @app_root,
        entrypoint: packets.map(&:entrypoint).compact.first,
        version: 4
      )

      packets.each do |packet|
        merge_packet(merged, packet)
      end

      merged.no_test_candidates = merged.tests.empty?
      merged.test_framework = packets.map(&:test_framework).compact.first || fallback_test_framework.to_s
      PacketFileBudget.enforce(merged, limits: LIMITS)
    end

    def merge_packet(merged, packet)
      packet.files.each do |entry|
        target = merged.add_file(entry.path)
        entry.evidence_items.each do |item|
          next if target.evidence_items.any? { |evidence| evidence.reason_code == item.reason_code && evidence.subject == item.subject }

          target.add_evidence(item)
        end
      end
      packet.tests.each do |test|
        merged.tests << test unless merged.tests.any? { |candidate| candidate.path == test.path }
      end
      packet.uncertainty.each do |note|
        merged.add_uncertainty(code: note.code, subject: note.subject, message: note.message)
      end
      packet.omitted_candidates.each do |omission|
        next if merged.omitted_candidates.any? { |existing| existing.subject == omission.subject && existing.category == omission.category }

        merged.omitted_candidates << omission
      end
      packet.convention_constant_matches.each do |match|
        merged.convention_constant_matches << match unless merged.convention_constant_matches.include?(match)
      end
    end

    def enrich_history(packet)
      primary = packet.files.find { |entry| entry.reason_codes.include?("files_seed_primary") }
      return unless primary

      context = @repository.context
      packet.history =
        if context.commit && context.root
          @history_provider.fetch(
            app_root: @app_root,
            repo_root: context.root,
            path: primary.path,
            revision: context.commit
          )
        else
          History.omitted(path: primary.path, reason: "repository_unavailable")
        end
      return unless packet.history.status == "omitted"

      packet.add_uncertainty(
        code: "history_context_unavailable",
        subject: primary.path,
        message: packet.history.reason
      )
    end
  end
end
