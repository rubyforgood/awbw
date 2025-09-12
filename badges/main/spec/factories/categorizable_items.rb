FactoryBot.define do
  factory :categorizable_item do
    # Association: belongs_to :category
    association :category

    # Polymorphic association: belongs_to :categorizable
    # Needs a categorizable instance, e.g., a Workshop
    association :categorizable, factory: :workshop
  end
end 