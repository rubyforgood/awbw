FactoryBot.define do
  factory :form_submission do
    association :person
    association :form
    association :event
  end
end
