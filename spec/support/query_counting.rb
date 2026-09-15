module QueryCounting
  def count_queries(&block)
    count = 0
    counter = ->(*) { count += 1 }

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)

    count
  end
end

RSpec.configure do |config|
  config.include QueryCounting, type: :request
end
