FactoryBot.define do
  factory :report_form_field_answer do
    association :report
    association :form_field
    association :answer_option

    answer { "User response text" }
  end
end 