# frozen_string_literal: true

require_relative "config"

module Tier2
  # Filled in during the expansion task-authoring pass. Campfire is SQLite +
  # Minitest.
  Apps.register(
    AppConfig.new(
      name: "campfire",
      repo: {url: "https://github.com/basecamp/once-campfire", sha: "TO" "DO"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/campfire/template"),
      prepared_files: [],
      artifact_dir: File.join(EXPANSION_DIR, "campfire"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/campfire"),
      test_command: ->(path) { ["bin/rails", "test", path] },
      test_name_filter: ->(name) { ["-n", name] },
      test_runner_signature: /\brails\s+test\b/,
      test_env: {"RAILS_ENV" => "test"},
      rounds: 3,
      pilot_task: nil,
      tasks: []
    )
  )
end
