# Rubydex compatibility evidence

**Checked:** 2026-07-30  
**Environment:** Ruby 4.0.1 on x86_64-darwin  
**Rubydex:** 0.3.0, installed as `rubydex-0.3.0-x86_64-darwin`

This document records the compatibility check for the historical Tier 3
offline runner. Rubydex is optional, separately installed evaluation tooling;
it is not a ctxpack runtime or development dependency.

## Historical evidence

Rubydex is installed only for this optional Tier 3 reproduction. Do not add it
to `Gemfile`, `ctxpack.gemspec`, `Gemfile.lock`, or the ctxpack runtime.

The check used:

```sh
gem install rubydex -v 0.3.0 --no-document
```

The upstream [issue #919](https://github.com/Shopify/rubydex/issues/919)
reproduces the failure with explicit `module_function :regular`, followed by
iteration over `Rubydex::Method` and calls to `#visibility`.

The fix shipped in [PR #802](https://github.com/Shopify/rubydex/pull/802),
“Resolve module_function visibility”, and is included in
[release v0.3.0](https://github.com/Shopify/rubydex/releases/tag/v0.3.0).
GitHub records PR #802 as merged on 2026-07-17. The v0.3.0 release notes,
published on 2026-07-23, list that fix.

| Rubydex | Reproduction result |
|---|---|
| 0.2.9 | Non-unwinding panic; process exited 134. |
| 0.3.0 | Process exited 0; visibility returned `public` and `private` for the two method entries. |

The 0.3.0 reproduction output was:

```text
[["Helper#regular()", :private], ["Helper::<Helper>#regular()", :public]]
```

## API compatibility audit

The historical runner's graph method list is unchanged between 0.2.9 and
0.3.0: `workspace_path=`, `index_workspace`, `resolve`, and
`constant_references` remain available.

`ResolvedConstantReference#declaration` and declaration `#definitions` also
remain available.

A narrow 0.3.0 workspace smoke used the runner's `Dir.chdir`,
`workspace_path=`, `index_workspace`, `resolve`, and resolved-constant path
handling. It mapped
`app/controllers/users_controller.rb` to `app/models/user.rb`.

## Repository boundary audit

- The main `Gemfile`, `ctxpack.gemspec`, and `Gemfile.lock` contain no Rubydex dependency.
- No production code, tests, fixtures, or main lockfile changed.
- `README.md`, `design.md`, and `specs/packet-compilation.md` retain the v0 decision that Rubydex is not required.
- Frozen Tier 3 metrics and results remain unchanged.
- The separate three-app release-boundary rerun was not spent.

## Optional Tier 3 procedure

Run the isolated reproduction before using a Rubydex version for offline
analysis:

```sh
ruby - 0.3.0 <<'RUBY'
version = ARGV.fetch(0)
gem "rubydex", version
require "rubydex"
require "tmpdir"

source = <<~SOURCE
  module Helper
    def regular; end
    module_function :regular
  end
SOURCE

Dir.mktmpdir do |dir|
  path = File.join(dir, "helper.rb")
  File.write(path, source)
  graph = Rubydex::Graph.new(workspace_path: dir)
  graph.index_all([path])
  graph.resolve
  rows = graph.declarations.grep(Rubydex::Method).map { |method| [method.name, method.visibility] }
  p rows.sort_by(&:first)
end
RUBY
```

With `0.3.0`, the output is
`[["Helper#regular()", :private], ["Helper::<Helper>#regular()", :public]]` and
the process exits 0. Replacing the argument with `0.2.9` reproduces the
non-unwinding panic and exit 134.

Run the workspace smoke with a temporary Gemfile prerequisite:

```sh
ruby - 0.3.0 <<'RUBY'
version = ARGV.fetch(0)
gem "rubydex", version
require "fileutils"
require "rubydex"
require "tmpdir"

Dir.mktmpdir do |dir|
  FileUtils.mkdir_p(File.join(dir, "app/controllers"))
  FileUtils.mkdir_p(File.join(dir, "app/models"))
  File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n")
  File.write(File.join(dir, "app/controllers/users_controller.rb"), <<~RUBY)
    class UsersController
      def index
        User.all
      end
    end
  RUBY
  File.write(File.join(dir, "app/models/user.rb"), "class User\nend\n")

  prefix = "file://#{dir}/"
  Dir.chdir(dir) do
    graph = Rubydex::Graph.new
    graph.workspace_path = dir
    graph.index_workspace
    graph.resolve
    rows = graph.constant_references.grep(Rubydex::ResolvedConstantReference).filter_map do |reference|
      next unless reference.location.uri.to_s.start_with?(prefix)

      source = reference.location.to_file_path.delete_prefix("#{dir}/")
      targets = reference.declaration.definitions.filter_map do |definition|
        next unless definition.location.uri.to_s.start_with?(prefix)

        definition.location.to_file_path.delete_prefix("#{dir}/")
      end
      [source, targets] unless targets.empty?
    end
    p rows
  end
end
RUBY
```

The workspace smoke outputs
`[["app/controllers/users_controller.rb", ["app/models/user.rb"]]]`.

Before using another Rubydex version for offline analysis, rerun both receipts.
These checks are immediate and do not rerun the three-app benchmark.

## Frozen evidence boundary

This addendum does not revise frozen Tier 3 measurements or their verdict.
