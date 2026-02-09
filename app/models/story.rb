class Story < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :windows_type
  belongs_to :organization, optional: true
  belongs_to :spotlighted_facilitator, class_name: "Person",
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
    attributes :title, :published, person_first: "people.first_name", person_last: "people.last_name"

    scope { join_rich_texts.left_joins(created_by: :person) }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  # Scopes
  # See Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable
  scope :story_name, ->(story_name) {
    story_name.present? ? where("stories.name LIKE ?", "%#{story_name}%") : all }

  def self.search_by_params(params)
    conditions = {}
    conditions[:title] = params[:title] if params[:title].present?
    conditions[:query] = params[:query] if params[:query].present?
    conditions[:published] = params[:published] if params[:published].present?
    stories = self.search(conditions)

    stories = stories.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    stories = stories.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    stories
  end

  def name
    title
  end

  def organization_name
    organization&.name
  end

  def organization_locality
    organization&.organization_locality
  end

  def organization_description
    organization&.organization_description
  end

  def attach_assets_from_idea!
    return unless story_idea
    story_idea.assets.find_each do |asset|
      new_asset = assets.build(type: asset.type)
      new_asset.file.attach(asset.file.blob)
    end

    save!
  end
end
