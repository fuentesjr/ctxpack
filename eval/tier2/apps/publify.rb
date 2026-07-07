# frozen_string_literal: true

require_relative "config"

module Tier2
  # Filled in during the expansion task-authoring pass. Publify is SQLite +
  # RSpec.
  Apps.register(
    AppConfig.new(
      name: "publify",
      repo: {url: "https://github.com/publify/publify", sha: "TO" "DO"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/publify/template"),
      prepared_files: [],
      artifact_dir: File.join(EXPANSION_DIR, "publify"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/publify"),
      test_command: ->(path) { ["bundle", "exec", "rspec", path] },
      test_name_filter: ->(name) { ["-e", name] },
      test_runner_signature: /\brspec\b/,
      test_env: {"RAILS_ENV" => "test"},
      rounds: 3,
      pilot_task: nil,
      tasks: []
    )
  )
end
