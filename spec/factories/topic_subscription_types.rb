FactoryBot.define do
  factory :topic_subscription_type do
    sequence(:name) { |n| "Topic #{n}" }
    event_selector { false }

    trait :facilitator_trainings do
      name { "Facilitator trainings" }
      event_selector { true }
    end

    trait :event_selector do
      event_selector { true }
    end

    trait :news do
      name { "News" }
    end

    trait :archived do
      archived_at { Time.current }
    end
  end
end
