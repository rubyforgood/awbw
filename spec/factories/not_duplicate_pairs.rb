FactoryBot.define do
  factory :not_duplicate_pair do
    record_type { "Person" }
    sequence(:first_record_id) { |n| n * 2 }
    second_record_id { first_record_id + 1 }
  end
end
