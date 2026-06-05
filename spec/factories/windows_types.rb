FactoryBot.define do
  factory :windows_type do
    sequence(:name) { |n| "Windows Type Name #{n}" }
    sequence(:short_name) { |n| "Short Name #{n}" }

    trait :adult do
      name { "Adult" }
      short_name { "Adult" }
    end

    trait :children do
      name { "Children" }
      short_name { "Children" }
    end

    trait :combined do
      name { "Combined" }
      short_name { "Combined" }
    end
  end
end
