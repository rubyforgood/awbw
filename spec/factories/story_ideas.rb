FactoryBot.define do
  factory :story_idea do
    association :windows_type
    association :organization
    association :workshop
    title { "My Title" }
    rhino_body { "<p>My Body</p>" }
    permission_given { true }
    publish_preferences { "I would like my full name published with the story" }
    association :created_by, factory: :user
    association :updated_by, factory: :user

    trait :with_story do
      after(:create) do |story_idea|
        create(:story,
               title: story_idea.title,
               rhino_body: story_idea.rhino_body,
               workshop: story_idea.workshop,
               windows_type: story_idea.windows_type,
               organization: story_idea.organization,
               created_by: story_idea.created_by,
               story_idea: story_idea)
      end
    end
  end
end
