require "ctxpack/compiler"
require "ctxpack/default_constant_resolver"
require "ctxpack/packet"

module Ctxpack
  class Error < StandardError; end

  def self.compile(app_root:, anchor:, task: nil, constant_resolver: nil)
    Compiler.new(
      app_root: app_root,
      anchor: anchor,
      task: task,
      constant_resolver: constant_resolver
    ).compile
  end
end
