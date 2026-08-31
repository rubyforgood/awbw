FactoryBot.define do
  factory :registration_ticket_callout_form do
    association :registration_ticket_callout
    association :form
    display_from { nil }
  end
end
