require "open3"
require "ctxpack/packet"

module Ctxpack
  class RepositorySnapshot
    Context = Struct.new(:commit, :dirty, :root, keyword_init: true)

    def initialize(app_root:)
      @app_root = app_root
    end

    def stamp
      snapshot = context
      RepoStamp.new(commit: snapshot.commit, dirty: snapshot.dirty)
    end

    def context
      return @context if defined?(@context)

      output, status = Open3.capture2(
        "git", "-C", @app_root, "rev-parse", "--show-toplevel", "HEAD",
        err: File::NULL
      )
      unless status.success?
        @context = unavailable_context
        return @context
      end

      root, commit = output.lines(chomp: true)
      unless root && commit
        @context = unavailable_context
        return @context
      end

      status_output, = Open3.capture2("git", "-C", @app_root, "status", "--porcelain", err: File::NULL)
      @context = Context.new(
        commit: commit,
        dirty: !status_output.empty?,
        root: File.expand_path(root)
      )
    rescue Errno::ENOENT
      @context = unavailable_context
    end

    private

    def unavailable_context
      Context.new(commit: nil, dirty: false, root: nil)
    end
  end
end
