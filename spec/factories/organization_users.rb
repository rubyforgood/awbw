FactoryBot.define do
  factory :organization_user do
    association :organization
    association :user

    position { :default }
  end
end
