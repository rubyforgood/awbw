class WindowsType < ApplicationRecord
  TYPES = [ "Adult", "Children", "Combined" ]

  has_many :categorizable_items, dependent: :destroy, as: :categorizable
  has_many :form_builders
  has_many :reports
  has_many :workshops

  # has_many :through
  has_many :age_ranges, -> { joins(:category_type).where(category_types: { name: "AgeRange" })
                                                  .order(Arel.sql("categories.position ASC, categories.name ASC")) },
           through: :categorizable_items,
           source: :category # needs to be after has_many :categorizable_items
  has_many :categories, through: :categorizable_items
  has_many :category_types, through: :categories

  validates :name, presence: true
  validates :short_name, presence: true

  # AgeRange categories tagged on this windows type, read from already-loaded
  # categorizable_items (no query) so the organizations index can compare them
  # against an org's age-range tags without an N+1. Use the :age_ranges
  # association when you want them ordered and don't already have the items loaded.
  def tagged_age_range_categories
    categorizable_items.map(&:category).compact.select { |category| category.category_type&.name == "AgeRange" }
  end
end
