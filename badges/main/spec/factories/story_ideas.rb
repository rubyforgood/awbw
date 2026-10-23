FactoryBot.define do
  factory :story_idea do
    association :windows_type
    association :organization
    title { "My Title" }
    rhino_body { "<p>My Body</p>" }
    permission_given { true }
    association :created_by, factory: :user
    association :updated_by, factory: :user

    transient do
      workshop { association :workshop }
      external_workshop_title { nil }
    end

    after(:build) do |story_idea, evaluator|
      next if story_idea.story_idea_workshops.any?
      story_idea.story_idea_workshops.build(workshop: evaluator.workshop) if evaluator.workshop
      story_idea.story_idea_workshops.build(external_workshop_title: evaluator.external_workshop_title) if evaluator.external_workshop_title.present?
    end

    trait :funder_only do
      funder_only { true }
    end

    trait :with_story do
      after(:create) do |story_idea, evaluator|
        create(:story,
               title: story_idea.title,
               rhino_body: story_idea.rhino_body,
               workshop: evaluator.workshop,
               windows_type: story_idea.windows_type,
               organization: story_idea.organization,
               created_by: story_idea.created_by,
               story_idea: story_idea)
      end
    end
  end
end
