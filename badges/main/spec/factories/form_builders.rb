FactoryBot.define do
  factory :form_builder do
    sequence(:name) { |n| "Form Builder Name #{n}" }

    association :windows_type
  end
end 