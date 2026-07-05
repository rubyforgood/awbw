class CommunityNews < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable, AuthorCreditable

  has_rich_text :rhino_body

  belongs_to :organization, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :author, class_name: "Person", inverse_of: :community_news_as_author, optional: true
  # Legacy "display author" pick, before author became a person. Kept so
  # existing rows credit the chosen person without a backfill.
  belongs_to :legacy_author_user, class_name: "User", foreign_key: :legacy_author_user_id, optional: true
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
  # author is required in the form; left optional at the model so legacy rows
  # (created before author became a person) remain valid.
  validates :title, presence: true, length: { maximum: 150 }
  validates :rhino_body, presence: true

  # Credit the explicit person author, then the legacy display-author user's
  # person (the creating user's person is AuthorCreditable's final fallback) —
  # so existing rows keep their attribution without a backfill.
  def primary_author_person
    author || legacy_author_user&.person
  end

  # Fold the legacy display-author user's person into credited-name search and
  # sort, matching author_person's precedence.
  def self.legacy_credited_user_columns
    [ [ "legacy_author_user_id", "credited_legacy_author" ] ]
  end

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # Scopes
  # See Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :published, person_first: "people.first_name", person_last: "people.last_name"

    scope { join_rich_texts.left_joins(:author) }
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

    # SearchCop's free-text query covers title + body + the explicit author. Also
    # match the credited author/legacy author/creator by name, OR-ed in via id
    # subqueries so the extra person joins stay isolated from SearchCop's joins.
    if params[:query].present?
      community_news = self.where(id: community_news.select("community_news.id"))
                           .or(self.where(id: by_credited_person_name(params[:query]).select("community_news.id")))
    end

    community_news = community_news.by_year(params[:year]) if params[:year].present? && params[:year].match?(/\A\d{4}\z/)
    community_news = community_news.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    community_news = community_news.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    community_news = community_news.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    community_news = community_news.where(author_id: params[:author_id]) if params[:author_id].present?
    community_news
  end
end
