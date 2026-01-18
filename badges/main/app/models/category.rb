class Category < ApplicationRecord
  include NameFilterable

  belongs_to :category_type, class_name: "CategoryType", foreign_key: :metadatum_id
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: "Workshop"

  scope :age_ranges, -> { joins(:category_type).where("metadata.name = 'AgeRange'") }
  scope :published, -> { where(published: true) }

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Scopes
  scope :category_type_id, ->(category_type_id) {
    category_type_id.present? ? where(metadatum_id: category_type_id) : all }
  scope :category_name, ->(category_name) {
    category_name.present? ? where("categories.name LIKE ?", "%#{category_name}%") : all }
  scope :published, ->(published = nil) {
    [ "true", "false" ].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }
end
