FactoryBot.define do
  factory :reader do
    sequence(:card_number) { |n| format("%06d", n) }
    full_name { "Ada Lovelace" }
    sequence(:email) { |n| "ada#{n}@example.com" }
  end
end
