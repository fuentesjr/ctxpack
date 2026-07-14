require "test_helper"

class SeedTest < Minitest::Test
  def test_seed_1_anchor_seed_from_evidence
    seed = Ctxpack::Seed.anchor("accounts#upgrade")
    assert_equal "anchor", seed.kind
    assert_equal "accounts#upgrade", seed.evidence
    assert_equal "accounts_upgrade", seed.identity
  end

  def test_seed_1_compile_via_seeds_kwarg_matches_anchor_kwarg
    app_root = fixture_app("minitest_basic")
    task = "Implement billing upgrade"

    via_anchor = Ctxpack.compile(app_root: app_root, anchor: "accounts#upgrade", task: task)
    via_seeds = Ctxpack.compile(
      app_root: app_root,
      seeds: [Ctxpack::Seed.anchor("accounts#upgrade")],
      task: task
    )

    assert_equal via_anchor.to_h, via_seeds.to_h
    assert_equal 2, via_seeds.version
    assert_equal ["anchor"], via_seeds.seeds.map(&:kind)
    assert_equal "accounts#upgrade", via_seeds.seeds.first.evidence
  end

  def test_seed_1_compile_rejects_missing_seed
    error = assert_raises(ArgumentError) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), task: "x")
    end
    assert_match(/seed|anchor/i, error.message)
  end

  def test_phase1_markdown_byte_identical_for_anchor_golden_path
    app_root = fixture_app("minitest_basic")
    packet = Ctxpack.compile(
      app_root: app_root,
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )
    markdown = Ctxpack.render_markdown(packet)
    manifest = JSON.parse(Ctxpack.render_manifest(packet))

    assert_equal 2, manifest.fetch("version")
    refute manifest.key?("seeds")
    assert_includes markdown, "Format: 2"
    assert_includes markdown, "## Anchor"
    refute_includes markdown, "## Seeds"
  end
end
