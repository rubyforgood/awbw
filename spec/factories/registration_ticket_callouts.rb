FactoryBot.define do
  factory :registration_ticket_callout do
    association :event
    sequence(:title) { |n| "Ticket callout #{n}" }
    subtitle { "A short supporting line" }
    description { "<p>Details for this callout.</p>" }
    callout_type { "reference" }
    payment_access_gated { false }
    # position is assigned by the positioning gem on save (appended within the event)

    trait :action do
      callout_type { "action" }
    end

    trait :payment_access_gated do
      payment_access_gated { true }
    end
  end
end
