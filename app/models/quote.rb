class Quote < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :workshop, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :quotable_item_quotes, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  validates :quote, presence: true, unless: -> { quote.blank? }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :quote
  end

  scope :active, ->(active=nil) { active ? where(inactive: !active) : where(inactive: false) }
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :published, ->(published=nil) { published ? active(published) : active }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }

  def self.search_by_params(params)
    quotes = all
    quotes = quotes.search(params[:query]) if params[:query].present? # SearchCop incl title, author, text
    quotes = quotes.sector_names(params[:sector_names]) if params[:sector_names].present?
    quotes = quotes.category_names(params[:category_names]) if params[:category_names].present?
    quotes = quotes.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    quotes = quotes.published(params[:published]) if params[:published].present?
    quotes = quotes.featured(params[:featured]) if params[:featured].present?
    quotes
  end

  def speaker
    speaker_name.nil? || speaker_name.empty?  ? "Participant" : speaker_name
  end

  def name
    quote.truncate(30)
  end
end
