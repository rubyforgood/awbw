FactoryBot.define do
  factory :role do
    association :user
    role { "member" }
  end
end
