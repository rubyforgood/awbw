class Story < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :windows_type
  belongs_to :project, optional: true
  belongs_to :spotlighted_facilitator, class_name: "Facilitator",
             foreign_key: "spotlighted_facilitator_id", optional: true
  belongs_to :story_idea, optional: true
  belongs_to :workshop, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Validations
  validates :windows_type_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :title, presence: true, uniqueness: true
  validates :body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :body
  end

  # Scopes
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :featured, -> { where(featured: true) }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }
  scope :story_name, ->(story_name) {
    story_name.present? ? where("stories.name LIKE ?", "%#{story_name}%") : all }
  scope :published, ->(published = nil) {
    [ "true", "false" ].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }

  def self.search_by_params(params)
    stories = self.all
    stories = stories.search(params[:query]) if params[:query].present?
    stories = stories.sector_names(params[:sector_names]) if params[:sector_names].present?
    stories = stories.category_names(params[:category_names]) if params[:category_names].present?
    stories = stories.story_name(params[:story_name]) if params[:story_name].present?
    stories = stories.published_search(params[:published_search]) if params[:published_search].present?
    stories = stories.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    stories
  end

  def name
    title
  end

  def organization_name
    project&.name
  end

  def organization_locality
    project&.organization_locality
  end

  def organization_description
    project&.organization_description
  end
end
