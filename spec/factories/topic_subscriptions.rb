FactoryBot.define do
  factory :topic_subscription do
    association :person
    topic_subscription_type
    interested_event { nil }
    source { "Facilitator Training registration" }

    trait :for_event do
      association :interested_event, factory: :event
      association :topic_subscription_type, event_selector: true
    end

    trait :unsubscribed do
      unsubscribed_at { Time.current }
    end
  end
end
