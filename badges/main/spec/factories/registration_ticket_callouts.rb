FactoryBot.define do
  factory :registration_ticket_callout do
    association :event
    sequence(:title) { |n| "Ticket callout #{n}" }
    subtitle { "A short supporting line" }
    description { "<p>Details for this callout.</p>" }
    callout_type { "reference" }
    payment_access_gated { false }
    hidden { false }
    # position is assigned by the positioning gem on save (appended within the event)

    # Convenience: `create(:registration_ticket_callout, resource:)` links one
    # resource through the join, and `resources: [a, b]` links several.
    transient do
      resource { nil }
      resources { [] }
    end

    after(:create) do |callout, evaluator|
      Array(evaluator.resource).each { |r| callout.resources << r }
      evaluator.resources.each { |r| callout.resources << r }
    end

    trait :action do
      callout_type { "action" }
    end

    trait :payment_access_gated do
      payment_access_gated { true }
    end

    trait :hidden do
      hidden { true }
    end

    trait :magic do
      magic_key { "faq" }
      title { "Frequently asked questions" }
    end
  end
end
