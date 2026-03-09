FactoryBot.define do
  factory :windows_type do
    sequence(:name) { |n| "Windows Type Name #{n}" }
    sequence(:short_name) { |n| "Short Name #{n}" }

    trait :adult do
      name { "ADULT WINDOWS" }
      short_name { "Adult" }
    end

    trait :children do
      name { "CHILDREN'S WINDOWS" }
      short_name { "Children" }
    end

    trait :combined do
      name { "ADULT & CHILDREN COMBINED (FAMILY) WINDOWS" }
      short_name { "Combined" }
    end
  end
end
