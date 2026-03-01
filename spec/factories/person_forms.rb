FactoryBot.define do
  factory :person_form do
    association :person
    association :form
  end
end
