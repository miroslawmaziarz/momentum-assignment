require "spec_helper"

# Assigned, not defaulted with ||=. The container sets RAILS_ENV=development for the web
# process, and `docker compose exec app bundle exec rspec` inherits it — a conditional
# default would silently run the whole suite against the development environment and
# database.
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |file| require file }

# Load the schema into the test database if migrations have been added since it was last
# prepared, so a fresh checkout does not need a separate setup step before `rails spec`.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Each example runs in a transaction that is rolled back afterwards, so examples cannot
  # leak state into one another.
  config.use_transactional_fixtures = true

  # `type: :request`, `type: :model` and friends are inferred from the directory a spec
  # lives in, so specs do not have to restate what their location already says.
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!
end
