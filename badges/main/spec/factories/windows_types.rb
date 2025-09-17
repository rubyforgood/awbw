FactoryBot.define do
  factory :windows_type do
    sequence(:name) { |n| "Windows Type Name #{n}" }

    trait :adult do
      name { 'ADULT WORKSHOP LOG' }
    end

    trait :children do
      name { 'CHILDREN WORKSHOP LOG'}
    end

    trait :combined do
      name { 'ADULT & CHILDREN COMBINED (FAMILY) LOG' }
    end
  end
end 