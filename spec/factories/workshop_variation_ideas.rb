FactoryBot.define do
  factory :workshop_variation_idea do
    sequence(:name) { |n| "Workshop Variation Idea #{n}" }
    rhino_body { "<p>This is a variation idea description</p>" }
    youtube_url { "https://www.youtube.com/watch?v=example" }
    permission_given { true }
    publish_preferences { "public" }
    association :workshop
    association :organization
    association :windows_type
    association :created_by, factory: :user
    association :updated_by, factory: :user
  end
end
