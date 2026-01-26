class Event < ApplicationRecord
  include TagFilterable, Trendable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy
  # has_many through
  has_many :registrants, through: :event_registrations, class_name: "User"
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Validations
  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :publicly_visible, in: [ true, false ]
  validates_numericality_of :cost_cents, greater_than_or_equal_to: 0, allow_nil: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :description
  end

  scope :featured, -> { where(featured: true) }
  scope :visitor_featured, -> { where(visitor_featured: true) }
  scope :published, ->(published = nil) { publicly_visible(published) }
  scope :publicly_visible, ->(publicly_visible = nil) { publicly_visible ? where(publicly_visible: publicly_visible): where(publicly_visible: true) }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }

  def self.search_by_params(params)
    stories = self.all
    stories = stories.search(params[:query]) if params[:query].present?
    stories = stories.sector_names(params[:sector_names]) if params[:sector_names].present?
    stories = stories.category_names(params[:category_names]) if params[:category_names].present?
    stories = stories.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    stories
  end

  def inactive?
    !publicly_visible
  end

  def registerable?
    publicly_visible &&
      (registration_close_date.nil? || registration_close_date >= Time.current)
  end

  def full_name
    "#{ title } (#{ start_date.strftime("%Y-%m-%d @ %I:%M %p") })"
  end

  def name
    title
  end

  # Virtual attribute for cost in dollars (converts to/from cost_cents)
  def cost
    return nil if cost_cents.nil?
    cost_cents / 100.0
  end

  def cost=(dollar_amount)
    if dollar_amount.blank?
      self.cost_cents = nil
    else
      dollar_amount = dollar_amount.to_s.gsub(/[^\d.]/, "").to_f
      self.cost_cents = (dollar_amount.to_f * 100).round
    end
  end
end
