FactoryBot.define do
  factory :topic_subscription_type do
    sequence(:name) { |n| "Topic #{n}" }

    trait :facilitator_trainings do
      name { "Facilitator trainings" }
    end

    trait :news do
      name { "News" }
    end

    trait :archived do
      archived_at { Time.current }
    end
  end
end
