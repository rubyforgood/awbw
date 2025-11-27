class WindowsType < ApplicationRecord
  TYPES = ["ADULT", "CHILDREN", "COMBINED"]

  has_many :categorizable_items, dependent: :destroy, as: :categorizable
  has_many :form_builders
  has_many :reports
  has_many :workshops

  # has_many :through
  has_many :age_ranges, -> { joins(:category_type).where(metadata: { name: "AgeRange" }) },
           through: :categorizable_items, source: :category # needs to be after has_many :categorizable_items
  has_many :categories, through: :categorizable_items
  has_many :category_types, through: :categories

  validates :name, presence: true
  validates :short_name, presence: true
end
