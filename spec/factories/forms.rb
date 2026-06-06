FactoryBot.define do
  factory :form do
    name { "Test Form" }

    trait :standalone do
      owner { nil }
    end

    trait :with_owner do
      association :owner, factory: :user
    end

    trait :with_fields do
      after(:create) do |form|
        create_list(:form_field, 3, form: form)
      end
    end

    trait :scholarship do
      role { "scholarship" }
      name { "Scholarship Application" }
    end
  end
end
