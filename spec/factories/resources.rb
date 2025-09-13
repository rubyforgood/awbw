FactoryBot.define do
  factory :resource do
    title { Faker::Lorem.sentence }
    kind { [Resource::KIND.sample] }
    sectors { "General" }
  end
end
