require "json"

module Ctxpack
  class ManifestRenderer
    def initialize(packet)
      @packet = packet
    end

    def render
      JSON.pretty_generate(@packet.to_h) + "\n"
    end
  end
end
