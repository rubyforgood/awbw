FactoryBot.define do
  factory :bookmark do
    # Association: belongs_to :user
    association :user

    # Polymorphic association: belongs_to :bookmarkable
    # Needs a bookmarkable instance, e.g., a Workshop or other model
    association :bookmarkable, factory: :workshop

    # Add other attributes if any (e.g., created_at, updated_at are handled by Rails)
  end
end 