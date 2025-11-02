class Resource < ApplicationRecord
  include Rails.application.routes.url_helpers

  # Associations
  belongs_to :user
  belongs_to :workshop, optional: true
  belongs_to :windows_type, optional: true
  has_one :form, as: :owner
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :images, as: :owner, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, as: :categorizable
  has_many :categories, through: :categorizable_items
  has_many :sectorable_items, dependent: :destroy, as: :sectorable
  has_many :sectors, through: :sectorable_items, source: :sector
  has_many :related_workshops, through: :sectors, source: :workshops
  has_many :attachments, as: :owner, dependent: :destroy
  has_many :reports, as: :owner
  has_many :workshop_resources, dependent: :destroy

  validates :title, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, presence: true
  attribute :inactive, :boolean, default: false

  # Nested Attributes
  accepts_nested_attributes_for :categorizable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }

  accepts_nested_attributes_for :sectorable_items,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }
  accepts_nested_attributes_for :images,
                                 allow_destroy: true,
                                 reject_if: proc { |resource| Resource.reject?(resource) }
  accepts_nested_attributes_for :attachments, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :form, reject_if: :all_blank, allow_destroy: true

  KINDS = ['Toolkit', 'Form', 'Template', 'Handout', 'Story']
  POPULAR_KINDS = [nil, "Resource", "Template", "Handout", "Scholarship", "Toolkit", "Form"]

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
  scope :popular, -> { where(kind: POPULAR_KINDS) }
  scope :published, -> (published=nil) { published.present? ? where(inactive: !published) : where(inactive: false) }
  scope :recent, -> { published.by_created }
  scope :sector_impact, -> { where(kind: "SectorImpact") }
  scope :scholarship, -> { where(kind: "Scholarship") }
  scope :story, -> { where(kind: ["Story", "LeaderSpotlight"]).order(created_at: :desc) }
  scope :theme, -> { where(kind: "Theme") }
  scope :title, -> (title) { where("title like ?", "%#{ title }%") }

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

  def main_image
    images.first
  end

  def main_image_url
    if main_image&.file&.attached?
      Rails.application.routes.url_helpers.url_for(main_image.file)
    else
      ActionController::Base.helpers.asset_path("theme_default.png")
    end
  end

  def main_attachment
    attachments.first
  end

  def main_attachment_url
    if main_attachment&.file&.attached?
      Rails.application.routes.url_helpers.url_for(main_attachment.file)
    end
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
