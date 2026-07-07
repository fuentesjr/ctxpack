# frozen_string_literal: true

require_relative "config"

module Tier2
  # Filled in during the expansion task-authoring pass. Lobsters is
  # MariaDB-backed + RSpec.
  Apps.register(
    AppConfig.new(
      name: "lobsters",
      repo: {url: "https://github.com/lobsters/lobsters", sha: "TO" "DO"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/lobsters/template"),
      prepared_files: [],
      artifact_dir: File.join(EXPANSION_DIR, "lobsters"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/lobsters"),
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
