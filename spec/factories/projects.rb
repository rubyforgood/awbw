FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project Name #{n}" }

    association :location
    association :windows_type
    association :project_status

    start_date { Date.today - 1.month }
    end_date { nil }
    description { Faker::Lorem.paragraph }
  end
end 