require "ctxpack/version"
require "ctxpack/compiler"
require "ctxpack/default_constant_resolver"
require "ctxpack/manifest_renderer"
require "ctxpack/markdown_renderer"
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

  def self.render_markdown(packet)
    MarkdownRenderer.new(packet).render
  end

  def self.render_manifest(packet)
    ManifestRenderer.new(packet).render
  end
end
