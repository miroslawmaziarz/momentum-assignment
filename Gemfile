source 'https://rubygems.org'

ruby file: '.ruby-version'

gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.1.3', '>= 8.1.3.1'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

gem 'solid_queue'

gem 'json', '< 3.0'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  gem 'factory_bot_rails', '~> 6.4'
  gem 'rspec-rails', '~> 8.0'

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false
end
