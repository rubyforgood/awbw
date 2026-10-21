FactoryBot.define do
  factory :staff_alias do
    sequence(:name) { |n| "Staff Member #{n}" }
    user

    trait :ignored do
      user { nil }
      ignored { true }
    end
  end
end
