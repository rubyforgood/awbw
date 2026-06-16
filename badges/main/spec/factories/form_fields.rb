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
    # Display-only types (informational text, section headers) can't be required.
    required { FormField::NON_INPUT_ANSWER_TYPES.exclude?(answer_type.to_s) }

    # Add other attributes based on schema if needed
  end
end
