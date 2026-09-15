FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |n| format("%06d", n) }
    title { "The Left Hand of Darkness" }
    author { "Ursula K. Le Guin" }
  end
end
