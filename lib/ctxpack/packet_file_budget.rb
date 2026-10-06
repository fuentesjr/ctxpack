require "ctxpack/packet"

module Ctxpack
  class PacketFileBudget
    def self.enforce(packet, limits:)
      new(limits).enforce(packet)
    end

    def self.omitted_category(entry)
      return "view_files" if entry.reason_codes.include?("view_candidate")
      return "test_files" if (entry.reason_codes & %w[minitest_candidate rspec_candidate diff_seed_paired_test]).any?
      return "constant_files" if entry.reason_codes.include?("referenced_constant")
      return "diff_files" if entry.reason_codes.include?("diff_seed_primary")

      "files"
    end

    def initialize(limits)
      @limits = limits
    end

    def enforce(packet)
      return packet if packet.files.length <= @limits.fetch(:max_total_files)

      packet.files.slice!(@limits.fetch(:max_total_files)..).each do |entry|
        packet.tests.reject! { |test| test.path == entry.path }
        packet.omitted_candidates << OmittedCandidate.new(
          category: self.class.omitted_category(entry),
          subject: omitted_subject(entry),
          reason: "max total files limit reached",
          limit_key: :max_total_files
        )
      end
      packet
    end

    private

    def omitted_subject(entry)
      evidence = entry.evidence_items.first
      return entry.path unless evidence&.reason_code == "referenced_constant"

      evidence.subject
    end
  end
end
