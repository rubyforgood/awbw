FactoryBot.define do
  factory :affiliation do
    association :organization
    association :person

    position { :default }
  end
end
