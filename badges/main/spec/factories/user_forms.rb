FactoryBot.define do
  factory :user_form do
    association :user
    association :form
  end
end 