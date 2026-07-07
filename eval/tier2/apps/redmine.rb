# frozen_string_literal: true

require_relative "config"

module Tier2
  Apps.register(
    AppConfig.new(
      name: "redmine",
      repo: {
        url: "https://github.com/redmine/redmine",
        sha: "3386d9595767b3d0c455ace9281e056e9f61bd56"
      },
      template_dir: File.join(ROOT, "tmp/tier2/template"),
      prepared_files: ["config/database.yml", "Gemfile.lock", "db/redmine_test.sqlite3"],
      artifact_dir: TIER2_DIR,
      work_dir: File.join(ROOT, "tmp/tier2"),
      test_command: ->(path) { ["bin/rails", "test", path] },
      test_name_filter: ->(name) { ["-n", name] },
      test_runner_signature: /\brails\s+test\b/,
      test_env: {"RAILS_ENV" => "test"},
      rounds: 3,
      pilot_task: 2,
      tasks: [
        TaskConfig.new(
          id: 1,
          anchor: "twofa#deactivate_init",
          kind: :feature,
          prompt_file: "task1_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task1_acceptance_test.rb",
              dest: "test/functional/tier2_task1_acceptance_test.rb"
            },
            test_target: "test/functional/tier2_task1_acceptance_test.rb"
          }
        ),
        TaskConfig.new(
          id: 2,
          anchor: "my#show_api_key",
          kind: :bug,
          prompt_file: "task2_prompt.md",
          seeded: true,
          seed_patch: "task2_seed.patch",
          packet_from_seeded: true,
          failing_capture: {
            test_target: "test/functional/my_controller_test.rb",
            filter_name: "test_show_api_key",
            expect_pattern: /1 failures|1 errors/,
            token: "{failing_test_output}",
            output_file: "tasks/task2_failing_output.txt"
          },
          scoring: {
            test_target: "test/functional/my_controller_test.rb",
            forbid_edits_under: ["test/"]
          }
        ),
        TaskConfig.new(
          id: 3,
          anchor: "roles#create",
          kind: :behavior,
          prompt_file: "task3_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task3_acceptance_test.rb",
              dest: "test/functional/tier2_task3_acceptance_test.rb"
            },
            test_target: "test/functional/tier2_task3_acceptance_test.rb"
          }
        )
      ]
    )
  )
end
