FactoryBot.define do
  factory :organization_person do
    association :organization
    association :person

    position { :default }
  end
end
