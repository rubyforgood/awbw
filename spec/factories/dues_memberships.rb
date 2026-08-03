FactoryBot.define do
  factory :dues_membership do
    association :person

    trait :cancelled do
      cancelled_at { Time.current }
    end
  end
end
