FactoryBot.define do
  factory :workshop_variation_idea do
    name { "Workshop Variation Idea" }
    description { "This is a variation idea description" }
    youtube_url { "https://www.youtube.com/watch?v=example" }
    inactive { true }
    position { 1 }
    association :workshop
    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
