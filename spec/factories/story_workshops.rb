FactoryBot.define do
  factory :story_workshop do
    association :story, workshop: nil
    association :workshop
  end
end
