FactoryBot.define do
  factory :borrowing do
    book
    reader

    trait :returned do
      returned_at { Time.current }
    end
  end
end
