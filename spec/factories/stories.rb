FactoryBot.define do
  factory :story do
    association :windows_type
    association :organization
    association :workshop
    association :created_by, factory: :user
    association :updated_by, factory: :user
    sequence(:title) { |n| "Story #{n}" }
    rhino_body { "<p>My Body</p>" }

    after(:create) do |story, _evaluator|
      if story.story_workshops.empty?
        story.story_workshops.create!(workshop: story.workshop) if story.workshop
        if story.external_workshop_title.present?
          story.story_workshops.create!(external_workshop_title: story.external_workshop_title)
        end
      end
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
