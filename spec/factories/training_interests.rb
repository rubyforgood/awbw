FactoryBot.define do
  factory :training_interest do
    association :person
    event { nil }
    status { "open" }
    source { "Facilitator Training registration" }

    trait :for_event do
      association :event, factory: :event
    end

    trait :converted do
      status { "converted" }
    end

    trait :closed do
      status { "closed" }
    end
  end
end
