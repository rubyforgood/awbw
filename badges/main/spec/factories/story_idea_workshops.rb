FactoryBot.define do
  factory :story_idea_workshop do
    association :story_idea
    association :workshop
  end
end
