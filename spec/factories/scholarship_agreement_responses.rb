FactoryBot.define do
  factory :scholarship_agreement_response do
    association :scholarship
    status { "declined" }
    reason { "Timing no longer works" }
    responded_at { Time.current }
    responder { "recipient" }
    amount_cents { 1000 }
  end
end
