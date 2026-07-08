# frozen_string_literal: true

module Tier2
  ROOT = File.expand_path("../../..", __dir__) unless const_defined?(:ROOT)
  TIER2_DIR = File.expand_path("..", __dir__) unless const_defined?(:TIER2_DIR)
  EXPANSION_DIR = File.expand_path("../../tier2-expansion", __dir__) unless const_defined?(:EXPANSION_DIR)

  class AppConfig
    attr_reader :name, :repo, :template_dir, :prepared_files, :remove_files,
                :artifact_dir, :work_dir, :test_command, :test_name_filter,
                :test_runner_signature, :test_env, :rounds, :pilot_task,
                :tasks

    def initialize(name:, repo:, template_dir:, prepared_files:, artifact_dir:,
                   work_dir:, test_command:, test_name_filter:,
                   test_runner_signature:, test_env:, tasks:, rounds: 3,
                   pilot_task: nil, config_dir: nil, remove_files: [])
      @name = name
      @repo = repo
      @template_dir = template_dir
      @prepared_files = prepared_files
      # Tracked files deleted from each cloned workspace and baked into the
      # workspace baseline (so the deletion never appears in the subject diff).
      # Used to neutralize repo-level agent-instruction files (CLAUDE.md /
      # AGENTS.md) that would otherwise be auto-loaded by the subject session
      # and confound / sabotage the task. Default [] → no-op for apps without
      # such files (Redmine, Campfire).
      @remove_files = remove_files
      @artifact_dir = artifact_dir
      @work_dir = work_dir
      @test_command = test_command
      @test_name_filter = test_name_filter
      @test_runner_signature = test_runner_signature
      @test_env = test_env
      @rounds = rounds
      @pilot_task = pilot_task
      @config_dir = config_dir
      @tasks = tasks
      @tasks_by_id = tasks.to_h { |task| [task.id, task] }
    end

    def repo_sha
      repo.fetch(:sha)
    end

    def task(id)
      @tasks_by_id.fetch(id)
    end

    def tasks_dir
      File.join(artifact_dir, "tasks")
    end

    def packets_dir
      File.join(artifact_dir, "packets")
    end

    def packets_meta
      File.join(packets_dir, "packets.json")
    end

    def golden_dir
      File.join(artifact_dir, "golden")
    end

    def runs_path
      File.join(artifact_dir, "runs.jsonl")
    end

    def workspaces_dir
      File.join(work_dir, "workspaces")
    end

    def score_logs_dir
      File.join(work_dir, "scoring-logs")
    end

    # Per-app override lets an app reuse another app's authenticated sterile
    # CLAUDE_CONFIG_DIR. Claude Code binds OAuth credentials to the literal
    # CLAUDE_CONFIG_DIR path (macOS Keychain), so a copied/symlinked dir is not
    # authenticated — an app must point at the exact authenticated path.
    def config_dir
      @config_dir || File.join(work_dir, "claude-config")
    end

    def stderr_dir
      File.join(work_dir, "stderr")
    end
  end

  class TaskConfig
    attr_reader :id, :anchor, :kind, :prompt_file, :seeded, :seed_patch,
                :packet_from_seeded, :failing_capture, :scoring

    def initialize(id:, anchor:, kind:, prompt_file:, seeded:, scoring:,
                   seed_patch: nil, packet_from_seeded: nil,
                   failing_capture: nil)
      @id = id
      @anchor = anchor
      @kind = kind
      @prompt_file = prompt_file
      @seeded = seeded
      @seed_patch = seed_patch
      @packet_from_seeded = packet_from_seeded.nil? ? seeded : packet_from_seeded
      @failing_capture = failing_capture
      @scoring = scoring
    end
  end

  module Apps
    REGISTRY = {}

    module_function

    def register(config)
      REGISTRY[config.name] = config
    end

    def available_names
      Dir[File.join(__dir__, "*.rb")]
        .map { |path| File.basename(path, ".rb") }
        .reject { |name| name == "config" }
        .sort
    end

    def known?(name)
      available_names.include?(name)
    end

    def load(name)
      require_relative name
      REGISTRY.fetch(name)
    rescue LoadError, KeyError
      raise "unknown app #{name.inspect}; known apps: #{available_names.join(', ')}"
    end
  end
end
