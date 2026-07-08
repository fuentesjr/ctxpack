# frozen_string_literal: true

require_relative "config"

module Tier2
  # Lobsters is MariaDB-backed (primary DB via the trilogy adapter) + RSpec.
  # Environment prep + traps: eval/tier2-expansion/lobsters/README.md.
  #
  # prepared_files: git clone --local copies only the committed tree, so the
  # two gitignored/patched files each workspace needs are copied in after clone:
  #   - config/database.yml — copied from database.yml.sample (points primary at
  #     the local MariaDB @ 127.0.0.1/lobsters_test, per the app's sample creds).
  #   - Gemfile.lock — the committed lock lacks the x86_64-darwin platform, so a
  #     clone would fail `bundle exec rspec`; the patched lock (bundled locally)
  #     carries it. The primary test DB (lobsters_test) lives server-side in the
  #     shared local MariaDB, not per-workspace; serial runs + RSpec
  #     transactional/truncation cleaning keep it clean between sessions.
  Apps.register(
    AppConfig.new(
      name: "lobsters",
      repo: {url: "https://github.com/lobsters/lobsters", sha: "430d864b0d7bf1b30913ee42e6cca3d9fbddcaa4"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/lobsters/template"),
      prepared_files: ["config/database.yml", "Gemfile.lock"],
      # Lobsters ships a committed CLAUDE.md (symlink) + AGENTS.md instructing
      # coding agents to refuse all contributions — aimed at PRs to the project,
      # but a subject session would auto-load CLAUDE.md and refuse the eval task.
      # We remove them from each sterile workspace (offline benchmark; nothing is
      # contributed upstream). See README.md "Agent-instruction files".
      remove_files: ["CLAUDE.md", "AGENTS.md"],
      artifact_dir: File.join(EXPANSION_DIR, "lobsters"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/lobsters"),
      # Reuse Redmine's authenticated sterile CLAUDE_CONFIG_DIR: Claude Code
      # binds OAuth to the literal config-dir path (Keychain), so a copy is not
      # authenticated. See AppConfig#config_dir. (Same rationale as Campfire.)
      config_dir: File.join(ROOT, "tmp/tier2/claude-config"),
      test_command: ->(path) { ["bundle", "exec", "rspec", path] },
      test_name_filter: ->(name) { ["-e", name] },
      test_runner_signature: /\brspec\b/,
      test_env: {"RAILS_ENV" => "test"},
      rounds: 3,
      pilot_task: 3,
      tasks: [
        TaskConfig.new(
          id: 1,
          anchor: "comments#disown",
          kind: :feature,
          prompt_file: "task1_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task1_acceptance_spec.rb",
              dest: "spec/requests/tier2_task1_acceptance_spec.rb"
            },
            test_target: "spec/requests/tier2_task1_acceptance_spec.rb"
          }
        ),
        TaskConfig.new(
          id: 2,
          anchor: "users#standing",
          kind: :feature,
          prompt_file: "task2_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task2_acceptance_spec.rb",
              dest: "spec/requests/tier2_task2_acceptance_spec.rb"
            },
            test_target: "spec/requests/tier2_task2_acceptance_spec.rb"
          }
        ),
        TaskConfig.new(
          id: 3,
          anchor: "inbox#all",
          kind: :bug,
          prompt_file: "task3_prompt.md",
          seeded: true,
          seed_patch: "task3_seed.patch",
          packet_from_seeded: true,
          failing_capture: {
            test_target: "spec/controllers/inbox_controller_spec.rb",
            filter_name: "marks the notification and associated message as read",
            expect_pattern: /[1-9]\d* failures?\b/,
            token: "{failing_test_output}",
            output_file: "tasks/task3_failing_output.txt"
          },
          scoring: {
            test_target: "spec/controllers/inbox_controller_spec.rb",
            forbid_edits_under: ["spec/"]
          }
        ),
        TaskConfig.new(
          id: 4,
          anchor: "stories#update",
          kind: :behavior,
          prompt_file: "task4_prompt.md",
          seeded: false,
          scoring: {
            acceptance_test: {
              source: "task4_acceptance_spec.rb",
              dest: "spec/requests/tier2_task4_acceptance_spec.rb"
            },
            test_target: "spec/requests/tier2_task4_acceptance_spec.rb"
          }
        )
      ]
    )
  )
end
