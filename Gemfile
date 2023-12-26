# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.3'

gem 'billing-service-client', git: 'git@bitbucket.org:kmnss/billing-service-client.git'
gem 'docyt_lib', git: 'git@bitbucket.org:kmnss/docyt_lib.git', submodules: true
gem 'docyt-server-client', git: 'git@bitbucket.org:kmnss/docyt-server-client.git'
gem 'kubeclient', github: 'andreychernih/kubeclient', branch: 'patch-status'
gem 'metrics-service-client', git: 'git@bitbucket.org:kmnss/metrics-service-client.git'
gem 'storage-service-client', git: 'git@bitbucket.org:kmnss/storage-service-client.git'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0'
# Use Puma as the app server, version set to 5.5.0 because latest(5.6.4) wasn't working properly
gem 'puma', '~> 5.5.0'
# Reduces boot times through caching; required in config/boot.rb
gem 'active_model_serializers', '0.9.3'
gem 'axlsx', git: 'https://github.com/randym/axlsx.git', ref: 'c8ac844'
gem 'axlsx_rails'
gem 'bootsnap', '>= 1.4.4', require: false
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
gem 'json-schema'
# MongoDB related gems
gem 'kaminari'
gem 'kaminari-mongoid'
gem 'mongoid', '~> 7.5.2'
gem 'mongoid-pagination'
gem 'mongoid-serializer'

gem 'roo', '~> 2.8'

gem 'rswag-api'
gem 'rswag-ui'

# OAuth request libraries
gem 'oauth2'
gem 'oauth-plugin'
gem 'signet'
gem 'slack-notifier'
gem 'slack-ruby-client'

gem 'draper'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'bunny-mock'
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'mongoid-rspec'
  gem 'pry-byebug'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails', '~> 3.8'
  gem 'rswag-specs'
  gem 'rubocop', '~> 0.80', require: false
  gem 'rubocop-rails', '~> 2.4', require: false
  gem 'rubocop-rspec', '~> 1.38', require: false
end

group :development do
  gem 'listen', '~> 3.3'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

group :test do
  gem 'database_cleaner-mongoid'
  gem 'faker', github: 'stympy/faker'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'simplecov-cobertura'
  gem 'webmock'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
