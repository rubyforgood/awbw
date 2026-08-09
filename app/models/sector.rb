class Sector < ApplicationRecord
  include NameFilterable, Publishable
  # Canonical sector tags, in display order. "Other" is kept at the end
  # as the catch-all free-text fallback for additional sectors (see
  # OTHER_SECTOR_NAME below) — it isn't a selectable tag itself. Descriptions for
  # these (the parenthetical clarifications) live in db/seeds.rb.
  SECTOR_TYPES = [
    "Batterers Intervention",
    "Child Abuse/Neglect",
    "Climate/Environmental",
    "Community Building",
    "Community Violence",
    "Court/Legal System",
    "Disability Services",
    "Domestic Violence",
    "Education",
    "Foster Care/Adoption",
    "Fundraising/Donor Engagement",
    "Grief/Loss",
    "Health/Medical",
    "Homelessness",
    "Human Trafficking",
    "Immigration",
    "Incarceration",
    "Indigenous/Tribal Nation",
    "LGBTQIA+",
    "Mental Health",
    "Military/Veterans",
    "Private Practice/Sole Proprietor",
    "Racial/Social Justice",
    "Religious/Faith-Based",
    "Reproductive Services",
    "Restorative/Transformative Justice",
    "Self-Care/Personal Growth",
    "Sexual Assault",
    "Staff/Organizational Development",
    "Substance Use/Recovery",
    "Systems/Policy Change",
    "Other"
  ]

  # The catch-all sector. Offered for "additional" sectors but not as a
  # respondent's single "primary" sector.
  OTHER_SECTOR_NAME = "Other"

  STORY_DISPLAY_TEXT = "Which sectors does this story fit into?"
  VIDEO_DISPLAY_TEXT = "Which sectors apply?"

  has_many :sectorable_items, dependent: :destroy
  has_many :workshops, through: :sectorable_items,
           source: :sectorable, source_type: "Workshop"
  has_many :stories, through: :sectorable_items,
           source: :sectorable, source_type: "Story"
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
  scope :sector_names_all, ->(names) do
    return all if names.blank?
    parsed = Array(names).flat_map { |n| n.to_s.split("--") }.map(&:strip).reject(&:blank?).map(&:downcase)
    return all if parsed.empty?
    where("LOWER(sectors.name) IN (?)", parsed)
  end
  scope :excluding_other, -> { where.not(name: OTHER_SECTOR_NAME) }
  # Featured in the Story Share portal, ordered by the admin-set position.
  scope :story_share_featured, -> { where.not(story_share_position: nil).order(:story_share_position) }
  scope :has_taggings, -> { joins(:sectorable_items).distinct }
  scope :taggings_presence, ->(value) do
    case value
    when "with" then has_taggings
    when "without" then where.missing(:sectorable_items)
    else all
    end
  end
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
    filtered = filtered.taggings_presence(params[:has_taggings])
    filtered
  end

  private

  def expire_sectors_cache
    Rails.cache.delete("published_sectors_with_sectorable_items")
    Rails.cache.delete("story_share_focus_area_sectors")
  end
end
