FactoryBot.define do
  factory :form_field do
    # Association: belongs_to :form
    association :form

    name { Faker::Lorem.sentence }
    status { :active } # Default to active
    answer_type { :free_form_input_one_line } # Default type
    input_type { :text_alphanumeric } # Default datatype
    sequence(:position) { |n| n }
    parent_id { nil }

    # Add other attributes based on schema if needed
  end
end
