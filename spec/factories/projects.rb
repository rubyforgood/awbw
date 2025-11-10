FactoryBot.define do
  factory :project do
    name { Faker::Company.name }
    association :windows_type
    association :location
  end
end
