FactoryBot.define do
  factory :registration_ticket_callout_resource do
    association :registration_ticket_callout
    association :resource
    subtitle { "A short card line" }
    page_content { "Longer copy shown under the title on the resource page." }
  end
end
