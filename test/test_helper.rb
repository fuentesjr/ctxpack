$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "ctxpack"
require "minitest/autorun"

module FixturePaths
  def fixture_app(name)
    File.expand_path("fixtures/apps/#{name}", __dir__)
  end
end

class Minitest::Test
  include FixturePaths
end

class UnavailableHistoryProvider
  def fetch(path:, **)
    Ctxpack::History.omitted(path: path, reason: "executable_unavailable")
  end
end
