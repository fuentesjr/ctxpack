Gem::Specification.new do |spec|
  spec.name = "ctxpack"
  spec.version = "0.1.0"
  spec.summary = "Deterministic Rails context packet compiler"
  spec.authors = ["ctxpack contributors"]
  spec.files = Dir["lib/**/*.rb"] + Dir["exe/*"]
  spec.bindir = "exe"
  spec.executables = ["ctxpack"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "prism", ">= 1.0"
  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rake", ">= 13.0"
end
