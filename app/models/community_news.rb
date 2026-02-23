class CommunityNews < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

  has_rich_text :rhino_body

  belongs_to :organization, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :author, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
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
  validates :author_id, presence: true
  validates :title, presence: true, length: { maximum: 150 }
  validates :rhino_body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # Scopes
  # See Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :published, person_first: "people.first_name", person_last: "people.last_name"

    scope { join_rich_texts.left_joins(author: :person) }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
  end

  scope :by_year, ->(year) { where(created_at: Date.new(year.to_i)..Date.new(year.to_i).end_of_year) }

  scope :community_news_name, ->(community_news_name) {
    community_news_name.present? ? where("community_news.name LIKE ?", "%#{community_news_name}%") : all }

  def self.search_by_params(params)
    conditions = {}
    conditions[:title] = params[:title] if params[:title].present?
    conditions[:query] = params[:query] if params[:query].present?

    # Use visibility checkbox filters when present; otherwise pass published to SearchCop
    if visibility_params_present?(params)
      community_news = apply_visibility_filters(self.search(conditions), params)
    else
      conditions[:published] = params[:published] if params[:published].present?
      community_news = self.search(conditions)
    end

    community_news = community_news.by_year(params[:year]) if params[:year].present? && params[:year].match?(/\A\d{4}\z/)
    community_news = community_news.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    community_news = community_news.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    community_news
  end
end
