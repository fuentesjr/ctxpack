require "ctxpack/packet"
require "ctxpack/packet_file_budget"

module Ctxpack
  # ROOT-1: a path under the application root whose real path (symlinks
  # resolved) is outside the real application root is never read or included.
  module RootConfinement
    REASON = "path resolves outside the application root"

    module_function

    # True when +path+ (relative to +app_root+, or absolute) exists and its real
    # path is outside the real application root. A path that cannot be
    # resolved cannot be read either, so it is not reported as escaping;
    # callers keep their own existence checks and messages.
    def outside?(app_root, path)
      root = File.realpath(app_root)
      real = File.realpath(File.expand_path(path, app_root))
      real != root && !real.start_with?(root + File::SEPARATOR)
    rescue SystemCallError
      false
    end

    # Drops included files that resolve outside the root, recording each as a
    # non-limit omission (null limit_key) instead.
    def enforce(packet)
      outside = packet.files.select { |entry| outside?(packet.app_root, entry.path) }
      outside.each do |entry|
        packet.files.delete(entry)
        packet.tests.reject! { |test| test.path == entry.path }
        packet.convention_constant_matches.reject! { |match| match.path == entry.path }
        packet.uncertainty.reject! { |item| item.subject == entry.path }
        packet.omitted_candidates << omission(PacketFileBudget.omitted_category(entry), entry.path)
      end
      packet
    end

    def omission(category, path)
      OmittedCandidate.new(category: category, subject: path, reason: REASON, limit_key: nil)
    end
  end
end
