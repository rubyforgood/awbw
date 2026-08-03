FactoryBot.define do
  factory :topic_subscription do
    association :person
    topic { "trainings" }
    interested_event { nil }
    source { "Facilitator Training registration" }

    trait :for_event do
      association :interested_event, factory: :event
    end

    trait :unsubscribed do
      unsubscribed_at { Time.current }
    end

    trait :news do
      topic { "news" }
    end
  end
end
