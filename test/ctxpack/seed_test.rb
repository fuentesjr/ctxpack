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
    assert_equal 3, via_seeds.version
    assert_equal ["anchor"], via_seeds.seeds.map(&:kind)
    assert_equal "accounts#upgrade", via_seeds.seeds.first.evidence
  end

  def test_seed_1_compile_rejects_missing_seed
    error = assert_raises(ArgumentError) do
      Ctxpack.compile(app_root: fixture_app("minitest_basic"), task: "x")
    end
    assert_match(/seed|anchor/i, error.message)
  end

  def test_phase2_anchor_packet_is_format_v3_with_seeds_and_anchor
    app_root = fixture_app("minitest_basic")
    packet = Ctxpack.compile(
      app_root: app_root,
      anchor: "accounts#upgrade",
      task: "Implement billing upgrade"
    )
    markdown = Ctxpack.render_markdown(packet)
    manifest = JSON.parse(Ctxpack.render_manifest(packet))

    assert_equal 3, manifest.fetch("version")
    assert_equal "anchor", manifest.fetch("seeds").first.fetch("kind")
    assert_includes markdown, "Format: 3"
    assert_includes markdown, "## Anchor"
    assert_includes markdown, "## Seeds"
  end

  def test_phase2_test_seed_includes_primary_and_surface
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.test("test/controllers/accounts_controller_test.rb")],
      task: "Fix upgrade"
    )
    assert_equal "test", packet.seeds.first.kind
    assert packet.file("test/controllers/accounts_controller_test.rb")
    assert packet.file("app/controllers/accounts_controller.rb")
    assert_nil packet.anchor
  end

  def test_phase2_files_seed_includes_named_file_and_neighbor_test
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.files(["app/controllers/accounts_controller.rb"])],
      task: "Inspect accounts"
    )
    assert_equal "files", packet.seeds.first.kind
    assert packet.file("app/controllers/accounts_controller.rb")
    assert(
      packet.file("test/controllers/accounts_controller_test.rb") ||
        packet.files.any? { |f| f.path.start_with?("test/") },
      "expected a test neighbor"
    )
  end

  def test_phase3_error_seed_persists_only_app_frames
    frames = ["app/controllers/accounts_controller.rb:10"]
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [Ctxpack::Seed.error(frames)],
      task: "Investigate production error"
    )
    assert_equal "error", packet.seeds.first.kind
    assert_equal frames.join("\n"), packet.seeds.first.evidence
    entry = packet.file("app/controllers/accounts_controller.rb")
    refute_nil entry
    assert_includes entry.reason_codes, "error_seed_frame"
    refute_includes packet.seeds.first.evidence, "password"
  end

  def test_phase4_multi_seed_merges_focus_and_seeds_array
    packet = Ctxpack.compile(
      app_root: fixture_app("minitest_basic"),
      seeds: [
        Ctxpack::Seed.test("test/controllers/accounts_controller_test.rb"),
        Ctxpack::Seed.anchor("accounts#upgrade")
      ],
      task: "Fix upgrade with test emphasis"
    )
    assert_equal %w[test anchor], packet.seeds.map(&:kind)
    assert_equal "accounts#upgrade", packet.anchor
    assert packet.file("test/controllers/accounts_controller_test.rb")
    assert packet.file("app/controllers/accounts_controller.rb")
    assert_equal 3, packet.version
  end
end
