FactoryBot.define do
  factory :story do
    association :windows_type
    association :project
    association :workshop
    title { "My Title" }
    body { "My Body" }
    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
