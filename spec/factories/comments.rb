FactoryBot.define do
  factory :comment do
    body { "This is a test comment" }

    # Polymorphic association: belongs_to :commentable
    association :commentable, factory: :user

    trait :for_person do
      association :commentable, factory: :person
    end
  end
end
