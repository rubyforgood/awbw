FactoryBot.define do
  factory :story_workshop do
    association :story
    association :workshop
  end
end
