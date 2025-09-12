FactoryBot.define do
  factory :workshop_age_range do
    association :workshop
    association :age_range
  end
end 