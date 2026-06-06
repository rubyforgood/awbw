FactoryBot.define do
  factory :form_answer do
    association :form_submission
    association :form_field
    submitted_answer { Faker::Lorem.sentence }
    question_name_when_answered { nil }
  end
end
