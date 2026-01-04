FactoryBot.define do
  factory :project_status do
    sequence(:name) { |n| "Status #{n}" }
  end
end
