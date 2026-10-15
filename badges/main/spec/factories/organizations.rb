FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "#{Faker::Company.name.gsub("'", " ")} #{n}" }
    # association :windows_type
    # association :location
    association :organization_status
  end
end
