FactoryBot.define do
  factory :registration_ticket_callout do
    association :event
    sequence(:title) { |n| "Ticket callout #{n}" }
    subtitle { "A short supporting line" }
    description { "<p>Details for this callout.</p>" }
    callout_type { "reference" }
    show_if_paid { false }
    # position is assigned by the positioning gem on save (appended within the event)

    trait :action do
      callout_type { "action" }
    end

    trait :paid_only do
      show_if_paid { true }
    end
  end
end
