# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

require 'simplecov'
require 'webmock/rspec'
require 'simplecov-rcov'

require 'rake'
require 'rails/tasks'
Rake::Task["tmp:create"].invoke

SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start 'rails'

WebMock.disable_net_connect!(allow_localhost: true)
# WebMock.allow_net_connect!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
# ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  # mongoid specific stuff
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
  end

  config.before(:each) do
    Rails.cache.clear
    DatabaseCleaner[:mongoid].start
  end

  config.after(:each) do
    DatabaseCleaner[:mongoid].clean
  end

  config.include Requests::JsonHelpers, :type => :controller


  config.before(:each) do

    # stub_request(:get, "http://ip-api.com/json/8.8.8.8").
    stub_request(:get, "http://www.telize.com/geoip/8.8.8.8").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.telize.com', 'User-Agent'=>'Ruby'}).
        # to_return(:status => 200, :body => "{\"status\":\"success\",\"country\":\"United States\",\"countryCode\":\"US\",\"region\":\"\",\"regionName\":\"\",\"city\":\"\",\"zip\":\"\",\"lat\":\"38\",\"lon\":\"-97\",\"timezone\":\"\",\"isp\":\"Level 3 Communications\",\"org\":\"Google\",\"as\":\"AS15169 Google Inc.\",\"query\":\"8.8.8.7\"}", :headers => {'content-type'=>'application/json'})
        to_return(:status => 200, :body => "{\"dma_code\":\"0\",\"ip\":\"8.8.8.8\",\"asn\":\"AS15169\",\"latitude\":38,\"country_code\":\"US\",\"country\":\"United States\",\"isp\":\"Google Inc.\",\"area_code\":\"0\",\"continent_code\":\"NA\",\"longitude\":-97,\"country_code3\":\"USA\"}", :headers => {'content-type'=>'application/json'})

    stub_request(:get, "http://www.telize.com/geoip/0.0.0.0").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.telize.com', 'User-Agent'=>'Ruby'}).
        # to_return(:status => 200, :body => "{\"status\":\"success\",\"country\":\"United States\",\"countryCode\":\"US\",\"region\":\"\",\"regionName\":\"\",\"city\":\"\",\"zip\":\"\",\"lat\":\"38\",\"lon\":\"-97\",\"timezone\":\"\",\"isp\":\"Level 3 Communications\",\"org\":\"Google\",\"as\":\"AS15169 Google Inc.\",\"query\":\"8.8.8.7\"}", :headers => {'content-type'=>'application/json'})
        to_return(:status => 200, :body => "{\"dma_code\":\"0\",\"ip\":\"0.0.0.0\",\"asn\":\"AS15169\",\"latitude\":38,\"country_code\":\"US\",\"country\":\"United States\",\"isp\":\"Google Inc.\",\"area_code\":\"0\",\"continent_code\":\"NA\",\"longitude\":-97,\"country_code3\":\"USA\"}", :headers => {'content-type'=>'application/json'})

    body = File.open(Rails.root.join('spec/support/fixtures/goodnoows-article.html')).read
    stub_request(:get, "http://goodnoows.com/a/189824201/").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.com', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => body, :headers => {'content-type'=>'text/html'})
  end

end


RSpec::Sidekiq.configure do |config|
  # Clears all job queues before each example
  config.clear_all_enqueued_jobs = true # default => true

  # Whether to use terminal colours when outputting messages
  config.enable_terminal_colours = true # default => true

  # Warn when jobs are not enqueued to Redis but to a job array
  config.warn_when_jobs_not_processed_by_sidekiq = false # default => true
end
