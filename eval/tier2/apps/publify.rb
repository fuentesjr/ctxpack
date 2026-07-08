# frozen_string_literal: true

require_relative "config"

module Tier2
  # Publify is SQLite + RSpec. The pinned unit is the publify_core ENGINE
  # (publify/publify_core v10.0.3), not the publify deploy app: the deploy app
  # is a thin shell (only app/controllers/application_controller.rb), while the
  # 31 real controllers live in publify_core. Pinning the engine keeps a
  # self-contained SQLite/RSpec unit. Env prep + the engine wrinkles are in
  # eval/tier2-expansion/publify/README.md.
  #
  # prepared_files (copied into each workspace after `git clone --local`, which
  # only carries the committed tree):
  #   - config/application.rb — a stub whose ONLY purpose is to satisfy ctxpack's
  #     app-root discovery (File.file? check); it is never booted (rspec loads
  #     spec/dummy/config/environment). The engine root has no config/application.rb
  #     of its own. Baked into the workspace baseline so it never appears in a
  #     subject diff.
  #   - Gemfile — patched to pin concurrent-ruby 1.3.4 (>= 1.3.5 dropped its
  #     implicit `require "logger"`, breaking Rails 6.1). Tracked+modified, so it
  #     must be copied in (the clone carries the unpatched committed Gemfile) and
  #     is baked into the baseline.
  #   - Gemfile.lock — gitignored upstream; the locally-bundled lock is copied in
  #     so `bundle exec rspec` resolves deterministically. Gitignored → never in
  #     the subject diff.
  #   - spec/dummy/db/test.sqlite3 — the prepared dummy-app test DB (gitignored),
  #     copied so each workspace starts ready (no per-workspace schema load).
  Apps.register(
    AppConfig.new(
      name: "publify",
      repo: {url: "https://github.com/publify/publify_core", sha: "80ede867d802949e218fdf0bb4f3c31f68f8a56a"},
      template_dir: File.join(ROOT, "tmp/tier2-expansion/publify/template"),
      prepared_files: ["config/application.rb", "Gemfile", "Gemfile.lock", "spec/dummy/db/test.sqlite3"],
      artifact_dir: File.join(EXPANSION_DIR, "publify"),
      work_dir: File.join(ROOT, "tmp/tier2-expansion/publify"),
      # Reuse Redmine's authenticated sterile CLAUDE_CONFIG_DIR: Claude Code
      # binds OAuth to the literal config-dir path (Keychain), so a copy is not
      # authenticated. See AppConfig#config_dir. (Same as Campfire/Lobsters.)
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
          anchor: "setup#index",
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
          anchor: "tags#index",
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
          anchor: "articles#preview",
          kind: :bug,
          prompt_file: "task3_prompt.md",
          seeded: true,
          seed_patch: "task3_seed.patch",
          packet_from_seeded: true,
          failing_capture: {
            test_target: "spec/controllers/articles_controller_spec.rb",
            filter_name: "assignes last article with id like parent_id",
            expect_pattern: /[1-9]\d* failures?\b/,
            token: "{failing_test_output}",
            output_file: "tasks/task3_failing_output.txt"
          },
          scoring: {
            test_target: "spec/controllers/articles_controller_spec.rb",
            forbid_edits_under: ["spec/"]
          }
        ),
        TaskConfig.new(
          id: 4,
          anchor: "admin/users#destroy",
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
