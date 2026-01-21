FactoryBot.define do
  factory :story do
    association :windows_type
    association :project
    association :workshop
    title { Faker::Lorem.sentence }
    rhino_body { "<p>My Body</p>" }
    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
