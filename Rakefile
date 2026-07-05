require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.pattern = "test/ctxpack/**/*_test.rb"
end

task default: :test

desc "Advisory metz-scan design-pressure scan of lib/ (never gates; log metz-scan friction in metz-scan-feedback.md)"
task :metz do
  # metz-scan is a globally installed CLI, not a bundle member, so it must
  # run outside Bundler's environment when invoked via `bundle exec rake`.
  run = ->(*cmd) { defined?(Bundler) ? Bundler.with_unbundled_env { system(*cmd) } : system(*cmd) }
  if run.call("command -v metz-scan > /dev/null 2>&1")
    run.call("metz-scan", "scan", "lib", "--format", "text")
    puts "\nmetz-scan is advisory: findings inform refactors but do not gate the build."
  else
    warn "metz-scan not installed; skipping (install notes in metz-scan-feedback.md)."
  end
end
