FactoryBot.define do
  factory :user_form_form_field do
    association :form_field
    association :user_form
    text { "User input value" }
  end
end 