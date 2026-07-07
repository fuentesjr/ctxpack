# frozen_string_literal: true

require_relative "config"

module Tier2
  # Filled in during the expansion task-authoring pass. Campfire is SQLite +
  # Minitest.
  Apps.register(
    AppConfig.new(
      name: "campfire",
      repo: {url: "https://github.com/basecamp/once-campfire", sha: "71ffeeea789599a334311f28bcb6816863985488"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/campfire/template"),
      prepared_files: ["storage/db/test.sqlite3"],
      artifact_dir: File.join(EXPANSION_DIR, "campfire"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/campfire"),
      # Reuse Redmine's authenticated sterile CLAUDE_CONFIG_DIR: Claude Code
      # binds OAuth to the literal config-dir path (Keychain), so a copy is not
      # authenticated. See AppConfig#config_dir.
      config_dir: File.join(ROOT, "tmp/tier2/claude-config"),
      test_command: ->(path) { ["bin/rails", "test", path] },
      test_name_filter: ->(name) { ["-n", name] },
      test_runner_signature: /\brails\s+test\b/,
      test_env: {"RAILS_ENV" => "test"},
      rounds: 3,
      pilot_task: 3,
      tasks: [
        TaskConfig.new(
          id: 1,
          anchor: "autocompletable/users#index",
          kind: :feature,
          prompt_file: "task1_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task1_acceptance_test.rb",
              dest: "test/integration/tier2_task1_acceptance_test.rb"
            },
            test_target: "test/integration/tier2_task1_acceptance_test.rb"
          }
        ),
        TaskConfig.new(
          id: 2,
          anchor: "accounts#edit",
          kind: :feature,
          prompt_file: "task2_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task2_acceptance_test.rb",
              dest: "test/integration/tier2_task2_acceptance_test.rb"
            },
            test_target: "test/integration/tier2_task2_acceptance_test.rb"
          }
        ),
        TaskConfig.new(
          id: 3,
          anchor: "rooms#index",
          kind: :bug,
          prompt_file: "task3_prompt.md",
          seeded: true,
          seed_patch: "task3_seed.patch",
          packet_from_seeded: true,
          failing_capture: {
            test_target: "test/controllers/rooms_controller_test.rb",
            filter_name: "test_index_redirects_to_the_user's_last_room",
            expect_pattern: /1 failures|1 errors/,
            token: "{failing_test_output}",
            output_file: "tasks/task3_failing_output.txt"
          },
          scoring: {
            test_target: "test/controllers/rooms_controller_test.rb",
            forbid_edits_under: ["test/"]
          }
        ),
        TaskConfig.new(
          id: 4,
          anchor: "rooms/involvements#update",
          kind: :behavior,
          prompt_file: "task4_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task4_acceptance_test.rb",
              dest: "test/integration/tier2_task4_acceptance_test.rb"
            },
            test_target: "test/integration/tier2_task4_acceptance_test.rb"
          }
        )
      ]
    )
  )
end
