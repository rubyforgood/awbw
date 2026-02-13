class Resource < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable
  include Rails.application.routes.url_helpers
  include ActionText::Attachable
  include Mentioner

  # Define rich text fields for mentions functionality
  def self.mentionable_rich_text_fields
    [ :rhino_body ]
  end

  PUBLISHED_KINDS = [ "Handout", "Template", "Toolkit", "Form" ]
  KINDS = PUBLISHED_KINDS + [ "Resource", "Story", "LeaderSpotlight", "SectorImpact", "Theme", "Scholarship" ]

  has_rich_text :rhino_body

  belongs_to :user
  belongs_to :workshop, optional: true
  belongs_to :windows_type, optional: true
  has_one :form, as: :owner
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, as: :categorizable
  has_many :reports, as: :owner
  has_many :sectorable_items, dependent: :destroy, as: :sectorable
  has_many :workshop_resources, dependent: :destroy

  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :related_workshops, through: :sectors, source: :workshops
  has_many :sectors, through: :sectorable_items, source: :sector

  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy
  has_one :downloadable_asset, -> { where(type: "DownloadableAsset") },
         as: :owner, class_name: "DownloadableAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  has_many :action_text_mentions,
           as: :mentionable,
           dependent: :destroy

  has_many :action_text_rich_texts,
           through: :action_text_mentions

  # Default values
  attribute :published, :boolean, default: false

  # Validations
  validates :title, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :downloadable_asset, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :gallery_assets, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :form, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :categorizable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }
  accepts_nested_attributes_for :sectorable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }

  # Search Cop — only attributes on resources table so MATCH() uses the FULLTEXT index (title, author, body).
  # No join to action_text_rich_texts; that would require MATCH across two tables, which MySQL cannot index.
  include SearchCop
  search_scope :search do
    attributes :title, :author, :body

    # scope { join_rich_texts }
    # attributes action_text_body: "action_text_rich_texts.plain_text_body"
    # options :action_text_body, type: :text, default: true, default_operator: :or
  end

  # Scopes
  scope :by_created, -> { order(created_at: :desc) }
  scope :by_featured_first, -> { order(featured: :desc, created_at: :desc) }
  scope :kinds, ->(kinds) {
    kinds = Array(kinds).flatten.map(&:to_s)
    where(kind: kinds) }
  scope :leader_spotlights, -> { kinds("LeaderSpotlight") }
  scope :published_kinds, -> { where(kind: PUBLISHED_KINDS) }
  scope :published, ->(flag = nil) do
    value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
    result = value ? published_kinds.where(published: true) : where(published: false)
  end
  scope :recent, -> { published.by_created }
  scope :sector_impact, -> { where(kind: "SectorImpact") }
  scope :scholarship, -> { where(kind: "Scholarship") }
  scope :story, -> { where(kind: [ "Story", "LeaderSpotlight" ]).order(created_at: :desc) }
  scope :theme, -> { where(kind: "Theme") }
  scope :title, ->(title) { where("title like ?", "%#{ title }%") }

  def self.search_by_params(params)
    resources = is_a?(ActiveRecord::Relation) ? self : all
    resources = resources.search(params[:query]) if params[:query].present? # SearchCop incl title, author, body
    resources = resources.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    resources = resources.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    resources = resources.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    resources = resources.title(params[:title]) if params[:title].present?
    resources = resources.kinds(params[:kinds]) if params[:kinds].present?
    resources = resources.published(params[:published]) if params[:published].present?
    resources
  end

  def story?
    [ "Story", "LeaderSpotlight" ].include? self.kind
  end

  def custom_label_list
    "#{self.title} (#{self.kind.upcase})" unless self.kind.nil?
  end

  def name
    title || id
  end

  def type_enum
    types.map { |title| [ title.titleize, title ] }
  end

  def types
    [ "Resource", "LeaderSpotlight", "SectorImpact",
     "Story", "Theme", "Scholarship", "TemplateAndHandout",
     "ToolkitAndForm"
    ]
  end

  def year
    created_at.year
  end

  def month
    created_at.month
  end

  def published? # AR override
    self[:published] && PUBLISHED_KINDS.include?(kind)
  end

  ## ActionText:Attachable
  def attachable_content_type
    "application/vnd.active_record.resource"
  end

  private
  def self.reject?(resource)
    resource["_create"] == "0"
  end
end
