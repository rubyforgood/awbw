FactoryBot.define do
  factory :form_completion do
    association :person
    association :form
    association :event
    completed_on { Date.current }
  end
end
