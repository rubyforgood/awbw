class Category < ApplicationRecord
  belongs_to :category_type, class_name: "CategoryType", foreign_key: :metadatum_id
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: 'Workshop'

  scope :age_ranges, -> { joins(:category_type).where("metadata.name = 'AgeRange'") }
  scope :published, -> { where(published: true) }

  # Validations
  validates_presence_of :name, uniqueness: true
end
