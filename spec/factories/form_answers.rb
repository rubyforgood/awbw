FactoryBot.define do
  factory :form_answer do
    association :form_submission
    association :form_field
    text { Faker::Lorem.sentence }
    question_text { nil }
  end
end
