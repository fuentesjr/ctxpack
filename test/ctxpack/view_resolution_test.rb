require "test_helper"

class ViewResolutionTest < Minitest::Test
  def test_view_1_2_3_6_7_includes_namespaced_view_with_empty_snippet_and_uncertainty
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "admin/widgets#show"
    )

    assert_equal [
      "app/controllers/admin/widgets_controller.rb",
      "app/views/admin/widgets/show.html.erb"
    ], packet.files.map(&:path)

    view = packet.file("app/views/admin/widgets/show.html.erb")
    refute_nil view
    assert_equal ["view_candidate"], view.reason_codes
    evidence = view.evidence_for("view_candidate").first
    assert_equal "admin/widgets#show", evidence.subject
    assert_empty evidence.snippet_ranges
    refute evidence.truncated
    assert(packet.uncertainty.any? { |note| note.code == "view_inferred_by_convention" })

    manifest_view = packet.to_h.fetch("files").find do |entry|
      entry.fetch("path") == "app/views/admin/widgets/show.html.erb"
    end
    assert_equal [], manifest_view.fetch("snippet_ranges")
  end

  def test_view_2_includes_all_format_variants_in_lexicographic_order
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "catalog_items#index"
    )

    assert_equal [
      "app/views/catalog_items/index.html.erb",
      "app/views/catalog_items/index.json.jbuilder"
    ], packet.files_with_reason("view_candidate").map(&:path)
  end

  def test_view_1_missing_template_does_not_fail_or_emit_view_uncertainty
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "viewless_reports#preview"
    )

    assert_equal ["app/controllers/viewless_reports_controller.rb"], packet.files.map(&:path)
    assert_empty packet.files_with_reason("view_candidate")
    refute(packet.uncertainty.any? { |note| note.code == "view_inferred_by_convention" })
  end

  def test_view_2_excludes_partials
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "partial_examples#show"
    )

    assert_equal ["app/views/partial_examples/show.html.erb"],
                 packet.files_with_reason("view_candidate").map(&:path)
    refute packet.file("app/views/partial_examples/_form.html.erb")
  end

  def test_view_5_truncates_view_variants_and_records_omitted_candidate
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "view_budgets#index"
    )

    assert_equal [
      "app/views/view_budgets/index.html.erb",
      "app/views/view_budgets/index.json.jbuilder"
    ], packet.files_with_reason("view_candidate").map(&:path)
    assert_nil packet.file("app/views/view_budgets/index.turbo_stream.erb")
    assert(packet.omitted_candidates.any? do |candidate|
      candidate.category == "view_files" &&
        candidate.subject == "app/views/view_budgets/index.turbo_stream.erb" &&
        candidate.reason == "max view files limit reached"
    end)
  end

  def test_lim_1_total_file_budget_drops_later_test_from_files_and_tests_to_run
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "saturation#show"
    )

    assert_equal [
      "app/controllers/saturation_controller.rb",
      "app/views/saturation/show.html.erb",
      "app/views/saturation/show.json.jbuilder",
      "app/models/alpha_one.rb",
      "app/models/beta_two.rb",
      "app/models/gamma_three.rb",
      "app/models/delta_four.rb",
      "test/controllers/saturation_controller_test.rb"
    ], packet.files.map(&:path)
    assert_equal ["test/controllers/saturation_controller_test.rb"], packet.tests.map(&:path)
    assert_nil packet.file("test/integration/saturation_show_flow_test.rb")
    assert(packet.omitted_candidates.any? do |candidate|
      candidate.category == "test_files" &&
        candidate.subject == "test/integration/saturation_show_flow_test.rb" &&
        candidate.reason == "max total files limit reached"
    end)
  end

  def test_fmt_4a_8_9_renders_view_reason_uncertainty_and_omission_suggestions
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      anchor: "view_budgets#index"
    )

    markdown = Ctxpack.render_markdown(packet)

    assert_includes markdown, <<~MARKDOWN
      Why: Conventional view template for `view_budgets#index`.
      Reason code: `view_candidate`
    MARKDOWN
    assert_includes markdown, "- Included view template(s) were matched by action->template convention and not confirmed against the action's actual render target."
    assert_includes markdown, "View `app/views/view_budgets/index.turbo_stream.erb` was omitted because max view files limit reached."
    assert_includes markdown, "- Confirm the action renders the included view template(s); it may redirect or render another."
    assert_includes markdown, "- Inspect omitted view file(s) manually: `app/views/view_budgets/index.turbo_stream.erb`."
  end
end
