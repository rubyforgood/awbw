FactoryBot.define do
  factory :organization_status do
    sequence(:name) { |n| "Status #{n}" }
  end
end
