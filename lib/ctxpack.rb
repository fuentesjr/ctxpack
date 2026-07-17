require "ctxpack/version"
require "ctxpack/seed"
require "ctxpack/compiler"
require "ctxpack/default_constant_resolver"
require "ctxpack/git_recon_history_provider"
require "ctxpack/manifest_renderer"
require "ctxpack/markdown_renderer"
require "ctxpack/packet"

module Ctxpack
  class Error < StandardError; end

  def self.compile(app_root:, anchor: nil, seeds: nil, task: nil, constant_resolver: nil, history_provider: nil)
    Compiler.new(
      app_root: app_root,
      anchor: anchor,
      seeds: seeds,
      task: task,
      constant_resolver: constant_resolver,
      history_provider: history_provider
    ).compile
  end

  def self.render_markdown(packet)
    MarkdownRenderer.new(packet).render
  end

  def self.render_manifest(packet)
    ManifestRenderer.new(packet).render
  end
end
