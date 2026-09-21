FactoryBot.define do
  factory :profile_change_request do
    person
    requested_by { association :user }
    field { "affiliation" }
    requested_value { "Start or end dates" }
    details { "Please update my end date to 2020." }
    status { "pending" }

    trait :primary_email do
      field { "primary_email" }
      requested_value { "new@example.com" }
      details { nil }
    end

    trait :organization_name do
      field { "organization_name" }
      requested_value { "New Org Name" }
      details { nil }
    end

    trait :resolved do
      status { "resolved" }
      resolution_method { "manual" }
      reviewed_at { Time.current }
    end

    trait :declined do
      status { "declined" }
      reviewed_at { Time.current }
    end
  end
end
