require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class HistoryIntegrationTest < Minitest::Test
  class RecordingProvider
    attr_reader :requests

    def initialize(result:)
      @result = result
      @requests = []
    end

    def fetch(**request)
      @requests << request
      @result
    end
  end

  def test_files_primary_makes_one_revision_pinned_request_after_file_selection
    app_root = fixture_app("minitest_basic")
    history = Ctxpack::History.included(
      path: "app/controllers/accounts_controller.rb",
      facts: [],
      truncated_count: 0
    )
    provider = RecordingProvider.new(result: history)
    revision, = Open3.capture2("git", "-C", app_root, "rev-parse", "HEAD")
    repo_root, = Open3.capture2("git", "-C", app_root, "rev-parse", "--show-toplevel")

    packet = Ctxpack.compile(
      app_root: app_root,
      seeds: [
        Ctxpack::Seed.files([
          "app/controllers/accounts_controller.rb",
          "app/models/order.rb"
        ]),
        Ctxpack::Seed.error(["app/controllers/accounts_controller.rb:5"])
      ],
      task: "Inspect account history",
      history_provider: provider
    )

    assert_equal 1, provider.requests.length
    assert_equal(
      {
        app_root: File.expand_path(app_root),
        repo_root: File.expand_path(repo_root.strip),
        path: "app/controllers/accounts_controller.rb",
        revision: revision.strip
      },
      provider.requests.first
    )
    assert_same history, packet.history
    assert_equal "app/controllers/accounts_controller.rb", packet.files.first.path
    assert_includes packet.file("app/controllers/accounts_controller.rb").reason_codes, "error_seed_frame"
  end

  def test_included_history_is_format_v4_and_renderers_are_pure_and_input_safe
    history = Ctxpack::History.included(
      path: "app/controllers/accounts_controller.rb",
      facts: [
        Ctxpack::HistoryFact.new(
          type: "coupled_path",
          path: "lib/```# not-a-heading.rb",
          count: 4,
          support_oid: "a" * 40
        ),
        Ctxpack::HistoryFact.new(
          type: "commit",
          oid: "b" * 40,
          subject: "``` ## not a packet section",
          roles: %w[repair recent]
        )
      ],
      truncated_count: 2
    )
    provider = RecordingProvider.new(result: history)
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [
        Ctxpack::Seed.files(["app/controllers/accounts_controller.rb"]),
        Ctxpack::Seed.error(["app/controllers/accounts_controller.rb:5"])
      ],
      task: "Inspect history",
      history_provider: provider
    )

    first_markdown = Ctxpack.render_markdown(packet)
    second_markdown = Ctxpack.render_markdown(packet)
    manifest = JSON.parse(Ctxpack.render_manifest(packet))

    assert_equal 4, packet.version
    assert_equal first_markdown, second_markdown
    assert_equal 1, provider.requests.length
    assert_operator first_markdown.index("## Evidence"), :<, first_markdown.index("## History")
    assert_operator first_markdown.index("## History"), :<, first_markdown.index("## Run")
    assert_includes first_markdown, "\\u0060\\u0060\\u0060"
    refute_match(/^## not a packet section$/, first_markdown)
    assert_includes first_markdown, "5-fact"
    assert_includes first_markdown, "2048-byte"
    assert_equal(
      {
        "status" => "included",
        "path" => "app/controllers/accounts_controller.rb",
        "facts" => [
          {
            "type" => "coupled_path",
            "path" => "lib/```# not-a-heading.rb",
            "count" => 4,
            "support_oid" => "a" * 40
          },
          {
            "type" => "commit",
            "oid" => "b" * 40,
            "subject" => "``` ## not a packet section",
            "roles" => %w[repair recent]
          }
        ],
        "truncated_count" => 2
      },
      manifest.fetch("history")
    )
    keys = packet.to_h.keys
    assert_equal keys.index("files") + 1, keys.index("history")
  end

  def test_applicable_provider_omission_preserves_primary_and_registers_one_follow_up
    history = Ctxpack::History.omitted(
      path: "app/controllers/accounts_controller.rb",
      reason: "shallow_repository"
    )
    provider = RecordingProvider.new(result: history)

    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.files(["app/controllers/accounts_controller.rb"])],
      task: "Inspect history",
      history_provider: provider
    )

    assert packet.file("app/controllers/accounts_controller.rb")
    assert_equal "omitted", packet.history.status
    assert_equal "shallow_repository", packet.history.reason
    follow_ups = packet.to_h.fetch("follow_ups").select do |item|
      item.fetch("code") == "history_context_unavailable"
    end
    assert_equal 1, follow_ups.length
    assert_equal "app/controllers/accounts_controller.rb", follow_ups.first.fetch("subject")
    markdown = Ctxpack.render_markdown(packet)
    assert_equal 1, markdown.scan("bounded local history was unavailable").length
  end

  def test_non_files_packet_has_null_history_and_does_not_call_provider
    provider = RecordingProvider.new(result: :unexpected)

    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "accounts#upgrade",
      task: "Upgrade accounts",
      history_provider: provider
    )

    assert_nil packet.history
    assert_nil packet.to_h.fetch("history")
    assert_empty provider.requests
    refute_includes Ctxpack.render_markdown(packet), "## History"
  end

  def test_files_primary_dropped_by_the_existing_file_budget_does_not_request_history
    provider = RecordingProvider.new(result: :unexpected)

    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [
        Ctxpack::Seed.anchor("saturation#show"),
        Ctxpack::Seed.files(["app/jobs/sync_billing_account_job.rb"])
      ],
      task: "Inspect saturated packet",
      history_provider: provider
    )

    assert_nil packet.file("app/jobs/sync_billing_account_job.rb")
    assert_nil packet.history
    assert_empty provider.requests
  end

  def test_files_primary_outside_git_is_an_omission_without_a_provider_call
    Dir.mktmpdir("ctxpack-history-no-git") do |tmpdir|
      FileUtils.mkdir_p(File.join(tmpdir, "app", "models"))
      File.write(File.join(tmpdir, "app", "models", "account.rb"), "class Account; end\n")
      provider = RecordingProvider.new(result: :unexpected)

      packet = Ctxpack.compile(
        app_root: tmpdir,
        seeds: [Ctxpack::Seed.files(["app/models/account.rb"])],
        task: "Inspect account",
        history_provider: provider
      )

      assert_equal "omitted", packet.history.status
      assert_equal "repository_unavailable", packet.history.reason
      assert_empty provider.requests
      assert packet.file("app/models/account.rb")
    end
  end

  def test_successful_empty_history_renders_a_fixed_no_signals_line
    history = Ctxpack::History.included(
      path: "app/controllers/accounts_controller.rb",
      facts: [],
      truncated_count: 0
    )
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.files(["app/controllers/accounts_controller.rb"])],
      task: "Inspect history",
      history_provider: RecordingProvider.new(result: history)
    )

    markdown = Ctxpack.render_markdown(packet)
    assert_includes markdown, "No bounded history signals were returned for this path."
    refute_includes markdown, "history_context_unavailable"
    assert_empty packet.to_h.fetch("history").fetch("facts")
  end
end
