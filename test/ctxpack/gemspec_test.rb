require "test_helper"

class GemspecTest < Minitest::Test
  def test_gem_includes_its_mit_license
    spec = Gem::Specification.load(File.expand_path("../../ctxpack.gemspec", __dir__))

    assert_equal ["MIT"], spec.licenses
    assert_includes spec.files, "LICENSE"
  end
end
