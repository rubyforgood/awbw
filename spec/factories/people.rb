FactoryBot.define do
  sequence(:person_email) { |n| "person#{n}@example.com" }

  factory :person do
    user { email.present? ? association(:user, email: email) : association(:user) }
    association :created_by, factory: :user
    association :updated_by, factory: :user
    first_name { Faker::Name.first_name.gsub("'", " ") }
    last_name { Faker::Name.last_name.gsub("'", " ") }

    after(:build) do |person|
      person.email = FactoryBot.generate(:person_email) if person.email.blank? && person.user.nil?
    end

    trait :legacy_without_email do
      after(:create) { |person| person.update_columns(email: nil) }
    end

    trait :anonymous_contributions do
      anonymous_contributions { true }
    end

    trait :with_organization do
      after(:create) do |person|
        person.organizations << create(:organization)
      end
    end
  end
end
