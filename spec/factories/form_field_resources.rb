FactoryBot.define do
  factory :form_field_resource do
    association :form_field
    association :resource
    sequence(:position) { |n| n }
  end
end
