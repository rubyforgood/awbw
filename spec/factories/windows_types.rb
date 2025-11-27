FactoryBot.define do
  factory :windows_type do
    sequence(:name) { |n| "Windows Type Name #{n}" }

    trait :adult do
      name { "ADULT WINDOWS" }
      short_name { "Adult" }
    end

    trait :children do
      name { "CHILDREN'S WINDOWS" }
      short_name { "Children's" }
    end

    trait :combined do
      name { "ADULT & CHILDREN COMBINED (FAMILY) WINDOWS" }
      short_name { "Combined" }
    end
  end
end 