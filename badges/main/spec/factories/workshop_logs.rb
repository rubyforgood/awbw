FactoryBot.define do
  factory :workshop_log do
    association :created_by, factory: :user
    association :organization
    association :windows_type
    association :workshop
    workshop_held_on { Date.today }
  end
end
