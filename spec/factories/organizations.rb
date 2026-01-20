FactoryBot.define do
  factory :organization do
    name { Faker::Company.name.gsub("'", " ") }
    # association :windows_type
    # association :location
    association :organization_status
  end
end
