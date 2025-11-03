FactoryBot.define do
  factory :story_idea do
    association :windows_type
    association :project
    association :workshop
    title { "My Title" }
    body { "My Body" }
    permission_given { true }
    publish_preferences { "I would like my full name published with the story" }
    association :created_by, factory: :user
    association :updated_by, factory: :user

    trait :with_story do
      after(:create) do |story_idea|
        create(:story,
               title: story_idea.title,
               body: story_idea.body,
               workshop: story_idea.workshop,
               windows_type: story_idea.windows_type,
               project: story_idea.project,
               created_by: story_idea.created_by,
               story_idea: story_idea)
      end
    end
  end
end
