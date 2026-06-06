class Sector < ApplicationRecord
  include NameFilterable, Publishable
  SECTOR_TYPES = [
    "Child Abuse",
    "Community Oppression/Violence",
    "Criminal/Legal",
    "Disability",
    "Domestic Violence",
    "Education/Schools",
    "Foster Care/Adoption",
    "Homeless",
    "Human Trafficking",
    "Immigration",
    "Incarceration",
    "Indigenous/Tribal Nation",
    "LGBTQIA+",
    "Mental Health",
    "Reproductive",
    "Restorative/Transformative Justice",
    "Sexual Assault",
    "Student",
    "Substance Use",
    "Veterans & Military",
    "Other"
  ]

  STORY_DISPLAY_TEXT = "Which sectors does this story fit into?"
  VIDEO_DISPLAY_TEXT = "Which sectors apply?"

  has_many :sectorable_items, dependent: :destroy
  has_many :workshops, through: :sectorable_items,
           source: :sectorable, source_type: "Workshop"
  # has_many through
  has_many :quotes, through: :workshops

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Cache expiration
  after_save :expire_sectors_cache
  after_destroy :expire_sectors_cache

  # Scopes
  scope :sector_name, ->(sector_name) {
    sector_name.present? ? where("sectors.name LIKE ?", "%#{sector_name}%") : all }
  scope :sector_ids, ->(ids) { where(id: ids.to_s.split("-").map(&:to_i)) }
  scope :has_taggings, -> { joins(:sectorable_items).distinct }
  scope :has_published_taggings, -> {
    subqueries = Tag::TAGGABLE_META.map do |_key, data|
      klass = data[:klass]
      klass.published
           .joins(:sectorable_items)
           .where("sectorable_items.sector_id = sectors.id")
           .select("1")
           .arel.exists
    end

    where(subqueries.reduce(:or))
  }

  scope :filter_scope, ->(params) do
    filtered = self.all
    filtered = filtered.sector_name(params[:sector_name])
    filtered = filtered.sector_ids(params[:sector_ids]) if params[:sector_ids].present?
    filtered = filtered.published if params[:published] == "true"
    filtered = filtered.where(published: false) if params[:published] == "false"
    filtered
  end

  private

  def expire_sectors_cache
    Rails.cache.delete("published_sectors_with_sectorable_items")
  end
end
