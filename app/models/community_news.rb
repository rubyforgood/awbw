class CommunityNews < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :project, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :author, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
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

  # Validations
  validates :author_id, presence: true
  validates :title, presence: true, length: { maximum: 150 }
  validates :body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :body
  end

  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :featured, -> { where(featured: true) }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }
  scope :community_news_name, ->(community_news_name) {
    community_news_name.present? ? where("community_news.name LIKE ?", "%#{community_news_name}%") : all }
  scope :published, ->(published=nil) {
    ["true", "false"].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }

  def self.search_by_params(params)
    community_news = self.all
    community_news = community_news.search(params[:query]) if params[:query].present?
    community_news = community_news.sector_names(params[:sector_names]) if params[:sector_names].present?
    community_news = community_news.category_names(params[:category_names]) if params[:category_names].present?
    community_news = community_news.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    community_news = community_news.published_search(params[:published_search]) if params[:published_search].present?
    community_news
  end

end
