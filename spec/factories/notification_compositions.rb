FactoryBot.define do
  factory :notification_composition do
    association :user
    kind { "draft" }
    scope_type { "general" }
    subject { "A note from Art With A Woman" }
    body { "Hi {{first_name}}," }
    cta_label { "View your portal profile" }
    recipient_segments { [ { "field" => "county", "value" => "LA", "join" => "AND" } ] }

    trait :template do
      kind { "template" }
      name { "Monthly newsletter" }
    end

    trait :event_scoped do
      scope_type { "event" }
      association :event
    end
  end
end
