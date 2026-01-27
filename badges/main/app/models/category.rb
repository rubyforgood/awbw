class Category < ApplicationRecord
  include NameFilterable
  include Positioning

  positioned on: :category_type_id

  belongs_to :category_type, class_name: "CategoryType", foreign_key: :category_type_id
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: "Workshop"

  scope :age_ranges, -> { joins(:category_type).where("category_types.name = 'AgeRange'") }
  scope :published, -> { where(published: true) }
  scope :ordered_by_position_and_name, -> { reorder(position: :asc, name: :asc) }

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :position, numericality: {
    only_integer: true,
    greater_than: 0,
    allow_nil: true # position gem handles assigning after validations so it needs to allow nil
  }

  # Cache expiration
  after_save :expire_categories_cache
  after_destroy :expire_categories_cache

  # Scopes
  scope :category_type_id, ->(category_type_id) {
    category_type_id.present? ? where(category_type_id: category_type_id) : all }
  scope :category_name, ->(category_name) {
    category_name.present? ? where("categories.name LIKE ?", "%#{category_name}%") : all }
  scope :published, ->(published = nil) {
    [ "true", "false" ].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }

  private

  def expire_categories_cache
    Rails.cache.delete("published_categories_by_type")
  end
end
