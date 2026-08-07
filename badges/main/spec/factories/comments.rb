FactoryBot.define do
  factory :comment do
    topic { "Test topic" }
    body { "This is a test comment" }

    # Polymorphic association: belongs_to :commentable
    association :commentable, factory: :user

    trait :flagged do
      flagged { true }
    end

    trait :for_person do
      association :commentable, factory: :person
    end

    trait :for_event_registration do
      association :commentable, factory: :event_registration
    end

    trait :for_workshop do
      association :commentable, factory: :workshop
    end

    trait :for_scholarship do
      association :commentable, factory: :scholarship
    end

    trait :for_continuing_education_registration do
      association :commentable, factory: :continuing_education_registration
    end
  end
end
