class Resource < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable
  include Rails.application.routes.url_helpers
  include ActionText::Attachable

  PUBLISHED_KINDS = [ "Handout", "Scholarship", "Template", "Toolkit", "Form" ]
  KINDS = PUBLISHED_KINDS + [ "Resource", "Story", "LeaderSpotlight", "SectorImpact", "Theme" ]

  has_rich_text :rhino_text

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
  has_many :attachments, as: :owner, dependent: :destroy # TODO - convert to GalleryImages
  has_many :images, as: :owner, dependent: :destroy # TODO - convert to GalleryImages
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  has_many :action_text_mentions,
           as: :mentionable,
           dependent: :destroy

  has_many :action_text_rich_texts,
           through: :action_text_mentions

  # Default values
  attribute :inactive, :boolean, default: false

  # Validations
  validates :title, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :gallery_assets, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :form, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :categorizable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }
  accepts_nested_attributes_for :sectorable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :title, :author, :text
  end

  # Scopes
  scope :by_created, -> { order(created_at: :desc) }
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }
  scope :featured, ->(featured = nil) { featured.present? ? where(featured: featured) : where(featured: true) }
  scope :kinds, ->(kinds) {
    kinds = Array(kinds).flatten.map(&:to_s)
    where(kind: kinds)
  }
  scope :leader_spotlights, -> { kinds("LeaderSpotlight") }
  scope :published_kinds, -> { where(kind: PUBLISHED_KINDS) }
  scope :published, ->(published = nil) {
    if [ "true", "false" ].include?(published)
      result = where(inactive: published == "true" ? false : true)
    else
      result = where(inactive: false)
    end
    result.published_kinds
  }
  scope :published_search, ->(published_search = nil) { published_search.present? ? published(published_search) : published_kinds }

  scope :recent, -> { published.by_created }
  scope :sector_impact, -> { where(kind: "SectorImpact") }
  scope :scholarship, -> { where(kind: "Scholarship") }
  scope :story, -> { where(kind: [ "Story", "LeaderSpotlight" ]).order(created_at: :desc) }
  scope :theme, -> { where(kind: "Theme") }
  scope :title, ->(title) { where("title like ?", "%#{ title }%") }

  def self.search_by_params(params)
    resources = all
    resources = resources.search(params[:query]) if params[:query].present? # SearchCop incl title, author, text
    resources = resources.sector_names(params[:sector_names]) if params[:sector_names].present?
    resources = resources.category_names(params[:category_names]) if params[:category_names].present?
    resources = resources.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    resources = resources.title(params[:title]) if params[:title].present?
    resources = resources.kinds(params[:kinds]) if params[:kinds].present?
    resources = resources.published_search(params[:published_search]) if params[:published_search].present?
    resources = resources.featured(params[:featured]) if params[:featured].present?
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

  def download_attachment
    primary_asset || gallery_assets.first || attachments.first
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

  ## ActionText:Attachable
  def attachable_content_type
    "application/vnd.active_record.resource"
  end
  # Used when editing
  def to_trix_content_attachment_partial_path
    "resource_mentions/trix_content_attachment"
  end

  # Used when displaying
  def to_attachable_partial_path
    "shared/mentions/attachable"
  end

  private
  def self.reject?(resource)
    resource["_create"] == "0"
  end
end
