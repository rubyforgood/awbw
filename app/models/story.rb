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
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy

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
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }

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

  # Credited-author name search (explicit author + creator fallback) comes from
  # AuthorCreditable#by_credited_person_name, OR-ed into full-text results below.

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

    # Use visibility checkbox filters when present; otherwise pass published to SearchCop
    if visibility_params_present?(params)
      stories = apply_visibility_filters(self.search(conditions), params)
    else
      conditions[:published] = params[:published] if params[:published].present?
      stories = self.search(conditions)
    end

    # Keyword search matches the title, the rich-text body, and the credited
    # author/creator name, OR-ed together via id subqueries so SearchCop's joins
    # and the `people` joins stay isolated from each other. (A plain LIKE handles
    # the title because SearchCop's default group pairs it with the boolean
    # `published` column and won't match a title on its own.)
    if params[:query].present?
      query = params[:query]
      stories = stories.where("stories.title LIKE ?", "%#{query}%")
                       .or(stories.where(id: self.search(query).select("stories.id")))
                       .or(stories.where(id: by_credited_person_name(query).select("stories.id")))
    end

    stories = stories.by_year(params[:year]) if params[:year].present? && params[:year].match?(/\A\d{4}\z/)
    stories = stories.facilitator_spotlights(params[:facilitator_spotlights]) if params[:facilitator_spotlights].present?
    stories = stories.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    stories = stories.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    stories = stories.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    stories = stories.authored_by(params[:author_id])
    stories
  end

  # Shareable, readable URLs (story_path, polymorphic_path, etc.): the id followed
  # by the title slugged with hyphens and bad URL characters stripped, e.g.
  # "23-my-great-story". Rails resolves it back via `id.to_i`, so `/stories/23`
  # and `/stories/23/edit` (which pass the bare id) keep working.
  def to_param
    return id&.to_s if title.blank?
    "#{id}-#{title.parameterize}"
  end

  def name
    title
  end

  # Email the communications box matches notifications against. Uniform accessor
  # so the shared notifications/_communications partial works across records.
  def communications_email
    author_person&.preferred_email
  end

  # Unattributed stories are credited to the facilitator who shared them.
  def missing_author_label
    "AWBW Facilitator"
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

  # StoryPopulation categories describe who a story is about (Children, Teens,
  # Adults, …) — the portal's audience facet.
  AUDIENCE_CATEGORY_TYPE = "StoryPopulation"

  def audience_categories
    categories.joins(:category_type).where(category_types: { name: AUDIENCE_CATEGORY_TYPE })
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
