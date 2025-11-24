class Resource < ApplicationRecord
  include Rails.application.routes.url_helpers

  PUBLISHED_KINDS = ["Handout", "Scholarship", "Template", "Toolkit", "Form"]
  KINDS = PUBLISHED_KINDS + ["Resource", "Story"]

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

  # Image associations
  has_many :attachments, as: :owner, dependent: :destroy # TODO - convert to GalleryImages
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Default values
  attribute :inactive, :boolean, default: false

  # Validations
  validates :title, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, presence: true

  # Nested attributes
  accepts_nested_attributes_for :main_image, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :gallery_images, reject_if: :all_blank, allow_destroy: true
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
  scope :featured, -> (featured=nil) { featured.present? ? where(featured: featured) : where(featured: true) }
  scope :kind, -> (kind) { where("kind like ?", kind ) }
  scope :leader_spotlights, -> { kind("LeaderSpotlight") }
  scope :published_kinds, -> { where(kind: PUBLISHED_KINDS) }
  scope :published, -> (published=nil) { published.present? ?
                                           where(inactive: !published) : where(inactive: false) }
  scope :recent, -> { published.by_created }
  scope :sector_impact, -> { where(kind: "SectorImpact") }
  scope :scholarship, -> { where(kind: "Scholarship") }
  scope :story, -> { where(kind: ["Story", "LeaderSpotlight"]).order(created_at: :desc) }
  scope :theme, -> { where(kind: "Theme") }
  scope :title, -> (title) { where("title like ?", "%#{ title }%") }

  def description
    text # TODO - rename field
  end
  def story?
    ["Story", "LeaderSpotlight"].include? self.kind
  end

  def custom_label_list
    "#{self.title} (#{self.kind.upcase})" unless self.kind.nil?
  end

  # Methods
  def led_count
    0
  end

  def name
    title || id
  end

  def main_image_url
    if main_image&.file&.attached?
      Rails.application.routes.url_helpers.url_for(main_image.file)
    elsif gallery_images.first&.file&.attached?
      Rails.application.routes.url_helpers.url_for(gallery_images.first.file)
    else
      ActionController::Base.helpers.asset_path("theme_default.png")
    end
  end

  def download_attachment
    main_image || gallery_images.first || attachments.first
  end

  def type_enum
    types.map { |title| [title.titleize, title ]}
  end

  def types
    ['Resource', 'LeaderSpotlight', 'SectorImpact',
     'Story', 'Theme', 'Scholarship', 'TemplateAndHandout',
     'ToolkitAndForm'
    ]
  end

  def year
    created_at.year
  end

  def month
    created_at.month
  end

  def self.search_by_params(params)
    resources = all
    resources = resources.search(params[:query]) if params[:query].present? # SearchCop incl title, author, text
    resources = resources.title(params[:title]) if params[:title].present?
    resources = resources.kind(params[:kind]) if params[:kind].present?
    resources = resources.published(params[:published]) if params[:published].present?
    resources = resources.featured(params[:featured]) if params[:featured].present?
    resources
  end

  private
  def self.reject?(resource)
    resource['_create'] == '0'
  end
end
