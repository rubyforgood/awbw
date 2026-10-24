FactoryBot.define do
  factory :story do
    association :windows_type
    association :organization
    association :created_by, factory: :user
    association :updated_by, factory: :user
    sequence(:title) { |n| "Story #{n}" }
    rhino_body { "<p>My Body</p>" }

    transient do
      workshop { association :workshop }
      external_workshop_title { nil }
    end

    after(:build) do |story, evaluator|
      next if story.story_workshops.any?
      story.story_workshops.build(workshop: evaluator.workshop) if evaluator.workshop
      story.story_workshops.build(external_workshop_title: evaluator.external_workshop_title) if evaluator.external_workshop_title.present?
    end

    trait :featured do
      featured { true }
    end

    trait :published do
      published { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :publicly_visible do
      publicly_visible { true }
    end

    trait :publicly_featured do
      publicly_featured { true }
    end

    trait :funder_only do
      funder_only { true }
    end
  end
end
