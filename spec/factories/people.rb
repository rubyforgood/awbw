FactoryBot.define do
  factory :person do
    user { email.present? ? association(:user, email: email) : association(:user) }
    association :created_by, factory: :user
    association :updated_by, factory: :user
    first_name { Faker::Name.first_name.gsub("'", " ") }
    last_name { Faker::Name.last_name.gsub("'", " ") }
    display_name_preference { "full_name" }

    trait :anonymous_contributions do
      anonymous_contributions { true }
    end

    trait :with_organization do
      after(:create) do |person|
        person.organizations << create(:organization)
      end
    end

    trait :without_audit do
      created_by { nil }
      updated_by { nil }
    end

    trait :without_user do
      user { nil }
      created_by { nil }
      updated_by { nil }
    end
  end

  factory :person_without_audit, parent: :person do
    created_by { nil }
    updated_by { nil }
  end

  factory :person_without_user, parent: :person do
    user { nil }
    created_by { nil }
    updated_by { nil }
  end
end
