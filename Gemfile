source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.0.5'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer' #, platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

# Use debugger
# gem 'debugger', group: [:development, :test]

# gem 'mongoid', git: 'git://github.com/mongoid/mongoid.git'
gem 'mongoid', '~> 4', github: 'mongoid/mongoid'

gem 'mongoid_slug'
gem 'thin'
gem 'bson_ext'

gem 'less-rails'
gem 'devise'
gem 'haml'
gem 'haml-rails'
gem 'twitter-bootstrap-rails'
gem 'simple_form'
# gem 'mechanize'
gem 'nokogiri'
gem 'mongoid-pagination'
gem 'dalli'
gem 'ruby-readability', :require => 'readability'
gem 'whatlanguage'
gem 'whenever', :require => false
gem 'chartkick'
gem 'rails_config'

gem 'sidekiq', '~> 3.3.0'
gem 'sidekiq-failures'
gem 'sidekiq-limit_fetch'

group :goodnoows, :staging, :peixe do
	gem 'newrelic_rpm'
end

group :development do
  gem 'quiet_assets'
  gem 'foreman'
  gem 'brakeman', :require => false

  gem 'capistrano', github: 'capistrano/capistrano', tag: 'v3.3.4' # 3.3.4 because of bug that affects cap-ec2
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler', '~> 1.1.2'
  gem 'capistrano-rvm'
  gem 'capistrano-sidekiq'
  gem 'cap-ec2', github: 'AmirKremer/cap-ec2', branch: 'fix-available-roles'
  gem 'capistrano-passenger'
end

group :test do
  gem 'shoulda-matchers'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'selenium-webdriver'
  gem 'simplecov', '~> 0.7.1'
  gem 'simplecov-rcov', :require => false
  gem 'webmock'
  gem 'rspec-sidekiq'
  gem 'timecop'
  gem 'factory_girl_rails'
  gem 'rspec' , '~> 3.1.0'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-rails'
  gem 'rspec-mocks'
  gem 'ci_reporter_rspec'
end

gem 'hipchat'

gem 'sinatra', '>= 1.3.0', :require => nil # used for sidekiq dashboard only
gem 'rest-client' # used to consume barbante api
gem 'aws-sdk', '~> 1.0' # used to download barbante from S3
gem 'colorize'

# gem 'elasticsearch-model'
# gem 'elasticsearch-rails'
###
