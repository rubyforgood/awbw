FactoryBot.define do
  factory :quotable_item_quote do
    # Association: belongs_to :quote
    association :quote

    # Polymorphic association: belongs_to :quotable
    # Needs a quotable instance, e.g., a Report
    association :quotable, factory: :report
  end
end 