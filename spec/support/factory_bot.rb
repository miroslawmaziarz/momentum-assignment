# Lets specs say `create(:book)` instead of `FactoryBot.create(:book)`. Factories
# themselves live in spec/factories/ and are picked up by factory_bot_rails.
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
