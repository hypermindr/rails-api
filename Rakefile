# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

if ENV['GENERATE_REPORTS'] == 'true'
	require 'rspec/core/rake_task'
	require 'ci/reporter/rake/rspec'
	RSpec::Core::RakeTask.new(:rspec)
	task :rspec => 'ci:setup:rspec'
end

Api::Application.load_tasks
