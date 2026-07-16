require_relative "lib/ctxpack/version"

Gem::Specification.new do |spec|
  spec.name = "ctxpack"
  spec.version = Ctxpack::VERSION
  spec.summary = "Context engineering CLI and deterministic Rails context compiler"
  spec.authors = ["ctxpack contributors"]
  spec.files = Dir["lib/**/*.rb"] + Dir["exe/*"]
  spec.bindir = "exe"
  spec.executables = ["ctxpack"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.4"

  spec.add_dependency "prism", ">= 1.0"
  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rake", ">= 13.0"
end
