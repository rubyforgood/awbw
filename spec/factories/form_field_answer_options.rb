FactoryBot.define do
  factory :form_field_answer_option do
    association :form_field

    association :answer_option
  end
end 