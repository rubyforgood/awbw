class Category < ApplicationRecord
  include NameFilterable, Publishable, RemoteSearchable
  remote_searchable_by :name

  positioned on: :category_type_id

  belongs_to :category_type, class_name: "CategoryType", foreign_key: :category_type_id
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: "Workshop"

  # Scopes
  # See NameFilterable, Publishable
  scope :age_ranges, -> { joins(:category_type).where(category_types: { name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE }) }
  scope :story_populations, -> { joins(:category_type).where(category_types: { name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE }) }
  scope :audiences, -> { joins(:category_type).where(category_types: { name: CategoriesTaggable::AUDIENCE_CATEGORY_TYPES }) }
  scope :story_categories, -> { joins(:category_type).where(category_types: { name: "StoryCategory" }) }
  scope :ordered_by_position_and_name, -> { reorder(position: :asc, name: :asc) }
  # Featured in the Story Share portal's audience nav, ordered by the admin-set position within its group.
  scope :story_share_featured, -> { where.not(story_share_position: nil).order(:story_share_position) }

  # The story forms' "Who is this story about?" tag set: age ranges, then story populations.
  def self.story_audience_rows
    [ age_ranges, story_populations ].map { |scope| scope.published.ordered_by_position_and_name.to_a }
  end

  # The Story Share audience nav is one row built from these groups in this order;
  # each group numbers its own story_share_position, so admins reorder within a group.
  def self.story_share_audience_groups
    CategoriesTaggable::AUDIENCE_CATEGORY_TYPES.index_with { |type_name| joins(:category_type).where(category_types: { name: type_name }) }
  end

  def self.story_share_audience_nav
    story_share_audience_groups.values.flat_map { |scope| scope.published.story_share_featured.to_a }
  end

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :position, numericality: {
    only_integer: true,
    greater_than: 0,
    allow_nil: true # position gem handles assigning after validations so it needs to allow nil
  }

  # Cache expiration
  after_save :expire_categories_cache
  after_destroy :expire_categories_cache

  # Scopes
  scope :has_taggings, -> { joins(:categorizable_items).distinct }
  scope :has_published_taggings, -> {
    subqueries = Tag::TAGGABLE_META.map do |_key, data|
      klass = data[:klass]
      klass.published
           .joins(:categorizable_items)
           .where("categorizable_items.category_id = categories.id")
           .select("1")
           .arel.exists
    end

    where(subqueries.reduce(:or))
  }
  scope :category_type_id, ->(category_type_id) {
    category_type_id.present? ? where(category_type_id: category_type_id) : all }
  scope :category_name, ->(category_name) {
    category_name.present? ? where("categories.name LIKE ?", "%#{category_name}%") : all }
  scope :category_names_all, ->(names) do
    return all if names.blank?
    parsed = Array(names).flat_map { |n| n.to_s.split("--") }.map(&:strip).reject(&:blank?).map(&:downcase)
    return all if parsed.empty?
    where("LOWER(categories.name) IN (?)", parsed)
  end

  private

  def expire_categories_cache
    Rails.cache.delete("published_categories_by_type")
  end
end
