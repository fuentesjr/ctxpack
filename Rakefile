require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.pattern = "test/ctxpack/**/*_test.rb"
end

task default: :test
