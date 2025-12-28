class Event < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy
  # has_many through
  has_many :registrants, through: :event_registrations, class_name: "User"
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Validations
  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :publicly_visible, in: [true, false]

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :description
  end

  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :featured, -> { where(featured: true) }
  scope :published, ->(published=nil) { publicly_visible(published) }
  scope :publicly_visible, ->(publicly_visible=nil) { publicly_visible ? where(publicly_visible: publicly_visible): where(publicly_visible: true) }
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
end
