FactoryBot.define do
  factory :event_attendance_time_entry do
    association :event_registration
    signed_in_at { 2.hours.ago }
    signed_out_at { 1.hour.ago }

    trait :open do
      signed_out_at { nil }
    end
  end
end
