class Story < ApplicationRecord
  include AuthorCreditable
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

  has_rich_text :rhino_body

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :windows_type
  belongs_to :organization, optional: true
  belongs_to :spotlighted_facilitator, class_name: "Person",
             foreign_key: "spotlighted_facilitator_id", optional: true
  belongs_to :author, class_name: "Person", optional: true
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

  # Validations
  validates :windows_type_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :title, presence: true, uniqueness: true
  validates :rhino_body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes all: [ :title, :published ]
    attributes :title, :published
    attributes person_first: "people.first_name", person_last: "people.last_name"
    options :all, type: :text, default: true, default_operator: :or

    scope { join_rich_texts.left_joins(created_by: :person) }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  # Scopes
  # See Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable
  scope :by_year, ->(year) { where(created_at: Date.new(year.to_i)..Date.new(year.to_i).end_of_year) }
  scope :story_name, ->(story_name) { story_name.present? ? where("stories.name LIKE ?", "%#{story_name}%") : all }
  scope :facilitator_spotlights, ->(value = nil) {
    return where.not(spotlighted_facilitator_id: nil) if value.blank?
    ActiveModel::Type::Boolean.new.cast(value) ?
      where.not(spotlighted_facilitator_id: nil) :
      where(spotlighted_facilitator_id: nil)
  }

  def self.search_by_params(params)
    conditions = {}
    conditions[:title] = params[:title] if params[:title].present?
    conditions[:query] = params[:query] if params[:query].present?

    # Use visibility checkbox filters when present; otherwise pass published to SearchCop
    if visibility_params_present?(params)
      stories = apply_visibility_filters(self.search(conditions), params)
    else
      conditions[:published] = params[:published] if params[:published].present?
      stories = self.search(conditions)
    end

    stories = stories.by_year(params[:year]) if params[:year].present? && params[:year].match?(/\A\d{4}\z/)
    stories = stories.facilitator_spotlights(params[:facilitator_spotlights]) if params[:facilitator_spotlights].present?
    stories = stories.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    stories = stories.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    stories = stories.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    stories
  end

  def name
    title
  end

  # AuthorCreditable: prefer the explicitly chosen author, falling back to the
  # creating user's person so stories predating the author field stay credited.
  def author_person
    author || created_by&.person
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

  def sector_names_all
    sectors.pluck(:name)
  end

  def attach_assets_from_idea!
    return unless story_idea

    has_primary = primary_asset&.file&.attached?
    story_idea.assets.order(:id).each do |asset|
      new_type = if !has_primary && asset.type == "GalleryAsset"
        has_primary = true
        "PrimaryAsset"
      else
        "GalleryAsset"
      end
      new_asset = assets.build(type: new_type)
      new_asset.file.attach(asset.file.blob)
    end

    save!
  end
end
