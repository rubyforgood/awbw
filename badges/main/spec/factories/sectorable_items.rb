FactoryBot.define do
  factory :sectorable_item do
    # Association: belongs_to :sector
    association :sector

    # Polymorphic association: belongs_to :sectorable
    # Needs a sectorable instance, e.g., a Workshop or Resource
    association :sectorable, factory: :workshop
  end
end 