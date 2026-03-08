FactoryBot.define do
  factory :affiliation do
    association :organization
    association :person

    title { "Facilitator" }
  end
end
