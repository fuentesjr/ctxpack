require "test_helper"
require "fileutils"
require "json"
require "tmpdir"

class PacketFormatTest < Minitest::Test
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
                 "## Anchor",
                 "## Files to inspect first",
                 "## Tests to run",
                 "## Uncertainty",
                 "## Retrieve more only if needed"
    refute_includes markdown, "## Omitted candidates"

    assert_includes markdown, "## Task\nImplement billing upgrade\n\n"
    assert_includes markdown, "- Anchor: `accounts#upgrade`"
    assert_includes markdown, "- Controller: `AccountsController`"
    assert_includes markdown, "- Action: `upgrade`"
    assert_includes markdown, "- File: `app/controllers/accounts_controller.rb`"
    assert_includes markdown, "- Generated from: #{packet.repo.commit[0, 7]} (#{packet.repo.dirty ? "dirty" : "clean"})"

    assert_equal packet.files.map { |entry| "### `#{entry.path}`\n" },
                 markdown.lines.grep(/\A### /)

    assert_includes markdown, <<~MARKDOWN
      Why: controller action for requested anchor.
      Reason code: `controller_action`

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
      Why: callback `set_account` applies to the requested action.
      Reason code: `before_action_callback`

      ```ruby
        def set_account
          @account = Account.find(params[:id])
        end
      ```
    MARKDOWN

    assert_includes markdown, <<~MARKDOWN
      Why: constant `Billing::Subscriptions` was referenced by the action or an applicable callback.
      Reason code: `referenced_constant`
    MARKDOWN

    assert_includes markdown, <<~MARKDOWN
      Why: test file matched the conventional controller test path.
      Reason code: `minitest_candidate`
    MARKDOWN

    assert_includes markdown, "- `bin/rails test test/controllers/accounts_controller_test.rb`"
    assert_includes markdown, "- `bin/rails test test/integration/accounts_upgrade_test.rb`"

    assert_includes markdown, "- Test file `test/integration/accounts_upgrade_test.rb` was inferred by path and should be verified."
    assert_includes markdown, "- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved."
    assert_includes markdown, "- Route discovery is delegated to Rails; run `bin/rails routes -g upgrade` if the exact endpoint matters."
    assert_includes markdown, "- Convention-only constant match `Billing::Subscriptions` resolved to `app/services/billing/subscriptions.rb`; verify it if the task depends on that behavior."

    assert_includes markdown, "- Inspect test file `test/integration/accounts_upgrade_test.rb` to confirm the path-inferred Minitest candidate covers the task."
    assert_includes markdown, "- Inspect applicable `around_action` behavior for `with_billing_audit` if it affects the task."
    assert_includes markdown, "- Inspect inline callback block behavior for `before_action` if it affects the task."
    refute_match(/\b\d{4}-\d{2}-\d{2}\b/, markdown)
  end

  def test_fmt_2_retrieve_more_uses_one_templated_suggestion_per_uncertainty_code
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "callback_edges#upgrade"
    )

    retrieve_more = markdown_section(Ctxpack.render_markdown(packet), "## Retrieve more only if needed")

    assert_equal 1, retrieve_more.scan("dynamic callback arguments").length
    assert_includes retrieve_more,
                    "- Inspect callback declarations with dynamic callback arguments: `dynamic_skip_callback`, `dynamic_options_callback`, `before_action`, `conditional_callback`."
    assert_includes retrieve_more, "- Inspect the superclass or concerns for callback `external_callback`."
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

    assert_includes markdown, "## Task\nNo task was provided.\n\n"
    assert_includes markdown, "- Generated from: unknown (not a git repository)"
    assert_includes markdown, "No Minitest candidates were found by ctxpack's path rules."
    assert_includes markdown, "## Retrieve more only if needed\n- Search `test/` by hand if the task needs test coverage."
  end

  def test_fmt_2_retrieve_more_is_omitted_when_no_uncertainty_or_omission_codes_are_present
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

    refute_includes Ctxpack.render_markdown(packet), "## Retrieve more only if needed"
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
    assert_includes markdown, "Snippet `show` was omitted because action snippet exceeded max snippet lines per file."
    assert_includes markdown, "Snippet `short_callback` was omitted because callback snippet exceeded remaining snippet lines per file."
    assert_includes markdown, "Inspect omitted snippets manually: `show`, `short_callback`."
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

  def test_fmt_9_omitted_candidates_names_truncated_constants_and_tests
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

    assert_includes constants_markdown, "## Omitted candidates"
    assert_includes constants_markdown, "Constant `EpsilonFive` was omitted because max constant files limit reached."
    assert_includes constants_markdown, "Inspect omitted constant `EpsilonFive` manually."

    assert_includes tests_markdown, "## Omitted candidates"
    assert_includes tests_markdown, "Test file `test/integration/search_bulk_update_c_test.rb` was omitted because max test files limit reached."
    assert_includes tests_markdown, "Inspect omitted test file `test/integration/search_bulk_update_c_test.rb` manually."
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
    assert_equal %w[version anchor repo entrypoint files tests uncertainty],
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
