FactoryBot.define do
  factory :dues_subscription do
    association :person

    trait :cancelled do
      cancelled_at { Time.current }
    end
  end
end
