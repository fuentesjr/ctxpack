require "test_helper"
require "fileutils"
require "json"
require "tmpdir"

class PacketFormatTest < Minitest::Test
  def test_fmt_7_test_3_path_inference_rendering_uses_semantic_packet_uncertainty
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: "Check coverage",
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )
    path = "test/integration/accounts_upgrade_test.rb"
    packet.tests << Ctxpack::TestCandidate.new(
      path: path,
      command: "bin/rails test #{path}",
      reason_code: "minitest_candidate",
      why: "matched integration test path tokens",
      rule: "future_semantic_rule_name"
    )
    packet.add_file(path).add_evidence(
      Ctxpack::EvidenceItem.new(
        reason_code: "minitest_candidate",
        subject: path,
        why: "matched integration test path tokens",
        snippet_ranges: [],
        truncated: false
      )
    )
    packet.add_uncertainty(
      code: "test_inferred_by_path",
      subject: path,
      message: "test candidate was inferred by path"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "`#{path}` — `minitest_candidate`: path-inferred; verify coverage"
    assert_includes markdown, "- `bin/rails test #{path}` — path-inferred; verify coverage"
  end

  def test_fmt_2_blockquotes_every_task_line_so_multiline_markdown_cannot_create_sections
    task = <<~TASK.chomp
      ## Injected heading

      - first item

      ```ruby
      puts "inside task"
      ```
    TASK
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: task
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, <<~MARKDOWN
      ## Task

      > ## Injected heading
      >
      > - first item
      >
      > ```ruby
      > puts "inside task"
      > ```
    MARKDOWN
    assert_equal ["## Task", "## How to use this packet", "## Anchor", "## Inspect first", "## Evidence", "## Run", "## Follow-ups"],
                 markdown.lines.grep(/\A## /).map(&:chomp)

    empty_task_packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: ""
    )
    assert_includes Ctxpack.render_markdown(empty_task_packet), "## Task\n\n>\n\n"
  end

  def test_fmt_2_normalizes_bare_carriage_returns_for_display_but_preserves_raw_manifest_task
    task = "First line\r## Injected heading\r- item"
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: task
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "## Task\n\n> First line\n> ## Injected heading\n> - item\n\n"
    refute_includes markdown, "\r"
    assert_equal task, JSON.parse(Ctxpack.render_manifest(packet)).fetch("task")
  end

  def test_fmt_2_places_a_blank_line_after_every_level_two_heading
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Check formatting"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "## Task\n\n> Check formatting"
    assert_includes markdown, "## Anchor\n\n- Anchor: `accounts#upgrade`"
    assert_includes markdown, "## Run\n\n- `bin/rails test"
    markdown.lines.grep(/\A## /).each do |heading|
      assert_includes markdown, "#{heading}\n"
    end
  end

  def test_fmt_2_pointer_only_packet_keeps_inspect_item_and_omits_evidence_section
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: "Inspect view",
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )
    path = "app/views/accounts/upgrade.html.erb"
    packet.add_file(path).add_evidence(
      Ctxpack::EvidenceItem.new(
        reason_code: "view_candidate",
        subject: "accounts#upgrade",
        why: "conventional view template for accounts#upgrade",
        snippet_ranges: [],
        truncated: false
      )
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "1. `#{path}` — `view_candidate`: conventional template for `accounts#upgrade`"
    refute_includes markdown, "## Evidence"
  end

  def test_fmt_2_5_11_declares_format_ranges_and_honest_unavailable_git_state
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: "Check upgrade",
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      app_root: fixture_app("minitest_basic"),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )
    packet.add_file("app/controllers/accounts_controller.rb").add_evidence(
      Ctxpack::EvidenceItem.new(
        reason_code: "controller_action",
        subject: "upgrade",
        why: "controller action for requested anchor",
        snippet_ranges: [[10, 15], [19, 20]],
        truncated: false
      )
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "- Generated from: unknown (Git state unavailable)"
    assert_includes markdown, "- Format: 2"
    assert_includes markdown, "`controller_action` — action `upgrade` · lines 10–15, 19–20"
  end

  def test_fmt_2_3_4_4a_5_det_2_renders_map_snippet_evidence_and_runnable_tests
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_order markdown,
                 "## Task",
                 "## How to use this packet",
                 "## Anchor",
                 "## Inspect first",
                 "## Evidence",
                 "## Run"
    assert_includes markdown, "- If the task already names a failing test, an error, or an exact location, start there and use this packet to verify coverage — not as a reading list."
    assert_includes markdown, "- Otherwise, start with `app/controllers/accounts_controller.rb` and open the other listed files only as the task touches them."

    inspect_first = markdown_section(markdown, "## Inspect first")
    assert_equal packet.files.map(&:path), inspect_first.scan(/`([^`]+)` —/).flatten
    assert_includes inspect_first, "`app/controllers/accounts_controller.rb` — `controller_action`: action and applicable callbacks"
    assert_includes inspect_first, "`app/services/billing/subscriptions.rb` — `referenced_constant`: `Billing::Subscriptions`"
    assert_includes inspect_first, "`test/integration/accounts_upgrade_test.rb` — `minitest_candidate`: path-inferred; verify coverage"

    evidence = markdown_section(markdown, "## Evidence")
    assert_includes evidence, "### `app/controllers/accounts_controller.rb`"
    assert_includes evidence, "`controller_action` — action `upgrade` · lines 10–15"
    refute_includes evidence, "### `app/services/billing/subscriptions.rb`"
    refute_includes evidence, "### `test/controllers/accounts_controller_test.rb`"

    run = markdown_section(markdown, "## Run")
    assert_includes run, "- `bin/rails test test/controllers/accounts_controller_test.rb`"
    assert_includes run, "- `bin/rails test test/integration/accounts_upgrade_test.rb` — path-inferred; verify coverage"
  end

  def test_fmt_2_8_9_renders_standing_scope_once_and_deduplicated_imperative_follow_ups
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    markdown = Ctxpack.render_markdown(packet)
    follow_ups = markdown_section(markdown, "## Follow-ups")

    assert_equal 1, markdown.scan("routes, superclass/concern callbacks, and locale files are not scanned by ctxpack v0").length
    assert_equal 1, markdown.scan("bin/rails routes -g upgrade").length
    assert_equal 1, markdown.scan("config/locales/").length
    refute_includes markdown, "## Uncertainty"
    refute_includes markdown, "## Omitted candidates"
    refute_includes markdown, "## Retrieve more only if needed"
    assert_equal follow_ups.lines.grep(/\A- /).uniq, follow_ups.lines.grep(/\A- /)
    assert_includes follow_ups, "- Inspect `around_action` callback `with_billing_audit`; it applies but is not snippeted in v0."
    assert_includes follow_ups, "- Inspect the inline `before_action` block; it applies but has no method snippet."
    assert_includes follow_ups, "- Inspect `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred candidate covers the task."
    assert_includes follow_ups, "- Verify convention-only constant match `Billing::Subscriptions` → `app/services/billing/subscriptions.rb` if the task depends on it."

    with_compiler_limits(max_constant_files: 1) do
      limited_packet = Ctxpack.compile(
        app_root: fixture_app("minitest_basic"),
        anchor: "constant_limits#show"
      )
      limited_follow_ups = markdown_section(Ctxpack.render_markdown(limited_packet), "## Follow-ups")

      assert_includes limited_follow_ups, "- Inspect omitted constant `BetaTwo`; the 1-constant limit was reached."
      refute_includes limited_follow_ups, "the 4-constant limit"
    end
  end

  def test_man_2_3_manifest_v2_serializes_complete_packet_facts_with_stable_key_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement\n\nbilling upgrade"
    )

    json = Ctxpack.render_manifest(packet)
    manifest = JSON.parse(json)

    assert_equal %w[version task anchor repo entrypoint files tests follow_ups omitted_candidates no_test_candidates],
                 json.scan(/\n  "([^"]+)":/).flatten
    assert_equal 2, manifest.fetch("version")
    assert_equal "Implement\n\nbilling upgrade", manifest.fetch("task")
    assert_equal true, manifest.fetch("repo").fetch("available")
    assert_equal packet.repo.commit, manifest.fetch("repo").fetch("commit")

    controller = manifest.fetch("files").first
    assert_equal %w[path evidence], controller.keys
    action = controller.fetch("evidence").first
    assert_equal %w[reason_code subject snippet_ranges truncated], action.keys
    assert_equal "upgrade", action.fetch("subject")
    assert_equal [[10, 15]], action.fetch("snippet_ranges")
    assert_equal false, action.fetch("truncated")

    inferred_test = manifest.fetch("tests").find { |test| test.fetch("rule") == "integration_path_match" }
    assert_equal %w[path command reason_code rule], inferred_test.keys
    assert_equal "test/integration/accounts_upgrade_test.rb", inferred_test.fetch("path")
    assert_includes manifest.fetch("follow_ups"), {
      "code" => "test_inferred_by_path",
      "subject" => "test/integration/accounts_upgrade_test.rb"
    }
    assert_includes manifest.fetch("follow_ups"), {
      "code" => "convention_constant_match",
      "subject" => "Billing::Subscriptions",
      "path" => "app/services/billing/subscriptions.rb"
    }
    assert_equal false, manifest.fetch("no_test_candidates")

    limited_manifest = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "constant_limits#show"
    ).to_h
    assert_includes limited_manifest.fetch("omitted_candidates"), {
      "category" => "constant_files",
      "subject" => "EpsilonFive",
      "reason" => "max constant files limit reached",
      "limit_key" => "max_constant_files"
    }
    assert_includes limited_manifest.fetch("follow_ups"), {
      "code" => "omitted_candidate",
      "subject" => "EpsilonFive",
      "category" => "constant_files",
      "limit_key" => "max_constant_files"
    }

    unavailable = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: nil,
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )
    unavailable.no_test_candidates = true
    unavailable_manifest = JSON.parse(Ctxpack.render_manifest(unavailable))

    assert_nil unavailable_manifest.fetch("task")
    assert_equal false, unavailable_manifest.fetch("repo").fetch("available")
    assert_nil unavailable_manifest.fetch("repo").fetch("commit")
    assert_equal [], unavailable_manifest.fetch("tests")
    assert_equal true, unavailable_manifest.fetch("no_test_candidates")
    assert_includes unavailable_manifest.fetch("follow_ups"), {
      "code" => "no_test_candidates",
      "subject" => "test/"
    }
  end

  def test_fmt_1_2_3_4_6_8_11_det_2_3_5_renders_markdown_packet_from_compiled_fixture
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert markdown.start_with?("# ctxpack context packet\n\n")
    assert_order markdown,
                 "# ctxpack context packet",
                 "## Task",
                 "## How to use this packet",
                 "## Anchor",
                 "## Inspect first",
                 "## Evidence",
                 "## Run",
                 "## Follow-ups"

    assert_includes markdown, "## Task\n\n> Implement billing upgrade\n\n"
    assert_includes markdown, "- Anchor: `accounts#upgrade`"
    assert_includes markdown, "- Controller: `AccountsController`"
    assert_includes markdown, "- Action: `upgrade`"
    assert_includes markdown, "- File: `app/controllers/accounts_controller.rb`"
    assert_includes markdown, "- Generated from: #{packet.repo.commit[0, 7]} (#{packet.repo.dirty ? "dirty" : "clean"})"

    assert_includes markdown, <<~MARKDOWN
      `controller_action` — action `upgrade` · lines 10–15

      ```ruby
        def upgrade
          subscription = Billing::Subscriptions.new(@account)
          subscription.upgrade!(plan: params[:plan])
          SyncBillingAccountJob.perform_later(@account.id)
          redirect_to account_path(@account)
        end
      ```
    MARKDOWN

    assert_includes markdown, <<~MARKDOWN
      `before_action_callback` — callback `set_account` applies · lines 23–25

      ```ruby
        def set_account
          @account = Account.find(params[:id])
        end
      ```
    MARKDOWN
    refute_match(/\b\d{4}-\d{2}-\d{2}\b/, markdown)
  end

  def test_fmt_2_follow_ups_name_each_uncertainty_subject_once
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "callback_edges#upgrade"
    )

    follow_ups = markdown_section(Ctxpack.render_markdown(packet), "## Follow-ups")

    %w[dynamic_skip_callback dynamic_options_callback before_action conditional_callback].each do |subject|
      assert_equal 1, follow_ups.scan("callback declaration `#{subject}`").length
    end
    assert_includes follow_ups, "- Inspect the superclass or concerns for callback `external_callback`; it applies but is not defined in this controller file."
  end

  def test_fmt_6_8_test_3_renders_rspec_candidate_reason_and_uncertainty_text
    packet = Ctxpack.compile(
      app_root: fixture_app("rspec_basic"),
      anchor: "accounts#upgrade"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "`spec/controllers/accounts_controller_spec.rb` — `rspec_candidate`: conventional controller spec path"
    assert_includes markdown, "`spec/requests/accounts_upgrade_spec.rb` — `rspec_candidate`: path-inferred; verify coverage"
    assert_includes markdown, "- `bundle exec rspec spec/requests/accounts_upgrade_spec.rb` — path-inferred; verify coverage"
    assert_includes markdown, "- Inspect `spec/requests/accounts_upgrade_spec.rb` to confirm the path-inferred candidate covers the task."
  end

  def test_fmt_2_11_test_5_renders_nil_task_unknown_repo_and_no_test_candidates
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: nil,
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )
    packet.no_test_candidates = true

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, "## Task\n\n> No task was provided.\n\n"
    assert_includes markdown, "- Generated from: unknown (Git state unavailable)"
    assert_includes markdown, "No Minitest candidates were found by ctxpack's path rules."
    assert_includes markdown, "## Follow-ups\n\n- Search `test/` by hand if the task needs test coverage."
  end

  def test_fmt_2_follow_ups_is_omitted_when_no_packet_specific_findings_are_present
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: "Check upgrade",
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )

    refute_includes Ctxpack.render_markdown(packet), "## Follow-ups"
  end

  def test_fmt_5_truncated_snippet_marker_is_inside_the_ruby_fence
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "long_snippets#show"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, <<~MARKDOWN
          touch 119
      # … truncated by ctxpack at 120 lines
      ```
    MARKDOWN
    refute_includes markdown, "    touch 120"
    assert_includes markdown, "Inspect omitted snippet `show`; the 120-line per-file snippet limit was reached."
    assert_includes markdown, "Inspect omitted snippet `short_callback`; the 120-line per-file snippet limit was reached."
  end

  def test_fmt_5_truncated_snippet_marker_uses_current_compiler_limit
    with_compiler_limits(max_snippet_lines_per_file: 7) do
      Dir.mktmpdir("ctxpack-renderer") do |app_root|
        FileUtils.mkdir_p(File.join(app_root, "app", "controllers"))
        File.write(
          File.join(app_root, "app", "controllers", "accounts_controller.rb"),
          "def upgrade\nend\n"
        )

        packet = Ctxpack::Packet.new(
          anchor: "accounts#upgrade",
          task: "Check upgrade",
          repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
          app_root: app_root,
          entrypoint: Ctxpack::Entrypoint.new(
            file: "app/controllers/accounts_controller.rb",
            controller: "AccountsController",
            action: "upgrade"
          )
        )
        packet.add_file("app/controllers/accounts_controller.rb").add_evidence(
          Ctxpack::EvidenceItem.new(
            reason_code: "controller_action",
            subject: "upgrade",
            why: "controller action for requested anchor",
            snippet_ranges: [[1, 1]],
            truncated: true
          )
        )

        markdown = Ctxpack.render_markdown(packet)

        assert_includes markdown, "# … truncated by ctxpack at 7 lines"
        refute_includes markdown, "# … truncated by ctxpack at 120 lines"
      end
    end
  end

  def test_fmt_9_follow_ups_name_omitted_constants_and_tests
    constants_packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "constant_limits#show"
    )
    tests_packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "search#bulk_update"
    )

    constants_markdown = Ctxpack.render_markdown(constants_packet)
    tests_markdown = Ctxpack.render_markdown(tests_packet)

    assert_includes constants_markdown, "## Follow-ups"
    assert_includes constants_markdown, "Inspect omitted constant `EpsilonFive`; the 4-constant limit was reached."

    assert_includes tests_markdown, "## Follow-ups"
    assert_includes tests_markdown, "Inspect omitted test file `test/integration/search_bulk_update_c_test.rb`; the 2-test limit was reached."
  end

  def test_man_2_3_render_manifest_uses_packet_hash_with_stable_key_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )

    json = Ctxpack.render_manifest(packet)
    parsed = JSON.parse(json)

    assert_equal packet.to_h, parsed
    assert_equal %w[version task anchor repo entrypoint files tests follow_ups omitted_candidates no_test_candidates],
                 json.scan(/\n  "([^"]+)":/).flatten
    assert_equal packet.repo.commit, parsed.fetch("repo").fetch("commit")
    refute_includes json, "app_root"
  end

  def test_man_2_render_manifest_uses_null_commit_outside_git
    packet = Ctxpack::Packet.new(
      anchor: "accounts#upgrade",
      task: nil,
      repo: Ctxpack::RepoStamp.new(commit: nil, dirty: false),
      entrypoint: Ctxpack::Entrypoint.new(
        file: "app/controllers/accounts_controller.rb",
        controller: "AccountsController",
        action: "upgrade"
      )
    )

    assert_nil JSON.parse(Ctxpack.render_manifest(packet)).fetch("repo").fetch("commit")
  end

  private

  def assert_order(text, *needles)
    positions = needles.map { |needle| text.index(needle) || flunk("missing #{needle.inspect}") }
    assert_equal positions.sort, positions
  end

  def markdown_section(text, heading)
    start = text.index(heading) || flunk("missing #{heading.inspect}")
    rest = text[start..]
    following = rest.index(/\n## /, heading.length)
    following ? rest[0...following] : rest
  end

  def with_compiler_limits(overrides)
    original = Ctxpack::Compiler::LIMITS
    Ctxpack::Compiler.send(:remove_const, :LIMITS)
    Ctxpack::Compiler.const_set(:LIMITS, original.merge(overrides).freeze)
    yield
  ensure
    Ctxpack::Compiler.send(:remove_const, :LIMITS)
    Ctxpack::Compiler.const_set(:LIMITS, original)
  end
end
