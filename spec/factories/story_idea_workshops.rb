FactoryBot.define do
  factory :story_idea_workshop do
    association :story_idea, workshop: nil
    association :workshop
  end
end
