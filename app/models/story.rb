class Story < ApplicationRecord
  include TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

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
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  has_rich_text :rhino_body

  # Validations
  validates :windows_type_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :title, presence: true, uniqueness: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :published, facilitator_first: "facilitators.first_name", facilitator_last: "facilitators.last_name"

    scope { join_rich_texts.left_joins(created_by: :facilitator) }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  # Scopes
  scope :featured, -> { where(featured: true) }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }
  scope :story_name, ->(story_name) {
    story_name.present? ? where("stories.name LIKE ?", "%#{story_name}%") : all }
  scope :published, ->(published = nil) {
    [ "true", "false" ].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }

  def self.search_by_params(params)
    conditions = {}
    conditions[:title] = params[:title] if params[:title].present?
    conditions[:query] = params[:query] if params[:query].present?
    conditions[:published] = params[:published_search] if params[:published_search].present?

    self.search(conditions)
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
