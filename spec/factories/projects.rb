FactoryBot.define do
  factory :project do
    name { Faker::Company.name.gsub("'", " ") }
    # association :windows_type
    # association :location
    association :project_status
  end
end
